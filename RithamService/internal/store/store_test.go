package store

import (
	"context"
	"testing"
)

// TestNew_EmptyURLReturnsErrNoDatabaseURL runs with no database present -- New must return
// ErrNoDatabaseURL before ever attempting a connection, so this case is never skipped.
func TestNew_EmptyURLReturnsErrNoDatabaseURL(t *testing.T) {
	_, err := New(context.Background(), "")
	if err != ErrNoDatabaseURL {
		t.Fatalf("New(ctx, \"\"): got error %v, want ErrNoDatabaseURL", err)
	}
}

// TestMigrate_CreatesIdentityTablesAndIsIdempotent only runs when RITHAM_DATABASE_URL is set.
// Without it, it skips with a message naming exactly how to bring up a database and run it.
func TestMigrate_CreatesIdentityTablesAndIsIdempotent(t *testing.T) {
	databaseURL := DatabaseURLFromEnv()
	if databaseURL == "" {
		t.Skip("RITHAM_DATABASE_URL is unset -- start the dev stack with " +
			"`docker compose -f docker-compose.dev.yml up -d postgres`, then run this test with " +
			"`RITHAM_DATABASE_URL=postgres://ritham:ritham@127.0.0.1:5432/ritham_dev?sslmode=disable " +
			"go test ./internal/store/...`")
	}

	ctx := context.Background()

	s, err := New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("New(ctx, databaseURL): unexpected error: %v", err)
	}
	t.Cleanup(s.Close)

	if err := Migrate(databaseURL); err != nil {
		t.Fatalf("Migrate: unexpected error on first run: %v", err)
	}

	for _, table := range []string{"users", "sessions"} {
		var exists bool
		query := `SELECT EXISTS (
			SELECT 1 FROM information_schema.tables
			WHERE table_schema = 'public' AND table_name = $1
		)`
		if err := s.Pool().QueryRow(ctx, query, table).Scan(&exists); err != nil {
			t.Fatalf("querying information_schema.tables for %q: %v", table, err)
		}
		if !exists {
			t.Errorf("expected table %q to exist after Migrate, it does not", table)
		}
	}

	// Migrate must be idempotent: running it again against an already-migrated database is
	// success (migrate.ErrNoChange), not an error.
	if err := Migrate(databaseURL); err != nil {
		t.Fatalf("Migrate: unexpected error on second run (expected idempotent no-op): %v", err)
	}
}
