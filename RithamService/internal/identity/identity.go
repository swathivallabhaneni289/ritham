// Package identity is the resolution of cmd/ritham-service/main.go's own former header comment,
// which stated: "This endpoint has no authentication in this first pass... Adding real hosting
// requires deciding an authentication story first." That question is answered here.
//
// Sign in with Apple is the only identity mechanism this service has, or will have for this
// phase's scope (04.1-CONTEXT.md's Identity and Account Recovery decision, which supersedes
// 04.1-RESEARCH.md Pattern 6's earlier device-keypair-only recommendation -- only the
// identity-issuance step changes; the opaque, server-side-revocable session/token model Pattern 6
// recommended is unchanged and is what session.go implements). Ritham stores no password or
// credential of its own: the server verifies an Apple-issued identity token against Apple's own
// published keys (apple.go) and, on success, issues its own opaque session token
// (session.go) -- it never sees, stores, or validates a user-chosen secret.
package identity

import (
	"time"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// sessionTTL is how long an issued session token remains valid before it must be reissued via a
// fresh sign-in. displayNameMaxLen bounds SetDisplayName's input; a name longer than this is
// rejected, never silently truncated.
const (
	sessionTTL        = 30 * 24 * time.Hour
	displayNameMaxLen = 60
)

// Service is the identity domain's single entry point: Apple sign-in, session issuance,
// authentication, revocation, and display-name management. It holds a database handle, the
// source of Apple's published signing keys, the expected token audience, and an injected clock
// so every time-dependent check (expiry) in this package is testable without touching wall time.
type Service struct {
	store    *store.Store
	keys     AppleKeySource
	audience string
	now      func() time.Time
}

// New constructs a Service. audience is the expected "aud" claim on every Apple identity token
// this service verifies -- normally RITHAM_APPLE_BUNDLE_ID.
func New(st *store.Store, keys AppleKeySource, audience string, now func() time.Time) *Service {
	return &Service{store: st, keys: keys, audience: audience, now: now}
}
