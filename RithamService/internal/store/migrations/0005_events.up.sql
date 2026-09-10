-- 0005_events: Goal-Events, RSVPs, and completions (GROUPEVENTS-02, GROUPEVENTS-01).
-- See docs/group-events.md §2 -- a Goal-Event is a shared, non-timed commitment, not a race and
-- not a challenge in Strava's competitive sense. Each person logs their own completion on their
-- own time; there is no synchronized start and no clock.

-- goal_events: the organizer's shared commitment. target_kind/target_value are genuinely
-- optional (target_kind = 'none' means target_value is NULL) -- the target lives on the event,
-- never on any individual member's own log.
CREATE TABLE goal_events (
    id                uuid PRIMARY KEY,
    group_id          uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name              text NOT NULL,
    activity_type     text NOT NULL,
    target_kind       text NOT NULL CHECK (target_kind IN ('none', 'distance', 'duration')),
    target_value      double precision,
    starts_on         date NOT NULL,
    ends_on           date NOT NULL,
    organizer_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX goal_events_group_id_idx ON goal_events (group_id);

-- event_rsvps: a pre-event headcount signal only. There is no roster column beyond the
-- (event, user) pair itself, and this table is never joined against event_completions in any
-- query this migration's own package writes -- docs/group-events.md §2's separation between "who
-- said they were in" and "who came out" is enforced by keeping these two tables on entirely
-- separate read paths, not by a filter that could be applied inconsistently.
CREATE TABLE event_rsvps (
    event_id     uuid NOT NULL REFERENCES goal_events(id) ON DELETE CASCADE,
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    responded_at timestamptz NOT NULL,
    PRIMARY KEY (event_id, user_id)
);

-- event_completions: a binary fact that someone finished, with an optional own time. This table
-- has NO column for a measured distance, a pace, a route, an ordinal position, a score, or a
-- completion fraction -- GROUPEVENTS-02 keeps that data in the user's own private log, so there
-- is nothing here for it to be written into. Adding such a column in a future migration would be
-- a product decision requiring its own review, not a schema oversight to fix.
--
-- own_time_seconds is the one number this table does store, and it is deliberately inert: no
-- query anywhere in this codebase orders, groups, or aggregates by it (see
-- internal/events/noranking_test.go's structural gate, plan 04.1-10).
--
-- group_visible defaults to true and is flipped to false by the leave-with-remove-posts
-- disposition (internal/groups.CompletionVisibility, wired from internal/events) -- a leaver's
-- past completions are hidden from the group going forward, never deleted.
CREATE TABLE event_completions (
    id               uuid PRIMARY KEY,
    event_id         uuid NOT NULL REFERENCES goal_events(id) ON DELETE CASCADE,
    user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    completed_at     timestamptz NOT NULL,
    own_time_seconds integer,
    photo_asset_id   uuid REFERENCES photo_assets(id),
    place_name       text,
    caption          text,
    posted_at        timestamptz NOT NULL DEFAULT now(),
    group_visible    boolean NOT NULL DEFAULT true,
    UNIQUE (event_id, user_id)
);

CREATE INDEX event_completions_event_id_idx ON event_completions (event_id);
CREATE INDEX event_completions_user_id_idx ON event_completions (user_id);
