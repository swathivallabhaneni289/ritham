package events

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/photo"
)

// stubPhotoChecker is a controllable PhotoOwnershipChecker double: owned records which
// (requesterUserID, assetID) pairs should succeed, everything else fails with
// photo.ErrAssetNotFound -- mirroring that sentinel's own doc comment ("deliberately the
// identical error whether the id doesn't exist at all or exists but belongs to a different
// user"), so completions_test.go never needs a real object store or S3-compatible backend.
type stubPhotoChecker struct {
	owned map[[2]uuid.UUID]bool
}

func newStubPhotoChecker() *stubPhotoChecker {
	return &stubPhotoChecker{owned: map[[2]uuid.UUID]bool{}}
}

func (s *stubPhotoChecker) grant(userID, assetID uuid.UUID) {
	s.owned[[2]uuid.UUID{userID, assetID}] = true
}

func (s *stubPhotoChecker) Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (photo.Asset, error) {
	if s.owned[[2]uuid.UUID{requesterUserID, assetID}] {
		return photo.Asset{ID: assetID, OwnerUserID: requesterUserID}, nil
	}
	return photo.Asset{}, photo.ErrAssetNotFound
}

// newTestHarnessWithPhotoChecker builds the standard testHarness and additionally wires checker
// as the events Service's PhotoOwnershipChecker, mirroring groups.Service's
// SetCompletionVisibility construction-time-optional-dependency precedent.
func newTestHarnessWithPhotoChecker(t *testing.T, checker PhotoOwnershipChecker) *testHarness {
	t.Helper()
	h := newTestHarness(t)
	h.svc.SetPhotoOwnershipChecker(checker)
	return h
}

func TestCompletion_LogsWithOnlyATimestamp(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	c, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime()})
	if err != nil {
		t.Fatalf("LogCompletion(timestamp only): unexpected error: %v", err)
	}
	if c.OwnTimeSeconds != nil || c.PhotoAssetID != nil || c.PlaceName != nil || c.Caption != nil {
		t.Errorf("completion with only a timestamp = %+v, want every optional field nil", c)
	}
}

func TestCompletion_OwnTimeStoredAndReturnedOtherwiseIdenticalShape(t *testing.T) {
	h := newTestHarness(t)
	organizerA := createUser(t, h.store, "OrganizerA")
	organizerB := createUser(t, h.store, "OrganizerB")
	groupA := createGroup(t, h, organizerA)
	groupB := createGroup(t, h, organizerB)
	eventA := createEvent(t, h, groupA, organizerA)
	eventB := createEvent(t, h, groupB, organizerB)

	ownTime := 1934
	withTime, err := h.svc.LogCompletion(context.Background(), organizerA, eventA, NewCompletion{CompletedAt: validCompletionTime(), OwnTimeSeconds: &ownTime})
	if err != nil {
		t.Fatalf("LogCompletion(with own time): unexpected error: %v", err)
	}
	if withTime.OwnTimeSeconds == nil || *withTime.OwnTimeSeconds != ownTime {
		t.Fatalf("OwnTimeSeconds = %v, want %d", withTime.OwnTimeSeconds, ownTime)
	}

	withoutTime, err := h.svc.LogCompletion(context.Background(), organizerB, eventB, NewCompletion{CompletedAt: validCompletionTime()})
	if err != nil {
		t.Fatalf("LogCompletion(without own time): unexpected error: %v", err)
	}
	if withoutTime.OwnTimeSeconds != nil {
		t.Fatalf("OwnTimeSeconds = %v, want nil", withoutTime.OwnTimeSeconds)
	}

	// Byte-identical in shape apart from the own-time field: same set of populated/nil fields
	// otherwise.
	if withTime.PhotoAssetID != nil || withoutTime.PhotoAssetID != nil {
		t.Errorf("PhotoAssetID should be nil on both: with=%v without=%v", withTime.PhotoAssetID, withoutTime.PhotoAssetID)
	}
	if withTime.PlaceName != nil || withoutTime.PlaceName != nil {
		t.Errorf("PlaceName should be nil on both: with=%v without=%v", withTime.PlaceName, withoutTime.PlaceName)
	}
	if withTime.Caption != nil || withoutTime.Caption != nil {
		t.Errorf("Caption should be nil on both: with=%v without=%v", withTime.Caption, withoutTime.Caption)
	}
}

func TestCompletion_SecondCompletionForSamePersonIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime()}); err != nil {
		t.Fatalf("LogCompletion (first): unexpected error: %v", err)
	}
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime()}); !errors.Is(err, ErrAlreadyCompleted) {
		t.Fatalf("LogCompletion (second, same person+event): got error %v, want ErrAlreadyCompleted", err)
	}

	list, err := h.svc.Completions(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("Completions: unexpected error: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("completions after a rejected duplicate = %d, want 1 (not duplicated)", len(list))
	}
}

func TestCompletion_ReferencingUnownedPhotoAssetIsRejectedAndStoresNothing(t *testing.T) {
	checker := newStubPhotoChecker()
	h := newTestHarnessWithPhotoChecker(t, checker)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	someoneElsesAsset := uuid.New() // never granted to organizer
	_, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{
		CompletedAt:  validCompletionTime(),
		PhotoAssetID: &someoneElsesAsset,
	})
	if !errors.Is(err, ErrPhotoNotOwned) {
		t.Fatalf("LogCompletion(unowned photo asset): got error %v, want ErrPhotoNotOwned", err)
	}

	list, err := h.svc.Completions(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("Completions: unexpected error: %v", err)
	}
	if len(list) != 0 {
		t.Errorf("completions after a rejected photo reference = %d, want 0 (stores nothing)", len(list))
	}
}

func TestCompletion_ReferencingOwnedPhotoAssetSucceeds(t *testing.T) {
	checker := newStubPhotoChecker()
	h := newTestHarnessWithPhotoChecker(t, checker)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	ownedAsset := createPhotoAsset(t, h.store, organizer)
	checker.grant(organizer, ownedAsset)

	c, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{
		CompletedAt:  validCompletionTime(),
		PhotoAssetID: &ownedAsset,
	})
	if err != nil {
		t.Fatalf("LogCompletion(owned photo asset): unexpected error: %v", err)
	}
	if c.PhotoAssetID == nil || *c.PhotoAssetID != ownedAsset {
		t.Errorf("PhotoAssetID = %v, want %s", c.PhotoAssetID, ownedAsset)
	}
}

func TestCompletion_OutsideEventWindowIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer) // window: 2026-09-12 (single day, per validEvent())

	tooEarly := time.Date(2026, 9, 10, 12, 0, 0, 0, time.UTC)
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: tooEarly}); !errors.Is(err, ErrOutsideEventWindow) {
		t.Fatalf("LogCompletion(before window): got error %v, want ErrOutsideEventWindow", err)
	}

	tooLate := time.Date(2026, 9, 14, 12, 0, 0, 0, time.UTC)
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: tooLate}); !errors.Is(err, ErrOutsideEventWindow) {
		t.Fatalf("LogCompletion(after window): got error %v, want ErrOutsideEventWindow", err)
	}
}

func TestCompletion_WithinSingleDayWindowSucceeds(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer) // window: 2026-09-12 (single day)

	withinWindow := time.Date(2026, 9, 12, 23, 30, 0, 0, time.UTC)
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: withinWindow}); err != nil {
		t.Fatalf("LogCompletion(within single-day window): unexpected error: %v -- ends_on == starts_on must still accept a completion posted late that same day", err)
	}
}

func TestCompletion_CaptionOverBoundIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	caption := strings.Repeat("a", 281)
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime(), Caption: &caption}); !errors.Is(err, ErrCaptionTooLong) {
		t.Fatalf("LogCompletion(over-length caption): got error %v, want ErrCaptionTooLong", err)
	}
}

func TestCompletion_PlaceNameOverBoundIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	place := strings.Repeat("a", 121)
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime(), PlaceName: &place}); !errors.Is(err, ErrPlaceNameTooLong) {
		t.Fatalf("LogCompletion(over-length place name): got error %v, want ErrPlaceNameTooLong", err)
	}
}

func TestCompletion_OwnTimeOutsideAcceptedRangeIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	negative := -1
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime(), OwnTimeSeconds: &negative}); !errors.Is(err, ErrInvalidOwnTime) {
		t.Fatalf("LogCompletion(negative own time): got error %v, want ErrInvalidOwnTime", err)
	}

	tooLarge := 24*60*60 + 1
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime(), OwnTimeSeconds: &tooLarge}); !errors.Is(err, ErrInvalidOwnTime) {
		t.Fatalf("LogCompletion(own time over 24h): got error %v, want ErrInvalidOwnTime", err)
	}
}

// TestCompletion_ListingOrdersByPostTimeOnlyNeverByOwnTime constructs three completions whose own
// times run opposite to their post times, and asserts the returned order follows post time --
// this test would fail under a time-based sort, which is the point.
func TestCompletion_ListingOrdersByPostTimeOnlyNeverByOwnTime(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	memberA := createUser(t, h.store, "MemberA")
	memberB := createUser(t, h.store, "MemberB")
	groupID := createGroup(t, h, organizer)
	addMember(t, h, groupID, organizer, memberA)
	addMember(t, h, groupID, organizer, memberB)
	eventID := createEvent(t, h, groupID, organizer)

	// Posted first, slowest own time (highest number).
	h.clock = time.Date(2026, 9, 12, 8, 0, 0, 0, time.UTC)
	slowest := 3600
	if _, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime(), OwnTimeSeconds: &slowest}); err != nil {
		t.Fatalf("LogCompletion(organizer, posted first): unexpected error: %v", err)
	}

	// Posted second, middle own time.
	h.clock = time.Date(2026, 9, 12, 9, 0, 0, 0, time.UTC)
	middle := 2400
	if _, err := h.svc.LogCompletion(context.Background(), memberA, eventID, NewCompletion{CompletedAt: validCompletionTime(), OwnTimeSeconds: &middle}); err != nil {
		t.Fatalf("LogCompletion(memberA, posted second): unexpected error: %v", err)
	}

	// Posted third (last), fastest own time (lowest number) -- if the query ever sorted by
	// own time, this completion (fastest) would appear first; it must appear last.
	h.clock = time.Date(2026, 9, 12, 10, 0, 0, 0, time.UTC)
	fastest := 1200
	if _, err := h.svc.LogCompletion(context.Background(), memberB, eventID, NewCompletion{CompletedAt: validCompletionTime(), OwnTimeSeconds: &fastest}); err != nil {
		t.Fatalf("LogCompletion(memberB, posted third): unexpected error: %v", err)
	}

	list, err := h.svc.Completions(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("Completions: unexpected error: %v", err)
	}
	if len(list) != 3 {
		t.Fatalf("len(completions) = %d, want 3", len(list))
	}
	wantOrder := []uuid.UUID{organizer, memberA, memberB}
	for i, want := range wantOrder {
		if list[i].User.UserID != want {
			t.Errorf("completions[%d].User.UserID = %s, want %s (post-time order, not own-time order)", i, list[i].User.UserID, want)
		}
	}
}

func TestCompletion_ListingReturnsOnlyGroupVisibleRows(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	c, err := h.svc.LogCompletion(context.Background(), organizer, eventID, NewCompletion{CompletedAt: validCompletionTime()})
	if err != nil {
		t.Fatalf("LogCompletion: unexpected error: %v", err)
	}

	_, err = h.store.Pool().Exec(context.Background(),
		"UPDATE event_completions SET group_visible = false WHERE id = $1", c.ID)
	if err != nil {
		t.Fatalf("hiding completion directly: %v", err)
	}

	list, err := h.svc.Completions(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("Completions: unexpected error: %v", err)
	}
	if len(list) != 0 {
		t.Errorf("completions after hiding the only row = %d, want 0 (group_visible = false excluded)", len(list))
	}
}

// TestCompletion_LeaverDispositionControlsListedVisibility exercises the real, wired
// CompletionVisibility implementation end to end: a member who leaves with the remove-posts
// disposition has their completions excluded from Completions; one who leaves with keep still
// appears.
func TestCompletion_LeaverDispositionControlsListedVisibility(t *testing.T) {
	h := newTestHarness(t)
	h.groupsvc.SetCompletionVisibility(NewCompletionVisibility())

	organizer := createUser(t, h.store, "Organizer")
	keeper := createUser(t, h.store, "Keeper")
	remover := createUser(t, h.store, "Remover")
	groupID := createGroup(t, h, organizer)
	addMember(t, h, groupID, organizer, keeper)
	addMember(t, h, groupID, organizer, remover)
	eventID := createEvent(t, h, groupID, organizer)

	if _, err := h.svc.LogCompletion(context.Background(), keeper, eventID, NewCompletion{CompletedAt: validCompletionTime()}); err != nil {
		t.Fatalf("LogCompletion(keeper): unexpected error: %v", err)
	}
	if _, err := h.svc.LogCompletion(context.Background(), remover, eventID, NewCompletion{CompletedAt: validCompletionTime()}); err != nil {
		t.Fatalf("LogCompletion(remover): unexpected error: %v", err)
	}

	if err := h.groupsvc.Leave(context.Background(), keeper, groupID, groups.DispositionKeepPosts); err != nil {
		t.Fatalf("Leave(keeper, keepPosts): unexpected error: %v", err)
	}
	if err := h.groupsvc.Leave(context.Background(), remover, groupID, groups.DispositionRemovePosts); err != nil {
		t.Fatalf("Leave(remover, removePosts): unexpected error: %v", err)
	}

	list, err := h.svc.Completions(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("Completions: unexpected error: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("len(completions) after keep+remove leaves = %d, want 1", len(list))
	}
	if list[0].User.UserID != keeper {
		t.Errorf("remaining completion belongs to %s, want the keep-disposition leaver %s", list[0].User.UserID, keeper)
	}
}

// TestCompletion_StructHasNoPositionTotalOrCompletedCountField exhaustively examines Completion's
// field set.
func TestCompletion_StructHasNoPositionTotalOrCompletedCountField(t *testing.T) {
	typ := reflect.TypeOf(Completion{})
	wantFields := map[string]bool{
		"ID": true, "EventID": true, "User": true, "CompletedAt": true,
		"OwnTimeSeconds": true, "PhotoAssetID": true, "PlaceName": true, "Caption": true, "PostedAt": true,
	}
	if typ.NumField() != len(wantFields) {
		t.Fatalf("Completion has %d fields, want exactly %d", typ.NumField(), len(wantFields))
	}
	for i := 0; i < typ.NumField(); i++ {
		name := typ.Field(i).Name
		if !wantFields[name] {
			t.Errorf("unexpected Completion field %q -- must have no position, total, or completed-count field", name)
		}
	}
}
