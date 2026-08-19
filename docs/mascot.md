# Momo — Ritham's Live Activity Mascot

## 1. Character concept

**Name: Momo** (fallback: **Mo**, see naming risk note below) — short for **Momentum**, Ritham's existing non-punishing streak system. This is a deliberate, literal tie: the mascot isn't a generic sidekick bolted onto the app, it *is* the Momentum system given a face. When Momentum already frames long-term consistency warmly ("you've built a real 12-week habit," never threat-framed), naming the mascot after it means every future reference to Momo is implicitly a reference to that same non-punishing philosophy.

**Naming risk to flag, not resolve here:** "Momo" has a prior association with the 2018–19 "Momo Challenge" creepypasta/hoax. There's no way to verify from this research how culturally live that association still is in 2026 — it may be fully faded, or it may still surface in search/social results. Treat this as a literal pre-ship task: run a name-recognition and trademark check before committing art and copy to "Momo." "Mo" is listed as a fallback specifically because it preserves the Momentum tie if "Momo" turns out to be a liability.

**Species: cat**, building directly on the original idea rather than replacing it. The case for keeping it:
- Cats carry almost no generational subculture coding. Compare to a Pokémon-style creature (reads young/gamer-coded) or an owl (now culturally *is* Duolingo, impossible to use without invoking that comparison). A cat is just... a cat — as legible to a Baby Boomer who's owned one as to a Gen Z user who grew up on cat content. That's the cross-generational bet this concept is making.
- Cats have a believable physical range for activity-mirroring: they can crouch, sprint, curl into a loaf, sit upright — the poses this feature needs (§2) are all things a cat's body plausibly does, so the illustration doesn't have to fight the animal's anatomy to sell each activity.
- Critically, a *resting* cat reads as content, not unwell. This matters structurally: Duolingo's owl reads as visibly "sick" when a streak lapses, which is the mechanism identified as the guilt-trip engine. A cat curled up and idle just looks like a cat being a cat. The species itself supports never having to draw a "punished" state.

**Visual style: two tiers, not one asset doing both jobs.** Design iteration on this (flat geometric mark → chibi cartoon → the current direction) surfaced a real constraint that doesn't go away no matter which style is chosen: the smallest render target for any pose is the Dynamic Island's minimal presentation, capped at roughly 45×36.67pt, with a documented failure mode where oversized or overdetailed assets can cause the Live Activity to fail to start outright. No single piece of art — however it's drawn — can be both a rich, realistic character *and* something that survives being shrunk to 45pt. So Momo is two coordinated assets, not one:

1. **Hero art — realistic/painted illustration.** The "real" Momo: used for the app icon, onboarding, marketing, the App Store listing, splash screens, and the full Lock Screen/expanded Dynamic Island presentation where there's room (up to 160pt height — plenty of room for real detail). This is the brief in §1a below.
2. **Functional glyph — a simplified mark derived *from* the hero art**, not drawn independently of it (so it still reads as the same character, just reduced). Used specifically for the Dynamic Island's compact and minimal states, where the 45×36.67pt cap makes fine detail physically impossible to render. This simplification pass happens after the hero art exists, the same way a detailed logo gets a "favicon" cut — not before.

The elder-care companion-robot research (Ferrarin et al. 2024, on the robotic seal Paro) found real infantilization concern — perceived as "child play," "demeaning for competent adults" — attached to *cutesy* anthropomorphic design aimed at older users (that research is about a therapeutic robot for dementia patients, a much more vulnerable population than a healthy fitness-app user, so treat it as suggestive, not conclusive). A more naturalistic, realistically-rendered character is arguably a better hedge against that specific risk than a cartoon was — worth keeping in mind as a point in favor of this direction, not just an aesthetic preference.

### 1a. Hero art brief

For an illustrator or an AI image tool (Midjourney, DALL·E, etc.) — no image-generation tool was available to produce this directly, so this is written to be handed off.

- **Species/coloring:** a ginger/orange tabby domestic short-hair — ties directly to Ritham's existing brand accent color (the warm amber/ember used throughout the app), with a cream-to-white belly, chest, and muzzle.
- **Build:** athletic, healthy, medium build — not plush/overweight, not skinny. Should read as "a cat that's actually active," reinforcing the activity-mirroring concept rather than undercutting it.
- **Expression:** calm, alert, warm — matches the "calm, present, quietly attentive" personality (§1). Not sleepy, not aggressive, not saccharine-cute.
- **Rendering style:** semi-realistic painted or 3D-rendered character illustration — think high-quality animated-film character art (Pixar/DreamWorks-adjacent) or a detailed digital painting, natural fur texture and soft lighting, rather than true photographic realism (which risks uncanny-valley for an app mascot) or flat vector. This is a deliberate default pick, not a directive — if true photographic realism is actually wanted, say so and the brief changes.
- **The whimsy/realism split:** rendering style (fur, lighting, proportions) can be fully realistic while the *situation* stays a little whimsical — a cat "wearing" a snugly-fitted helmet or "holding" a small dumbbell is an established illustration convention (real pet-product photography and animated mascots do this constantly) and doesn't fight the realistic-rendering goal.
- **Poses needed** — same seven activities as §2, described for an illustrator rather than as SVG coordinates:
  - *Idle:* sitting/loafed naturally, paws tucked, tail wrapped around, relaxed and alert.
  - *Walk:* standing, mid-step, relaxed natural gait.
  - *Run:* full stride, dynamic motion, ears back, focused.
  - *Cycle:* sitting upright, wearing a small properly-fitted bike helmet.
  - *Swim:* wearing snug, realistically-fitted swim goggles, mid-paddle or at a pool's edge.
  - *Strength:* standing/braced, paws on or holding a small dumbbell.
  - *Hike:* standing, wearing a small properly-fitted backpack.
- **Deliverable format:** each pose as its own image, consistent character design (same coat pattern, same proportions) across all seven, on a transparent or easily-removable background, high enough resolution to be resized down for both the hero placements and the glyph-simplification pass in §1b.

### 1b. Deriving the functional glyph from the hero art

Once hero art exists per pose, the compact/minimal Dynamic Island glyph is a *separate, simplified* asset traced or redrawn from it, not the same file scaled down (a scaled-down detailed painting turns to visual noise at 45pt, it doesn't just get smaller cleanly). Practically:
- Reduce each hero pose to its silhouette + the one or two accessory shapes that carry the activity read (helmet, goggles, dumbbell, backpack) — the same "accessory carries the differentiation" principle already used in the flat-icon exploration earlier in this process.
- Flatten to 2–3 colors, high contrast, no gradients or fine texture — gradients and soft edges are exactly what falls apart at minimal-presentation size.
- Test at both the 52.33×36.67pt compact cap and the ~45×36.67pt minimal cap on real devices before shipping, per the failure mode noted in §3.

**Personality: calm, present, quietly attentive — the explicit anti-Duo.** Duolingo's owl works *because* it's willing to be a menace and the brand owns that publicly (the sick app icon, the meme'd "stalker" persona, stunts that reportedly drove real engagement spikes). That's a legitimate, verified strategy — for Duolingo. It is flatly incompatible with Ritham's stated philosophy: non-punishing, no dark patterns, warm but not gimmicky. Momo cannot get sick, cannot die, cannot guilt-trip, cannot nag. What actually makes a mascot effective isn't the guilt mechanic itself — it's that the mascot's state is **mechanically tied to real user behavior** rather than being pure decoration (Duo's health icon, Pokémon GO's buddy candy, Walkr's fuel, Pokémon Sleep's Snorlax are all structurally the same idea). Ritham keeps that mechanical-tie lesson while rejecting the decay half of it:

- **Growth-only, monotonic states.** Any lasting visual change to Momo (a small worn-in accessory at a meaningful Momentum milestone, say) only ever accumulates. Nothing reverses, degrades, or looks worse because of a gap. This is consistent with Momentum's existing framing and is the direct alternative to a "sick"/"starving" state.
- **The actual mechanical tie is the live session mirror, not a decay meter.** Momo wearing goggles *because you're swimming right now*, in real time, during the session — that live correspondence between mascot and behavior is itself the mechanism that matters. It needs no punishment attached to be legible or feel connected to what you're actually doing.

**On cross-generational appeal — stated honestly as a hypothesis, not a proven claim.** No direct study of consumer-app-mascot perception across age groups exists; the adjacent evidence (elder-care robotic companions) is suggestive but describes a higher-stakes context than a healthy adult opening a fitness app. So the honest position is: this concept is a design hypothesis with three concrete hedges built in — (1) a deliberately non-childish, iconographic visual style; (2) a species with minimal generational coding; (3) full opt-out via one ordinary setting rather than a segmented "fun mode" (see §4/§5) — and a handful of interviews with older users of Duolingo or Finch should happen before heavy art investment, not be assumed away.

**On retention — explicitly not the pitch.** Duolingo frames its mascot as core growth strategy. Peloton and Strava sustain strong engagement with **zero mascot**, via human instructors and social/competitive mechanics instead — real counter-evidence that a mascot is necessary for retention. Momo's value proposition should be scoped as *brand warmth plus a glanceable, at-a-glance indicator of what kind of session is running* — not as an engagement lever, and Ritham shouldn't set internal success metrics that assume it moves retention numbers.

---

## 2. Pose set per activity

| Activity Type | Pose/Equipment | Notes |
|---|---|---|
| **Run** | Mid-stride, one paw forward and one back, ears back, slight forward lean; no gear | Posture alone carries the read — fastest/most dynamic gait of the set, distinguishes from Walk purely through stride width and lean angle since no accessory is added |
| **Walk** | Upright, relaxed four-point or two-point stance, tail swaying, ears neutral; no gear | Deliberately the *plainest* pose — slower, looser posture than Run, no equipment at all, reinforcing that Walk is the lowest-friction, always-available activity |
| **Cycle** | Seated on a small bike silhouette, paws on handlebars, small rounded helmet | Helmet is the single clearest differentiator at tiny render sizes — reads as a distinct colored shape on the head silhouette even when the bike itself is too small to resolve |
| **Swim** | Paddling-paws pose (limbs extended, low profile), goggles, small ripple/wave motif beneath | Goggles chosen specifically because they're a simple, high-contrast shape that survives down to the ~36pt minimal-presentation cap; a swim cap was considered but overlaps the head silhouette too closely with the base cat shape to read distinctly |
| **Hike** | Sturdy wide stance, small backpack, walking stick held diagonally | Backpack is the strongest silhouette add here — bulks out the back profile, immediately distinct from Walk's plain silhouette even in a single-color glyph |
| **Strength / Lift** | Grounded, wide/crouched stance, holding a small dumbbell shape in front | Widest, lowest stance of the set (contrast with Run/Walk's upright postures); paired with a live rest-timer rather than a cadence of pose swaps — see §3 |
| **Idle / default** | Seated "cat loaf" — paws tucked, tail curled around, eyes relaxed | Used before a session starts and after one ends; deliberately the calmest, most neutral pose in the set — never a "waiting anxiously" read, just at rest |

---

## 3. Live Activity technical design

### Lock Screen layout
- **Leading region:** the current activity's pose art, sized to fit within the documented 160pt max height and the standard 14pt content margin.
- **Elapsed time:** `Text(date, style: .timer)` — renders continuously, ticking with zero app involvement and zero update budget cost. This is the one genuinely "free" source of liveliness in the whole feature and should carry most of the "this is happening right now" feeling, rather than the mascot art trying to.
- **Distance / pace (cardio):** plain text, refreshed via periodic `ActivityContent` updates from the app's own tracking loop.
- **Rest timer (Strength):** `ProgressView(timerInterval:)` — also system-rendered and free; the correct load-bearing "live" element for a modality with no distance data.
- **Momentum streak status:** a short static line (e.g. "12-week streak · Day 3 today"), set once at session start. It does not need to live-update mid-session, so it costs nothing beyond the initial write.
- **Background:** `.activityBackgroundTint(_:)` set to a Ritham brand color, respecting the documented light/dark default otherwise, with `.activitySystemActionForegroundColor(_:)` used to keep the system dismiss control legible against it.

### Dynamic Island
- **Compact:** leading slot = simplified single-color mascot glyph; trailing slot = live elapsed timer. Design target: the **52.33×36.67pt standard-class cap**, not the larger 62.33pt Pro Max figure — designing to the smaller shared cap keeps one asset safe across the device fleet rather than requiring per-class variants.
- **Minimal** (shown when 2+ Live Activities compete for the Island): a single glyph within the documented ~45×36.67pt hard cap. At this size the art is not activity-specific pose detail — it's the simplified Momo mark, since exceeding this size can cause the Live Activity to fail to start outright, not just clip.
- **Expanded** (long-press): full pose art in the `.leading`/`.center` region; elapsed time, distance/pace, or rest timer in `.trailing`; Momentum streak line across `.bottom`.
- **Lock Screen / no-Island devices:** the same view code path renders as a banner overlay on alert-configured updates.

### Update cadence for pose-swapping — the honest constraint
Two things shape everything here: there is **no `TimelineProvider`-style scheduling primitive** for Live Activities, so nothing resembling "swap pose B at T+10min" can be pre-computed; and Apple's own guidance says to update **only when real content changes**, not on a decorative schedule. So a continuously-cycling or idle-looping mascot animation is not a supported pattern — full stop. What *is* feasible:

- **A small number of discrete, state-triggered poses per activity** — for v1, exactly two: a start/idle pose and an in-motion/active pose, swapped when the app's own tracking logic detects a real session-state change (session started, session ended). Each swap gets the system's automatic cross-fade (capped at 2 seconds, and suppressed entirely on Always-On Display, where the swap becomes an instant cut — poses should be designed to look acceptable as a hard cut, not just a fade).
- **Cardio (Run/Walk/Cycle/Swim/Hike):** these activities already require continuous GPS/location tracking, which is a documented reason iOS keeps the tracking process alive in the background. It is a **reasonable but unverified inference** that this same running process can call local `Activity.update()` (which carries no documented rate limit) to refresh distance/pace and trigger pose swaps without touching the push-notification budget at all. This should be validated empirically during implementation, not assumed; if the process is ever suspended unexpectedly, the correct fallback is to freeze on the last known pose plus the still-live timer, never an error state.
- **Strength/Lift is structurally different and must not be designed as a scaled-down version of the cardio cadence.** There's no GPS, so there's no standing justification that the app process stays alive in the background between sets. Its Live Activity should not assume it can push updates on a timer while the phone is locked. Instead: the primary "live" element is the rest-timer `ProgressView(timerInterval:)`, which is genuinely free and needs no app wake at all; pose and set-count changes happen **only when the user actively interacts with the app** (logging a completed set), i.e. event-driven, not scheduled. Between sets, the display is simply a static resting pose plus the live-ticking rest timer.
- Milestone-triggered micro-variants (halfway point, pace PR, cooldown) are a legitimate extension of this same state-driven model, but are scoped as post-MVP (§4) to keep the v1 state machine — and asset count — small and shippable.

### The 8-hour ceiling
Verified hard OS limit: a Live Activity runs for at most 8 hours before the system force-ends it, after which it can remain visible on the Lock Screen for up to 4 more hours (12 hours total, non-configurable — there is no duration parameter or entitlement to extend it). Run, Walk, Cycle, Swim, and Strength sessions are essentially never going to hit this in practice, so it's a non-issue for v1's activity set. **Hike is the one activity that can plausibly exceed it**, which is exactly why Hike is scoped as post-MVP (§4) rather than shipped alongside this ceiling unhandled. The eventual design: as a session approaches the ceiling (e.g. ~7h45m), end the current Activity and start a fresh one, carrying cumulative elapsed time forward as a value in the new Activity's initial content state (since the OS's own per-activity clock resets to zero for the new instance). This is a **teardown-and-recreate, not a cross-fade** — there is no supported animated transition across that boundary, the old Live Activity disappears and a new one appears. Whether that produces a visible flicker or gap in the Dynamic Island is not documented anywhere and should be treated as an open, untested UX risk to verify on real devices before Hike ships. The restart itself needs two paths implemented, since a phone deep into a multi-hour hike is plausibly locked or pocketed: the app restarting it directly if it's still running in the background (plausible, given Hike's own GPS background tracking), with a **push-to-start** fallback from a server tracking elapsed session time for the case where the app has been fully suspended.

### Android — honest scope note, not a spec
ActivityKit and Live Activities are iOS-only. Ritham's roadmap already commits to iOS-native for v1, so no Android equivalent ships alongside this feature, and this section is a forward-looking direction, not a design. Structurally, the nearest Android analog is an **ongoing foreground-service notification**, a meaningfully more constrained surface — a single notification layout (collapsed/expanded via standard notification styles) rather than ActivityKit's Lock-Screen-plus-Dynamic-Island split, with far less freedom for custom layout. Android has been moving toward a "Live Updates"-style notification concept for similar ongoing-status use cases in recent OS versions, but its current name, OS version gate, and capabilities are unverified here — this research was scoped entirely to iOS. When Android is actually on the roadmap, this needs its own research and design pass; the realistic starting assumption is a much simpler concept (static icon plus text status) rather than a ported version of the pose-swapping system described above.

---

## 4. MVP scope vs. later expansion

### Ships in v1
- **Activity types:** Run, Walk, Cycle, Strength — the four already-spec'd types — plus the shared Idle/default state. Swim, Hike, and Elliptical are explicitly deferred (see below); they're "extensible others" in Ritham's own spec, not yet fully built out, and Hike specifically needs the 8-hour-chaining work (§3) done first regardless.
- **Poses per activity:** exactly two — an idle/start pose and an active/in-motion pose — swapped only on real session-start/session-end transitions the app already tracks. No milestone micro-variants in v1; keeping the state machine to a single transition per activity keeps both the art budget and the update-mechanism risk small for a first ship.
- **Concrete asset count:** 4 activity types × 2 poses × 3 size tiers (full Lock Screen/expanded art, compact-slot glyph, minimal-slot glyph) = 24, plus the shared idle/default pose across the same 3 tiers = 3, for **≈27 total art assets** — achievable in a single illustration pass.
- **Toggle:** one ordinary setting ("Show Momo on Lock Screen" or similar), on by default, instantly reversible, living in Settings alongside other notification/display preferences — not a separate "fun mode" or anything that reads as age- or persona-segmented.
- **Momentum streak line:** static text, set once at session start.

### Stretch / later
- **Additional activity types:** Swim, Hike, Elliptical, and any further activity types Ritham adds — each is additive illustration work against the same system, not a new mechanism.
- **Milestone micro-pose variants within a session** (halfway point, pace PR, approaching a goal) — richer state machine, strictly growth/celebration-only, never a negative or "behind" visual.
- **Seasonal accessory variants** (e.g. a scarf in colder months) — cosmetic only, must never gate core functionality or read as a monetization nudge.
- **Achievement-tied accessories at Momentum milestones** (e.g. a small worn accessory at a 12-week mark) — purely additive and celebratory, never removed for a lapse, and dismissible/hideable like the rest of the feature.
- **Apple Watch Smart Stack** and **CarPlay** minimal treatments (CarPlay disables interactive elements, and Momo has none anyway, so this is low-risk, low-priority polish).
- **iOS 27 landscape Dynamic Island** adaptation via `isDynamicIslandLimitedInWidth`, once that ships out of beta.
- **Long-hike 8-hour chaining** (local restart plus push-to-start fallback) — build immediately before Hike itself ships, not before, since it has no purpose until then.
- **Android ongoing-status equivalent** — its own research and design pass, out of scope until Android is actually on the roadmap.

---

## 5. What NOT to do

Grounded directly in the mascot-precedent research and Ritham's non-punishing, no-dark-patterns brand:

1. **No decay, sickness, or guilt states tied to a broken streak.** This is the single most direct anti-pattern — Duolingo's app icon visibly "sick" during streak jeopardy is exactly the mechanic Ritham's brand forbids. Momo does not get sick, does not die, does not look sad because of a gap.
2. **No mascot-initiated nagging notifications** ("Momo misses you!") separate from the Live Activity itself. Update only when there's real new content — Duolingo's guilt-trip notification escalation is documented precedent for exactly this kind of backlash.
3. **No forced or hidden-cost opt-out.** The mascot must be a single, ordinary, instantly-reversible toggle — never framed as losing a reward for turning it off, never buried three menus deep.
4. **No burning update budget (or app energy) on cosmetic idle-animation loops.** There's no supported looping-animation primitive for Live Activities in the first place, and Apple's guidance is to update only on real state change — so this isn't just wasteful, it's against the documented pattern entirely.
5. **No competitive or comparative mascot behavior** ("your friend's Momo is ahead"). Keep it individual and personal, consistent with the non-punishing philosophy and with staying out of leaderboard-shaming territory.
6. **No mascot "death" or shock stunts**, however well they worked for Duolingo. Tonally wrong for a trust-and-warmth brand meant to span every generation, and especially wrong layered onto fitness, where people already carry complicated feelings about missed sessions.
7. **No oversized or over-detailed assets.** There's a real, hard failure mode — an image exceeding the minimal presentation's ~45×36.67pt cap can cause the Live Activity to fail to start, not just render poorly. Every pose must be tested at every size tier on real devices before shipping.
8. **No letting mascot art crowd the data.** The Lock Screen's primary job is glanceable session data — elapsed time, distance, pace, rest timer. Momo is secondary in the visual hierarchy and must never cover or shrink the numbers people actually opened the Lock Screen to check.
9. **No age-segmented "fun mode."** One universal, ordinary setting for everyone — consistent with Ritham's progressive-disclosure-not-separate-modes principle, and the direct answer to the (unverified but plausible) infantilization concern research surfaces for older users: let anyone opt out without it reading as a special accommodation.
10. **No treating the mascot as a proven retention lever internally.** Don't set engagement KPIs assuming Momo moves them — Peloton and Strava's verified success with zero mascot is direct evidence a mascot isn't necessary for retention, and overclaiming internally risks pressure to reintroduce exactly the guilt/urgency mechanics this document argues against.
