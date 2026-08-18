# Ritham — Cycle Tracking & Recovery-Aware Momentum: Design Document

**Status:** Design draft
**Scope:** Two new opt-in features. Neither modifies the mandatory health-intake questionnaire, the condition-tag/clearance-gate system, or the core Momentum streak mechanics — both are additive, adaptive-suggestion layers only, in the same product category as [`docs/dietary-pattern.md`](./dietary-pattern.md).

**Citation convention used throughout:**
`[Evidence: Author Year]` — a claim directly grounded in the provided research synthesis.
`[Inference: ...]` — a product/design conclusion the Ritham team is drawing that is *not* directly stated in the source research (e.g., how to wire a well-evidenced finding into an app mechanic).
`[Unverified: ...]` — something the research explicitly could not confirm; stated as an open question, never asserted as fact.

---

## 1. Cycle Tracking — opt-in and scope

### 1.1 How it's turned on

- **Never presented at mandatory health intake.** The intake questionnaire's condition tags and clearance gates (none/recommended/required-blocking) are reserved for medical conditions. Cycle tracking is not a condition and is never asked about there.
- **Settings-page opt-in only.** It lives as a toggle under Settings, off by default for every user. Enabling it is a deliberate, separate action, not a default inferred from age, sex, or any intake answer.
- Turning it on shows a short consent screen: what's logged, that it drives *suggestions* only (never gates), that it explicitly defers to Pregnancy/Postpartum tags (see 1.4), and a preview of the disclaimer in Section 4.
- It sits in the same product category as an existing preference layer like Dietary Pattern — an adaptive suggestion input, not a condition. It carries **no clearance gate at any tier.** `[Inference: this categorization follows directly from the task's framing and is the load-bearing design decision for the rest of this doc]`
- Can be turned off at any time from the same settings screen; on disable, the user is asked whether to retain or delete their logged cycle history. `[Inference: opt-in implies revocable, and user control over sensitive logged data is a reasonable extension of that principle]`

### 1.2 What's logged

- **Period start dates** — the primary input. A one-tap "my period started today" log, editable retroactively for the past few days.
- **Average cycle length** — an optional fallback for users who don't want to log every period; lets the app project phase windows from a single number rather than requiring ongoing logging.
- **Optional daily symptom tags** — e.g., cramping, fatigue, low mood, poor sleep. Lightweight, never mandatory. This log is what actually drives suggestion adjustments (see Section 2), not the phase label itself.
- **Optional contraceptive method category** — none / combined hormonal (pill, patch, ring) / hormonal IUD / progestin-only pill or implant / non-hormonal. This does not gate anything; it recalibrates how much confidence the phase estimate carries (see 1.3).

### 1.3 How phases are estimated

Ritham computes an estimated phase window (menstrual ~days 1–5, follicular ~days 1–13, ovulatory ~days 12–14, luteal ~days 15–28 of a modeled cycle) from logged period start dates and, as more cycles are logged, a rolling average cycle length. `[Evidence: NIH/NICHD; MedlinePlus]`

This is presented as an **estimate, explicitly labeled low-confidence** — Ritham does not assert "you are ovulating today" as fact. `[Evidence: Elliott-Sale et al. 2025 — period-tracking apps have "extremely low predictive accuracy" for ovulation day, ~20%; the "textbook" 28-day/day-14-ovulation cycle represents as few as ~10% of real-world cycles; up to 66% of exercising women show subtle or overt menstrual disturbance even while bleeding on a regular schedule]`

Confidence is downgraded further, and the UI says so plainly, when:

- **Cycle length varies significantly** cycle-to-cycle in the user's own logged history.
- **Combined hormonal contraceptive use is logged** (pill/patch/ring). These pharmacologically suppress the hypothalamic-pituitary-ovarian axis, producing a flattened, exogenous hormone profile with a withdrawal bleed that is not a true menstrual cycle — phase-based suggestions are disabled or heavily caveated for this group. `[Evidence: Cabre et al. 2024; Elliott-Sale et al. 2020]`
- **Progestin-only pill/implant use is logged.** Effect on ovulation suppression varies by person and formulation, and no reliable suppression rate exists in the underlying research to build a confidence adjustment on. `[Unverified: the research explicitly could not find a verified ovulation-suppression rate for POPs/implants — Ritham states this to the user as "effect varies and isn't well established" rather than inventing a number]`
- **Conversely, hormonal IUD use is logged** — because the mechanism is mainly local/uterine, IUD users retain a physiological response pattern much closer to a natural cycle, so standard calendar estimation applies more reasonably to them than to combined-hormonal-contraceptive users. `[Evidence: Cabre et al. 2024]`

**Irregular-cycle handling:** cycles consistently shorter than 21 days or longer than 35 days, or absent bleeding, trigger a purely **educational** note suggesting the user consider discussing it with a clinician — cycle regularity is treated in the literature as a genuine health signal. `[Evidence: Attia et al. 2023 and NIH/MedlinePlus definition of irregular cycle; Vollmar, Mahalingaiah & Jukic 2024/2025 on cycle regularity as a "vital sign"]` This note is informational only. It is **not** a clearance gate and does not touch the intake condition-checklist system in any way — it doesn't block, downgrade, or flag anything outside the cycle-tracking feature itself.

### 1.4 Explicit rule: Pregnancy / Postpartum interaction

**Stated plainly: cycle tracking defers entirely to the existing Pregnancy and Postpartum condition tags. It never attempts to model pregnancy or postpartum states itself, and it never asks pregnancy-screening questions of its own (e.g., no "could you be pregnant?" prompts) — that determination belongs solely to the condition checklist.**

- If a user with cycle tracking **ON** has a Pregnancy or Postpartum tag added to their profile (via intake or a later update), cycle tracking **auto-disables immediately**: phase estimation stops, all phase-based suggestion adjustments stop, and the user sees a one-time notice: *"Cycle tracking has been turned off because your profile now includes Pregnancy/Postpartum — Ritham follows your existing condition settings for this instead."* `[Inference: this is the explicit product rule the task requires; it exists to prevent the two systems from ever modeling the same state independently]`
- Previously logged period/symptom data is retained but frozen out of active suggestion logic while the tag is present; the user can delete it from Settings at any time.
- Re-enabling cycle tracking after a Pregnancy/Postpartum tag is later removed is **always a fresh, explicit opt-in action** by the user — it never re-enables automatically. `[Inference]`

---

## 2. Phase-based workout adjustment

### 2.1 Design principle, stated up front

The single largest risk in this feature is building a calendar-phase-driven prescription table — exactly the pattern the research identifies as unsupported. The evidence is clear that this doesn't hold up: strength/endurance effects across phase are "trivially reduced... likely to be so small as to be meaningless for most of the population" `[Evidence: McNulty et al. 2020]`; it's "premature to conclude" hormone fluctuations meaningfully affect resistance-training performance or adaptation `[Evidence: Colenso-Semple et al. 2023]`; phase-based recommendations are "without a good basis" `[Evidence: D'Souza et al. 2023]`; and even the *mechanism* underlying "day 10, therefore follicular, therefore train harder" is shaky, since apps and calendars predict ovulation day with only ~20% accuracy `[Evidence: Elliott-Sale et al. 2025]`.

So Ritham does **not** key adjustments off the estimated phase label. Instead: **logged symptoms are the trigger, and the phase label is context-only, shown for the user's own awareness but never fed into the suggestion logic.** This mirrors how Ritham already treats other day-to-day fatigue/soreness input — it's the same architecture, not a special cycle-specific rule. `[Inference: this is the design resolution of the well-evidenced/speculative split the research demands]`

Two claims are kept explicitly separate rather than conflated: **symptom burden is real and legitimately affects training tolerance, RPE, and motivation** `[Evidence: Carmichael et al. 2021]`, while **objective maximal physical capacity changing by phase is not demonstrated** at the population level `[Evidence: McNulty et al. 2020; Carmichael et al. 2021 — of 35 studies on objective performance, 20 found no cycle effect]`. Ritham's copy adjusts for how a symptomatic day *feels*, and never implies the user's underlying capability is diminished "this week." `[Inference, informed by Pfender et al. 2024's feminist-lens finding that cycle-syncing content can reinforce narratives that women's bodies are inherently limiting — Ritham avoids "you're weaker this week" framing entirely]`

Like everything in Section 1, this is a **suggestion**, never a gate — the same category as Dietary Pattern, not the condition checklist.

### 2.2 Phase reference table

| Cycle phase (estimated, context only) | Typical physiology (shown for awareness — not a suggestion trigger) | Well-evidenced adjustment Ritham actually makes | Contested/speculative claims — Ritham does **not** adjust on these |
|---|---|---|---|
| **Menstrual** (~days 1–5) | Estrogen and progesterone low `[Evidence: NIH/NICHD]` | If symptoms (cramping, fatigue, poor sleep) are logged that day, surface a lower-intensity or technique-light alternative — the same symptom-triggered mechanism used on any other day `[Evidence: Carmichael et al. 2021 on real symptom burden affecting tolerance/RPE/motivation; Saw, Main & Gastin 2016 — subjective self-report tracks training response more sensitively than objective measures]` | "Higher injury risk while menstruating" — not asserted for this phase; not supported by any source in the research base |
| **Follicular** (~days 1–13) | Estrogen rising `[Evidence: NIH/NICHD]` | None phase-specific — suggestions on these days are driven purely by symptom log and Recovery-aware Momentum sleep input, identical to any other day | "Best phase to push intensity / build strength," a common cycle-syncing claim — **not implemented.** `[Evidence: McNulty et al. 2020 — effects "so small as to be meaningless for most of the population"; Colenso-Semple et al. 2023 — "premature to conclude" hormones appreciably influence acute performance or adaptations; D'Souza et al. 2023 — such recommendations are "without a good basis"]` |
| **Ovulatory** (~days 12–14) | LH surge; estrogen peaks then drops sharply `[Evidence: NIH/NICHD]` | None phase-specific | Elevated ACL/injury-risk claim — genuinely contested, not used as a trigger. `[Evidence: Balachandar et al. 2017 reported elevated pre-ovulatory risk but relied on retrospective, non-hormone-verified staging; Dos'Santos et al. 2023, restricted to biomechanical surrogates, found evidence "inconclusive," of "very low" quality, with "considerable individual variation," and explicitly cautioned practitioners against changing practice on it]` Also: Ritham has the *least* confidence in labeling this phase correctly on any given day at all. `[Evidence: Elliott-Sale et al. 2025 — ~20% predictive accuracy for actual ovulation day]` |
| **Luteal** (~days 15–28) | Progesterone rises then falls; smaller secondary estrogen rise `[Evidence: NIH/NICHD]` | Same symptom-triggered adjustment as above — late-luteal/PMS-type symptoms are handled exactly like symptoms logged any other day, not by a luteal-specific rule | A small resting-metabolic-rate rise is real but tiny, and not used to change suggestions. `[Evidence: Benton, Hutchins & Dawes 2020 — effect size 0.33, which "weakened and lost significance" in more recent, better-controlled studies]` "Recovery is slower in luteal phase" — **not implemented.** `[Evidence: Cabre et al. 2024 — recovery-marker studies "do not report clear or consistent effects" by phase; Funaki et al. 2022 — muscle-damage markers tracked progesterone concentration specifically, not phase category]` |

### 2.3 Where the "cycle syncing" trend is overstated relative to the evidence

Ritham states this plainly to users rather than quietly under-delivering on a popular expectation: health-communication researchers who studied the popular "cycle syncing" trend directly (as distinct from the underlying sports-science literature) found that "clinical research on the effects of cycle syncing is inconclusive," that the format is built on "fragmented interpretations" rather than a nuanced read of the science, and — pointedly — that the uncertainty itself usually isn't disclosed to viewers `[Evidence: Pfender, Kuijpers, Wanzer & Bleakley 2024]`. A follow-up content analysis found only 4% of #cyclesyncing creators even mentioned research, and concluded directly: "the menstrual cycle does not commonly affect aerobic and anaerobic performance" `[Evidence: Pfender, Wanzer, Mikkers & Bleakley 2025]`. Ritham's phase table above is built to not repeat that pattern: the "well-evidenced" column is intentionally thin, and every stronger claim marketed elsewhere as settled is named in the "contested" column along with why.

---

## 3. Recovery-aware Momentum

### 3.1 Sleep input

**MVP — self-report.** A simple daily prompt, e.g. "How did you sleep last night?" (Great / OK / Poor), optionally with a note. This is the primary signal, not a placeholder for something better: subjective self-report measures track acute and chronic training-load response more sensitively and consistently than objective physiological measures in the cited research. `[Evidence: Saw, Main & Gastin 2016]`

**v2 — wearable HRV/sleep-stage data**, per Ritham's existing wearable-fusion roadmap item. When connected, wearable signals augment (never replace) the self-report. A single isolated HRV reading is **not** allowed to drive the day's suggestion on its own: combining HRV with wellbeing/self-report and resting heart rate outperformed HRV alone in training-outcome studies `[Evidence: Alfonso, Clarke & Capdevila 2025]`, and a more recent wearables study found self-reported stress/energy didn't correlate with measured HRV at all — "energized" was even associated with *lower* HRV in that sample — with the authors explicitly cautioning against single-reading-driven personalization. `[Evidence: Ungaro et al. 2026]`

### 3.2 The mechanic: how a "bad sleep" day adjusts the suggested session

If a user logs poor sleep (MVP), or the combined self-report + wearable signal reads as poor recovery (v2), Ritham's suggested session for that day shifts toward technique-light, lower-velocity/lower-force, moderate-intensity work, and away from high-skill, max-effort, explosive, or heavy-load sessions.

This direction is directly supported: sleep loss impairs skill control most (SMD −0.87), then explosive power (−0.63), speed (−0.52), and max force (−0.35), while raising perceived exertion (+0.39) — the same workload simply feels harder `[Evidence: Kong et al. 2025 meta-analysis, 45 trials]`. Aerobic endurance is also reduced, more so in the meta-analysis's non-athlete subgroup (SMD −1.02) — the closest direct bridge to Ritham's general user base `[Evidence: Kong et al. 2025]`. A controlled trial found sustained restriction cut bar velocity up to 15% and raised session RPE 11% before raw completed volume necessarily dropped — "exercise quality degrades before quantity" `[Evidence: Knowles et al. 2022]`. One night of restricted sleep alone shifted autonomic balance toward sympathetic dominance and lowered HRV in healthy non-athlete women, the most direct mechanistic bridge available to a general-population feature `[Evidence: Jung, So & Ko 2026]`.

**This rule itself is flagged as an inference, not a cited guideline** — no source in the research (not CDC, not the actual National Sleep Foundation, not the ACSM/ECSS consensus statement) issues an explicit "bad night → lighter session" rule. It's Ritham's own synthesis of the Tier 1 findings above. `[Inference — this is the single most important flag in this document and should stay visible in-product-facing research documentation, not buried]`

**What it does not claim:** a single poor night is not injury-risk messaging. The injury-risk literature is about chronic, habitual short sleep, not one night: adolescent athletes sleeping <8h were 1.7× more likely to report injury than those sleeping ≥8h `[Evidence: Milewski et al. 2014]`; a systematic review of soccer players and a cohort study of track athletes reach the same chronic-pattern conclusion `[Evidence: Cantón et al. 2026; Viegas et al. 2022]`. Ritham never tells a user "you're at higher injury risk today" off one bad night — that would overstate what the cited studies actually measured. If poor sleep is logged repeatedly over time, Ritham can surface a general educational note suggesting a conversation with a clinician about persistent poor sleep or unresolving daytime sleepiness — informational only, never a gate. `[Evidence: CDC and MedlinePlus both note persistent poor sleep or unresolved daytime sleepiness warrants clinician follow-up]`

### 3.3 Invariants: this must not create a new way to lose the streak

Stated as an explicit list, because "a lighter suggestion is still fine" is easy to state and easy to accidentally violate in implementation:

1. **The qualification bar is unchanged.** Whatever session meets Ritham's existing qualifying-session definition (10 minutes / 3 working sets) still qualifies, full stop. Sleep input never modifies that bar.
2. **A lighter suggested session that meets the bar is a fully qualifying Momentum session** — identical in streak effect to any other qualifying session. Recovery-aware Momentum changes what Ritham *suggests*, never what *counts*.
3. **Declining the lighter suggestion and doing the originally planned (harder) session is always available**, and also fully qualifies normally. The sleep check-in never restricts what a user can actually do.
4. **Skipping the sleep check-in has zero effect.** No data is treated as neutral — never as a missed-input penalty, never as an assumed "bad" state.
5. **The feature never auto-consumes a shield and never auto-triggers a Recovery Week.** Recovery Week stays a user-initiated flag under the existing injury/recovery guardrail; a poor-sleep signal alone does not invoke it on the user's behalf. `[Inference: preserves the existing guardrail's user-agency design rather than building a parallel, automatic version of it]`
6. **The weekly cadence target (default 3 qualifying sessions/week) is untouched.** The feature cannot raise or lower it, and cannot mark a day non-qualifying that would otherwise qualify.
7. **No penalty, asterisk, badge, or messaging** for training harder than suggested, or for accepting the lighter option — either choice is presented and tracked identically.

### 3.4 Composition with Cycle Tracking (one line)

If both features are active and both would suggest an adjustment on the same day (e.g., logged period symptoms and poor sleep both present), suggestions compose rather than stack or conflict: Ritham surfaces a single, most-conservative relevant suggestion, and neither feature ever gates the session regardless of how many signals are active. `[Inference]`

---

## 4. Disclaimer text

Tone matches Ritham's existing disclaimers: general education, not a substitute for a doctor, and — specifically for cycle tracking — deliberately avoiding overclaiming on injury-risk-by-phase given how contested that literature is.

**Cycle Tracking disclaimer**

> Cycle tracking in Ritham is a personal logging and estimation tool, not a medical or diagnostic device. Phase estimates are calculated from the dates you log and are approximate — even regular cycles vary person to person and cycle to cycle, and Ritham cannot confirm ovulation or hormonal phase directly. This feature is not a method of contraception or fertility planning and should not be used to prevent or plan pregnancy.
>
> Workout suggestions adjusted through cycle tracking are based on symptoms you log, not on a clinical assessment, and are never used to block or gate access to any workout. Research on how the menstrual cycle affects exercise performance, recovery, and injury risk is mixed, and in several areas more limited or inconclusive than popular fitness content often suggests. Ritham deliberately does not claim that a given cycle phase increases your injury risk or determines how well you'll perform — the current evidence doesn't support that level of certainty, and we'd rather say so than overstate it.
>
> If your cycles are irregular, unusually painful, or absent, or you're unsure whether something you're experiencing is typical for you, talk to a doctor or clinician — Ritham is not a substitute for medical care.
>
> If your profile includes a Pregnancy or Postpartum condition tag, cycle tracking turns off automatically and your existing pregnancy/postpartum guidance applies instead.

**Recovery-aware Momentum disclaimer**

> Recovery-aware Momentum uses how you report you slept — and, if you've connected one, your wearable's sleep and heart-rate-variability data — to suggest a lighter workout option on days it looks like you might be under-recovered. This is general education, based on our team's read of current sleep-and-training research, not a medical or diagnostic assessment or a specific clinical guideline.
>
> It's a suggestion, not a requirement. You can always do your originally planned session instead, and either choice counts toward your Momentum streak the same way, as long as it meets Ritham's usual qualifying bar. A single rough night's sleep is not a diagnosis, and Ritham does not treat it as a sign of elevated injury risk.
>
> If poor sleep is a regular pattern for you, or you're dealing with ongoing daytime sleepiness that isn't improving, consider talking to a doctor — Ritham is not a substitute for medical advice.
