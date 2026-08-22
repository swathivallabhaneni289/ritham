# Ritham Health-Intake Questionnaire & Condition-Based Recommendation Rules

Published as an interactive artifact: https://claude.ai/code/artifact/cc23b004-94e6-48e7-97de-7de55f438d84

> **Before you build this.** This draft is grounded in published screening/guideline research, but it is not clinical or legal advice, and it hasn't been reviewed by a lawyer, clinician, or registered dietitian. Two things worth knowing before shipping any of it:
>
> **PAR-Q+** (the standard pre-exercise screening form the gate section below is modeled on) is copyrighted, and its license only permits photocopying the *entire, unmodified* form — not a reworded or partial version. The gate questions here are original wording inspired by its clinical logic, not the licensed instrument itself, which is the point — but get that confirmed by counsel before launch, especially if "PAR-Q+" is ever referenced by name in-product.
>
> **SCOFF** (the eating-disorder screen in Section 1.4) is a validated academic instrument in wide clinical use — have a clinician confirm the wording and scoring logic here matches current guidance before it ships.

**Design constraint governing every section below:** this is a fixed-choice screening questionnaire, not free text and not live AI-generated advice. Condition tags map to pre-vetted, guideline-based rule sets (general adjustments, using real published guideline language/ranges where cited — never a number Ritham computed for one specific user). Red-flag and high-risk conditions gate to a "talk to your doctor/dietitian first" message and **block** personalized suggestions rather than soften them. Every adjusted suggestion carries a visible disclaimer and stays editable. Nothing in this document should be read as, or built as, a diagnostic tool.

A note on sourcing discipline: every rule below is grounded in the research done for this project. Where the research explicitly flagged a figure as unverified, secondary-sourced, or unconfirmed against a primary guideline (the AFib "210 min/week," "50–70% max HR per AHA," the ACSM "currently active" threshold, specific glucose cutoffs used as user-facing numbers, and any FDA claim-language examples), that figure does **not** appear anywhere in this document, including as reference text. Where the research simply didn't cover a condition/exercise or condition/nutrition pairing (e.g., kidney-specific exercise mechanics, cancer-specific exercise mechanics, osteoporosis nutrition, postpartum lactation nutrition), the corresponding table cell says so explicitly rather than filling the gap with plausible-sounding content.

---

## 1. Intake Question Flow

### 1.0 Opening disclaimer (shown once, before Question 1)

> Ritham asks a few questions about your health so we can show general, guideline-based workout and food suggestions that fit you better — not to diagnose or treat anything. This is a short screening questionnaire, not a medical exam, and your answers aren't reviewed by a doctor or dietitian.
>
> If you have a health condition, are pregnant, are recovering from an injury or surgery, or take medication, please talk to your doctor or another qualified professional before starting or changing an exercise or eating routine. If you think you might be having a medical emergency right now, stop and call 911 (or your local emergency number) instead of continuing this questionnaire.
>
> Every suggestion Ritham gives you afterward is a general starting point you can edit or turn off, and you can update these answers anytime in Settings.

### 1.1 About you (asked before the health questions)

**Q0. What's your age?**
`[ Numeric entry ]`

- **Routing:** Under 18 → tag `Under 18 (Minor)` is set permanently on the profile (re-confirmed at each birthday/re-screen). 65 or older → tag `65+ / Deconditioned / Returning After Inactivity` is pre-set (can also be reached by adults under 65 via U-1 in §1.4).
- **Parental consent gate (new — see also REQUIREMENTS.md MINOR-01/02):** Under 13 → onboarding halts immediately after Q0; a parent/guardian must complete a verifiable consent step before the account is usable at all (calibration session, tracking, and every question below all wait on this — COPPA requires verifiable consent for any personal-information collection from a child under 13, and Ritham collects plenty). 13–17 → onboarding continues with zero parental involvement through calibration, the explanation-register choice, and Q0b (dietary pattern); a parent-approval step gates only the rest of this questionnaire — §1.2 onward, including the SCOFF screen — so a teen can track workouts and build Momentum before or without a parent ever approving anything. This is a consent step, not a UX fork — it never produces a distinct "kid mode" screen, per the no-age-gated-fork principle in §CROSSGEN-05.
- This question is asked here, not buried in the condition checklist, because age alone — independent of any diagnosed condition — changes what Ritham is allowed to suggest (see Section 3, row 1).
- **Precedence rule:** an age-derived `65+ / Deconditioned / Returning After Inactivity` tag (set by Q0) can only be *added to* by U-1, never cleared by it. A 65+ user who answers "No" to U-1 keeps the tag from Q0 — U-1 is an additional way to reach the tag for under-65 users, not the sole authority over who holds it.

### 1.2 Gate section (PAR-Q–style general screen)

Framing line shown above this section:

> These next questions are the kind a doctor's office typically asks before starting a new activity program. A "yes" doesn't stop you from using Ritham — it just means we'll ask you to check in with a professional before we turn on personalized suggestions in that area.

**G1.** Has a doctor ever told you that you have a heart condition or high blood pressure? — `Yes / No`

**G2.** Do you feel chest pain or significant shortness of breath at rest, during your daily activities, or during exercise? — `Yes / No`

**G3.** In the past 12 months, have you lost your balance because of dizziness, or lost consciousness? *(This doesn't include brief lightheadedness from breathing hard during a tough workout.)* — `Yes / No`

**G4.** Have you been diagnosed with any other ongoing medical condition not covered above — for example diabetes, kidney disease, cancer, an eating disorder, or another chronic condition? — `Yes / No`

**G5.** Are you currently taking a prescription medication for an ongoing health condition, or following a specific meal plan or nutrition targets given to you by a doctor or dietitian? — `Yes / No`

*If G5 = Yes, two immediate follow-ups appear:*
- **MED-1.** Does this include a medication for your heart or blood pressure, such as a beta-blocker? — `Yes / No / Not sure` → sets modifier tag `Rate-Limiting Heart/BP Medication`
- **MED-2.** Is this a specific meal plan or nutrition targets from a doctor or dietitian (not just general advice)? — `Yes / No` → sets modifier tag `Existing Clinician-Prescribed Diet or Meal Plan`

**G6.** Do you currently have — or have you had in the last 12 months — a bone, joint, or soft-tissue problem that gets worse with physical activity? — `Yes / No`

**G7.** Has a doctor ever told you that you should only do physical activity that is medically supervised? — `Yes / No`

**Branching:**
- **All of G1–G7 = No** → brief affirmation ("Good to know — you're clear to move on.") and continue straight to the condition checklist (§1.3). Gate answers alone don't skip the checklist, since conditions like mild osteoarthritis or a non-severe allergy wouldn't necessarily trigger a "yes" here.
- **Any of G1–G7 = Yes** → show a clearance interstitial (copy in Section 4) **before** continuing to the checklist:
  - If **G2 or G3 = Yes** (chest pain/shortness of breath at rest, or fainting/dizziness/loss of consciousness), the interstitial uses the *urgent* variant, which leads with the emergency carve-out line and is visually distinct from the routine variant.
  - Any other "yes" combination uses the *routine* clearance variant.
  - Either way, the user proceeds to the checklist afterward so Ritham can still capture which condition category applies (needed for messaging, for the referral text to be specific, and because a "yes" here doesn't by itself tell us *which* rule set to hold back).

### 1.3 Condition checklist

Shown to everyone, framed as:

> Do any of these apply to you? Select all that apply. Choosing "None of the above" clears any other selections.

**Cardiovascular**
- [ ] High blood pressure
- [ ] Heart disease (including a prior heart attack, heart failure, coronary artery disease, or a cardiac surgery/procedure)
- [ ] Irregular heartbeat (arrhythmia, e.g., atrial fibrillation)
- [ ] Another heart or circulatory condition

**Metabolic**
- [ ] Type 1 diabetes
- [ ] Type 2 diabetes
- [ ] Prediabetes
- [ ] Another metabolic condition

**Musculoskeletal / Joint**
- [ ] Osteoarthritis (knee, hip, or other joint)
- [ ] Osteoporosis or osteopenia (low bone density)
- [ ] Chronic or ongoing low back pain
- [ ] A prior injury or surgery (e.g., joint replacement, ACL repair, rotator cuff repair)

**Pregnancy / Postpartum**
*Shown with the rationale line: "We ask this because pregnancy and the months after birth change what activity and eating guidance is safe to personalize — not for any other reason."*
- [ ] Currently pregnant
- [ ] Postpartum (gave birth within the last 12 months)

**Kidney / Renal**
- [ ] Diagnosed kidney disease (CKD)
- [ ] Currently on dialysis

**Eating Disorder History**
*Shown with the rationale line: "We ask so we can turn off calorie- and weight-focused features that could be unhelpful for some people — not to label or judge anything."*
- [ ] Current or past eating disorder, disordered eating, or a difficult relationship with food or exercise

**Food Allergies**
- [ ] I have one or more food allergies

**Other Serious Condition**
- [ ] Currently undergoing treatment for cancer (e.g., chemotherapy or radiation)
- [ ] Another serious or complex condition not listed above

*(This ninth category isn't in a standard short checklist, but the research is explicit that active cancer treatment carries the same nutrition-personalization risk as kidney disease or an eating disorder — malnutrition is common and undetected in oncology outpatients, and generic "calorie deficit" logic can be actively harmful — so it needs its own hard-gated tag rather than falling through the cracks of the other eight categories. This mirrors PAR-Q+'s own "any other condition not listed" branch.)*

- [ ] **None of the above**

### 1.4 Severity / context follow-ups (shown only for categories selected above)

**If any Cardiovascular box is checked:**
- **CV-1.** In the last 6 weeks, have you had a heart attack, heart surgery, or a cardiac procedure (such as a stent, ablation, or pacemaker placement)? — `Yes / No`
- **CV-2** *(if "High blood pressure" checked)*. How would you describe your blood pressure right now? — `Well-controlled with treatment / Not sure, or I haven't checked recently / My doctor has told me it's high or not well-controlled`
- **CV-2b** *(if "Irregular heartbeat" checked)*. Is your heart rhythm currently well-controlled with treatment? — `Yes / Not sure / No`

**If any Metabolic box is checked (except "Prediabetes" alone):**
- **M-1.** Do you take insulin, or a medication that can cause low blood sugar (such as a sulfonylurea)? — `Yes / No / Not sure`
- **M-2.** Have you been told you have diabetes-related eye disease, nerve damage in your feet, or a current foot wound? — `Yes / No / Not sure`

**If any Musculoskeletal / Joint box is checked:**
- **MSK-1.** Is this currently flaring up, or has it gotten noticeably worse in the last 2 weeks? — `Yes / No`
- **MSK-2** *(only if "prior injury or surgery" checked)*. Has your surgeon or physical therapist cleared you for regular exercise? — `Yes, fully cleared / Still in recovery, not yet cleared / Not applicable`

**If "Currently pregnant" is checked:**
- **PG-1.** Has your doctor told you about any pregnancy complications — for example high blood pressure, a placenta condition, preterm labor, bleeding, or a heart or lung condition? — `Yes / No / Not sure`

**If "Postpartum" is checked:**
- **PP-1.** Did you have a C-section, or were there any complications with your delivery? — `Yes / No`
- **PP-2.** How many weeks postpartum are you? — `Under 6 weeks / 6–12 weeks / Over 12 weeks`

**If any Kidney / Renal box is checked:**
- **KR-1.** Are you currently on dialysis? — `Yes / No`
- **KR-2.** Has your doctor or dietitian given you specific limits on things like protein, potassium, phosphorus, or fluids? — `Yes / No / Not sure` *(informational — doesn't change the gate, which is already the most restrictive setting for this category; lets Ritham's referral message acknowledge an existing plan instead of sounding generic.)*

**If "Eating disorder history" is checked:**

Shown first: *"These next questions are a standard, widely-used screening tool, not a diagnosis. We ask so we can turn off calorie- and weight-focused features that could be unhelpful, not to judge or label anything. Your individual answers are never shown to us as a score or a label — only used to turn certain features on or off."*

- **ED-1.** Do you make yourself sick because you feel uncomfortably full? — `Yes / No`
- **ED-2.** Do you worry you have lost control over how much you eat? — `Yes / No`
- **ED-3.** Have you recently lost more than about 14 lb (6.4 kg) in a 3-month period? — `Yes / No`
- **ED-4.** Do you believe yourself to be fat when others say you are too thin? — `Yes / No`
- **ED-5.** Would you say that food dominates your life? — `Yes / No`

*(This is the SCOFF questionnaire, the validated instrument the research names explicitly — 2 or more "yes" answers is the established positive-screen threshold. The score is computed and used internally only; it is never displayed to the user as a number, a "positive/negative" result, or any label naming a disorder. See Section 1.5 on how the result surfaces.)*

**If "I have one or more food allergies" is checked:**
- **FA-1.** Is any of your allergies severe or life-threatening — for example, could it cause anaphylaxis, or have you been prescribed an epinephrine auto-injector (like an EpiPen)? — `Yes / No / Not sure`

**If any "Other Serious Condition" box is checked:**
- **OS-1.** Is this a new diagnosis, or a change in treatment, within the last 3 months? — `Yes / No` *(affects the tone/urgency of the referral message only — the gate itself is already the most restrictive setting either way.)*

**Universal follow-up (shown to everyone, regardless of what else was selected — including "None of the above"):**
- **U-1.** One more thing: are you 65 or older, or returning to exercise after being inactive for the last 3 months or more? — `Yes / No` → sets tag `65+ / Deconditioned / Returning After Inactivity`, which stacks with any other tags a user has.

### 1.5 How a positive eating-disorder screen surfaces to the user

A positive SCOFF screen (§1.4) never shows the user a label, a score, or the word "disorder." It resolves to the same neutral, supportive referral message described in Section 4, with the relevant features quietly turned off — the user always sees "here's what changed and why," never "here's what you screened positive for." Every other required-blocking trigger in this document — including the ones that fire after onboarding is finished, like the goal-weight cross-check — uses this identical neutral treatment, not just the SCOFF result. See Section 5 for the complete, single list of what triggers it.

### 1.6 Flow mechanics: expiry, re-screening, and temporary states

- **Validity window:** condition tags and any "cleared by a professional" toggle (Section 4) remain in effect for up to 12 months, or until the user edits an answer, whichever comes first. Ritham prompts a re-screen at the 12-month mark, or immediately if the user indicates in-app that something has changed.
- **The "I've talked to a professional" toggle is not a permanent unlock.** It re-prompts "has anything changed since you last checked in?" at each re-screen point rather than silently persisting forever.
- **Temporary/acute illness (informational, not a gated question):** general copy shown near the workout tab reminds users that if they're currently sick with a cold, flu, or fever, it's a good idea to wait until they've recovered before increasing intensity — this applies to everyone, independent of condition tags.

---

## 2. Workout Adjustment Rule Table

**Gate legend for this table:** `none` = personalized suggestions shown normally · `recommended` = suggestions shown, but paired with a "check with a professional first" note and a lighter default intensity · `required-blocking` = no personalized intensity/modality suggestion at all; only generic, non-individualized activity information and a referral message.

Where a row notes "no exercise-specific guidance identified in this framework," that reflects a real gap in the research provided (not every condition/exercise pairing was researched) — the gate defaults to the more cautious setting rather than guessing at content.

| Condition Tag | Workout Adjustment | Contraindicated / Avoid | Clearance Gate |
|---|---|---|---|
| **Under 18 (Minor)** | No exercise-specific restriction from this framework based on age alone; standard general-activity suggestions apply. | — | none |
| **65+ / Deconditioned / Returning After Inactivity** | Same aerobic/strength targets as any adult, plus a 3rd component: multicomponent balance + functional-strength work, prioritized ahead of aerobic work if very deconditioned. Set intensity relative to the individual (RPE or the talk test — moderate = can talk but not sing, vigorous = can say only a few words), not a fixed benchmark. Start low, progress gradually across duration/frequency/intensity; any duration counts toward weekly totals. Extra emphasis on warm-up/cool-down. | Jumping straight into vigorous intensity or heavy loads without a gradual build-up. | none (progression pace is the adjustment, not a block) |
| **Hypertension — Managed** | Aerobic and/or resistance training most days; resistance training is treated as roughly equivalent to aerobic work for blood-pressure benefit. Progress duration first, then frequency/intensity. Cue exhaling through the exertion phase of a lift. | Holding the breath during heavy lifts (Valsalva maneuver) — flag this specifically for anyone in this tag. | recommended |
| **Hypertension — Uncontrolled / Unsure** | Hold personalized intensity suggestions; offer only general, non-vigorous activity information until status is clarified. | Vigorous-intensity and heavy-resistance suggestions. | required-blocking |
| **Heart Disease — Stable** | Gradual, supervised-style progression (cardiac-rehab-aligned pacing); increase duration/intensity slowly based on tolerance. | Sudden jumps in intensity without a gradual build. | recommended |
| **Heart Disease — Recent Event / Symptomatic** | Hold personalized suggestions; direct to a cardiac-rehab program or physician-directed plan. Rest days here should never break the user's streak or trigger streak-loss messaging. | Any self-directed intensity or resistance-training suggestion. | required-blocking |
| **Arrhythmia — Stable / Rate-Controlled** | Moderate-intensity activity is generally well-tolerated; keep the format similar to Ritham's default aerobic/strength mix. | Sustained very-high-intensity/high-volume endurance efforts (a U-shaped intensity/arrhythmia-risk relationship is noted in the research). | recommended |
| **Arrhythmia — Uncontrolled / Unsure** | Hold personalized intensity suggestions until rate control is established. | Any intensity increase; new dizziness or chest pain during activity should stop the session. | required-blocking |
| **Rate-Limiting Heart/BP Medication** *(modifier — applies alongside any cardiovascular tag)* | Use RPE or the talk test to set intensity instead of heart-rate zones — these medications blunt the heart-rate response, so HR-based targets are unreliable for this user. | Presenting or relying on heart-rate-zone-based targets for this user. | none (adjusts method, doesn't itself gate) |
| **Diabetes (Type 1 or Type 2) — On Insulin or Hypoglycemia-Risk Medication** | Standard aerobic + resistance targets, paired with a reminder to check blood glucose before exercising and to have fast-acting carbohydrate available; suggest rechecking after exercise given the risk of delayed post-exercise low blood sugar. | Starting exercise during symptoms of low blood sugar (shakiness, confusion, sweating, weakness) without checking/treating first. | recommended |
| **Diabetes (Type 1 or Type 2) — Not on Hypoglycemia-Risk Medication** | Standard aerobic + resistance targets; no routine glucose-check reminder needed. | — | none |
| **Prediabetes** | Standard consistent moderate-activity progression, resistance training encouraged as an addition. | — | none |
| **Diabetes — Retinopathy / Foot Complication Flagged** *(modifier)* | If eye disease flagged: favor low-impact modes (e.g., stationary cycling, swimming) and avoid framing suggestions around vigorous or jarring effort pending an eye exam. If foot wound/ulcer flagged: shift to non-weight-bearing suggestions until resolved; otherwise, walking-type weight-bearing activity is not automatically restricted for neuropathy alone. | Vigorous aerobic/resistance work, jumping/jarring movement, head-down positions for flagged retinopathy; weight-bearing activity on an active foot wound. | recommended |
| **Osteoarthritis** | Low-impact aerobic modes (walking, cycling, swimming/water aerobics); strengthening of muscles around the affected joint; flexibility and balance work; gait aids/bracing during flares or longer/uneven-terrain walks. Once an individualized program is established and well-tolerated, ongoing suggestions can move to standard (no-gate) personalization. | High-impact, repetitive-loading activity (running, jumping, skiing) especially during flares; daily hard-surface impact; painful deep loaded knee flexion (modify range rather than cut entirely). | recommended |
| **Osteoporosis / Osteopenia** | Weight-bearing endurance activity and progressive resistance training targeting hip and spine; balance/posture training; neutral-spine core bracing instead of flexion-based ab work. | Loaded spinal flexion (toe touches, sit-ups/crunches, rounded-forward bending); spinal twisting, especially combined with flexion; high-impact/jumping activity if bone density loss or a prior fragility fracture is significant. | recommended |
| **Chronic Low Back Pain** | Trunk strengthening/endurance, motor-control and stabilization work, general aerobic activity, aquatic exercise; hamstring flexibility work; core-activation cueing (exhale through effort, avoid breath-holding); "stay active" framing over rest. | Anything that causes significant pain during or hours after activity; heavy/loaded flexion or twisting if it's pain-provoking for this individual. | recommended |
| **Prior Injury / Surgery — Not Yet Cleared** | Hold loading/intensity progression for the affected area specifically; general, low-impact, non-affected-area activity can still be suggested. Rest or modified sessions here should never break the user's streak or trigger streak-loss messaging. | Loading the affected joint/area at all beyond surgeon/PT-set limits; for shoulder/rotator cuff specifically: overhead pressing, upright rows, heavy/deep bench press, behind-the-neck movements. | required-blocking (for the affected area/loading progression specifically) |
| **Prior Injury / Surgery — Cleared** | Conservative reintroduction: start meaningfully below prior activity level and progress gradually rather than resuming at pre-injury load immediately. | Jumping straight back to pre-injury intensity/volume. | recommended |
| **Musculoskeletal Flare** *(modifier — applies with any Musculoskeletal tag above, when flagged worse in the last 2 weeks)* | Temporarily treat the underlying condition as higher-caution: reduce load/intensity, favor low-impact alternatives, pause progression until the flare settles. | Advancing progression during an active flare. | recommended |
| **Pregnancy — Uncomplicated** | Walking, swimming, stationary cycling, low-impact aerobics; modified yoga/Pilates avoiding prolonged supine positioning after the first trimester; most uncomplicated pregnancies can continue moderate aerobic and strength activity throughout. | Contact sports, high fall-risk activities (off-road cycling, horseback riding, downhill skiing), scuba/sky diving, hot yoga/hot Pilates. Any of the ACOG warning signs (vaginal bleeding, breathlessness before exertion, dizziness, chest pain, calf pain/swelling, regular painful contractions, decreased fetal movement, fluid leakage) should stop the session immediately. | recommended |
| **Pregnancy — Complicated / Unsure** | Hold personalized suggestions entirely; general, non-quantified information only. Rest days here should never break the user's streak or trigger streak-loss messaging. | Any self-directed exercise suggestion. | required-blocking |
| **Postpartum — Uncomplicated** | Pelvic-floor exercises can start immediately; light walking as tolerated within days for an uncomplicated vaginal delivery; gradual, progressive return with general/core strengthening. | High-intensity/high-impact activity (running, jumping) before roughly 12 weeks postpartum, or before pelvic-floor/core function is reassessed if symptoms (leaking, heaviness, pain) are present. | recommended |
| **Postpartum — C-Section / Complications** | Hold personalized suggestions until explicit clearance is confirmed; general, non-quantified information only. Rest days here should never break the user's streak or trigger streak-loss messaging. | Any self-directed resumption of exercise before clearance. | required-blocking |
| **Kidney Disease / Dialysis** | No exercise-specific guidance was identified in the research for this project. Per the general ACSM screening principle that known renal disease should prompt medical clearance, hold personalized workout suggestions and route to the user's care team — dialysis scheduling and fluid/electrolyte status can also affect safe exercise timing. | Any self-directed intensity suggestion. | required-blocking |
| **Eating Disorder History — Positive Screen / Active Symptoms** | Shift entirely away from quantified/compensatory framing (no "burn X," no streak-linked intensity pressure); general movement-for-enjoyment suggestions only. Rest days here should never break the user's streak or trigger streak-loss messaging. | Any calorie-burn-framed or compensatory-exercise suggestion tied to food intake. | required-blocking |
| **Eating Disorder History — Self-Reported Only / Negative Screen** | Standard workout suggestions, with quantified/compensatory framing (e.g., "calories burned this session") off by default and available only if the user explicitly opts in. | Framing workouts as compensation for eating. | recommended |
| **Severe Food Allergy** | No exercise-specific adjustment identified in this framework. | — | none |
| **Non-Severe Food Allergy** | No exercise-specific adjustment identified in this framework. | — | none |
| **Other Serious Condition / Active Cancer Treatment** | No exercise-specific guidance was identified in the research for this project. Per general chronic-condition screening guidance, hold personalized workout suggestions and route to the user's care team — treatment type/phase can affect fatigue, immune status, and cardiac considerations in ways this framework can't safely generalize. | Any self-directed intensity suggestion. | required-blocking |
| **Existing Clinician-Prescribed Diet or Meal Plan** *(modifier)* | No workout-specific rule from this framework — see Nutrition table. | — | none |
| **None of the Above / Baseline** | Full standard Ritham programming: gradual progression across duration, frequency, and intensity per general adult activity guidance. | — | none |

---

## 3. Nutrition Adjustment Rule Table

**Gate legend for this table:** `none` = personalized quantity suggestions (portions, calorie ranges, macro splits) shown normally, editable · `recommended` = general framework-level guidance shown (plate-method style, food-quality tips, published population reference ranges as education), but paired with a "talk to a dietitian/doctor" note · `required-blocking` = **zero** personalized quantity suggestion of any kind — no calorie number, no macro split, no portion target, no weight-loss goal — generic educational content only (or nothing), plus a referral message.

Any numeric range that appears below (2,300mg/1,500mg sodium; <10%/<6% saturated fat; <10% added sugar; the ADA's ~45–60g carb-per-meal starting range; the CDC's 5–7% body-weight figure) is a **published population-level reference figure**, shown as general education text identical for every user in that row — never a number Ritham calculates individually from someone's data. This is the line this table is built around.

| Condition Tag | General Guidance Direction | What Ritham Should NOT Do | Clearance Gate |
|---|---|---|---|
| **Under 18 (Minor)** | General movement and food-variety education only. | No weight-loss framing, no calorie targets, no macro targets, no portion-restriction guidance, no weight-loss goal-setting feature at all — independent of any condition otherwise reported, per AAP guidance that dieting itself is a discouraged behavior for minors. | required-blocking (specifically for any weight-management/calorie/portion feature) |
| **65+ / Deconditioned / Returning After Inactivity** | No nutrition-specific rule from this framework; standard general guidance (see "None of the Above" row) applies. | Assuming reduced activity implies reduced nutrition needs. | none |
| **Hypertension — Managed** | DASH-style eating-pattern awareness: more vegetables, fruit, whole grains, low-fat dairy, lean protein; general sodium-awareness education, optionally citing the published 2,300mg (standard) and 1,500mg (further-reduction) reference ranges as population-level education. | Calculating or displaying a personalized sodium mg/day target; implying a specific BP outcome ("this will lower your BP to X"). | recommended |
| **Hypertension — Uncontrolled / Unsure** | Same DASH-style *educational* content as above may still be shown (it's general population guidance, low-risk to display) — but no personalized quantity target of any kind, and content is paired with a clearance note. | Any personalized sodium, calorie, or macro number. | required-blocking (for personalized quantities specifically) |
| **Heart Disease — Stable** | AHA's general heart-pattern education: favor whole over refined grains, varied produce daily, unsaturated over saturated fats, minimize ultraprocessed foods, limit added sugar, reduce sodium; may cite the <10%/<6% saturated-fat reference ranges as general education. | Prescribing an individualized saturated-fat percentage or cholesterol mg target; suggesting supplement or medication-interaction guidance. | recommended |
| **Heart Disease — Recent Event / Symptomatic** | General heart-healthy educational content only, no personalized targets, paired with a clearance note. | Any personalized calorie/macro/fat-gram number. | required-blocking |
| **Arrhythmia — Stable/Rate-Controlled or Uncontrolled/Unsure** | No arrhythmia-specific nutrition rule was identified in the research; if hypertension or heart disease is also flagged, that row's guidance applies. | Inventing an arrhythmia-specific dietary rule not covered by the research. | none (unless combined with Hypertension or Heart Disease tags above) |
| **Diabetes (Type 1 or Type 2) — any medication status** | ADA's Diabetes Plate Method (½ plate non-starchy vegetables, ¼ protein, ¼ carbohydrate foods, plus water) as the primary no-math framework; general carb-consistency education (keeping carb intake roughly steady meal-to-meal); added-sugar-awareness education, optionally citing the ADA's general ~45–60g-per-meal starting range and the <10%-of-calories added-sugar reference as population-level education. | Calculating a personalized carbohydrate-gram target; any insulin-dosing or medication-adjustment suggestion (dosing decisions belong entirely with the user's clinician, never with the app). | recommended |
| **Prediabetes** | Same Plate Method framework; general education that consistent moderate activity plus modest weight management (may cite CDC's National DPP 5–7% figure as population-level education) is associated with lower progression risk — framed as population evidence, not a personal projection. | Calculating a personalized weight-loss percentage or calorie target from the 5–7% figure. | none |
| **Diabetes — Retinopathy / Foot Complication Flagged** *(modifier)* | No incremental nutrition rule beyond the Diabetes row above — this flag changes exercise guidance (Section 2), not nutrition guidance, per the research reviewed. | — | recommended (same as underlying Diabetes row) |
| **Osteoarthritis / Osteoporosis / Chronic Low Back Pain / Prior Injury or Surgery (any)**, including a flagged **Musculoskeletal Flare** | No nutrition-specific rule was identified in the research for these conditions; standard general guidance applies. Flare status (MSK-1) changes the Workout table's guidance only — it does not change nutrition guidance. | Assuming weight loss is medically indicated because of joint or back pain, and defaulting to a deficit-oriented suggestion on that basis — goal-setting here should be the user's own choice, not an algorithmic inference from a musculoskeletal tag. | none |
| **Pregnancy — Uncomplicated** | General, non-numeric educational content about eating patterns during pregnancy (e.g., "focus on nutrient-dense foods, and follow your prenatal care team's guidance on weight gain") may be shown; no calorie or weight-loss targets under any circumstance. | Setting a calorie deficit or weight-loss goal for this user under any circumstance — ACOG guidance is that intentional weight loss/calorie restriction is not recommended during pregnancy; also should not calculate a macro target. | required-blocking (for any calorie/macro/weight-loss quantity) |
| **Pregnancy — Complicated / Unsure** | No personalized content at all, including the general educational text allowed in the row above; referral only. | Any nutrition suggestion, quantified or not. | required-blocking |
| **Postpartum — Uncomplicated** | General, non-restrictive recovery-supportive education (adequate intake to support healing); no calorie-deficit target within this window without clinician input. | Offering or suggesting a weight-loss calorie target as a feature during this window; assuming breastfeeding status without asking. | required-blocking (specifically for the weight-loss goal-setting feature; general educational content is shown normally) |
| **Postpartum — C-Section / Complications** | General educational content only, more conservative than the uncomplicated row; defer to OB clearance for anything beyond that. | Any personalized quantity target. | required-blocking |
| **Kidney Disease / Dialysis** | None — zero personalized guidance of any kind, including general framework content, because protein/potassium/phosphorus/fluid needs move in different directions depending on CKD stage and dialysis status, and even dedicated renal-diet tools disclaim their own output as insufficient without an RD. In licensure states, generating individualized nutrition therapy for kidney disease without an RDN is not just inadvisable but restricted by law. | Showing any calorie, protein, potassium, phosphorus, or fluid target — even a "general" one. | required-blocking |
| **Eating Disorder History — Positive Screen / Active Symptoms** | None — zero calorie, macro, weight, or portion-quantity display of any kind for this user; shift entirely to non-numeric, behavior-based content (e.g., general food-variety education) if any nutrition content is shown at all. | Displaying calorie counts, macro targets, or portion sizes; allowing this user to set a weight-loss goal in-app; any "calories remaining" or similar running total. | required-blocking |
| **Eating Disorder History — Self-Reported Only / Negative Screen** | General framework guidance permitted, but numeric targets (calories, macros, portions) stay off by default and require the user to explicitly opt in — never presented as the default view. | Defaulting this user into calorie-deficit-forward messaging; framing food in "good/bad" terms. | recommended |
| **Severe Food Allergy** | Standard label-check reminder, plus a standing, mandatory "verify independently before eating" flag attached to every food-related suggestion that touches a flagged allergen category. | Presenting any meal/recipe/portion suggestion as guaranteed "safe" for this user's allergy, or silently substituting around an allergen without flagging it for the user to confirm. | recommended (mandatory independent verification, every time) |
| **Non-Severe Food Allergy** | Standard label-check reminder only. | — | none |
| **Other Serious Condition / Active Cancer Treatment** | None — zero personalized quantity guidance, for the same reason as kidney disease: malnutrition is common and often undetected in this population, and a generic deficit-oriented calculation can push in exactly the wrong direction. General referral to an oncology-credentialed dietitian only. | Assuming a calorie deficit is appropriate; showing any calorie/macro/portion number. | required-blocking |
| **Existing Clinician-Prescribed Diet or Meal Plan** *(modifier)* | Defer entirely to the plan the user's own doctor/dietitian already gave them; if shown at all, Ritham's role is logging/tracking against that existing plan, not generating a competing one. | Layering Plate Method, DASH, or any other Ritham framework on top of an existing clinician-prescribed plan without that clinician's sign-off. | recommended (defer to existing plan) |
| **None of the Above / Baseline** | Full personalization available: general frameworks (Plate Method-style, food-quality guidance) presented as editable starting points; calorie/macro estimates, where offered, are clearly labeled general estimates the user can adjust. | — | none |

---

## 4. Disclaimer & Legal Framing

### 4.1 Questionnaire opening (shown once, before Question 1)

> Ritham asks a few questions about your health so we can show general, guideline-based workout and food suggestions that fit you better — not to diagnose or treat anything. This is a short screening questionnaire, not a medical exam, and your answers aren't reviewed by a doctor or dietitian.
>
> If you have a health condition, are pregnant, are recovering from an injury or surgery, or take medication, please talk to your doctor or another qualified professional before starting or changing an exercise or eating routine. If you think you might be having a medical emergency right now, stop and call 911 (or your local emergency number) instead of continuing this questionnaire.
>
> Every suggestion Ritham gives you afterward is a general starting point you can edit or turn off, and you can update these answers anytime in Settings.

### 4.2 Routine clearance interstitial (any Gate G1–G7 = Yes, without G2/G3)

> **Let's have you check in with a professional first.**
>
> Based on what you told us, we'd like you to talk with a doctor or a qualified exercise/nutrition professional before we turn on personalized workout and food suggestions. This isn't Ritham judging your fitness — it's just that a few of your answers are outside what a general screening questionnaire can safely personalize on its own.
>
> You can still use Ritham to log workouts and meals manually, and see general (non-personalized) guidance, in the meantime. Once you've checked in with a professional, come back to Settings and let us know — we'll turn personalized suggestions back on.
>
> `[Continue to the rest of the questions]`

### 4.3 Urgent clearance interstitial (G2 or G3 = Yes)

> **Before anything else: if you're currently experiencing chest pain, difficulty breathing, sudden severe dizziness, or think you may be having a medical emergency, stop and call 911 (or your local emergency number) right now. Don't wait to finish this questionnaire.**
>
> If that's not what's happening right now: based on your answers, please talk with a doctor before starting or changing an exercise routine. We'll hold off on personalized suggestions until you've done that.
>
> `[I understand — continue to the rest of the questions]`

### 4.4 Persistent tag on any condition-adjusted suggestion (compact form, always visible)

> Adjusted for **[Condition]** · General guidance, not medical advice · Edit in Settings

### 4.5 Expanded disclaimer (behind a tap/expand on the compact tag)

> This suggestion reflects a general, guideline-based adjustment for **[Condition]**. It is not personalized medical or nutrition advice, not a diagnosis, and not a substitute for your doctor or a registered dietitian — no clinician has reviewed it for you individually. Using Ritham doesn't create a doctor-patient or dietitian-client relationship. Always check with your healthcare provider before changing your exercise or eating habits, especially if your condition, medications, or symptoms have changed since you last answered these questions.

### 4.6 Required-blocking message (shown in place of any suggestion, for required-blocking gates)

> **We're holding off on personalized suggestions here.**
>
> Based on what you told us, this isn't something Ritham can safely tailor on its own — we'd like you to check with a doctor, registered dietitian, or other qualified professional first. You can still track your workouts and meals manually, and see general, non-personalized information.
>
> Once you've talked with a professional, come back to Settings to let us know, and we'll turn personalized suggestions back on for this area.

### 4.7 Standing footer disclaimer (visible wherever any adjusted suggestion appears, short form)

> Ritham is not a medical provider and does not diagnose, treat, cure, or prevent any disease or condition. Suggestions are general and guideline-based, not individualized medical or nutrition prescriptions. If something here conflicts with advice from your doctor or dietitian, follow their advice.

---

## 5. Red-Flag Escalation Logic

**Governing principles, applied before any specific rule below:**
- Any **"Not sure"** answer on a clearance-relevant follow-up resolves to the *more cautious* branch — never the more permissive one.
- When **two or more red-flag tags** apply at once (e.g., Heart Disease + Kidney Disease, or Pregnancy + Eating Disorder History), Ritham applies the single **most restrictive** gate across all applicable tags — gates are never averaged, blended, or softened because one tag alone might have been milder.
- A required-blocking gate blocks *personalized suggestions in that domain (workout and/or nutrition)*, not app access as a whole — manual logging and generic, non-personalized information stay available throughout.

**Specific combinations that immediately trigger a required-blocking state (no personalized workout and/or nutrition suggestion until resolved):**

1. **G2 or G3 = Yes** (chest pain/shortness of breath at rest or daily activity, or fainting/dizziness/loss of consciousness in the last 12 months) → urgent interstitial (§4.3); both workout and nutrition personalization held until the user confirms professional clearance.
2. **Any Cardiovascular tag + CV-1 = Yes** (heart attack, cardiac surgery, or a cardiac procedure within the last 6 weeks) → `Heart Disease — Recent Event / Symptomatic`, required-blocking, both domains.
3. **"High blood pressure" + CV-2 = "My doctor has told me it's high or not well-controlled" OR "Not sure, or I haven't checked recently"** → `Hypertension — Uncontrolled / Unsure`, required-blocking for workout intensity; nutrition education can still show (general DASH content is low-risk) but with no personalized quantity. *(Both branches map here — "Not sure" is not a pass-through to Managed; the tag name and the governing "Not sure resolves to the more cautious branch" principle both require this.)*
4. **"Irregular heartbeat" + CV-2b = "No" OR "Not sure"** → `Arrhythmia — Uncontrolled / Unsure`, required-blocking, workout domain.
5. **Any Metabolic tag (not Prediabetes alone) + M-1 = Yes** (on insulin or a hypoglycemia-risk medication) → workout suggestions carry a standing glucose-check-before-exercising reminder (recommended gate, not required-blocking).
6. **Any Metabolic tag + M-2 = Yes** (retinopathy, neuropathy, or foot wound flagged) → `Diabetes — Retinopathy / Foot Complication Flagged`, required-blocking for vigorous/resistance/high-impact/weight-bearing suggestions specifically (not a full personalization block).
7. **"Currently pregnant" (regardless of PG-1 answer)** → nutrition: required-blocking on any calorie/macro/weight-loss quantity or goal-setting, absolute, independent of complication status.
8. **"Currently pregnant" + PG-1 = Yes or Not sure** → `Pregnancy — Complicated / Unsure`, required-blocking across *both* workout and nutrition domains, full referral to OB.
9. **"Postpartum" + PP-1 = Yes** (C-section or delivery complications) → `Postpartum — C-Section / Complications`, required-blocking, workout domain, until explicit clearance is confirmed.
10. **Any Kidney/Renal box checked**, regardless of any follow-up answer → required-blocking, both domains, always — this tag alone is sufficient; no combination needed.
11. **SCOFF score ≥ 2 "Yes"** (ED-1 through ED-5) → `Eating Disorder History — Positive Screen`, required-blocking on all nutrition quantity features; workout suggestions shift to non-quantified, non-compensatory framing; supportive referral message (§1.5), never a diagnostic label.
12. **Any Musculoskeletal tag + MSK-2 = "Still in recovery, not yet cleared"** → `Prior Injury / Surgery — Not Yet Cleared`, required-blocking for loading/progression in the affected area specifically (not a full-body block); general low-impact suggestions for unaffected areas remain available.
13. **Any "Other Serious Condition" box checked**, regardless of OS-1 answer → required-blocking, both domains, always.
14. **Under 18 + a weight-loss goal is set or requested anywhere in the app** (not just at intake) → treated identically to a positive ED screen for nutrition purposes: required-blocking on the weight-loss/calorie/portion feature, supportive redirect message, no quantity shown.
15. **A goal weight is set (anywhere in the app, not only at intake) that falls below a healthy-BMI floor, and no Eating Disorder History was reported** → treat as a red flag equivalent to a positive ED screen: pause the weight-loss/calorie feature and surface the supportive referral message, rather than silently computing a target toward that goal. *(This closes the specific gap the research flags in other apps' intake designs — screening once at signup but never re-checking an implausible goal set later.)*
16. **Severe Food Allergy (FA-1 = Yes or Not sure)** → not a personalization block, but a standing, non-removable "verify independently" flag attached to every food suggestion touching that allergen category, every time, with no expiry.

**Non-combination, always-on rules** (these are standing product-wide prohibitions, not gate states any user can be in or clear):
- The urgent-emergency line ("if you think you're having a medical emergency, call 911") is shown at the top of the gate section (§1.2) and repeated in the urgent interstitial (§4.3) — it is never conditional on a specific answer combination, since a true emergency shouldn't wait on questionnaire logic to catch it.
- Ritham never generates an insulin-dosing or medication-adjustment suggestion, for any user, under any tag or combination of tags. This isn't something a clearance or a "cleared by a professional" toggle can unlock — it's out of scope for the product entirely, full stop, and belongs solely with the user's clinician.
