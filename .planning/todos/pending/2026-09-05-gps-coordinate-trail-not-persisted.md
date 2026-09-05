---
created: 2026-09-05T11:54:22.000Z
title: GPS coordinate trail not persisted — route comparison runs on a proxy heuristic
area: engineering
files: [RithamCore/Sources/RithamCore/Cardio/CardioSession.swift, RithamApp/Ritham/Persistence/CardioSessionRecord.swift, RithamApp/Ritham/Cardio/GPSTrackingSession.swift, RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift, RithamApp/Ritham/Cardio/Views/RouteComparisonView.swift]
---

## Problem

Flagged during Phase 2 plan 02-10 (cardio UI) execution, 2026-09-05: no per-sample GPS coordinate
trail is persisted anywhere in the codebase. `CardioProgress` (RithamCore), `CardioSessionRecord`
(SwiftData), and `GPSTrackingSession` (RithamApp) all keep only aggregate distance/elevation/
splits — never the actual lat/lng breadcrumb trail of a session.

This is a real architectural gap for CARDIO-03 (route/segment comparison, opt-in). The plan
02-10 executor documented it honestly rather than scope-creeping a schema change into other
plans' owned files (fixing it touches 02-01's `CardioSession.swift` and 02-08's
`CardioSessionRecord.swift`, both already committed and tested):

- `CardioHistoryView`'s MapKit route map is real, working code, but it's gated on non-empty
  coordinate input and is currently always called with `[]` — so it never actually renders a
  route.
- `RouteComparisonView`'s "same route" detection is a documented proxy — same activity type
  within 250m of start location — not real polyline/track matching, since there's no polyline to
  match against.

## Solution

TBD. Adding real coordinate-trail persistence means:
- A new `@Model` (or an array field) to store the lat/lng/timestamp trail per cardio session,
  touching `CardioSessionRecord.swift`'s existing schema (SwiftData migration considerations)
- `GPSTrackingSession` actually accumulating and handing off the trail, not just aggregates
- `CardioTrackAccumulator` (or a sibling) computing route/segment matches from real polylines
  instead of the current start-point-proximity heuristic

Not urgent — the current proxy is honestly documented and doesn't misrepresent itself as more
than it is (CARDIO-03 is opt-in and single-user-only per the plan-checker's scoping, so no user
ever sees a fabricated comparison). Worth doing before CARDIO-03 is presented as a finished
feature, or before Phase 3's Momentum tracking builds anything on top of session location data.
