package photo

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// Compile-time assertion: PutShared's image parameter is StrippedImage, never []byte or any other
// type. If this line fails to compile, PutShared's signature has drifted from the type-enforced
// guarantee T-04.1-16 depends on -- the whole reason the shared tier cannot be handed unstripped
// bytes even by mistake.
var _ func(*ObjectStore, context.Context, string, StrippedImage) error = (*ObjectStore).PutShared

// stubObjectWriter is a no-network objectWriter used by every Service test below except the
// schema-shape test. It lets Ingest's own logic (strip-first, write-shared, insert-row) be
// exercised fully without a running S3-compatible backend, following
// internal/httpapi/middleware_test.go's stub-authenticator precedent (04.1-03).
type stubObjectWriter struct {
	putSharedCalls           int
	putPrivateOriginalCalls  int
	putSharedErr             error
	lastSharedKey            string
	lastSharedImg            StrippedImage
}

func (w *stubObjectWriter) PutPrivateOriginal(ctx context.Context, key string, raw []byte, contentType string) error {
	w.putPrivateOriginalCalls++
	return nil
}

func (w *stubObjectWriter) PutShared(ctx context.Context, key string, img StrippedImage) error {
	w.putSharedCalls++
	w.lastSharedKey = key
	w.lastSharedImg = img
	return w.putSharedErr
}

// photoTestHarness wires a Service against a real, live database (RITHAM_DATABASE_URL) and a
// stub object writer, following internal/identity/identity_test.go's testHarness convention:
// skip loudly, with an actionable message, when no database is configured.
type photoTestHarness struct {
	svc    *Service
	store  *store.Store
	writer *stubObjectWriter
	clock  time.Time
}

func newPhotoTestHarness(t *testing.T) *photoTestHarness {
	t.Helper()
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		t.Skip("RITHAM_DATABASE_URL is unset -- start a database (see docker-compose.dev.yml, " +
			"or a native Postgres per 04.1-01-SUMMARY.md) and run this test with " +
			"`RITHAM_DATABASE_URL=postgres://$(whoami)@localhost:5432/ritham_dev" +
			"?sslmode=disable go test ./internal/photo/...`")
	}

	if err := store.Migrate(databaseURL); err != nil {
		t.Fatalf("store.Migrate: unexpected error: %v", err)
	}

	ctx := context.Background()
	st, err := store.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("store.New: unexpected error: %v", err)
	}
	t.Cleanup(st.Close)

	writer := &stubObjectWriter{}
	clock := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	svc := newService(st, writer, func() time.Time { return clock })
	return &photoTestHarness{svc: svc, store: st, writer: writer, clock: clock}
}

// createTestUser inserts a minimal users row so photo_assets.owner_user_id's foreign key is
// satisfiable, and registers cleanup that cascades to any photo_assets/photo_export_consents
// rows the test created.
func createTestUser(t *testing.T, h *photoTestHarness) uuid.UUID {
	t.Helper()
	id := uuid.New()
	_, err := h.store.Pool().Exec(context.Background(),
		`INSERT INTO users (id, apple_subject) VALUES ($1, $2)`,
		id, "photo-test-subject."+id.String())
	if err != nil {
		t.Fatalf("insert test user: %v", err)
	}
	t.Cleanup(func() {
		_, _ = h.store.Pool().Exec(context.Background(), "DELETE FROM users WHERE id = $1", id)
	})
	return id
}

func countPhotoAssets(t *testing.T, h *photoTestHarness, owner uuid.UUID) int {
	t.Helper()
	var count int
	err := h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM photo_assets WHERE owner_user_id = $1", owner,
	).Scan(&count)
	if err != nil {
		t.Fatalf("count photo_assets: %v", err)
	}
	return count
}

// --- No-database, no-bucket behaviors ---

func TestObjectStore_PutShared_ZeroValueReturnsErrNotStripped(t *testing.T) {
	o := &ObjectStore{}
	err := o.PutShared(context.Background(), "some-key", StrippedImage{})
	if !errors.Is(err, ErrNotStripped) {
		t.Fatalf("PutShared(zero-value StrippedImage): got error %v, want ErrNotStripped", err)
	}
}

// --- Connected behaviors: live Postgres, stub object writer ---

func TestIngest_WritesExactlyOneObjectAndOneRow(t *testing.T) {
	h := newPhotoTestHarness(t)
	owner := createTestUser(t, h)
	raw := loadFixture(t, fixtureGPSExif)

	asset, err := h.svc.Ingest(context.Background(), owner, raw, "image/jpeg")
	if err != nil {
		t.Fatalf("Ingest: unexpected error: %v", err)
	}

	if h.writer.putSharedCalls != 1 {
		t.Errorf("PutShared calls = %d, want 1", h.writer.putSharedCalls)
	}
	if h.writer.putPrivateOriginalCalls != 0 {
		t.Errorf("PutPrivateOriginal calls = %d, want 0 -- this phase's client never calls it", h.writer.putPrivateOriginalCalls)
	}
	if h.writer.lastSharedImg.isZero() {
		t.Error("PutShared was called with a zero-value StrippedImage")
	}

	if got := countPhotoAssets(t, h, owner); got != 1 {
		t.Errorf("photo_assets row count = %d, want 1", got)
	}
	if asset.OwnerUserID != owner {
		t.Errorf("asset.OwnerUserID = %v, want %v", asset.OwnerUserID, owner)
	}
	if asset.SharedKey == "" {
		t.Error("asset.SharedKey is empty")
	}
}

func TestIngest_HEICInputRecordsNoRowAndWritesNoObject(t *testing.T) {
	h := newPhotoTestHarness(t)
	owner := createTestUser(t, h)
	raw := loadFixture(t, fixtureHEICCapture)

	_, err := h.svc.Ingest(context.Background(), owner, raw, "image/heic")
	if !errors.Is(err, ErrUnsupportedFormat) {
		t.Fatalf("Ingest(HEIC): got error %v, want ErrUnsupportedFormat", err)
	}

	if h.writer.putSharedCalls != 0 {
		t.Errorf("PutShared calls = %d, want 0 -- HEIC rejection must be total, not partial", h.writer.putSharedCalls)
	}
	if got := countPhotoAssets(t, h, owner); got != 0 {
		t.Errorf("photo_assets row count = %d, want 0", got)
	}
}

func TestAsset_ReturnsOwnAssetButNotAnotherUsers(t *testing.T) {
	h := newPhotoTestHarness(t)
	owner := createTestUser(t, h)
	other := createTestUser(t, h)
	raw := loadFixture(t, fixtureGPSExif)

	asset, err := h.svc.Ingest(context.Background(), owner, raw, "image/jpeg")
	if err != nil {
		t.Fatalf("Ingest: unexpected error: %v", err)
	}

	got, err := h.svc.Asset(context.Background(), owner, asset.ID)
	if err != nil {
		t.Fatalf("Asset(owner, own asset): unexpected error: %v", err)
	}
	if got.ID != asset.ID {
		t.Errorf("Asset(owner): got ID %v, want %v", got.ID, asset.ID)
	}

	_, err = h.svc.Asset(context.Background(), other, asset.ID)
	if !errors.Is(err, ErrAssetNotFound) {
		t.Fatalf("Asset(other user, owner's asset): got error %v, want ErrAssetNotFound", err)
	}
}

func TestAsset_UnknownIDReturnsErrAssetNotFound(t *testing.T) {
	h := newPhotoTestHarness(t)
	owner := createTestUser(t, h)

	_, err := h.svc.Asset(context.Background(), owner, uuid.New())
	if !errors.Is(err, ErrAssetNotFound) {
		t.Fatalf("Asset(unknown id): got error %v, want ErrAssetNotFound", err)
	}
}

// TestPhotoAssetsSchema_HasNoLocationColumn is a behavioral companion to the migration-file grep
// acceptance check: it asks the live database's own catalog, not just the source SQL text,
// whether any photo_assets column name suggests it could hold a GPS position, a capture location,
// or an address (T-04.1-21).
func TestPhotoAssetsSchema_HasNoLocationColumn(t *testing.T) {
	h := newPhotoTestHarness(t)
	rows, err := h.store.Pool().Query(context.Background(),
		`SELECT column_name FROM information_schema.columns WHERE table_name = 'photo_assets'`)
	if err != nil {
		t.Fatalf("schema query: %v", err)
	}
	defer rows.Close()

	forbidden := []string{"lat", "lon", "coordinate", "address", "location"}
	for rows.Next() {
		var col string
		if err := rows.Scan(&col); err != nil {
			t.Fatalf("scan column_name: %v", err)
		}
		lower := strings.ToLower(col)
		for _, f := range forbidden {
			if strings.Contains(lower, f) {
				t.Errorf("photo_assets has column %q, which matches forbidden pattern %q", col, f)
			}
		}
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("rows.Err: %v", err)
	}
}
