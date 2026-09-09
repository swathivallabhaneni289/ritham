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
//
// Two photo routes now exist too (GROUPEVENTS-03), behind the same RequireSession middleware.
// They depend on the same database as identity, plus an S3-compatible object store configured
// from the RITHAM_OBJECT_STORE_* env vars (README.md); either being unavailable leaves the photo
// routes unregistered (404) rather than crashing the process, matching the identity routes'
// degrade-gracefully precedent.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/httpapi"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/identity"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/photo"
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

	st := buildStore()
	idsvc := buildIdentityService(st)
	photosvc, objectStore := buildPhotoService(st)

	server := &http.Server{
		Addr:         addr,
		Handler:      httpapi.NewMux(idsvc, photosvc, objectStore),
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
		IdleTimeout:  idleTimeout,
	}

	log.Printf("ritham-service listening on %s", addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("ritham-service: server stopped: %v", err)
	}
}

// buildStore connects to and migrates RITHAM_DATABASE_URL, or returns nil when it is not
// configured -- see this file's header comment for why that is a deliberate non-fatal outcome
// (both identity and photo routes degrade to unregistered, not a crash) rather than a startup
// failure. Both buildIdentityService and buildPhotoService are built from this single pool rather
// than each opening their own, so this service holds exactly one connection pool regardless of
// how many route groups end up depending on the database.
func buildStore() *store.Store {
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		log.Printf("ritham-service: RITHAM_DATABASE_URL is not set -- starting without identity " +
			"or photo routes; only the pre-existing workout-plan endpoint is served")
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

	return st
}

// buildIdentityService constructs the identity.Service backing the four identity routes, or
// returns nil when st is nil (no database configured at startup).
func buildIdentityService(st *store.Store) *identity.Service {
	if st == nil {
		return nil
	}

	audience := os.Getenv(appleBundleIDEnvVar)
	if audience == "" {
		audience = defaultAppleBundleID
	}

	return identity.New(st, identity.NewAppleJWKS(nil, ""), audience, time.Now)
}

// buildPhotoService constructs the photo.Service and photo.ObjectStore backing the two photo
// routes, or returns (nil, nil) when st is nil or the object store cannot be constructed (e.g. a
// malformed RITHAM_OBJECT_STORE_ENDPOINT) -- either leaves the photo routes unregistered (404)
// rather than crashing the process, matching buildIdentityService's degrade-gracefully behavior.
// Constructing an *ObjectStore does not itself require the S3-compatible backend to be reachable
// (minio-go connects lazily on first real operation), so this succeeds even before the local
// MinIO dev stack is started; only a real upload/fetch would then fail.
func buildPhotoService(st *store.Store) (*photo.Service, *photo.ObjectStore) {
	if st == nil {
		return nil, nil
	}

	objectStore, err := photo.NewObjectStore(photo.ObjectStoreConfigFromEnv())
	if err != nil {
		log.Printf("ritham-service: constructing object store: %v -- starting without photo routes", err)
		return nil, nil
	}

	return photo.New(st, objectStore, time.Now), objectStore
}
