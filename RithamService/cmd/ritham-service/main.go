// Command ritham-service wires and starts the HTTP server. It holds no business logic of its
// own -- per Go Backend Research §2's cmd/ convention, all of that lives under internal/.
//
// This endpoint has no authentication in this first pass. It is bound to the loopback interface
// for exactly that reason: loopback binding is the real mitigation for the absent-auth gap Go
// Backend Research §7 flags, not something to argue away. Adding real hosting requires deciding
// an authentication story first.
package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/httpapi"
)

const (
	defaultPort = "8080"

	readTimeout  = 5 * time.Second
	writeTimeout = 10 * time.Second
	idleTimeout  = 60 * time.Second
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}
	// The loopback host is always prepended, regardless of the PORT override, so no
	// configuration can widen the binding beyond 127.0.0.1. A bare ":port" binds every
	// interface, which would expose this unauthenticated endpoint to the local network.
	addr := "127.0.0.1:" + port

	server := &http.Server{
		Addr:         addr,
		Handler:      httpapi.NewMux(),
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
		IdleTimeout:  idleTimeout,
	}

	log.Printf("ritham-service listening on %s", addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("ritham-service: server stopped: %v", err)
	}
}
