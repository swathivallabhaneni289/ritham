# Ritham "Dietary Pattern" Preference — Design Addendum

Addendum to [`docs/health-screening.md`](./health-screening.md) §1 (Intake Question Flow) and §3 (Nutrition Adjustment Rule Table). Nothing in those two sections' existing logic changes. This document defines one new, purely preference-based tag that layers on top of them.

> **Design constraint governing every section below:** Dietary Pattern is a food preference, not a health condition. It is captured, stored, and read completely separately from the condition checklist (§1.3) and the Clearance Gate columns in both rule tables (§2, §3). It has no severity follow-ups, no gate value of its own, and no entry anywhere in the Red-Flag Escalation Logic (§5). Everywhere below, it only ever changes *which specific foods* populate a food slot that the existing Nutrition Adjustment Rule Table (§3) has already decided, independently, to show.

A note on sourcing discipline, consistent with the parent document: every nutrient/food claim below is tied to a source from the nutrition research done for this addendum (NIH ODS, Harvard Nutrition Source, Mayo Clinic, ADA, NHLBI). Where that research flagged something as not-found or unofficial — ADA not publishing explicit protein-substitution line items for the Plate Method, NHLBI's DASH page having no official vegetarian/vegan version — this document says so explicitly rather than presenting Ritham's own constructed swap as if it were a published guideline. Anywhere this document builds a swap that isn't itself published anywhere (most of Section 3's table), it's marked **Ritham's construction, grounded in [sources]**, not a claim that ADA or NHLBI publishes a vegan plate method.

---

## 1. The Intake Question

### Where it's asked

Directly after **Q0** (age) in **§1.1 "About You"** — the same section, not the condition checklist. §1.1 already exists in the parent flow specifically to hold personal-profile facts that shape suggestions but aren't a medical screen. Dietary Pattern is added to that same section as **Q0b**, asked to every user, unconditionally, before the Gate section (§1.2) and well before the Condition Checklist (§1.3).

It is never rendered as a checkbox inside §1.3's condition list, never triggers a severity follow-up the way a checked condition box does (§1.4), and is not touched by the "None of the above clears any other selections" behavior that governs §1.3 — the two questions are visually and structurally distinct so a user, and an engineer reading the code later, can't mistake one for the other.

### Question text and options

**Q0b. Which of these best describes how you eat?**

- `No restriction — I eat everything`
- `Vegetarian (no meat, poultry, or fish — dairy and eggs are fine)`
- `Vegan (no meat, poultry, fish, dairy, eggs, or other animal products)`

*(Single-select. Stored as `dietary_pattern: none | vegetarian | vegan`. No numeric entry, no follow-up questions, no expiry/re-screen logic — editable anytime in Settings, same as any other preference field.)*

### Framing copy shown above the question

> We ask this so the food examples and protein ideas Ritham shows you actually match how you eat — it's a food preference, not a health question, and it never changes any of the condition-based guidance you saw above.

---

## 2. Explicit Non-Gating Rule

**Rule, stated plainly for engineers implementing this:**

> `dietary_pattern` never changes a Clearance Gate value, never triggers `required-blocking`, and never blocks, unlocks, or softens a condition-specific suggestion. It has no row of its own in either Adjustment Rule Table and no entry in the Red-Flag Escalation Logic (§5). Its *only* effect is substituting which specific foods/protein sources populate a slot inside whatever guidance the Condition Tag(s) have already permitted — nothing more. If the applicable Condition Tag's gate is `required-blocking`, `dietary_pattern` has nothing to act on: there is no personalized suggestion left for it to flavor.

Concretely: the Nutrition Adjustment Rule Table (§3) resolves a gate value from Condition Tags alone, exactly as it does today. Only *after* that gate is resolved — and only if it resolved to `none` or `recommended` — does a second, independent lookup key off `dietary_pattern` decide which example foods render inside that already-permitted content. `dietary_pattern` is never part of the gate-resolution step itself, and no `required-blocking` message anywhere in §3 gets a vegan- or vegetarian-flavored variant, because a `required-blocking` gate has no personalized content for a food swap to attach to in the first place.

### Worked example: Vegan + Kidney Disease / Dialysis

A user with both `Kidney Disease / Dialysis` (Condition Tag) and `vegan` (Dietary Pattern) gets:

- **Clearance Gate:** `required-blocking` — unchanged, identical to a non-vegan user with the same condition tag.
- **Guidance shown:** none. Per the existing §3 row, this is "zero personalized guidance of any kind, including general framework content" — no plate method, no protein list, no swap table, vegan or otherwise.
- **What's shown instead:** the exact §4.6 required-blocking message, unedited — *"We're holding off on personalized suggestions here... we'd like you to check with a doctor, registered dietitian, or other qualified professional first."*
- **What Dietary Pattern is allowed to do:** at most, silently carry `vegan` as context for the eventual referral conversation — the same low-stakes way KR-2 today lets the referral message "acknowledge an existing plan instead of sounding generic" — never to generate its own vegan-flavored kidney-diet content.

This example is also the clearest reason the non-gating rule matters beyond tidiness. Renal nutrition needs (protein, potassium, phosphorus, fluid) move in different directions depending on CKD stage and dialysis status, per the existing kidney-disease row's own reasoning. *(Flagging as inference, not sourced in the underlying research: several of the swap table's own vegan staples in Section 3 — legumes, nuts, tofu — are, as a matter of general nutrition knowledge, often higher in potassium and phosphorus than the animal proteins they'd be replacing.)* If that inference holds, it's a good illustration of why this isn't just a formality: an engineer who let `dietary_pattern` reach into a `required-blocking` row and auto-generate "vegan-friendly kidney food ideas" wouldn't just be breaking a design rule — they could be recreating, inside Ritham, the exact undifferentiated plant-protein swap that the underlying condition rule exists to prevent.

---

## 3. Protein & Food-Source Swap Table

Applies only where the Nutrition Adjustment Rule Table (§3) has already resolved a gate of `none` or `recommended` for the user's Condition Tag(s) — i.e., only where the parent table is already showing personalized or framework-level food content. For the `required-blocking` variant of any row below (e.g., `Hypertension — Uncontrolled/Unsure`, `Heart Disease — Recent Event/Symptomatic`), no food content of any kind is shown, per Section 2's rule, regardless of Dietary Pattern.

| Existing Nutrition Row | Standard example foods | Vegetarian swap | Vegan swap |
|---|---|---|---|
| **Baseline / None of the Above** | chicken breast, turkey, lean beef, fish, eggs, dairy | eggs, Greek yogurt, cottage cheese, milk — plus lentils, chickpeas, black beans, tofu, tempeh | lentils, chickpeas, black beans, kidney beans, tofu, tempeh, edamame, seitan, almonds, peanuts, pumpkin seeds, fortified soy products |
| **Diabetes Plate Method** (¼-plate protein quarter) | chicken breast, turkey, fish, lean beef, eggs, low-fat cottage cheese | eggs, low-fat cottage cheese or Greek yogurt — plus tofu, tempeh, lentils, chickpeas, black beans ⚑¹ | tofu, tempeh, edamame, seitan, lentils, chickpeas, black beans, kidney beans ⚑¹ — nuts/seeds in modest portions |
| **Hypertension — DASH-style pattern** ("lean protein" element) | chicken breast, fish (e.g., salmon), lean beef, low-fat dairy | low-fat dairy, eggs — plus beans, lentils, nuts ⚑² | beans, lentils, chickpeas, tofu, walnuts, almonds, pumpkin seeds ⚑² |
| **Heart Disease — AHA pattern** ("unsaturated over saturated" protein/fat element) | skinless poultry, fish (especially fatty fish like salmon), lean cuts of meat, eggs in moderation | eggs, low-fat dairy — plus tofu, tempeh, legumes, walnuts, almonds, ground flaxseed, chia seeds ⚑³ | tofu, tempeh, edamame, legumes, walnuts, almonds, ground flaxseed, chia seeds, canola/soybean oil for cooking ⚑³ |

**⚑¹ Diabetes Plate Method note (Ritham inference, flagged):** unlike meat, legumes carry meaningful carbohydrate alongside their protein, so a generous bean/lentil portion is doing some of the work of the plate's carbohydrate quarter too, not just its protein quarter. ADA's "Eating for Diabetes Management" page explicitly lists **"Vegetarian or Vegan Meal Patterns"** as a recognized pattern and states the Diabetes Plate framework "can be a framework for all the above meal patterns" — but it does **not** publish an explicit protein-for-legume substitution ratio. That portioning detail isn't in the ADA material this research could access, so treat it as something worth a dietitian's confirmation before shipping.

**⚑² DASH note (Ritham inference, flagged):** NHLBI's official DASH eating plan page has **no vegetarian or vegan adaptation** — it lists "meats, poultry, and fish" as one food group (≤6 servings/day) and beans/nuts as separate groups, without framing the latter as a substitute for the former. The swap above is Ritham's own construction: using DASH's *own already-included* bean/nut/legume groups as the user's primary protein source when meat is excluded, rather than inventing a new food group. This is not an NHLBI-published substitution.

**⚑³ Heart Disease note:** flax, chia, walnuts, and canola/soybean oil supply plant omega-3 (ALA), but the body converts under 15% of ALA into the long-chain EPA/DHA forms most heart-health guidance is actually about — see Section 4 for the full nutrient note and the algal-oil-supplement mention.

---

## 4. Nutrient-Awareness Education Blocks

Shown once, in-app, tied to the `dietary_pattern` field — general education, not personalized to any specific Condition Tag, shown identically whether or not the user also has a condition flagged (a condition tag can add its own separate disclaimer per §4.4/§4.5 of the parent doc, but doesn't change this text).

**Grounding note on the "protein combining" claim below:** Harvard T.H. Chan Nutrition Source states plant protein sources should be eaten "each day," not "each meal," to cover all amino acids. Mayo Clinic's vegetarian-diet guidance doesn't mention protein-combining as a concern at all. The Academy of Nutrition and Dietetics' 2016 position paper is the source most commonly cited for "you don't need to combine proteins at the same meal" and its abstract affirms vegan/vegetarian diets are "nutritionally adequate... across all life stages" when appropriately planned — but the exact full-text wording on same-meal-vs-across-the-day timing is paywalled and wasn't independently confirmed. The claim is included because two of three sources checked directly support it and the third is silent rather than contradictory.

### Vegan education block

> **Eating vegan? A few nutrients are worth extra attention.**
>
> - **Vitamin B12** — found naturally only in animal foods, so this is the one nutrient nearly every vegan needs a deliberate plan for. Good sources: fortified nutritional yeast, fortified breakfast cereals, and a B12 supplement — many vegans use one as a matter of course, not as a backup plan.
> - **Iron** — plant iron (non-heme) absorbs less efficiently than the iron in meat; a fully plant-based diet needs roughly 1.8x the iron intake of a diet that includes meat to land in the same place. Good sources: lentils, spinach, tofu, chickpeas, kidney beans, cashews, fortified grains/cereals. Pairing these with a vitamin-C-rich food (citrus, peppers, tomatoes) helps absorption.
> - **Zinc** — legumes and whole grains contain phytates that bind zinc and reduce how much your body absorbs. Good sources: pumpkin seeds, lentils, peanuts, whole wheat bread, kidney beans. Soaking beans, grains, and seeds before cooking can help.
> - **Omega-3 (EPA/DHA)** — flaxseed, chia, walnuts, and canola/soybean oil provide a plant omega-3 (ALA), but your body converts less than 15% of it into the long-chain EPA/DHA forms it actually uses. An algal-oil supplement is the most direct plant-based way to get EPA/DHA — worth asking a doctor or dietitian about, especially during pregnancy.
> - **Calcium** — without dairy, this takes more deliberate planning. Good sources: kale, broccoli, bok choy, fortified soy or almond milk, calcium-set tofu, fortified orange juice or cereal. (Spinach is high in calcium on a label but a poor real-world source — oxalates block most of it from actually absorbing.)
> - **Vitamin D** — without fortified dairy, plant sources are limited. Good sources: UV-treated mushrooms, fortified plant milks; a lichen-derived vegan D3 supplement is available and raises blood levels more effectively than D2.
> - **Iodine** — seafood, eggs, and dairy are the main dietary sources, and a vegan diet excludes all three. Iodized salt is the most reliable everyday source; seaweed also contains iodine, but in wildly inconsistent amounts, so it isn't a dependable substitute on its own.
>
> **On protein specifically:** you don't need to pair "complete" proteins in the same meal (the classic rice-and-beans-together idea). Eating a variety of plant proteins — beans, lentils, tofu, tempeh, nuts, seeds, whole grains — across the day covers what your body needs. A few, like quinoa and chia, are already complete proteins on their own.

### Vegetarian education block

> **Eating vegetarian? A couple of nutrients are worth a little extra attention.**
>
> - **Vitamin B12** — dairy and eggs give you some coverage, but a vegetarian diet still carries a higher deficiency risk than one that includes meat. Fortified cereals and nutritional yeast are easy to add, and it's worth mentioning to a doctor if dairy and eggs aren't a regular part of your diet either.
> - **Iron** — plant iron (non-heme) absorbs less efficiently than the iron in meat, and dairy/eggs don't change that math — a vegetarian diet needs roughly 1.8x the iron of a diet that includes meat. Lentils, spinach, tofu, chickpeas, kidney beans, cashews, and fortified grains are good sources; pairing with a vitamin-C-rich food helps absorption.
> - **Zinc** — legumes and whole grains contain phytates that reduce absorption, so vegetarians run a bit lower here too. Pumpkin seeds, lentils, peanuts, whole wheat bread, and kidney beans are good sources.
> - **Omega-3 (EPA/DHA)** — unless you eat fish, flax/chia/walnuts only convert to the long-chain forms your body uses at a rate below 15%. An algal-oil supplement is worth a conversation with your doctor.
>
> Calcium, vitamin D, and iodine aren't called out here the way they are for vegans — dairy and eggs cover most of what those three nutrients need for most people, which is the main nutritional difference between a vegetarian and a vegan diet. And between dairy, eggs, and a variety of plant proteins across the day, protein adequacy generally isn't a concern — no need to pair specific plant proteins at the same meal for a "complete" protein either.

---

## 5. Disclaimer

> Dietary Pattern guidance is general plant-based nutrition education, not an individualized meal plan, and it's not a substitute for a registered dietitian — especially if you're vegan and also managing a health condition Ritham has flagged, where the two may need to be balanced by a professional in ways general education alone can't safely cover.
