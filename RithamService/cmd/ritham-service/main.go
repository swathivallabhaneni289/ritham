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
//
// Ten friends routes now exist too (HOUSEHOLD-02, GROUPEVENTS-01): the mutual friend graph,
// invite links, and contact matching. They depend on the same database as identity; contact
// matching additionally reads RITHAM_CONTACT_MATCH_SALT (README.md) once at startup. A missing
// database leaves the friends routes unregistered (404), matching every other route group's
// degrade-gracefully precedent.
//
// Nine group routes now exist too (GROUPEVENTS-01, HOUSEHOLD-02): small, closed, invite-only
// groups built on the friends graph above. They depend on the same database as identity; a
// missing database leaves the group routes unregistered (404), matching every other route
// group's degrade-gracefully precedent.
//
// Eight Goal-Event/RSVP/completion routes now exist too (GROUPEVENTS-01, GROUPEVENTS-02): a
// shared, non-timed commitment with binary completion logging and no ranking mechanism anywhere.
// They depend on the same database as identity and on groupssvc's own RequireMember gate; a
// missing database leaves them unregistered (404), matching every other route group's
// degrade-gracefully precedent. buildGroupsService also wires the events package's real
// CompletionVisibility implementation into groupssvc here, replacing 04.1-08's placeholder no-op
// (groups.Service defaults to one at construction) now that event_completions exists.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/events"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/friends"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
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
	friendssvc := buildFriendsService(st)
	groupssvc := buildGroupsService(st, friendssvc)
	eventssvc := buildEventsService(st, groupssvc, photosvc)

	server := &http.Server{
		Addr:         addr,
		Handler:      httpapi.NewMux(idsvc, photosvc, objectStore, friendssvc, groupssvc, eventssvc),
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

// buildFriendsService constructs the friends.Service backing the ten friends routes, or returns
// nil when st is nil (no database configured at startup), matching buildIdentityService's and
// buildPhotoService's degrade-gracefully precedent. The contact-match salt is read from
// RITHAM_CONTACT_MATCH_SALT exactly once here, not per request (friends.New's own doc comment).
func buildFriendsService(st *store.Store) *friends.Service {
	if st == nil {
		return nil
	}

	return friends.New(st, time.Now, friends.ContactMatchSaltFromEnv())
}

// buildGroupsService constructs the groups.Service backing the nine group routes, or returns nil
// when st or friendssvc is nil (no database configured at startup, or the friends service itself
// failed to build for the same reason), matching every other service builder's degrade-gracefully
// precedent. friendssvc satisfies groups.FriendPredicate directly -- Invite consults the friends
// package's own AreFriends method, never a second copy of the friendship query (T-04.1-46).
func buildGroupsService(st *store.Store, friendssvc *friends.Service) *groups.Service {
	if st == nil || friendssvc == nil {
		return nil
	}

	svc := groups.New(st, friendssvc, time.Now)
	// Replace 04.1-08's placeholder no-op CompletionVisibility with the real implementation now
	// that event_completions exists (see this file's header comment and
	// internal/events.NewCompletionVisibility's own doc comment).
	svc.SetCompletionVisibility(events.NewCompletionVisibility())
	return svc
}

// buildEventsService constructs the events.Service backing the eight Goal-Event/RSVP/completion
// routes, or returns nil when st or groupssvc is nil (no database configured at startup, or the
// groups service itself failed to build for the same reason), matching every other service
// builder's degrade-gracefully precedent. groupssvc satisfies events.MembershipGate directly --
// every events.Service method calls groupssvc's own RequireMember, never a restated membership
// query (T-04.1-57). photosvc satisfies events.PhotoOwnershipChecker directly (its Asset method's
// signature is identical); when photosvc is nil (object store unavailable), the photo-ownership
// check stays at its fail-closed default (events.noopPhotoOwnershipChecker) -- a completion may
// still be logged, just never with a photo reference, rather than the whole events surface going
// unregistered over an unrelated dependency.
func buildEventsService(st *store.Store, groupssvc *groups.Service, photosvc *photo.Service) *events.Service {
	if st == nil || groupssvc == nil {
		return nil
	}

	svc := events.New(st, groupssvc, time.Now)
	if photosvc != nil {
		svc.SetPhotoOwnershipChecker(photosvc)
	}
	return svc
}
