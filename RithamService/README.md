# RithamService

A small Go backend that generates workout plans. It is the first server-side component of
Ritham's new Go backend (see `.planning/PROJECT.md` Key Decisions, D-06/D-07) and exists
alongside the `RithamApp`/`RithamCore` Swift client without touching or replacing any of it.

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

## Run the tests

```bash
cd RithamService
go test ./...
```

## Scope note

This is a first pass, deliberately kept small: no framework, no router library, no Dockerfile,
no CI config, no deployment manifest, and no authentication. Production hosting and an
authentication story are both out of scope until a real hosting decision is made -- the server
binds to loopback only for now specifically because there is no auth in front of it. The module
has zero third-party dependencies; every capability comes from the Go standard library.
