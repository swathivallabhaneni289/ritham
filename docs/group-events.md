# Group Goal-Events — Design Document

Ritham's existing social surfaces (household accounts, the Momentum streak) are built on one non-negotiable rule: social features are opt-in, never default-public, and never comparative — "fixed cheers, no ranking, no visible pace/weight comparison." This document extends that same rule to a new surface: friends, groups, a shared goal-event (e.g. a group 5K walk, a swim, a hike), photo+location logging, a shared feed, and a digital finisher certificate.

Two failure modes from the research shape every decision below:

1. **Comparison stress.** Strava's group challenges still surface a "Top Contributors" leaderboard underneath the collective goal; Peloton's per-class leaderboard drew documented demotivation and distrust — and that backlash was specifically among people who already follow each other, not strangers, which is the reason "friends-only" doesn't neutralize this risk on its own. Ritham's resolution, after weighing this tradeoff explicitly: **a user can optionally attach their own completion time when they log a completion — off by default, their choice each time, never required and never inferred.** If shown, it's never ranked, sorted, or scored against anyone else's — no leaderboard, no "1st," no fastest-to-slowest ordering. Someone who takes their own time to finish, or who's simply not comfortable sharing a number that day, posts exactly the same "completed" card as anyone else. See §2.
2. **Location/photo exposure.** The 2018 Strava heatmap incident happened because default-on, opt-out sharing of precise activity data was aggregated and published — and the same failure mode (individual home addresses, security-detail movements, patrol timing) kept recurring through 2025 even after Strava added manual exclusion and geofenced "Map Visibility." The lesson isn't "add an opt-out," it's "don't default to precision, and don't retain what you don't need." See §3.

---

## 1. Friends & Groups

### Adding a friend

Friending is **mutual and request-based**, not a one-directional follow: both people must accept before any connection exists. There is no public profile search and no "find friends" contact-scan that runs without explicit, per-side opt-in — this is the direct lesson from Peloton's May 2024 incident, where full legal names and searchable profiles became visible by default (opt-out, not opt-in), catching users off guard about years of activity suddenly tied to a discoverable identity. Ritham never puts a user in a searchable-by-strangers state; there is no state a user can be in without having explicitly said yes twice (their own opt-in to be findable via contacts, *and* the specific request from the other person).

Three ways to connect, all closed-loop:
- **Contact matching**, off by default per side — a user opts in to "let contacts who also opted in find me," and a match surfaces only when both sides have opted in.
- **Invite link or QR code**, generated per-invite, **expiring after a set window or first use**. A permanent, forwardable invite link is public discoverability wearing a different hat — exactly the surface Strava had to redesign invites around after retiring email invites in favor of mutual-follow gating. Ritham avoids the problem at the source: links die.
- **In-person / direct share** (text, AirDrop-style) — no in-app directory involved at all.

### Forming a group

Groups are small, closed, and invite-only, sent only to people already on the user's friend list — there is no "public group anyone can join" tier at all, unlike Strava Clubs, which explicitly support that mode. A group has no visibility rung beyond its own members: it does not appear in any search, is not listed on any profile, and generates no public/aggregate signal (see §3's heatmap discussion — the same "don't create an aggregate surface" logic applies to group discoverability, not just location).

**Membership mechanics, deliberately un-Strava:**
- Any member can **leave at any time**, no transfer-of-ownership gate. Strava requires a Club owner to hand off ownership before leaving — real friction that Ritham doesn't need, because groups aren't administered entities with public standing to protect.
- If the person who created the group (the *organizer* — a convenience role, not a title with public weight) leaves, **the group simply continues**. No auto-promotion drama, no "ownership vacuum" state: any remaining member can create the next goal-event. There is nothing to transfer because there is nothing public attached to the role.
- Removing a member is available to any member, or restricted to the organizer, per group preference — but there is no admin approval queue, no join-request inbox, because nobody outside the already-mutual friend graph can ever request to join.
- Group size stays intentionally small (the product default should bias toward "the people doing this 5K together," not toward scaling into a club). Smaller closed groups also reduce the aggregate-exposure surface described in §3.

### Composing with Ritham's existing visibility spectrum

Ritham doesn't need a new naming scheme here — it needs one more rung on the ladder that already governs household accounts and Momentum: **Only Me → Household → *this specific group***. That's the ceiling. There is no "Friends of friends" rung and no "Public/Everyone" rung anywhere in this feature — not for a friend's profile, not for a group, not for a completion post, not for a certificate. Anything a user shares beyond the group boundary is a deliberate, individual **export** (§5), never a setting that widens who can passively see the group's activity.

---

## 2. Goal-Events

### What a Goal-Event is

A Goal-Event is a **shared, non-timed commitment**, not a race and not a challenge in Strava's competitive sense. The organizer sets:
- **Activity type** (walk, run, swim, hike, ride, etc.)
- **A target** — distance or duration (e.g. "5K," "45 minutes"), optional
- **A target date or window** (a single day, or an open window like "this weekend")

That's it. The target lives on the **event** — the group isn't racing toward a shared number, everyone is individually completing the same agreed activity. **When a person logs their completion, adding their own time is entirely their choice — off by default, asked (not assumed) at the moment of logging, and skippable with zero friction.** Distance, pace, and route stay in the user's personal, private log unless they separately choose to add them too. A completion card reads either *"completed the Saturday 5K Walk"* or, only if that person opted in that time, *"completed the Saturday 5K Walk — 32:14"* — both are complete, normal, unremarkable cards; neither reads as withholding something. Time, when present, is a fact about that one person's own completion, not a ranking input: the feed order stays chronological-by-post (below), and the certificate stays unranked (§5), regardless of who did or didn't include a number.

### Joining

Invited friends/group members RSVP individually ("I'm in"). RSVP is visible pre-event as a headcount of interest ("6 friends are in for the Saturday hike") — this is a low-stakes, pre-commitment signal, not a completion tracker, and it lives on a separate screen from the post-event completion feed (see below — this separation is deliberate, not incidental).

### Logging completion — explicitly not a race

Each person logs **their own completion, on their own time**, even for a single-day event. There's no synchronized start, no clock. Logging is binary: **done**. A user may optionally record their own distance/duration/route for their **personal, private log** (visible only to them, same private tier as any other personal activity) — that data never travels to the group feed, the certificate, or any export, by construction, not by a filter someone could get wrong.

**Where Ritham draws the line, compared to the research:** Strava's group challenges show a "Top Contributors" leaderboard beneath the collective total; Racery's Uniteam mode pools effort into one shared team avatar but still exposes contribution level to teammates; Apple Fitness scores a percentage-of-personal-ring, which is individualized but still a score with a winner; Peloton's per-class leaderboard sorts everyone by output, live. Ritham lets a user optionally attach their own time to their own card (per the tradeoff above), but takes every *ranking* mechanism off the table entirely — no pooled total, no contribution ranking, no leaderboard sort, no score, no winner, and no comparison of who did or didn't include a number. A time, when present, is information about one person's own effort, shared at their own discretion — never a contest input.

**No "first to complete."** Completions render in the feed **in the order they were posted**, never sorted fastest-to-slowest — a normal chronological social feed, not a leaderboard with a race clock. This is safe specifically *because* there's no synchronized starting gun: early-vs-late in the feed only means "who logged their completion sooner," not "who was faster," since everyone started on their own schedule. The card itself never carries an ordinal position, medal, or "1st" marker, and the feed is never re-sortable by time — showing a time is not the same product decision as building a way to rank people by it, and Ritham only makes the first one.

**Non-completion is a non-event.** This is the gap none of the researched platforms had to solve (none of them show a closed, named friend group's roster against completions the way this feature could). The rule: the completion feed shows **positive completions only** — there is no greyed-out avatar, no "hasn't finished yet" state, no red X, no countdown-pressure banner, and critically, **no denominator paired with the completion view**. RSVP count ("6 are in") lives on the pre-event screen; the completion feed after the event never re-displays that number next to a completion count, so the app itself never juxtaposes "went in" against "came out" in one glance. When the target date/window passes, the event **closes silently**: no expiry notice, no nudge to people who didn't log, no "missed it" surface anywhere. Completions already logged simply stand, permanently, in the group's history.

### Actual copy

Principles are easy to get right; empty and partial states are where they're tested. Literal strings:

| Moment | Copy |
|---|---|
| Creating the event | "Start a Group Goal" *(never "Challenge")* |
| Event description, shown to invitees | "Everyone does this together, on their own time. There's no clock and no ranking — log it whenever it works for you." |
| RSVP confirmation | "You're in for the Saturday 5K Walk." |
| Pre-event progress (RSVP screen only) | "6 friends are in." |
| Completion confirmation (to the user) | "You did it! 🎉 Logged for the Saturday 5K Walk." followed by an optional, unchecked-by-default prompt: "Want to add your time? Totally up to you." with a skip that's exactly as prominent as the add-time action. |
| Group feed card (time not added) | "Priya completed the Saturday 5K Walk." |
| Group feed card (time added, by choice) | "Priya completed the Saturday 5K Walk — 32:14." *(never a distance, pace, or rank — and never styled differently from the no-time version beyond the number itself)* |
| Group feed reaction | Fixed cheers — the same non-comparative reaction set already used elsewhere in Ritham; no kudos counts, no "most-cheered" surface. |
| Event closing (silent — no copy shown to non-completers) | *(nothing — the event simply stops appearing as upcoming)* |
| Group history, after the window closes | "Completed by:" followed by the celebration cards — no count, no fraction. The cards *are* the summary; a number alongside them would let anyone who also saw the RSVP screen back into who's missing. |

---

## 3. Photo + Location Logging, With Privacy Built In

**Headline commitment: Ritham will never build a cross-user aggregate location visualization — no heatmap, no "most active area," no feature that plots activity data across users onto a map, ever.** This is the direct, structural response to the 2018 Strava incident: the exposure wasn't caused by one bad toggle, it was caused by a *feature* — an aggregate view built from many users' location data — sitting on top of defaults that were opt-out. Aggregation is the part that turns individually-reasonable sharing into a strategic-intelligence artifact; Ritham removes that feature category entirely rather than trying to secure it.

### The upload flow

1. User attaches a photo to a completion log.
2. **EXIF GPS (and all EXIF metadata) is stripped server-side, unconditionally, before the image is ever written to any group-visible or exportable storage.** This happens regardless of what the client claims to have already stripped — a different client, a replayed request, or a future API path could otherwise bypass client-only stripping, which is exactly the gap that makes "the app is supposed to strip it" an unsafe design on its own.
3. The original file, metadata intact, is retained *only* in the user's own private library (their personal device/backup), never in the copy served to the group or to any export.
4. Location sharing is a **separate, explicit opt-in from photo sharing** — attaching a photo never implies attaching a place. A user who shares the photo but leaves location off gets a completion card with no place information at all.

### Precise GPS: don't capture it, don't just withhold it

The stronger design isn't "capture precise coordinates and hide them behind a setting" — it's **don't store precise coordinates for a completion log in the first place**, unless the user separately opts into a personal route view (their own private map, same tier as a personal photo library). That data, if it exists at all, never reaches the group feed, the certificate, any aggregate, or any export — there's no shared code path that could leak it because it was never written to shared storage to begin with. This matters because the 2018→2025 pattern (military bases, then home addresses, then presidential security details, then submarine patrol timing) wasn't one incident — it was the same underlying data being surfaced through a *new* feature each time. The fix that actually holds up over years is minimizing what's retained, not adding more toggles to a growing pile of stored precision.

### Location display default: named place, never a pin

If a user opts in to sharing location, the default is a **reverse-geocoded, coarse named place** — "Griffith Park," "near Austin, TX" — never coordinates, never a pin on a map, never an address. Two things from the research shape this specifically:

- **Fixed-radius geofencing is defeatable by correlation.** Strava's own Map Visibility documentation acknowledges that clipping the same fixed radius around a point across multiple activities lets an observer converge on the center anyway — the boundary becomes the secret. Ritham avoids this by never exposing a radius or boundary at all: a named-place bucket (park, neighborhood, city) has no geometric edge to triangulate against.
- **Derived precision is still precision.** Tinder's 2016 vulnerability let attackers reconstruct exact coordinates from something that looked safe on its face — a displayed "distance away" figure. The lesson generalizes: don't expose *any* number (distance, radius, "how close") that a determined viewer could triangulate from. Ritham's named-place display has no numeric handle to pull on.

### Privacy Zone — a standing default, not a per-post decision

A user can set one or more sensitive locations (home, in-laws' house, workplace) once, in settings. **Any activity or photo whose location falls inside that zone is automatically generalized or fully suppressed across every shared surface — feed, certificate, export — without requiring the user to remember to toggle anything that day.** This is deliberately more conservative than what Strava shipped after 2018: Strava's exclusion mechanism was (and by its own current documentation, remains) opt-out and manually applied per user, and the recurring exposures through 2025 are the evidence that "opt-out, if you know to use it" doesn't hold up for people who don't think of themselves as a sensitive case until it's too late. Ritham's default location granularity (coarse named place, for everyone, always) is the baseline protection; the Privacy Zone is a second, reinforcing layer for places a user specifically never wants surfaced at all, even at named-place resolution.

### What Ritham should never do

- Never show a precise GPS pin or coordinates by default, anywhere shared — feed, certificate, or export.
- Never auto-tag or auto-embed the exact address or coordinates a photo was taken at.
- Never build a cross-user aggregate map, heatmap, or "popular locations" feature of any kind.
- Never bundle location sharing into photo sharing as one opt-in — they are always two separate switches.
- Never rely on client-side EXIF stripping as the only safeguard.
- Never expose a derived numeric value (radius, "distance from X," clip boundary) that could be triangulated into a precise point.
- Never let an event's *coordination* location (the exact trailhead address the organizer shared with the group to plan the meetup) leak into anything the group later shares outside itself (see §5) — coordination detail and shareable/export detail are different data with different audiences.

---

## 4. The Shared Portal/Feed

**Visibility: the group, and only the group — by default and permanently.** Not public, not discoverable, not indexed, not reachable by a generic shareable link. There is no tier above "this group" for this surface (see §1's ladder). Leaving or being removed from the group removes that person's access to the feed going forward — but their past completion cards (photo, caption, named place) remain visible to the group they were posted to, the same way they'd remain in any shared chat history after someone leaves. A user who leaves can also choose to remove their own past posts as part of that action; the app should offer this explicitly at the leave step rather than leaving it as an unstated default either way.

**What it shows, per completion:**
- Name and avatar of the person who completed it
- The Goal-Event name and activity type
- Completion date
- Optional photo (EXIF-stripped, per §3)
- Optional generalized location (named place, per §3 — never a pin)
- Optional short personal caption
- Fixed cheers from other group members — the same non-comparative reaction Ritham already uses elsewhere, not a kudos count that could itself become a leaderboard

**What it never shows:** pace, time, distance-based rank, "first to complete," a denominator paired against completions (per §2's non-completion rule), or anyone's precise location. The feed is ordered chronologically by when a completion was posted — a normal social-feed convention, safe here specifically because there's no synchronized start to make "earlier" mean "faster" (§2).

The group's own goal-event history — past events, and who completed each — lives in this same closed space, functioning as the group's shared archive rather than any individual's public trophy wall.

---

## 5. Digital Participation Certificate

### What's on it

- Ritham branding/logo
- The Goal-Event name and activity type
- The participant's own name
- Completion date
- **Their own completion time — only if they chose to add it when logging** (same opt-in as the group feed card, §2; off by default, never assumed, and the certificate is equally complete and normal-looking either way)

**Explicitly not on it, ever, regardless of the time opt-in:** pace, distance-as-measured, place/rank within the group, exact GPS coordinates or address, and — critically for the export case below — anyone else's name, photo, participation status, or time, and no "X of Y completed" figure. A user's choice to show their own time never implies anything about how their time compares to a friend's, because no friend's time is ever shown alongside it.

### Generation

The certificate auto-generates per person, the moment they log completion — a template merge (Ritham brand frame + event name + participant name + date), the same mechanic RunSignup and dedicated badge vendors (Virtualbadge.io, IssueBadge) use natively for finisher certificates and digital bibs. Default template is a **branded graphic/badge design**, not the user's own photo — this is a deliberate default, not just an aesthetic choice (see export, below).

### Sending to the group

The certificate posts to the group feed alongside (or as) the completion card — visible only within the group, same tier as everything else in §4. No separate send step is required; completing the event *is* what generates and shares it.

### External sharing — designed so it can't leak the group

Exporting outside Ritham (e.g., to a phone's camera roll or directly to another app) produces an image containing **only the exporting user's own data**: their name, the event name, the completion date, and Ritham branding — plus a generalized location only if that user specifically opted into showing it on their own export. It never contains:

- A member count, roster, or "X of Y" figure — group *composition* is exactly the kind of information a solo export shouldn't carry.
- The group's name, if that name is person-identifying (e.g., a group literally named after its members).
- Any other member's name, photo, or completion status.

Two leak paths worth naming explicitly, both closed by design rather than by asking users to be careful:

- **The badge-first default template solves the "whose photo is this" problem structurally** — because the default export is a graphic, not a photo, there's no image containing other people to accidentally include. A user who wants *their own* event photo on their export can use it — but if a group photo has other members visibly in it, external export of that image is only enabled once every visible person has separately granted "okay to share this outside Ritham" for that specific photo, or the user crops/selects a solo shot instead. Group presence in a shared feed and group presence in something posted to the public internet are different consent decisions, and the second one is never assumed from the first.
- **The event name is free text and can itself be a location or identity disclosure** (a title like "Sunrise loop from Rachel's place" defeats every location control in §3 just by being typed into a name field). This needs a check at *both* moments, because the two people who can act on it aren't the same person: at creation, a brief nudge to the organizer ("this name will be visible if anyone exports a certificate — avoid addresses or specific places") catches it at the source. But the person exporting is usually someone else entirely, who didn't write the name and may not notice its sensitivity — so the export flow also shows a "this is what will be shared outside Ritham" preview with an **editable display-name field**, letting the exporting user rename their own certificate copy (e.g., "Sunrise loop from Rachel's place" → "Sunday morning walk") without needing the organizer's involvement or altering the name anyone else in the group sees.

The exported certificate also goes through the same EXIF-stripping guarantee as any other shared image (§3) — nothing about the export path is exempt from the ingest-time rules.

### Personal archive

Past certificates accumulate in the user's own private record (visible to them, and at most their household, per the existing spectrum) — a personal keepsake trail, not a public trophy case ranked or ordered against anyone else's.
