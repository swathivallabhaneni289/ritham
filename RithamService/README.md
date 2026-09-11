# RithamService

Go backend for Ritham's server-side logic (workout-plan generation, and — starting in Phase
04.1 — identity, friends, groups, goal-events, and the group feed). See
`.planning/phases/04.1-group-goal-events-accountability-circles/04.1-RESEARCH.md` for the full
architecture writeup.

## Run it locally

```bash
cd RithamService
go run ./cmd/ritham-service
```

The server binds to `127.0.0.1:8080` by default. Set `PORT` to use a different port on the
loopback interface (for example `PORT=9090 go run ./cmd/ritham-service`); the loopback host is
always prepended, so no configuration can widen the binding to the network.

The iOS Simulator shares the host Mac's network, so a Debug build can point directly at
`http://127.0.0.1:8080` with no extra networking setup.

## Local dev stack

`docker-compose.dev.yml` starts a local Postgres 16 and a local MinIO, both bound to
`127.0.0.1` only — matching `cmd/ritham-service/main.go`'s existing loopback discipline. Nothing
in this stack is reachable outside this machine.

```bash
cd RithamService
docker compose -f docker-compose.dev.yml up -d
```

This also runs a one-shot `createbuckets` job that creates the two object-storage tiers
`RITHAM_OBJECT_STORE_BUCKET_PRIVATE` and `RITHAM_OBJECT_STORE_BUCKET_SHARED` name (defaults
below), so plan 04.1-04's photo pipeline has both buckets waiting for it.

To tear the stack down (keeping data): `docker compose -f docker-compose.dev.yml stop`.
To tear it down and delete all data: `docker compose -f docker-compose.dev.yml down -v`.

**Alternative: a native Postgres install.** If Docker isn't available, `internal/store`'s
Postgres half works unmodified against any local Postgres 16+ (for example a Homebrew
`postgresql@16` service): `createdb ritham_dev`, then point `RITHAM_DATABASE_URL` at it (for
example `postgres://$(whoami)@localhost:5432/ritham_dev?sslmode=disable` under peer/trust auth).
MinIO has no equivalent native substitute here — the object-store buckets still need the
`createbuckets` compose job, or an equivalent bucket created by hand against whatever
S3-compatible endpoint `RITHAM_OBJECT_STORE_ENDPOINT` points to.

## Environment variables

This phase introduces seven environment variables. None has a production value yet — see
"Deployment prerequisites (unresolved)" below.

| Variable | Purpose | Local dev value |
|----------|---------|------------------|
| `RITHAM_DATABASE_URL` | Postgres connection string, read by `internal/store.New` and `internal/store.Migrate` | `postgres://ritham:ritham@127.0.0.1:5432/ritham_dev?sslmode=disable` |
| `RITHAM_APPLE_BUNDLE_ID` | Expected `aud` claim on every Apple identity token `internal/identity.VerifyIdentityToken` verifies | `com.ritham.app` (also the default when unset) |
| `RITHAM_OBJECT_STORE_ENDPOINT` | MinIO/S3-compatible endpoint | `127.0.0.1:9000` |
| `RITHAM_OBJECT_STORE_ACCESS_KEY` | Object store access key | `ritham` |
| `RITHAM_OBJECT_STORE_SECRET_KEY` | Object store secret key | `ritham-dev-secret` |
| `RITHAM_OBJECT_STORE_BUCKET_PRIVATE` | Bucket for original, EXIF-intact photos (private tier) | `ritham-photos-private` |
| `RITHAM_OBJECT_STORE_BUCKET_SHARED` | Bucket for stripped, group-visible photos (shared tier) | `ritham-photos-shared` |
| `RITHAM_CONTACT_MATCH_SALT` | Fixed, server-side application salt HMAC-applied to every contact-match digest before it is stored or queried (`internal/friends.ContactMatchSaltFromEnv`, read once at startup) | `ritham-dev-contact-match-salt-DO-NOT-USE-IN-PRODUCTION` (also the default when unset -- **changing this in a real deployment invalidates every previously stored digest**, since a digest salted under the old value can never match one salted under the new value again) |

The object-store four are declared and documented here; they are consumed starting in plan
04.1-04.

If `RITHAM_DATABASE_URL` is unset, the service still starts and serves the workout-plan route --
only the four identity routes (`POST /v1/identity/apple`, `POST /v1/identity/revoke`,
`GET /v1/identity/me`, `PUT /v1/identity/display-name`), the two photo routes, and the ten friends
routes are left unregistered.

The ten friends routes (`internal/friends`, HOUSEHOLD-02/GROUPEVENTS-01 -- the mutual friend
graph, invite links, and contact matching) all sit behind `RequireSession`, matching the identity
and photo routes' degrade-gracefully precedent when `RITHAM_DATABASE_URL` is unset:
`POST /v1/friends/requests`, `POST /v1/friends/requests/{id}/accept`,
`POST /v1/friends/requests/{id}/decline`, `GET /v1/friends`, `GET /v1/friends/requests`,
`DELETE /v1/friends/{userId}`, `POST /v1/invites`, `POST /v1/invites/redeem`,
`PUT /v1/friends/contact-match`, `POST /v1/friends/contact-match/query`.

## Running migrations

Migrations live in `internal/store/migrations/` and are embedded into the binary. Run them via
`store.Migrate`, called at service start and from tests — this package exposes no standalone CLI
and no force-version or drop-everything helper on purpose (T-04.1-02): every schema change goes
through the versioned, reversible migration runner, never hand-edited SQL against a live
database.

## Run the tests

```bash
cd RithamService
go test ./...
```

`internal/store`'s tests split into two cases:

- The empty-URL case (`New` returns `store.ErrNoDatabaseURL`) runs with no database present and
  is never skipped.
- The connected cases (migration application, idempotency) require a running database. Without
  `RITHAM_DATABASE_URL` set, they skip with a message naming the exact compose command and env
  var to run them:

```bash
docker compose -f docker-compose.dev.yml up -d postgres
RITHAM_DATABASE_URL='postgres://ritham:ritham@127.0.0.1:5432/ritham_dev?sslmode=disable' \
  go test ./internal/store/...
```

## Deployment prerequisites (unresolved)

Recorded verbatim as still-open, per 04.1-RESEARCH.md's Environment Availability section (no
fallback exists for any of these three):

1. **No production database instance.** `RITHAM_DATABASE_URL` has a local-dev value only; no
   managed or self-hosted Postgres has been provisioned for production use.
2. **No object-storage provider chosen.** The local dev stack runs MinIO because `minio-go`'s
   S3-compatible client works against any compatible backend (self-hosted MinIO, Cloudflare R2,
   AWS S3) — but which one Ritham actually deploys against has not been decided.
3. **No non-loopback hosting.** `cmd/ritham-service/main.go` binds to `127.0.0.1` only. This
   plan does not change that, and adding authentication in plan 04.1-03 does not by itself
   authorize widening the bind address — that remains a decision requiring its own review, made
   only once real hosting is chosen.

`cmd/ritham-service/main.go` stays bound to `127.0.0.1` until those three items are decided.

Two more surfaced by Phase 4.1 (plan 04.1-17, this phase's close-out):

4. **No transport security (TLS) is configured anywhere in this stack.** Every client/server
   round trip so far has been loopback-only (Simulator sharing the host Mac's network), so this
   has never been exercised. Real two-device use — required to actually test friends, groups,
   goal-events, and the shared feed with a second live person — is not possible until hosting
   (item 3) and transport security are decided together; neither is safe to stand up alone.
5. **Account deletion is unbuilt.** Apple's App Store Review Guidelines require an in-app account
   deletion path for any app offering account creation (Guideline 5.1.1(v)), and this phase's
   Sign in with Apple flow (`internal/identity`) is exactly that kind of account creation. No
   deletion route, service method, or UI exists yet. Phase 5 must decide and build this before
   public App Store submission — it is a submission blocker, not a nice-to-have.

## Phase 5 privacy-review handoff (LAUNCH-04)

Recorded here, plainly and specifically, so LAUNCH-04's reviewer does not have to reconstruct
what this phase actually collects and stores from planning documents. Eight categories:

1. **Apple's stable subject identifier and an opaque Ritham user id.** No password or credential
   of Ritham's own exists or is planned — see `internal/identity`.
2. **Session tokens, stored only as digests, revocable.** The raw token is never persisted;
   `internal/identity`'s revoke route invalidates a session by digest.
3. **Salted digests of contact identifiers, only while a user is opted in, deleted on opt-out.**
   `internal/friends`'s contact-matching feature (`RITHAM_CONTACT_MATCH_SALT`) stores only an
   HMAC digest of a contact identifier, never the raw phone number or email, and only for the
   duration of the opt-in.
4. **The friend graph, group memberships, goal events, RSVPs, and completions.** The core social
   data model this phase adds (`internal/friends`, `internal/groups`, `internal/events`).
5. **Photos, stored in a group-visible tier only after unconditional server-side metadata
   stripping** (`internal/photo`, `StripAndReencode`, `TestSharedTierRequiresPipeline` above); the
   metadata-intact original never leaves the owner's own device.
6. **Coarse place-name strings only.** No coordinate is ever stored anywhere on this server, and
   Privacy Zone definitions never leave the client device (`RithamApp/Ritham/Social/PrivacyZones`).
7. **A third-party geocoding processor disclosure.** The client's platform geocoder
   (`LocationAttachment.swift`'s `SystemGeocoder`) sends a transient coordinate to Apple's own
   geocoding servers to resolve a coarse place name. This is Apple acting as a data processor of
   that value, even though Ritham's own backend never receives the coordinate — flagged explicitly
   by 04.1-07-SUMMARY.md and repeated here because "on-device" does not cover this call by itself.
8. **Per-photo export-consent grants.** `internal/feed`'s `exportconsent.go` gates a certificate
   export that includes another member's photo behind that member's own consent.

## Scope note

No framework or router library is used (Go 1.22+'s `net/http` method-and-path pattern syntax
covers routing). Production hosting and an authentication story are both still open (see
"Deployment prerequisites" above) — the server binds to loopback only for now specifically
because there is no auth in front of it. The module's dependency list starts with this plan
(`github.com/jackc/pgx/v5`, `github.com/golang-migrate/migrate/v4`); every dependency added was
verified against its public source repository first, never added speculatively.
