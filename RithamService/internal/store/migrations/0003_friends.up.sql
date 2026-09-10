-- 0003_friends: the mutual friend graph and its three closed-loop connection paths (HOUSEHOLD-02,
-- GROUPEVENTS-01). See docs/group-events.md §1 -- mutual/request-based friending only, never a
-- one-directional follow; three connection paths (contact match, invite link, direct share) and no
-- others; contact matching requires both sides to independently opt in.

-- friend_requests: a request from one user to another. Exactly one pending request may exist per
-- ordered (from, to) pair at a time -- the partial unique index below enforces this at the
-- database level, not just in application code. Two ordered pairs (A->B and B->A) may both be
-- pending simultaneously; that is a distinct pair by this index's own definition.
CREATE TABLE friend_requests (
    id              uuid PRIMARY KEY,
    from_user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    state           text NOT NULL CHECK (state IN ('pending', 'accepted', 'declined')),
    connection_path text NOT NULL CHECK (connection_path IN ('contact_match', 'invite_link', 'direct_share')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    resolved_at     timestamptz
);

CREATE UNIQUE INDEX friend_requests_pending_pair_idx
    ON friend_requests (from_user_id, to_user_id)
    WHERE state = 'pending';

CREATE INDEX friend_requests_to_user_id_idx ON friend_requests (to_user_id);
CREATE INDEX friend_requests_from_user_id_idx ON friend_requests (from_user_id);

-- friendships: a mutual connection, stored exactly once as an unordered pair. The CHECK below is
-- the structural expression of "mutual, never one-directional" (docs/group-events.md §1): a
-- directional follow cannot be represented in this schema at all, because there is no row shape
-- for it -- every row is an unordered pair by construction, not by convention.
CREATE TABLE friendships (
    user_a_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    established_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_a_id, user_b_id),
    CHECK (user_a_id < user_b_id)
);

CREATE INDEX friendships_user_b_id_idx ON friendships (user_b_id);

-- contact_match_optins: per-user opt-in flag for contact matching (§1). A match surfaces only
-- when both sides' rows here have opted_in = true -- see contact_match_digests below.
CREATE TABLE contact_match_optins (
    user_id    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    opted_in   boolean NOT NULL DEFAULT false,
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- contact_match_digests: salted digests of a user's own identifiers (their own phone number/email,
-- hashed client-side, then salted server-side -- see internal/friends/contactmatch.go), stored so
-- that OTHER users who already have this person in their device contacts can find them. Never a
-- raw contact identifier -- no column exists for one. Deleted in full whenever the owning user
-- turns opted_in off, so opting out is not merely a flag flip.
CREATE TABLE contact_match_digests (
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    digest  bytea NOT NULL,
    PRIMARY KEY (user_id, digest)
);

-- invite_tokens: single-use, window-expiring invite links (§1). Only a SHA-256 digest of the
-- token is stored, mirroring 0001_identity's sessions.token_sha256 discipline -- the plaintext
-- token is returned to the issuer exactly once and never persisted.
CREATE TABLE invite_tokens (
    token_sha256        bytea PRIMARY KEY,
    issuer_user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at           timestamptz NOT NULL,
    consumed_at          timestamptz,
    consumed_by_user_id  uuid REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX invite_tokens_issuer_user_id_idx ON invite_tokens (issuer_user_id);
