# Decisions (ADRs)

No ADR-classified documents were found in this ingest batch (`.planning/intel/classifications/`). No architectural decisions were locked, and no LOCKED-vs-LOCKED conflict is possible for this batch.

Docs reviewed:
- docs/cycle-recovery.md — PRD
- docs/dietary-pattern.md — SPEC
- docs/group-events.md — SPEC
- docs/health-screening.md — SPEC
- docs/roadmap.md — PRD
- docs/weekly-timetable.md — DOC

## Architecture-flavored statements found in non-ADR docs (not locked, informational only)

These read like architectural commitments but appear inside PRD/SPEC prose rather than a dedicated ADR with Decision/Consequences/Accepted-status structure. Flagged here so `gsd-roadmapper` can decide whether any should be promoted to a formal ADR later.

- **Local-first data storage, cloud sync as backup not source of truth.**
  source: docs/roadmap.md ("Data storage model" row, §1 Core Features > Cardio & Activity Tracking)
- **No cross-user aggregate location visualization will ever be built (no heatmap, no "most active area" feature), as a permanent product-category exclusion.**
  source: docs/group-events.md §3 ("Headline commitment")
- **Server-side EXIF stripping is unconditional and does not rely on client-side stripping as a safeguard.**
  source: docs/group-events.md §3 ("The upload flow")
- **Forgiveness mechanics (shields, comeback repair, injury guardrail) are never monetized, permanently.**
  source: docs/roadmap.md §1 ("The Monetization Boundary")
- **`dietary_pattern` is never part of gate-resolution logic; it is strictly downstream of the Clearance Gate decided by Condition Tags.**
  source: docs/dietary-pattern.md §2 ("Explicit Non-Gating Rule")

None of these are marked `locked: true` by any classification, so they carry normal (non-LOCKED) precedence and can be revisited without triggering a BLOCKER.
