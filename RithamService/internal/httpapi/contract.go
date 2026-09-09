// Package httpapi is the thin HTTP layer over internal/plan and internal/identity: decode a
// request, call the domain package, encode a response. It holds no plan-generation or identity
// logic of its own.
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

// AppleSignInRequest is the entire set of values permitted to leave the device for
// POST /v1/identity/apple (ACCOUNT-01). It has exactly three fields:
//
//   - identityToken: the raw Apple-issued identity JWT, verified server-side against Apple's
//     published keys (internal/identity.VerifyIdentityToken) -- never trusted at face value.
//   - nonce: the client-generated nonce Sign in with Apple's own flow already produces, checked
//     against the token's own nonce claim to bind this request to that specific authorization.
//   - displayName: optional, set only on first sign-in when the stored value is still empty --
//     never overwrites an existing name.
//
// No device identifier, no contact data, and no location field is accepted here, matching this
// file's existing WorkoutPlanRequest data-minimization discipline. The field count and JSON tag
// names below are asserted by reflection in handler_test.go.
type AppleSignInRequest struct {
	IdentityToken string `json:"identityToken"`
	Nonce         string `json:"nonce"`
	DisplayName   string `json:"displayName"`
}

// SessionResponse is returned by a successful POST /v1/identity/apple. sessionToken is the
// opaque bearer token the client must present on every authenticated route thereafter -- it is
// returned here exactly once and is never recoverable from the server again (only its SHA-256
// digest is stored).
type SessionResponse struct {
	UserID       string `json:"userId"`
	DisplayName  string `json:"displayName"`
	SessionToken string `json:"sessionToken"`
	ExpiresAt    string `json:"expiresAt"`
}

// MeResponse is returned by GET /v1/identity/me: the caller's own identity and current display
// name, nothing else.
type MeResponse struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
}

// DisplayNameRequest is the entire request body for PUT /v1/identity/display-name -- exactly one
// field, the new name. A name over identity.displayNameMaxLen is rejected (400), never truncated.
type DisplayNameRequest struct {
	DisplayName string `json:"displayName"`
}
