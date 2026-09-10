// This file holds leaving, member removal, removal-policy changes, the group member roster, and
// RequireMember -- the single exported authorization gate every group-scoped read or write in a
// later plan (04.1-10, 04.1-12) calls before touching data. A bare fetch by a group's opaque
// UUID id is never acceptable on its own: the id being unguessable is not the same property as
// the caller actually belonging to the group, and membership is the real boundary.
//
// There is no ownership transfer and no automatic succession anywhere in this file. The organizer
// is a convenience role with no public standing (docs/group-events.md §1): nobody is elevated
// into it when the organizer leaves, because there is nothing public attached to the role for
// Strava's owner-handoff friction to protect here. Any remaining member can start the group's next
// goal-event; the group simply continues.
package groups

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// LeaveDisposition is the explicit, required choice a leaving member makes about their own past
// completions (docs/group-events.md §4: offered explicitly at the leave step, never defaulted
// either way).
type LeaveDisposition string

const (
	// DispositionKeepPosts leaves the caller's past completions visible to the group after they
	// leave.
	DispositionKeepPosts LeaveDisposition = "keepPosts"
	// DispositionRemovePosts hides the caller's past completions from the group's feed going
	// forward.
	DispositionRemovePosts LeaveDisposition = "removePosts"
)

var (
	// ErrRemovalNotPermitted is returned by RemoveMember when the group's removal policy does not
	// authorize the acting user to remove the target.
	ErrRemovalNotPermitted = errors.New("groups: removal not permitted under this group's policy")
	// ErrRemoveSelf is returned by RemoveMember when the actor names themself as the target.
	// Leaving is the dedicated route for that; removal is never self-directed.
	ErrRemoveSelf = errors.New("groups: cannot remove yourself; use leave instead")
)

// Member is one group_members row joined against its user's display name, for a group's roster
// view.
type Member struct {
	UserID      uuid.UUID
	DisplayName string
	JoinedAt    time.Time
}

// Members returns groupID's current roster, oldest-joined first. userID must already be a member
// -- Members is itself gated by RequireMember, so listing a group's roster is a group-scoped read
// like any other.
func (s *Service) Members(ctx context.Context, userID, groupID uuid.UUID) ([]Member, error) {
	if err := s.RequireMember(ctx, userID, groupID); err != nil {
		return nil, err
	}

	const query = `
		SELECT u.id, u.display_name, gm.joined_at
		FROM group_members gm
		JOIN users u ON u.id = gm.user_id
		WHERE gm.group_id = $1
		ORDER BY gm.joined_at
	`
	rows, err := s.store.Pool().Query(ctx, query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	members := []Member{}
	for rows.Next() {
		var m Member
		if err := rows.Scan(&m.UserID, &m.DisplayName, &m.JoinedAt); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return members, nil
}

// Leave removes userID's membership row from groupID unconditionally -- any member may leave at
// any moment, including the organizer and including the group's last remaining member; neither
// case is blocked or gated. When disposition is DispositionRemovePosts, the caller's past
// completions are hidden from the group in the same transaction as the membership deletion, via
// the injected CompletionVisibility seam, so the two either both happen or neither does.
func (s *Service) Leave(ctx context.Context, userID, groupID uuid.UUID, disposition LeaveDisposition) error {
	tx, err := s.store.Pool().Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	const deleteQuery = `DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`
	tag, err := tx.Exec(ctx, deleteQuery, groupID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotAMember
	}

	if disposition == DispositionRemovePosts {
		if err := s.completionVisibility.HideGroupCompletions(ctx, tx, groupID, userID); err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

// RemoveMember removes targetUserID from groupID at actorUserID's request. actorUserID must
// already be a member; actorUserID may never name themself as the target (ErrRemoveSelf -- Leave
// is the route for that). Under PolicyAnyMember any member may remove any other member; under
// PolicyOrganizerOnly only the group's organizer may. The not-permitted status is returned only
// once actorUserID is already confirmed to be a member of this specific group, so it never leaks
// information about a group the actor is not in.
func (s *Service) RemoveMember(ctx context.Context, actorUserID, groupID, targetUserID uuid.UUID) error {
	if actorUserID == targetUserID {
		return ErrRemoveSelf
	}

	isActorMember, err := s.isMember(ctx, groupID, actorUserID)
	if err != nil {
		return err
	}
	if !isActorMember {
		return ErrNotAMember
	}

	organizerID, policy, err := s.organizerAndPolicy(ctx, groupID)
	if err != nil {
		return err
	}

	if policy == PolicyOrganizerOnly && actorUserID != organizerID {
		return ErrRemovalNotPermitted
	}

	const deleteQuery = `DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`
	tag, err := s.store.Pool().Exec(ctx, deleteQuery, groupID, targetUserID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotAMember
	}
	return nil
}

// SetRemovalPolicy changes groupID's removal policy. Only a current member may call this.
func (s *Service) SetRemovalPolicy(ctx context.Context, actorUserID, groupID uuid.UUID, policy RemovalPolicy) error {
	isMember, err := s.isMember(ctx, groupID, actorUserID)
	if err != nil {
		return err
	}
	if !isMember {
		return ErrNotAMember
	}

	const query = `UPDATE groups SET removal_policy = $1 WHERE id = $2`
	_, err = s.store.Pool().Exec(ctx, query, string(policy), groupID)
	return err
}

// RequireMember is the single authorization gate for every group-scoped read or write. It returns
// nil when userID is a member of groupID, and ErrNotAMember for every other case -- including a
// groupID that does not exist -- so a group id alone never confirms the group's existence
// (T-04.1-45, mirroring Get's own identical-sentinel property).
func (s *Service) RequireMember(ctx context.Context, userID, groupID uuid.UUID) error {
	isMember, err := s.isMember(ctx, groupID, userID)
	if err != nil {
		return err
	}
	if !isMember {
		return ErrNotAMember
	}
	return nil
}

// organizerAndPolicy reads groupID's current organizer and removal policy in one query.
func (s *Service) organizerAndPolicy(ctx context.Context, groupID uuid.UUID) (organizerID uuid.UUID, policy RemovalPolicy, err error) {
	const query = `SELECT organizer_user_id, removal_policy FROM groups WHERE id = $1`
	var policyStr string
	err = s.store.Pool().QueryRow(ctx, query, groupID).Scan(&organizerID, &policyStr)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.UUID{}, "", ErrNotAMember
		}
		return uuid.UUID{}, "", err
	}
	return organizerID, RemovalPolicy(policyStr), nil
}
