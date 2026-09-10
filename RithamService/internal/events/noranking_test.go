package events

// TestNoRankingMechanism is a source-scanning structural gate: it walks every non-test .go file
// in this package and in internal/httpapi, strips comment lines (so a comment documenting a
// prohibition, e.g. "no field for a position, a total, ..." never trips the gate documenting it),
// and fails the build if a later edit introduces:
//
//  1. A ranking-shaped identifier or bare word: rank, score, leaderboard, position, or winner,
//     matched on a whole-word boundary so a legitimate identifier that merely contains one of
//     these as a substring (e.g. "disposition", which contains "position") is never a false
//     positive.
//  2. A SQL ordering or aggregate construct applied to the own-time column: an ORDER BY clause
//     whose target is own_time_seconds, or an aggregate function (SUM/AVG/MIN/MAX/COUNT/RANK/
//     ROW_NUMBER/DENSE_RANK) wrapped directly around own_time_seconds, found inside any raw
//     string (backtick-delimited) SQL query literal in either package.
//  3. A Go-level sort applied to OwnTimeSeconds (sort.Slice/sort.SliceStable naming
//     OwnTimeSeconds on the same source line) -- the Go-level equivalent of (2), in case a future
//     edit sorts completions in memory rather than in SQL.
//
// This is the enforcing gate behind docs/group-events.md §2's core promise: showing a time is not
// the same product decision as building a way to rank people by it, and Ritham makes only the
// first. GROUPEVENTS-02's must_haves truth is structural: "No query in this package orders,
// groups, ranks, or aggregates completions by time or by count."

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// rankingWordPattern matches a whole-word occurrence (case-insensitive) of any of the five
// ranking-shaped words this gate forbids in non-comment source. \b is Go regexp's standard word
// boundary (word chars are [0-9A-Za-z_]), so "disposition" never matches "position": there is no
// boundary between the 's' and 'p' that precede it.
var rankingWordPattern = regexp.MustCompile(`(?i)\b(rank|score|leaderboard|position|winner)\b`)

// backtickStringPattern extracts the content of every raw string literal (SQL query bodies, in
// this codebase's convention) in a source file.
var backtickStringPattern = regexp.MustCompile("(?s)`([^`]*)`")

// orderByOwnTimePattern matches an ORDER BY clause whose target includes own_time_seconds,
// anywhere later in the same raw string.
var orderByOwnTimePattern = regexp.MustCompile(`(?is)order\s+by[^;]*own_time_seconds`)

// aggregateOwnTimePattern matches an aggregate/ranking SQL function wrapped directly around
// own_time_seconds.
var aggregateOwnTimePattern = regexp.MustCompile(`(?i)(sum|avg|min|max|count|rank|row_number|dense_rank)\s*\(\s*[a-z0-9_.]*own_time_seconds`)

// goSortOwnTimePattern matches a Go-level sort.Slice/sort.SliceStable call whose same source line
// also names OwnTimeSeconds -- the in-memory equivalent of an ORDER BY on the own-time column.
var goSortOwnTimePattern = regexp.MustCompile(`(?i)sort\.(Slice|SliceStable).*OwnTimeSeconds|OwnTimeSeconds.*sort\.(Slice|SliceStable)`)

// scanDirs are this gate's two target directories, both reachable relative to this test file's
// own package directory (internal/events).
var scanDirs = []string{".", "../httpapi"}

func TestNoRankingMechanism(t *testing.T) {
	var scannedFiles int

	for _, dir := range scanDirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			t.Fatalf("reading directory %q: %v", dir, err)
		}

		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			name := entry.Name()
			if !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") {
				continue
			}

			path := filepath.Join(dir, name)
			raw, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("reading file %q: %v", path, err)
			}
			scannedFiles++

			checkNoRankingWords(t, path, string(raw))
			checkNoOwnTimeOrderingOrAggregate(t, path, string(raw))
		}
	}

	// This project already learned (per 03-10's own no-sharing structural gate precedent) that a
	// bare non-empty check lets a gate go silently vacuous when code relocates -- assert a real
	// floor instead.
	const minScannedFiles = 6
	if scannedFiles < minScannedFiles {
		t.Fatalf("scanned %d files, want at least %d -- this gate may have stopped walking a real directory", scannedFiles, minScannedFiles)
	}
	t.Logf("TestNoRankingMechanism scanned %d files across %v", scannedFiles, scanDirs)
}

// checkNoRankingWords strips comment lines from content and fails t if any remaining line
// contains a whole-word ranking-shaped identifier.
func checkNoRankingWords(t *testing.T, path, content string) {
	t.Helper()
	for i, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "//") {
			continue // a comment documenting a prohibition never trips the gate documenting it
		}
		// Strip a trailing line comment on an otherwise-real code line (e.g. `x := 1 // score`)
		// so a trailing comment doesn't trip the gate either.
		if idx := strings.Index(line, "//"); idx >= 0 {
			line = line[:idx]
		}
		if m := rankingWordPattern.FindString(line); m != "" {
			t.Errorf("%s:%d: found ranking-shaped word %q in non-comment source: %q", path, i+1, m, strings.TrimSpace(line))
		}
	}
}

// checkNoOwnTimeOrderingOrAggregate extracts every raw string (SQL query) literal and every
// non-comment source line from content, and fails t if own_time_seconds is ever ordered by or
// aggregated over in SQL, or sorted over in Go.
func checkNoOwnTimeOrderingOrAggregate(t *testing.T, path, content string) {
	t.Helper()

	for _, sql := range backtickStringPattern.FindAllStringSubmatch(content, -1) {
		body := sql[1]
		if !strings.Contains(strings.ToLower(body), "own_time_seconds") {
			continue
		}
		if orderByOwnTimePattern.MatchString(body) {
			t.Errorf("%s: SQL query orders by own_time_seconds: %q", path, body)
		}
		if aggregateOwnTimePattern.MatchString(body) {
			t.Errorf("%s: SQL query aggregates over own_time_seconds: %q", path, body)
		}
	}

	for i, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "//") {
			continue
		}
		if goSortOwnTimePattern.MatchString(line) {
			t.Errorf("%s:%d: Go-level sort applied to OwnTimeSeconds: %q", path, i+1, strings.TrimSpace(line))
		}
	}
}
