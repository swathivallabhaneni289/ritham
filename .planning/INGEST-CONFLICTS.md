## Conflict Detection Report

### BLOCKERS (0)

None. No ADR-classified documents were present in this ingest batch, so no LOCKED-vs-LOCKED contradiction is possible. No documents were classified UNKNOWN at low confidence. Cross-ref graph (cycle-recovery.md -> dietary-pattern.md -> health-screening.md; weekly-timetable.md -> health-screening.md) contains no cycles.

### WARNINGS (0)

None found. Two PRDs exist (docs/roadmap.md, docs/cycle-recovery.md); their overlapping requirement (the Momentum qualifying-session bar and Recovery Week guardrail) was checked line-by-line and states identical acceptance criteria in both documents (10-minute cardio / 3-working-set lift bar; Recovery Week is user-initiated only, never auto-triggered). No divergent acceptance criteria were found on any shared requirement across the six documents, so nothing was routed to the competing-variants bucket.

### INFO (4)

[INFO] No ADRs present in this batch
  Found: All 6 ingested docs classified as PRD, SPEC, or DOC — none as ADR.
  Note: docs/roadmap.md (PRD), docs/cycle-recovery.md (PRD), docs/health-screening.md/docs/dietary-pattern.md/docs/group-events.md (SPEC), docs/weekly-timetable.md (DOC). Several architecture-flavored statements appear inside PRD/SPEC prose (local-first storage model in docs/roadmap.md §1; "never build cross-user aggregate location visualization" in docs/group-events.md §3; unconditional server-side EXIF stripping in docs/group-events.md §3; forgiveness mechanics never monetized in docs/roadmap.md §1) but carry no `locked: true` status and are not expressed as formal ADRs. Logged for gsd-roadmapper's awareness in case any should be promoted to a locked ADR.

[INFO] Auto-resolved: PRD > DOC on Momentum qualifying-session definition
  Found: docs/weekly-timetable.md §4 rule 3 states only a "GPS-tracked run/walk of 10+ minutes, or a lift with 3+ working sets across 2+ exercises" counts toward the weekly Momentum target, claiming this is "exactly as already specified."
  Note: docs/roadmap.md §4 (PRD, higher precedence than DOC) specifies the cardio qualifying bar as "continuous tracked movement, minimum 10 minutes, whether tracked by GPS or by the manual stopwatch," and separately states "manually-entered sessions... still count, but are labeled distinctly from sensor-verified ones." weekly-timetable.md's restatement drops the manual-stopwatch path, narrowing the rule. Per default precedence (PRD > DOC) and per the workflow's non-locked precedence rule, docs/roadmap.md wins — the qualifying-session definition in synthesized intel (requirements.md REQ-momentum-streak-system) retains the manual-stopwatch path. weekly-timetable.md's cell text should be corrected to match when this feature is built.

[INFO] Reviewed, no contradiction: group-events.md completion-time visibility vs. roadmap.md's "no visible pace/weight comparison"
  Found: docs/roadmap.md Feature 5 (household accounts) states the household circle has "no visible comparison of pace or weight lifted." docs/group-events.md §2 permits a user to optionally attach their own completion time to a group-feed completion card (off by default, their choice each time, never ranked/sorted).
  Note: These apply to different surfaces — roadmap.md's rule governs the household circle; group-events.md's opt-in time display governs the separate friend/group goal-event feed, and group-events.md itself restates the same non-comparative principle ("no visible pace/weight comparison") as its own governing constraint before introducing the opt-in exception. Read as scope-distinct, not contradictory. Even if treated as an ambiguity, SPEC (docs/group-events.md) outranks PRD (docs/roadmap.md) under default precedence, so no auto-resolution action was needed.

[INFO] Precedence-consistent layering confirmed across dependent docs
  Found: docs/dietary-pattern.md (SPEC) and docs/weekly-timetable.md (DOC) each explicitly declare themselves additive restatements of docs/health-screening.md (SPEC); docs/cycle-recovery.md (PRD) explicitly declares it does not modify the condition-tag/clearance-gate system or core Momentum streak mechanics.
  Note: Each of these declared-additive docs was checked against its stated parent(s) for contradiction. Aside from the one narrowing noted above (weekly-timetable.md's qualifying-session cell), no other contradictions were found. Default precedence order (ADR > SPEC > PRD > DOC) required no further tie-breaking in this batch.
