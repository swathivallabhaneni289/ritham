// Package httpapi is the thin HTTP layer over internal/plan: decode a request, call
// plan.Generate, encode a response. It holds no plan-generation logic of its own.
package httpapi

import "github.com/swathivallabhaneni289/ritham/RithamService/internal/plan"

// WorkoutPlanRequest is the entire set of values permitted to leave the device (D-07). It has
// exactly three fields:
//
//   - frequencyPerWeek: a Settings preference with no health-sensitivity.
//   - experienceLevel: a coarse category derived client-side from CalibrationBaseline or
//     self-report -- never the underlying pace-zone/starting-weight numbers.
//   - guidancePermission: the client's already-resolved workout ClearanceGate value, not any
//     diagnosis-bearing data, raw condition tag, or screening answer.
//
// No stable per-user or per-device identifier is accepted here, or ever will be for this
// endpoint's current scope. Adding a field to this struct widens LAUNCH-04's GDPR/CCPA
// privacy-review surface and is therefore a decision requiring its own review, not an
// implementation detail -- see 02-RESEARCH.md's Go Backend Research §4 and 02-CONTEXT.md's D-07.
// The field count and JSON tag names below are asserted by reflection in handler_test.go, so
// widening this boundary later fails a test gate rather than passing silently.
//
// <!-- planner-discipline-allow: guidancePermission -->
type WorkoutPlanRequest struct {
	FrequencyPerWeek   int                     `json:"frequencyPerWeek"`
	ExperienceLevel    plan.ExperienceLevel    `json:"experienceLevel"`
	GuidancePermission plan.GuidancePermission `json:"guidancePermission"`
}

// WorkoutPlanResponse wraps the generated plan.Plan under a "plan" key, per
// 02-RESEARCH.md's Go Backend Research §3.
type WorkoutPlanResponse struct {
	Plan plan.Plan `json:"plan"`
}
