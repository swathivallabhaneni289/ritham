// This file is the export-consent gate: the decision that governs whether a photo containing
// other people may leave Ritham entirely (an export to a digital finisher certificate, a share
// sheet, or any future export surface). docs/group-events.md §5's first named leak path is exactly
// this: presence in a group feed and presence on the public internet are different consent
// decisions, and the second is never assumed from the first. A photo visible to a closed group of
// people who already agreed to see each other's completions is not the same thing as a photo any
// of those people agreed to have leave the group -- this file is the boundary between those two.
//
// The underlying photo_export_consents table already exists (migration 0002_photos, plan 04.1-04)
// -- its nullable granted_at column IS the pending/granted state machine RequestExportConsent and
// GrantExportConsent operate on. This plan adds no new table for it.
package feed

import (
	"context"
	"errors"

	"github.com/google/uuid"
)

var (
	// ErrExportConsentMissing is returned by GrantExportConsent when photoAssetID has no pending
	// request row for subjectUserID -- there is nothing for that subject to grant.
	ErrExportConsentMissing = errors.New("feed: export consent missing")
	// ErrNotPhotoOwner is returned by RequestExportConsent when ownerUserID does not actually own
	// photoAssetID -- nothing is recorded when this is returned.
	ErrNotPhotoOwner = errors.New("feed: not the photo owner")
)

// ExportGate is ExportAllowed's result: whether photoAssetID may currently be exported, and, when
// it may not, exactly which subjects' consent is still outstanding -- so a client can say who is
// still pending, never just "no".
type ExportGate struct {
	Allowed            bool
	AwaitingSubjectIDs []uuid.UUID
}

// RequestExportConsent is callable only by photoAssetID's owner -- ownerUserID must actually own
// the asset, verified against photo_assets directly, never assumed from the caller's session
// alone. It records one pending (granted_at IS NULL) row per named subject, idempotently (a
// subject already requested is left untouched, not reset to pending again). A non-owner's attempt
// fails with ErrNotPhotoOwner and records nothing at all.
func (s *Service) RequestExportConsent(ctx context.Context, ownerUserID, photoAssetID uuid.UUID, subjectUserIDs []uuid.UUID) error {
	isOwner, err := s.isPhotoOwner(ctx, ownerUserID, photoAssetID)
	if err != nil {
		return err
	}
	if !isOwner {
		return ErrNotPhotoOwner
	}

	const query = `
		INSERT INTO photo_export_consents (photo_asset_id, subject_user_id, granted_at)
		VALUES ($1, $2, NULL)
		ON CONFLICT (photo_asset_id, subject_user_id) DO NOTHING
	`
	for _, subjectID := range subjectUserIDs {
		if _, err := s.store.Pool().Exec(ctx, query, photoAssetID, subjectID); err != nil {
			return err
		}
	}
	return nil
}

// GrantExportConsent records that subjectUserID -- always the authenticated caller, never a
// different person named in a request body (the handler layer enforces this by construction: it
// never reads a subject id from anywhere but the session) -- grants export consent for
// photoAssetID. It requires a pending request row to already exist for this exact
// (photoAssetID, subjectUserID) pair; granting a photo/subject pair nobody ever requested returns
// ErrExportConsentMissing rather than silently creating one.
func (s *Service) GrantExportConsent(ctx context.Context, subjectUserID, photoAssetID uuid.UUID) error {
	const query = `
		UPDATE photo_export_consents SET granted_at = $3
		WHERE photo_asset_id = $1 AND subject_user_id = $2
	`
	tag, err := s.store.Pool().Exec(ctx, query, photoAssetID, subjectUserID, s.now())
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrExportConsentMissing
	}
	return nil
}

// ExportAllowed reports whether photoAssetID may currently be exported: allowed only when every
// recorded subject has granted (no photo_export_consents row with granted_at IS NULL remains for
// this asset), and allowed immediately when no subject was ever recorded at all -- the default
// badge template case, or a solo shot with nobody else in it.
func (s *Service) ExportAllowed(ctx context.Context, exporterUserID, photoAssetID uuid.UUID) (ExportGate, error) {
	_ = exporterUserID // not yet used to restrict who may check -- any authenticated caller may
	// ask a photo's export status; the handler layer still requires a valid session for every
	// route (T-04.1-13). Kept as a parameter to match this plan's own artifact signature and to
	// leave room for a future caller-scoped restriction without an API break.

	const query = `
		SELECT subject_user_id FROM photo_export_consents
		WHERE photo_asset_id = $1 AND granted_at IS NULL
	`
	rows, err := s.store.Pool().Query(ctx, query, photoAssetID)
	if err != nil {
		return ExportGate{}, err
	}
	defer rows.Close()

	awaiting := []uuid.UUID{}
	for rows.Next() {
		var subjectID uuid.UUID
		if err := rows.Scan(&subjectID); err != nil {
			return ExportGate{}, err
		}
		awaiting = append(awaiting, subjectID)
	}
	if err := rows.Err(); err != nil {
		return ExportGate{}, err
	}

	return ExportGate{Allowed: len(awaiting) == 0, AwaitingSubjectIDs: awaiting}, nil
}

// isPhotoOwner reports whether userID owns photoAssetID, read directly against photo_assets.
func (s *Service) isPhotoOwner(ctx context.Context, userID, photoAssetID uuid.UUID) (bool, error) {
	var exists bool
	err := s.store.Pool().QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM photo_assets WHERE id = $1 AND owner_user_id = $2)`,
		photoAssetID, userID,
	).Scan(&exists)
	return exists, err
}
