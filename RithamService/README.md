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

## Environment variables

This phase introduces six environment variables. None has a production value yet — see
"Deployment prerequisites (unresolved)" below.

| Variable | Purpose | Local dev value |
|----------|---------|------------------|
| `RITHAM_DATABASE_URL` | Postgres connection string, read by `internal/store.New` and `internal/store.Migrate` | `postgres://ritham:ritham@127.0.0.1:5432/ritham_dev?sslmode=disable` |
| `RITHAM_OBJECT_STORE_ENDPOINT` | MinIO/S3-compatible endpoint | `127.0.0.1:9000` |
| `RITHAM_OBJECT_STORE_ACCESS_KEY` | Object store access key | `ritham` |
| `RITHAM_OBJECT_STORE_SECRET_KEY` | Object store secret key | `ritham-dev-secret` |
| `RITHAM_OBJECT_STORE_BUCKET_PRIVATE` | Bucket for original, EXIF-intact photos (private tier) | `ritham-photos-private` |
| `RITHAM_OBJECT_STORE_BUCKET_SHARED` | Bucket for stripped, group-visible photos (shared tier) | `ritham-photos-shared` |

The object-store four are declared and documented here; they are consumed starting in plan
04.1-04.

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

## Scope note

No framework or router library is used (Go 1.22+'s `net/http` method-and-path pattern syntax
covers routing). Production hosting and an authentication story are both still open (see
"Deployment prerequisites" above) — the server binds to loopback only for now specifically
because there is no auth in front of it. The module's dependency list starts with this plan
(`github.com/jackc/pgx/v5`, `github.com/golang-migrate/migrate/v4`); every dependency added was
verified against its public source repository first, never added speculatively.
