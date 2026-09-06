---
created: 2026-09-06T04:00:00.000Z
title: SessionEditView built and tested but not reachable from StrengthHistoryView
area: engineering
files: [RithamApp/Ritham/Strength/Views/SessionEditView.swift, RithamApp/Ritham/Strength/Views/StrengthHistoryView.swift]
---

## Problem

Flagged during Phase 2 plan 02-15 (strength history) execution, 2026-09-06: `SessionEditView` and
`SessionEditModel` (retroactive session editing, merge, and split — STRENGTH-05) are fully built
and unit-tested (`SessionRevisionScreenTests`, 9/9 passing), but there is no entry point into them
from `StrengthHistoryView` — no `.sheet(item:)` or navigation link from a history row opens it.
The plan's declared `files_modified` scope for that task excluded `StrengthHistoryView.swift`, so
the executor correctly didn't touch it, but that leaves the feature functionally unreachable in
the shipped app despite being code-complete.

## Solution

Add a `.sheet(item:)` (or equivalent navigation) entry point from a row in `StrengthHistoryView`
that opens `SessionEditView` for that session. Small, scoped UI-wiring task — no new domain logic
needed, everything underneath already works and is tested. Should be quick to close out; worth
doing before Phase 2 is considered fully done, since STRENGTH-05 isn't actually usable without it.
