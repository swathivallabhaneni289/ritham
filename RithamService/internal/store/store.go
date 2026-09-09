// Package store is the first database this codebase has ever had. It is reached only through
// RITHAM_DATABASE_URL, and no production instance exists today -- only the local Docker Postgres
// started via RithamService/docker-compose.dev.yml (per 04.1-RESEARCH.md's Environment
// Availability section). Real hosting is a separate, still-undecided prerequisite recorded in
// RithamService/README.md's "Deployment prerequisites (unresolved)" section.
package store

import (
	"context"
	"errors"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrNoDatabaseURL is returned by New when no database URL was supplied. Callers use
// errors.Is(err, store.ErrNoDatabaseURL), never a string comparison, matching internal/plan's
// exported-sentinel-per-package convention so httpapi can map store failures the same way it
// already maps plan.Generate failures.
var ErrNoDatabaseURL = errors.New("store: no database URL configured")

// databaseURLEnvVar is the single environment variable this package reads a connection string
// from.
const databaseURLEnvVar = "RITHAM_DATABASE_URL"

// DatabaseURLFromEnv reads RITHAM_DATABASE_URL. It performs no validation and does not connect --
// callers pass the result to New, which does both.
func DatabaseURLFromEnv() string {
	return os.Getenv(databaseURLEnvVar)
}

// Store holds the service's single pgx connection pool.
type Store struct {
	pool *pgxpool.Pool
}

// New constructs a Store backed by a pgxpool.Pool and pings it once before returning, so a
// misconfigured or unreachable database fails at startup rather than on the first query. An
// empty databaseURL returns ErrNoDatabaseURL without attempting a connection.
func New(ctx context.Context, databaseURL string) (*Store, error) {
	if databaseURL == "" {
		return nil, ErrNoDatabaseURL
	}

	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, err
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}

	return &Store{pool: pool}, nil
}

// Pool returns the underlying pgxpool.Pool for callers that need to run queries directly.
func (s *Store) Pool() *pgxpool.Pool {
	return s.pool
}

// Close releases every connection in the pool. Safe to call once, at process shutdown.
func (s *Store) Close() {
	s.pool.Close()
}

// Ping verifies the pool can still reach the database.
func (s *Store) Ping(ctx context.Context) error {
	return s.pool.Ping(ctx)
}
