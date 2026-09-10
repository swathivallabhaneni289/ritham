// Package groups is small, closed, invite-only groups and the membership predicate every later
// group-scoped surface (feed, events, completion) authorizes against (GROUPEVENTS-01, HOUSEHOLD-02).
//
// docs/group-events.md §1 is explicit that a group has no public or joinable-by-anyone tier at
// all -- not a private default with a public option, but no such tier existing. A group is
// invisible to search, is not listed on any profile, and generates no public or aggregate signal.
// The only way in is an invitation sent by an existing member to one of their own friends
// (internal/friends' own AreFriends predicate, never a second copy of that query); the only way
// to confirm a group exists at all is to already be a member of it (see Get, and T-04.1-45).
//
// This file holds group creation, friend-gated invitation, and the membership-scoped reads.
// membership.go holds leaving, removal, removal-policy, and RequireMember -- the single
// authorization gate every group-scoped read or write in a later plan calls before touching data.
package groups

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// maxMembers is the closed group's size cap, matching the constant plan 04.1-02 declared on the
// client side. docs/group-events.md §1 asks for a size that biases toward the people doing one
// activity together, not toward scaling into a club, and a smaller closed group also reduces the
// aggregate-exposure surface §3 describes. If this number ever changes, the client constant must
// change with it -- the two are one product decision expressed in two languages, not two
// independent choices that happen to agree today.
const maxMembers = 12

// maxGroupNameLen bounds a group's name (T-04.1-50: oversized-input rejection).
const maxGroupNameLen = 60

// RemovalPolicy governs who may remove a member from a group (see membership.go's RemoveMember).
type RemovalPolicy string

const (
	// PolicyAnyMember lets any member remove any other member.
	PolicyAnyMember RemovalPolicy = "anyMember"
	// PolicyOrganizerOnly restricts removal to the group's organizer.
	PolicyOrganizerOnly RemovalPolicy = "organizerOnly"
)

var (
	// ErrNotAMember is returned by every membership-scoped read or write when the acting user is
	// not a member of the group in question -- including when the group id does not exist at all.
	// The two cases are indistinguishable by design (T-04.1-45): a group id alone must never
	// confirm that a group exists.
	ErrNotAMember = errors.New("groups: not a member of this group")
	// ErrNotFriends is returned by Invite when the inviter and invitee have no friendship row.
	ErrNotFriends = errors.New("groups: users are not friends")
	// ErrGroupFull is returned by Join when the group already holds maxMembers members.
	ErrGroupFull = errors.New("groups: group is full")
	// ErrAlreadyMember is returned by Join when the caller is already a member of the group.
	ErrAlreadyMember = errors.New("groups: already a member of this group")
	// ErrNoInvitation is returned by Join and DeclineInvitation when no pending invitation is
	// addressed to the caller for the group in question.
	ErrNoInvitation = errors.New("groups: no pending invitation")
	// ErrNameTooLong is returned by Create when name exceeds maxGroupNameLen.
	ErrNameTooLong = errors.New("groups: name exceeds the maximum length")
)

// FriendPredicate is the capability Invite needs from the friends package -- satisfied by
// *friends.Service's own AreFriends method, passed in through this interface rather than
// restated. Two definitions of "are these people friends" would eventually disagree, and this is
// the boundary where that disagreement would let a stranger into a closed group (T-04.1-46).
type FriendPredicate interface {
	AreFriends(ctx context.Context, a, b uuid.UUID) (bool, error)
}

// CompletionVisibility is the seam membership.go's Leave uses to hide a leaving member's past
// completions from the group's feed when they choose the remove disposition. Declared here
// (alongside Service and New) because it is a construction-time-optional dependency: a Service
// built with no call to SetCompletionVisibility uses noopCompletionVisibility, so Leave's remove
// path is a real, tested no-op until plan 04.1-10's events package lands the completions table's
// visibility column and wires its own implementation in -- this package never reaches into the
// events schema directly.
type CompletionVisibility interface {
	// HideGroupCompletions marks userID's past completions within groupID as no longer visible to
	// the group. tx runs the same transaction as the membership row's deletion, so a leave with
	// the remove disposition is atomic: either both happen, or neither does.
	HideGroupCompletions(ctx context.Context, tx dbtx, groupID, userID uuid.UUID) error
}

// noopCompletionVisibility satisfies CompletionVisibility with no effect. This is the default
// every Service is constructed with; SetCompletionVisibility overrides it once a real
// implementation exists.
type noopCompletionVisibility struct{}

func (noopCompletionVisibility) HideGroupCompletions(ctx context.Context, tx dbtx, groupID, userID uuid.UUID) error {
	return nil
}

// dbtx is the minimal capability this package's mutating helpers need from a database handle --
// satisfied structurally by both *pgxpool.Pool and pgx.Tx, mirroring internal/friends' own dbtx
// convention, so a helper can run either as its own standalone statement or as one step inside a
// larger transaction without duplicating its logic for each case.
type dbtx interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// DBTX is a true type alias for dbtx -- the exact type CompletionVisibility.HideGroupCompletions'
// tx parameter requires. dbtx itself stays unexported (every other symbol in this file uses the
// lowercase name), but Go's structural interface satisfaction requires an exact parameter-type
// match, not just an equivalent method set: an external package's own locally-declared interface
// with an identical Exec/Query/QueryRow method set does NOT satisfy dbtx by signature identity
// (verified directly against the compiler before this alias was added -- see 04.1-10-SUMMARY.md).
// This one-line alias is the smallest fix: plan 04.1-10's events package can now declare
// HideGroupCompletions(ctx, tx DBTX, groupID, userID uuid.UUID) error and implement
// CompletionVisibility from outside this package, with no other symbol here touched and no
// existing call site changed.
type DBTX = dbtx

// Service is the groups domain's single entry point.
type Service struct {
	store                *store.Store
	friends              FriendPredicate
	now                  func() time.Time
	completionVisibility CompletionVisibility
}

// New constructs a Service. completionVisibility defaults to a no-op (see CompletionVisibility's
// doc comment); call SetCompletionVisibility once a real implementation exists.
func New(st *store.Store, fr FriendPredicate, now func() time.Time) *Service {
	return &Service{store: st, friends: fr, now: now, completionVisibility: noopCompletionVisibility{}}
}

// SetCompletionVisibility overrides the default no-op CompletionVisibility. Not part of New's own
// signature (locked by this plan's artifacts) since it is a construction-time-optional dependency
// that a later plan (04.1-10) wires in only once it exists.
func (s *Service) SetCompletionVisibility(cv CompletionVisibility) {
	s.completionVisibility = cv
}

// Group is a groups row.
type Group struct {
	ID              uuid.UUID
	Name            string
	OrganizerUserID uuid.UUID
	RemovalPolicy   RemovalPolicy
	CreatedAt       time.Time
}

// GroupDetail is a Group plus its current member count, for the single-group detail view. A
// member count is safe to expose to the group's own members (it is not an external
// discoverability signal -- see the package doc comment and docs/group-events.md §3's
// "don't create an aggregate surface" reasoning, which is about surfaces reachable by
// non-members, not about a group's own membership seeing its own size).
type GroupDetail struct {
	Group
	MemberCount int
}

// Invitation is a group_invitations row.
type Invitation struct {
	GroupID       uuid.UUID
	InviteeUserID uuid.UUID
	InviterUserID uuid.UUID
	State         string
	CreatedAt     time.Time
	ResolvedAt    *time.Time
}

// isMember reports whether userID has a group_members row for groupID.
func (s *Service) isMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	const query = `SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2)`
	var exists bool
	err := s.store.Pool().QueryRow(ctx, query, groupID, userID).Scan(&exists)
	return exists, err
}

// Create makes organizerUserID the group's sole initial member and its organizer -- a convenience
// role with no public standing (see membership.go's package doc comment). An empty policy
// defaults to PolicyAnyMember.
func (s *Service) Create(ctx context.Context, organizerUserID uuid.UUID, name string, policy RemovalPolicy) (Group, error) {
	if len(name) > maxGroupNameLen {
		return Group{}, ErrNameTooLong
	}
	if policy == "" {
		policy = PolicyAnyMember
	}

	tx, err := s.store.Pool().Begin(ctx)
	if err != nil {
		return Group{}, err
	}
	defer tx.Rollback(ctx)

	id := uuid.New()
	now := s.now()

	const insertGroup = `
		INSERT INTO groups (id, name, organizer_user_id, removal_policy, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	if _, err := tx.Exec(ctx, insertGroup, id, name, organizerUserID, string(policy), now); err != nil {
		return Group{}, err
	}

	const insertMember = `
		INSERT INTO group_members (group_id, user_id, joined_at)
		VALUES ($1, $2, $3)
	`
	if _, err := tx.Exec(ctx, insertMember, id, organizerUserID, now); err != nil {
		return Group{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return Group{}, err
	}

	return Group{ID: id, Name: name, OrganizerUserID: organizerUserID, RemovalPolicy: policy, CreatedAt: now}, nil
}

// Invite creates a pending invitation from inviterUserID (who must already be a member of
// groupID) to inviteeUserID (who must already be the inviter's friend, per the injected
// FriendPredicate -- T-04.1-46). The invitee is not a member until they call Join. Re-inviting a
// former member, or re-sending after a decline, upserts onto the same (group, invitee) row rather
// than accumulating invitation history, since only the current state is ever read.
func (s *Service) Invite(ctx context.Context, inviterUserID, groupID, inviteeUserID uuid.UUID) (Invitation, error) {
	isMember, err := s.isMember(ctx, groupID, inviterUserID)
	if err != nil {
		return Invitation{}, err
	}
	if !isMember {
		return Invitation{}, ErrNotAMember
	}

	areFriends, err := s.friends.AreFriends(ctx, inviterUserID, inviteeUserID)
	if err != nil {
		return Invitation{}, err
	}
	if !areFriends {
		return Invitation{}, ErrNotFriends
	}

	now := s.now()
	const query = `
		INSERT INTO group_invitations (group_id, invitee_user_id, inviter_user_id, created_at, state, resolved_at)
		VALUES ($1, $2, $3, $4, 'pending', NULL)
		ON CONFLICT (group_id, invitee_user_id) DO UPDATE
		SET inviter_user_id = EXCLUDED.inviter_user_id,
		    created_at = EXCLUDED.created_at,
		    state = 'pending',
		    resolved_at = NULL
		WHERE group_invitations.state != 'pending'
	`
	if _, err := s.store.Pool().Exec(ctx, query, groupID, inviteeUserID, inviterUserID, now); err != nil {
		return Invitation{}, err
	}

	return Invitation{
		GroupID:       groupID,
		InviteeUserID: inviteeUserID,
		InviterUserID: inviterUserID,
		State:         "pending",
		CreatedAt:     now,
	}, nil
}

// Join accepts a pending invitation addressed to userID, adding them to groupID's membership.
// The member cap and the insert are enforced inside one transaction with the group row locked
// (T-04.1-48), so two concurrent joins on the same group cannot both pass a pre-check and
// overshoot maxMembers.
func (s *Service) Join(ctx context.Context, userID, groupID uuid.UUID) error {
	tx, err := s.store.Pool().Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Lock the group row (if it exists) so a concurrent Join against the same group serializes
	// here, before either transaction counts members or inserts.
	if _, err := tx.Exec(ctx, `SELECT id FROM groups WHERE id = $1 FOR UPDATE`, groupID); err != nil {
		return err
	}

	var alreadyMember bool
	err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2)`,
		groupID, userID).Scan(&alreadyMember)
	if err != nil {
		return err
	}
	if alreadyMember {
		return ErrAlreadyMember
	}

	now := s.now()
	const consumeInvitation = `
		UPDATE group_invitations
		SET state = 'accepted', resolved_at = $1
		WHERE group_id = $2 AND invitee_user_id = $3 AND state = 'pending'
	`
	tag, err := tx.Exec(ctx, consumeInvitation, now, groupID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNoInvitation
	}

	var memberCount int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM group_members WHERE group_id = $1`, groupID).Scan(&memberCount); err != nil {
		return err
	}
	if memberCount >= maxMembers {
		return ErrGroupFull
	}

	const insertMember = `
		INSERT INTO group_members (group_id, user_id, joined_at)
		VALUES ($1, $2, $3)
	`
	if _, err := tx.Exec(ctx, insertMember, groupID, userID, now); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// DeclineInvitation resolves a pending invitation addressed to userID as declined, creating no
// membership. Returns ErrNoInvitation when no pending invitation exists for this (group, user)
// pair.
func (s *Service) DeclineInvitation(ctx context.Context, userID, groupID uuid.UUID) error {
	const query = `
		UPDATE group_invitations
		SET state = 'declined', resolved_at = $1
		WHERE group_id = $2 AND invitee_user_id = $3 AND state = 'pending'
	`
	tag, err := s.store.Pool().Exec(ctx, query, s.now(), groupID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNoInvitation
	}
	return nil
}

// ListForUser returns every group userID is currently a member of, ordered by when they joined.
// A group the caller was merely invited to (never joined) or has since left is never included --
// this is a membership-scoped query, not a bare fetch filtered afterwards.
func (s *Service) ListForUser(ctx context.Context, userID uuid.UUID) ([]Group, error) {
	const query = `
		SELECT g.id, g.name, g.organizer_user_id, g.removal_policy, g.created_at
		FROM groups g
		JOIN group_members gm ON gm.group_id = g.id
		WHERE gm.user_id = $1
		ORDER BY gm.joined_at
	`
	rows, err := s.store.Pool().Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	groupsList := []Group{}
	for rows.Next() {
		var g Group
		var policy string
		if err := rows.Scan(&g.ID, &g.Name, &g.OrganizerUserID, &policy, &g.CreatedAt); err != nil {
			return nil, err
		}
		g.RemovalPolicy = RemovalPolicy(policy)
		groupsList = append(groupsList, g)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return groupsList, nil
}

// Get returns groupID's detail from userID's point of view. Membership is part of the query
// itself (a JOIN, not a separate check afterwards), so a non-member fetch of a real group and a
// fetch of a random UUID return the identical ErrNotAMember sentinel -- a group id alone must
// never confirm the group's existence (T-04.1-45).
func (s *Service) Get(ctx context.Context, userID, groupID uuid.UUID) (GroupDetail, error) {
	const query = `
		SELECT g.id, g.name, g.organizer_user_id, g.removal_policy, g.created_at,
		       (SELECT COUNT(*) FROM group_members gm2 WHERE gm2.group_id = g.id)
		FROM groups g
		JOIN group_members gm ON gm.group_id = g.id AND gm.user_id = $2
		WHERE g.id = $1
	`
	var d GroupDetail
	var policy string
	err := s.store.Pool().QueryRow(ctx, query, groupID, userID).
		Scan(&d.ID, &d.Name, &d.OrganizerUserID, &policy, &d.CreatedAt, &d.MemberCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return GroupDetail{}, ErrNotAMember
		}
		return GroupDetail{}, err
	}
	d.RemovalPolicy = RemovalPolicy(policy)
	return d, nil
}
