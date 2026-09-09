package store

import (
	"embed"
	"errors"
	"net/url"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5" // registers the "pgx5" scheme
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

// migrationFS embeds every migration this package ships, so the binary carries its own schema
// history and never depends on a migrations/ directory existing on disk at runtime.
//
//go:embed migrations/*.sql
var migrationFS embed.FS

// pgx5Scheme is the URL scheme golang-migrate's database/pgx/v5 driver registers itself under
// (see its package init()). pgxpool.New accepts a standard "postgres://" URL; golang-migrate
// resolves its driver purely from the URL scheme. The same RITHAM_DATABASE_URL therefore cannot
// be passed unmodified to both -- Migrate rewrites the scheme on its own copy of the URL rather
// than requiring two differently-schemed env vars for one database.
const pgx5Scheme = "pgx5"

// Migrate applies every embedded migration, up, against databaseURL. It is idempotent:
// migrate.ErrNoChange (already at the latest version) is treated as success, not an error.
// This package exposes no force-version or drop-everything helper -- every schema change goes
// through this versioned, reversible path, per T-04.1-02.
func Migrate(databaseURL string) error {
	sourceDriver, err := iofs.New(migrationFS, "migrations")
	if err != nil {
		return err
	}

	migrateURL, err := rewriteSchemeForMigrate(databaseURL)
	if err != nil {
		return err
	}

	m, err := migrate.NewWithSourceInstance("iofs", sourceDriver, migrateURL)
	if err != nil {
		return err
	}
	defer m.Close()

	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return err
	}
	return nil
}

// rewriteSchemeForMigrate returns databaseURL with its scheme replaced by pgx5Scheme, leaving
// every other component (host, credentials, query parameters) untouched.
func rewriteSchemeForMigrate(databaseURL string) (string, error) {
	u, err := url.Parse(databaseURL)
	if err != nil {
		return "", err
	}
	u.Scheme = pgx5Scheme
	return u.String(), nil
}
