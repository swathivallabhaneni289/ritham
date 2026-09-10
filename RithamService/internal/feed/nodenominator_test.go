package feed

// TestNoDenominatorOrRanking is a structural gate with two halves, mirroring
// internal/events/noranking_test.go's own precedent for this codebase's ranking-shaped surface.
//
// Half 1 (TestPageJSONKeySet): serializes a fully populated Page to JSON and asserts the resulting
// key set exactly matches an explicit expected list. feed.Page/feed.Item ARE this plan's wire
// contract -- feed_handler.go encodes them directly, never through a second translation struct --
// so pinning this package's own JSON output IS pinning the wire shape. A future field addition
// anywhere in Page's reachable struct graph fails this test rather than shipping silently. This
// test lives in package feed (not internal/httpapi) because internal/httpapi imports internal/feed
// -- the reverse import does not exist, so the wire-shape assertion has to live on this side.
//
// Half 2 (TestNoDenominatorOrRanking): walks every non-test .go file in this package and in
// internal/httpapi, strips comment lines, and fails the build if a later edit introduces a
// denominator/ranking-shaped identifier in non-comment source. It reuses internal/events'
// established ranking-word list (rank/score/leaderboard/position/winner) and adds this plan's own
// denominator-shaped words (total/denominator/fraction/percent), plus compound forms of "count"
// that would themselves be a completion-measuring aggregate this plan is specifically about
// (completionCount/completion_count, cheerCount/cheer_count) -- deliberately NOT a bare \bcount\b
// and NOT memberCount/member_count: internal/httpapi's own RSVPStateResponse.Count (plan 04.1-10,
// a legitimate pre-event headcount) and GroupDetailResponse.MemberCount (plan 04.1-08, a group
// roster size) are both already-shipped figures docs/group-events.md §2 explicitly permits, and
// this gate must not trip on code it doesn't own.

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

// TestPageJSONKeySet is Half 1 -- see this file's header comment.
func TestPageJSONKeySet(t *testing.T) {
	ownTime := 1800
	photoURL := "https://example.com/photo.jpg"
	placeName := "Riverside Park"
	caption := "Great walk!"

	page := Page{
		Items: []Item{
			{
				CompletionID:   uuid.New(),
				Actor:          Person{UserID: uuid.New(), DisplayName: "Someone"},
				EventID:        uuid.New(),
				EventName:      "Saturday 5K Walk",
				ActivityType:   "walk",
				CompletedAt:    time.Now(),
				OwnTimeSeconds: &ownTime,
				PhotoURL:       &photoURL,
				PlaceName:      &placeName,
				Caption:        &caption,
				PostedAt:       time.Now(),
				Cheers:         ViewerCheers{NiceWorkSentByViewer: true, KeepGoingSentByViewer: true},
			},
		},
		NextCursor: "some-opaque-cursor",
	}

	body, err := json.Marshal(page)
	if err != nil {
		t.Fatalf("json.Marshal(Page): unexpected error: %v", err)
	}

	var decoded map[string]json.RawMessage
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("json.Unmarshal(top level): unexpected error: %v", err)
	}
	assertExactKeySet(t, "Page", decoded, []string{"items", "nextCursor"})

	var items []map[string]json.RawMessage
	if err := json.Unmarshal(decoded["items"], &items); err != nil {
		t.Fatalf("json.Unmarshal(items): unexpected error: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("len(items) = %d, want 1", len(items))
	}
	assertExactKeySet(t, "Item", items[0], []string{
		"completionId", "actor", "eventId", "eventName", "activityType", "completedAt",
		"ownTimeSeconds", "photoUrl", "placeName", "caption", "postedAt", "cheers",
	})

	var actor map[string]json.RawMessage
	if err := json.Unmarshal(items[0]["actor"], &actor); err != nil {
		t.Fatalf("json.Unmarshal(actor): unexpected error: %v", err)
	}
	assertExactKeySet(t, "Person", actor, []string{"userId", "displayName"})

	var cheers map[string]json.RawMessage
	if err := json.Unmarshal(items[0]["cheers"], &cheers); err != nil {
		t.Fatalf("json.Unmarshal(cheers): unexpected error: %v", err)
	}
	assertExactKeySet(t, "ViewerCheers", cheers, []string{"niceWorkSentByViewer", "keepGoingSentByViewer"})
}

func assertExactKeySet(t *testing.T, label string, obj map[string]json.RawMessage, want []string) {
	t.Helper()
	got := make([]string, 0, len(obj))
	for k := range obj {
		got = append(got, k)
	}
	sort.Strings(got)
	wantSorted := append([]string(nil), want...)
	sort.Strings(wantSorted)
	if !reflect.DeepEqual(got, wantSorted) {
		t.Errorf("%s JSON key set = %v, want exactly %v", label, got, wantSorted)
	}
}

// denominatorWordPattern matches a whole-word occurrence (case-insensitive) of any ranking- or
// denominator-shaped bare word this gate forbids in non-comment source, plus the compound
// "count" identifiers that would themselves be an aggregate figure. It deliberately does NOT
// include a bare \bcount\b -- internal/httpapi's RSVPStateResponse.Count (04.1-10) is a legitimate
// pre-event headcount this gate must not trip on.
var denominatorWordPattern = regexp.MustCompile(
	`(?i)\b(rank|score|leaderboard|position|winner|total|denominator|fraction|percent)\b|` +
		`completion_count|completionCount|cheer_count|cheerCount`,
)

// aggregateSQLPattern matches a SQL aggregate/window function call anywhere inside a raw string
// (backtick-delimited) literal -- this package's and httpapi's convention for SQL query bodies.
var aggregateSQLPattern = regexp.MustCompile(`(?i)\b(sum|avg|count|rank|row_number|dense_rank)\s*\(`)

var backtickStringPattern = regexp.MustCompile("(?s)`([^`]*)`")

// scanDirs are this gate's two target directories, both reachable relative to this test file's
// own package directory (internal/feed).
var scanDirs = []string{".", "../httpapi"}

// TestNoDenominatorOrRanking is Half 2 -- see this file's header comment.
func TestNoDenominatorOrRanking(t *testing.T) {
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

			checkNoDenominatorWords(t, path, string(raw))
			checkNoAggregateSQL(t, path, string(raw))
		}
	}

	// A bare non-empty check lets a gate go silently vacuous when code relocates (this
	// codebase's own established lesson -- see internal/events/noranking_test.go and
	// internal/momentum's 03-10 precedent) -- assert a real floor instead.
	const minScannedFiles = 6
	if scannedFiles < minScannedFiles {
		t.Fatalf("scanned %d files, want at least %d -- this gate may have stopped walking a real directory", scannedFiles, minScannedFiles)
	}
	t.Logf("TestNoDenominatorOrRanking scanned %d files across %v", scannedFiles, scanDirs)
}

func checkNoDenominatorWords(t *testing.T, path, content string) {
	t.Helper()
	for i, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "//") {
			continue // a comment documenting a prohibition never trips the gate documenting it
		}
		if idx := strings.Index(line, "//"); idx >= 0 {
			line = line[:idx]
		}
		if m := denominatorWordPattern.FindString(line); m != "" {
			t.Errorf("%s:%d: found denominator/ranking-shaped word %q in non-comment source: %q", path, i+1, m, strings.TrimSpace(line))
		}
	}
}

func checkNoAggregateSQL(t *testing.T, path, content string) {
	t.Helper()
	for _, sql := range backtickStringPattern.FindAllStringSubmatch(content, -1) {
		body := sql[1]
		if m := aggregateSQLPattern.FindString(body); m != "" {
			t.Errorf("%s: SQL query contains an aggregate/ranking function %q: %q", path, m, body)
		}
	}
}
