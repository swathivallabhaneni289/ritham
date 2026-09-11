package photo

// TestSharedTierRequiresPipeline is the module-wide, source-level companion to objectstore.go's
// own type-level guarantee: PutShared's photo parameter is StrippedImage, never []byte, so no
// caller could pass raw bytes even if it tried (T-04.1-16's key_links). A type check alone cannot
// catch a future package that reaches for the object-store client directly instead of going
// through this package's Ingest entry point -- if a second package ever vendored its own writer or
// constructed a minio client of its own, the type guarantee at this package's boundary would never
// see it. This test is the backstop: it walks every non-test .go file in the module OUTSIDE this
// package and fails if any of them calls PutShared or constructs a minio client directly, keeping
// "only internal/photo may write to the shared object-storage tier" true of the whole module, not
// just this package's own call graph.
//
// TestPutSharedSignatureIsOpaque pins the asymmetric writer signature itself at the source-text
// level, a second, independent guarantee beyond the compiler alone -- mirroring
// CertificateComposer.swift/CertificateTests.swift's own precedent (RithamApp) for pairing a type
// constraint with a source-text pin.
//
// Both tests follow this codebase's established source-scanning gate shape
// (internal/events/noranking_test.go, internal/feed/nodenominator_test.go): strip comment lines so
// a comment documenting a prohibition never trips the gate documenting it, and assert a real floor
// on files scanned so the walk cannot pass vacuously if directory resolution ever silently found
// nothing.

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// moduleRoot is RithamService/ itself, reachable relative to this test file's own package
// directory (internal/photo).
const moduleRoot = "../.."

func TestSharedTierRequiresPipeline(t *testing.T) {
	var scannedFiles int

	err := filepath.WalkDir(moduleRoot, func(path string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		// internal/photo is the one package permitted to write to the shared tier -- skip it,
		// which also skips this very test file, avoiding any self-reference concern.
		if strings.Contains(filepath.ToSlash(path), "/internal/photo/") {
			return nil
		}

		raw, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		scannedFiles++
		checkNoDirectSharedTierWrite(t, path, string(raw))
		return nil
	})
	if err != nil {
		t.Fatalf("walking %s: %v", moduleRoot, err)
	}

	// A bare non-empty check lets a gate go silently vacuous when code relocates (this project's
	// own established lesson -- see internal/events/noranking_test.go and
	// RithamApp/RithamTests/Phase4CoverageTests.swift's identical precedent) -- assert a real
	// floor instead. 26 non-test .go files exist outside internal/photo as of this plan.
	const minScannedFiles = 15
	if scannedFiles < minScannedFiles {
		t.Fatalf("scanned %d files outside internal/photo, want at least %d -- this gate may have stopped walking a real directory", scannedFiles, minScannedFiles)
	}
	t.Logf("TestSharedTierRequiresPipeline scanned %d files outside internal/photo", scannedFiles)
}

func checkNoDirectSharedTierWrite(t *testing.T, path, content string) {
	t.Helper()
	for i, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "//") {
			continue // a comment documenting a prohibition never trips the gate documenting it
		}
		if idx := strings.Index(line, "//"); idx >= 0 {
			line = line[:idx]
		}
		if strings.Contains(line, "PutShared(") {
			t.Errorf("%s:%d: calls PutShared directly outside internal/photo: %q", path, i+1, strings.TrimSpace(line))
		}
		if strings.Contains(line, "minio.New(") {
			t.Errorf("%s:%d: constructs a minio client directly outside internal/photo: %q", path, i+1, strings.TrimSpace(line))
		}
	}
}

// TestPutSharedSignatureIsOpaque is the source-text pin described in this file's header comment.
func TestPutSharedSignatureIsOpaque(t *testing.T) {
	raw, err := os.ReadFile("objectstore.go")
	if err != nil {
		t.Fatalf("reading objectstore.go: %v", err)
	}
	source := string(raw)
	const wantSignature = "func (o *ObjectStore) PutShared(ctx context.Context, key string, img StrippedImage) error"
	if !strings.Contains(source, wantSignature) {
		t.Errorf("objectstore.go's PutShared signature no longer matches the expected opaque-image shape: want to find %q", wantSignature)
	}
	if strings.Contains(source, "PutShared(ctx context.Context, key string, img []byte)") {
		t.Errorf("objectstore.go's PutShared accepts a raw []byte -- the shared tier must only accept a StrippedImage")
	}
}
