package photo

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// ErrAssetNotFound is returned by Asset when no photo_assets row matches both the given asset id
// AND the requesting user id together -- an asset id alone is never treated as an access grant
// (T-04.1-19). This is deliberately the identical error whether the id doesn't exist at all or
// exists but belongs to a different user, so a caller cannot distinguish "no such asset" from
// "that asset isn't yours" by probing ids.
var ErrAssetNotFound = errors.New("photo: asset not found")

// objectWriter is the minimal capability Service needs from object storage -- a structural
// interface so service_test.go can substitute a stub with no S3-compatible backend running, while
// *ObjectStore (the real implementation) satisfies it with no explicit declaration required. This
// mirrors internal/httpapi/middleware.go's authenticator interface, the identical pattern plan
// 04.1-03 already established for exactly this reason (RequireSession's tests run with a stub and
// no database).
//
// Critically, this interface's PutShared method signature is unchanged from ObjectStore's own --
// its image parameter is still StrippedImage, never []byte. Widening it here would silently
// destroy the type-enforced guarantee T-04.1-16 depends on, so this interface exists only to let
// Ingest's *caller* be swapped in tests, never to loosen what Ingest can hand to the shared tier.
type objectWriter interface {
	PutPrivateOriginal(ctx context.Context, key string, raw []byte, contentType string) error
	PutShared(ctx context.Context, key string, img StrippedImage) error
}

// Asset is one row of photo_assets: a group-visible photo, always the output of
// StripAndReencode, addressable by id and scoped to its owner.
type Asset struct {
	ID          uuid.UUID
	OwnerUserID uuid.UUID
	SharedKey   string
	CreatedAt   time.Time
}

// Service is the sole entry point this codebase has for turning uploaded bytes into a
// group-visible photo asset. It never exposes the object store or the stripping pipeline directly
// to callers outside this package -- httpapi's upload handler calls only Service.Ingest, never
// touching ObjectStore or StripAndReencode itself, which is what keeps the pipeline unbypassable
// at the HTTP layer.
type Service struct {
	st  *store.Store
	os  objectWriter
	now func() time.Time
}

// New constructs a Service backed by a real *ObjectStore. now is injected (not time.Now directly)
// so tests can control CreatedAt deterministically, matching internal/identity.New's precedent.
func New(st *store.Store, os *ObjectStore, now func() time.Time) *Service {
	return newService(st, os, now)
}

// newService is the test-only entry point: it accepts any objectWriter, not just a concrete
// *ObjectStore, so Ingest's behavior can be fully exercised with a stub writer and no running
// S3-compatible backend. New (above) is the only production caller and always passes a real
// *ObjectStore, which satisfies objectWriter structurally.
func newService(st *store.Store, os objectWriter, now func() time.Time) *Service {
	return &Service{st: st, os: os, now: now}
}

// Ingest runs raw through StripAndReencode and, only on success, writes exactly one object to the
// shared tier and inserts exactly one photo_assets row. declaredContentType is the client's
// claimed Content-Type; it is never consulted by StripAndReencode or trusted for anything --
// StripAndReencode determines the true format from the bytes themselves. It is accepted here only
// so a future caller (e.g. request logging) has it available, per this plan's artifact signature.
//
// On any StripAndReencode failure (unsupported format, decode failure, too large), Ingest returns
// that error unchanged: no row is inserted and no object is written. The failure is total, not
// partial -- there is no path where a rejected upload leaves a trace in either the database or
// object storage.
func (s *Service) Ingest(ctx context.Context, ownerUserID uuid.UUID, raw []byte, declaredContentType string) (Asset, error) {
	_ = declaredContentType // see doc comment: not consulted by the stripping pipeline

	stripped, err := StripAndReencode(raw)
	if err != nil {
		return Asset{}, err
	}

	assetID := uuid.New()
	sharedKey := assetID.String()

	if err := s.os.PutShared(ctx, sharedKey, stripped); err != nil {
		return Asset{}, err
	}

	createdAt := s.now()
	_, err = s.st.Pool().Exec(ctx,
		`INSERT INTO photo_assets (id, owner_user_id, shared_object_key, content_type, created_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		assetID, ownerUserID, sharedKey, stripped.ContentType(), createdAt,
	)
	if err != nil {
		return Asset{}, err
	}

	return Asset{ID: assetID, OwnerUserID: ownerUserID, SharedKey: sharedKey, CreatedAt: createdAt}, nil
}

// Asset returns the requester's own asset. It selects by id AND owner_user_id together in a
// single query (T-04.1-19), so an asset id alone is never sufficient to read someone else's
// photo -- a mismatched owner returns the identical ErrAssetNotFound a nonexistent id would.
func (s *Service) Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (Asset, error) {
	var a Asset
	err := s.st.Pool().QueryRow(ctx,
		`SELECT id, owner_user_id, shared_object_key, created_at
		 FROM photo_assets WHERE id = $1 AND owner_user_id = $2`,
		assetID, requesterUserID,
	).Scan(&a.ID, &a.OwnerUserID, &a.SharedKey, &a.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Asset{}, ErrAssetNotFound
		}
		return Asset{}, err
	}
	return a, nil
}
