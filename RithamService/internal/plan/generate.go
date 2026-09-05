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
// plan carrying only a referral note.
type Plan struct {
	FrequencyPerWeek int
	Sessions         []Session
	GuidanceNote     string
}

// Generate produces a Plan for the given weekly frequency, experience bucket and guidance
// permission. It returns a distinct exported sentinel error for each unrecognized input so the
// HTTP handler can map each to a 4xx rather than a 5xx.
func Generate(frequencyPerWeek int, level ExperienceLevel, permission GuidancePermission) (Plan, error) {
	return Plan{}, nil
}
