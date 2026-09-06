---
created: 2026-09-06T00:00:00.000Z
title: Stale comeback window can re-fire rebuild transition in a large catch-up reconcile()
area: engineering
files: [RithamCore/Sources/RithamCore/Momentum/MomentumReconciliation.swift, RithamCore/Sources/RithamCore/Momentum/MomentumLedger.swift]
---

## Problem

Flagged during Phase 3 plan 03-03 (reconciliation fold) execution, 2026-09-06, and re-flagged
during plan 03-04 (persistence) without a fix, since fixing it requires touching
`MomentumReconciliation.swift`, out of both plans' file scope: a stale, already-expired-but-unclaimed
`ComebackWindow` can re-fire its "rebuilt streak" zero-the-streak transition against a newly-met
week's streak increment, if both land in the *same* `reconcile()` call. This only arises from a
large multi-week catch-up fold — i.e., a user who hasn't opened the app in a long stretch, long
enough that a previous comeback window expired unclaimed AND at least one subsequent week was
independently met, all reconciled in a single pass.

Does not affect any of 03-03's or 03-04's required named tests or acceptance criteria — both
plans tested and shipped the literal, in-scope implementation and documented this as a known,
accepted edge case rather than silently papering over it.

## Solution

Requires a structural fix to `MomentumReconciliation.swift`'s fold logic and/or a
`ComebackWindow.resolved`-style marker field on the persisted ledger shape
(`MomentumLedgerRecords.swift`) so a stale window's transition can't re-fire once superseded by a
later met week in the same fold pass. Whoever next touches either file should evaluate whether
this is worth fixing now or remains an acceptable rare-case simplification — see
`03-03-SUMMARY.md` and `03-04-SUMMARY.md`'s "Next Phase Readiness" sections for the full
reasoning trail.
