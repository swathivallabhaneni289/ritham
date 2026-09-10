-- 0006_feed: the group feed's pagination index and the fixed, count-free cheer table
-- (GROUPEVENTS-04, docs/group-events.md §2/§4).

-- completion_cheers has NO counter column and no aggregate view over it, deliberately --
-- GROUPEVENTS-04 rules out a kudos count that could itself become a ranking surface. A viewer's
-- own cheer state is read per-viewer (internal/feed/cheers.go's SendCheer/WithdrawCheer and
-- feed.go's per-viewer EXISTS lookups), never summed across users.
CREATE TABLE completion_cheers (
    completion_id uuid NOT NULL REFERENCES event_completions(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cheer         text NOT NULL,
    sent_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (completion_id, user_id, cheer)
);

-- Supports EventFeed's cursor pagination (filtered by event_id, ordered by posted_at). GroupFeed
-- pages across every event in a group via a join through goal_events, so this single-table index
-- does not fully cover that path -- see 04.1-12-SUMMARY.md for the documented tradeoff.
CREATE INDEX event_completions_event_posted_idx ON event_completions (event_id, posted_at);
