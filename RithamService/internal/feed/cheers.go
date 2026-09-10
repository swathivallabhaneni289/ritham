// This file is Ritham's first cheer implementation -- 04.1-RESEARCH.md's Pitfall 1 confirmed no
// cheer, kudos, or reaction code exists anywhere in this codebase before this plan; only the
// product rule did. The accepted values match RithamCore's own fixed cheer enum
// (RithamCore/Sources/RithamCore/Social/Cheer.swift: niceWork, keepGoing) byte-for-byte on raw
// value, so the client and server lists can never drift apart. `HOUSEHOLD-01` (Phase 4 round 2)
// should reuse this package rather than building a second cheer mechanic.
//
// The absence of a count anywhere below is the requirement itself, not a simplification
// (docs/group-events.md §2/§4's "no kudos counts, no most-cheered surface"). No exported function
// in this file returns a cheer count, a cheer list, or a per-person breakdown -- SendCheer and
// WithdrawCheer both return only an error, and the only cheer state any caller can ever read is
// their own, via feed.go's per-viewer ViewerCheers on a feed Item.
package feed

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

// ErrUnknownCheer is returned by SendCheer/WithdrawCheer when cheer is not one of the two values
// in knownCheers.
var ErrUnknownCheer = errors.New("feed: unknown cheer")

// knownCheers is the fixed, exactly-two cheer vocabulary this package accepts -- see this file's
// header comment for why it must never diverge from RithamCore.Cheer's own raw values.
var knownCheers = map[string]bool{
	"niceWork":  true,
	"keepGoing": true,
}

// SendCheer records that userID cheers completionID with cheer, or does nothing if that exact
// (completion, user, cheer) row already exists -- idempotence comes from the schema's own
// composite primary key (ON CONFLICT DO NOTHING), never from a pre-check that a race could defeat.
// userID must be able to see completionID (requireVisibleCompletion, the same visibility test
// reading the feed itself uses) -- a user who cannot see a completion cannot cheer it.
func (s *Service) SendCheer(ctx context.Context, userID, completionID uuid.UUID, cheer string) error {
	if !knownCheers[cheer] {
		return ErrUnknownCheer
	}
	if _, _, err := s.requireVisibleCompletion(ctx, userID, completionID); err != nil {
		return err
	}

	const query = `
		INSERT INTO completion_cheers (completion_id, user_id, cheer, sent_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (completion_id, user_id, cheer) DO NOTHING
	`
	_, err := s.store.Pool().Exec(ctx, query, completionID, userID, cheer, s.now())
	return err
}

// WithdrawCheer removes userID's cheer of cheer on completionID. Withdrawing a cheer that was
// never sent is a no-op, never an error -- DELETE affecting zero rows is a normal outcome, not a
// failure. userID must be able to see completionID, identically to SendCheer.
func (s *Service) WithdrawCheer(ctx context.Context, userID, completionID uuid.UUID, cheer string) error {
	if !knownCheers[cheer] {
		return ErrUnknownCheer
	}
	if _, _, err := s.requireVisibleCompletion(ctx, userID, completionID); err != nil {
		return err
	}

	const query = `DELETE FROM completion_cheers WHERE completion_id = $1 AND user_id = $2 AND cheer = $3`
	_, err := s.store.Pool().Exec(ctx, query, completionID, userID, cheer)
	return err
}
