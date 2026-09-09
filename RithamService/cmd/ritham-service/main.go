// Command ritham-service wires and starts the HTTP server. It holds no business logic of its
// own -- per Go Backend Research §2's cmd/ convention, all of that lives under internal/.
//
// Authenticated routes now exist: internal/identity's Sign in with Apple + opaque revocable
// session model, wired in via internal/httpapi's RequireSession middleware
// (ACCOUNT-01, see 04.1-CONTEXT.md). The pre-existing workout-plan route deliberately stays
// unauthenticated and identifier-free -- it never accepted a per-user identifier and shipping
// auth elsewhere does not change that boundary (04.1-RESEARCH.md Pitfall 4).
//
// The service still binds to the loopback interface regardless of authentication now existing.
// That is a separate decision: real (non-loopback) hosting is still an unresolved deployment
// prerequisite (see README.md's "Deployment prerequisites"), and shipping auth does not by
// itself authorize widening the bind address.
//
// If RITHAM_DATABASE_URL is not configured, the service still starts and continues serving the
// workout-plan route -- only the four identity routes are left unregistered (404, not a 500 or a
// crash) -- so a database misconfiguration cannot take down the already-shipped feature.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/httpapi"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/identity"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

const (
	defaultPort = "8080"

	readTimeout  = 5 * time.Second
	writeTimeout = 10 * time.Second
	idleTimeout  = 60 * time.Second

	// appleBundleIDEnvVar names the env var carrying the expected "aud" claim on every Apple
	// identity token this service verifies.
	appleBundleIDEnvVar  = "RITHAM_APPLE_BUNDLE_ID"
	defaultAppleBundleID = "com.ritham.app"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}
	// The loopback host is always prepended, regardless of the PORT override, so no
	// configuration can widen the binding beyond 127.0.0.1.
	addr := "127.0.0.1:" + port

	idsvc := buildIdentityService()

	server := &http.Server{
		Addr:         addr,
		Handler:      httpapi.NewMux(idsvc),
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
		IdleTimeout:  idleTimeout,
	}

	log.Printf("ritham-service listening on %s", addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("ritham-service: server stopped: %v", err)
	}
}

// buildIdentityService constructs the identity.Service backing the four identity routes, or
// returns nil when no database is configured -- see this file's header comment for why that is
// a deliberate non-fatal outcome rather than a startup failure.
func buildIdentityService() *identity.Service {
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		log.Printf("ritham-service: RITHAM_DATABASE_URL is not set -- starting without identity " +
			"routes; only the pre-existing workout-plan endpoint is served")
		return nil
	}

	ctx := context.Background()
	st, err := store.New(ctx, databaseURL)
	if err != nil {
		log.Fatalf("ritham-service: connecting to database: %v", err)
	}

	if err := store.Migrate(databaseURL); err != nil {
		log.Fatalf("ritham-service: running migrations: %v", err)
	}

	audience := os.Getenv(appleBundleIDEnvVar)
	if audience == "" {
		audience = defaultAppleBundleID
	}

	return identity.New(st, identity.NewAppleJWKS(nil, ""), audience, time.Now)
}
