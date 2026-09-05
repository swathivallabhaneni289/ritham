// Package plan generates workout plans. It has no HTTP dependency: Generate is a pure function
// so plan-shaping logic can be tested directly, without a server (see 02-RESEARCH.md's Go
// Backend Research §2/§6).
package plan

import "errors"

// Sentinel errors returned by Generate for each independently invalid input. The HTTP handler
// (internal/httpapi) maps every one of these to HTTP 400, never a panic or a 500.
var (
	ErrUnsupportedFrequency      = errors.New("plan: unsupported weekly frequency")
	ErrUnknownExperienceLevel    = errors.New("plan: unknown experience level")
	ErrUnknownGuidancePermission = errors.New("plan: unknown guidance permission")
)

// ExperienceLevel is a coarse, client-derived experience bucket. These four string values are
// the exact wire values the Swift client sends and must match its coding keys character for
// character.
type ExperienceLevel string

const (
	ExperienceBeginner       ExperienceLevel = "beginner"
	ExperienceIntermediate   ExperienceLevel = "intermediate"
	ExperienceAdvanced       ExperienceLevel = "advanced"
	ExperienceDailyExerciser ExperienceLevel = "dailyExerciser"
)

// GuidancePermission mirrors the client's already-resolved ClearanceGate for the workout domain
// -- the D-07 minimized signal in place of any diagnosis-bearing data. It has exactly the three
// values ClearanceGate itself has, from least to most restrictive.
type GuidancePermission string

const (
	PermissionNone             GuidancePermission = "none"
	PermissionRecommended      GuidancePermission = "recommended"
	PermissionRequiredBlocking GuidancePermission = "requiredBlocking"
)

// Exercise is one prescribed movement within a Session.
type Exercise struct {
	Name     string
	Sets     int
	RepRange string
}

// Session is one training day within a Plan.
type Session struct {
	DayIndex  int
	Focus     string
	Exercises []Exercise
}

// Plan is a full weekly workout plan, or -- under the most restrictive permission -- an empty
// plan carrying only a referral note and no numeric field populated anywhere.
type Plan struct {
	FrequencyPerWeek int
	Sessions         []Session
	GuidanceNote     string
}

// generalGuidanceNote, consultationGuidanceNote and referralGuidanceNote are the three guidance
// notes Generate attaches at, respectively, PermissionNone, PermissionRecommended and
// PermissionRequiredBlocking. This mirrors HEALTH-03's on-device three-level guidance semantics
// (general / professional-consultation / referral-only) rather than reinventing them here.
const (
	generalGuidanceNote      = "General strength-training guidance only. This plan is not a substitute for professional advice."
	consultationGuidanceNote = "General strength-training guidance only. Check with a professional before starting a new program."
	referralGuidanceNote     = "This falls under required-blocking guidance: no personalized plan is provided. Please consult a healthcare professional before starting a workout program."
)

// volume describes how much work a Session prescribes per exercise, scaled by ExperienceLevel:
// fewer sets and a higher rep range for the least experienced bucket, more sets and a lower rep
// range for the most experienced.
type volume struct {
	sets     int
	repRange string
}

var volumeByLevel = map[ExperienceLevel]volume{
	ExperienceBeginner:       {sets: 2, repRange: "12-15"},
	ExperienceIntermediate:   {sets: 3, repRange: "8-12"},
	ExperienceAdvanced:       {sets: 4, repRange: "6-10"},
	ExperienceDailyExerciser: {sets: 5, repRange: "5-8"},
}

// supportedFrequencies is the set of weekly frequencies Generate accepts (02-CONTEXT.md's
// Claude's Discretion: 3/5/7 days/week, a Settings preference).
var supportedFrequencies = map[int]bool{3: true, 5: true, 7: true}

// focusRotation orders session focus areas so a week's sessions vary rather than repeating one
// focus. It has 7 entries -- one per day of the largest supported frequency -- so every
// supported frequency (3, 5, 7) gets that many distinct focuses with no repeats.
var focusRotation = []string{
	"full-body foundations",
	"upper-body push",
	"lower-body strength",
	"upper-body pull",
	"core and mobility",
	"full-body power",
	"active recovery and mobility",
}

// focusExercise names one representative exercise per focus area in focusRotation.
var focusExercise = map[string]string{
	"full-body foundations":        "Goblet squat",
	"upper-body push":              "Barbell bench press",
	"lower-body strength":          "Barbell back squat",
	"upper-body pull":              "Bent-over row",
	"core and mobility":            "Plank hold",
	"full-body power":              "Kettlebell swing",
	"active recovery and mobility": "Bodyweight mobility flow",
}

// Generate produces a Plan for the given weekly frequency, experience bucket and guidance
// permission. It returns a distinct exported sentinel error for each unrecognized input so the
// HTTP handler can map each to a 4xx rather than a 5xx.
func Generate(frequencyPerWeek int, level ExperienceLevel, permission GuidancePermission) (Plan, error) {
	if !supportedFrequencies[frequencyPerWeek] {
		return Plan{}, ErrUnsupportedFrequency
	}

	vol, ok := volumeByLevel[level]
	if !ok {
		return Plan{}, ErrUnknownExperienceLevel
	}

	switch permission {
	case PermissionRequiredBlocking:
		// HEALTH-03's required-blocking rule: no numeric prescription anywhere, zero sessions,
		// a referral note only. FrequencyPerWeek is left at its zero value deliberately -- this
		// mirrors the action's "no numeric field populated anywhere in the returned structure"
		// requirement, not just an empty session list.
		return Plan{Sessions: []Session{}, GuidanceNote: referralGuidanceNote}, nil
	case PermissionNone, PermissionRecommended:
		// fall through to full-plan construction below
	default:
		return Plan{}, ErrUnknownGuidancePermission
	}

	sessions := make([]Session, frequencyPerWeek)
	for i := 0; i < frequencyPerWeek; i++ {
		focus := focusRotation[i]
		sessions[i] = Session{
			DayIndex: i + 1,
			Focus:    focus,
			Exercises: []Exercise{
				{Name: focusExercise[focus], Sets: vol.sets, RepRange: vol.repRange},
			},
		}
	}

	guidanceNote := generalGuidanceNote
	if permission == PermissionRecommended {
		guidanceNote = consultationGuidanceNote
	}

	return Plan{
		FrequencyPerWeek: frequencyPerWeek,
		Sessions:         sessions,
		GuidanceNote:     guidanceNote,
	}, nil
}
