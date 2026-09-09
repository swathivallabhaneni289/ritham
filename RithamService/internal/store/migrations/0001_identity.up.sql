-- 0001_identity: the first two tables this database ever gets.
--
-- users.apple_subject is UNIQUE and NOT NULL because Apple's stable subject identifier is the
-- only identity anchor this system has (04.1-CONTEXT.md's Identity and Account Recovery
-- decision).
--
-- sessions stores only a SHA-256 digest of the bearer token, never the token itself -- the
-- column name makes that self-evident, and its bytea type means a plaintext token cannot be
-- written into it without a type error.

CREATE TABLE users (
    id            uuid PRIMARY KEY,
    apple_subject text NOT NULL UNIQUE,
    display_name  text NOT NULL DEFAULT '',
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
    id           uuid PRIMARY KEY,
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_sha256 bytea NOT NULL UNIQUE,
    issued_at    timestamptz NOT NULL DEFAULT now(),
    expires_at   timestamptz NOT NULL,
    revoked_at   timestamptz
);

CREATE INDEX sessions_user_id_idx ON sessions(user_id);
