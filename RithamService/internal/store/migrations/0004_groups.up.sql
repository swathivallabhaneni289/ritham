-- 0004_groups: small, closed, invite-only groups and the membership predicate every later
-- group-scoped surface (feed, events, completion) authorizes against (GROUPEVENTS-01, HOUSEHOLD-02).
-- See docs/group-events.md §1 -- a group is invisible to search, is not listed on any profile,
-- generates no public or aggregate signal, and has membership mechanics deliberately unlike
-- Strava's: any member leaves at any time with no ownership handoff, and the organizer leaving
-- simply continues the group because there is nothing public attached to the role.

-- groups: deliberately has no visibility, discoverability, public-slug, or member-count column.
-- docs/group-events.md §1 states no public or joinable-by-anyone tier exists at all for this
-- feature -- not a private default with a public option, but no such tier existing -- so the
-- absence of such a column here is the implementation of that rule, not a schema convenience a
-- later migration happens not to have added yet. Adding one later would be a product decision,
-- not a schema oversight to fix.
CREATE TABLE groups (
    id                 uuid PRIMARY KEY,
    name               text NOT NULL,
    organizer_user_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    removal_policy     text NOT NULL DEFAULT 'anyMember' CHECK (removal_policy IN ('anyMember', 'organizerOnly')),
    created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX groups_organizer_user_id_idx ON groups (organizer_user_id);

-- group_members: the membership predicate's own storage. A row here is the sole definition of
-- "is a member of this group" -- every group-scoped read or write in this and later plans is
-- ultimately scoped by a query against this table (internal/groups/membership.go's RequireMember).
CREATE TABLE group_members (
    group_id  uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, user_id)
);

CREATE INDEX group_members_user_id_idx ON group_members (user_id);

-- group_invitations: a pending, accepted, or declined invitation from an existing friend into a
-- closed group. One row per (group, invitee) pair -- a fresh invite after a prior decline or a
-- former member's departure reuses (upserts onto) the same row rather than accumulating history,
-- since only the current state, not the full invitation history, is ever read.
CREATE TABLE group_invitations (
    group_id        uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    invitee_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    inviter_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    resolved_at     timestamptz,
    state           text NOT NULL CHECK (state IN ('pending', 'accepted', 'declined')),
    PRIMARY KEY (group_id, invitee_user_id)
);

CREATE INDEX group_invitations_invitee_user_id_idx ON group_invitations (invitee_user_id);
