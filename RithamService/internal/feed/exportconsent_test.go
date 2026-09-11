package feed

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
)

// TestRequestExportConsent_OwnerOnly asserts only photoAssetID's real owner may call
// RequestExportConsent, and that a non-owner's attempt records nothing at all.
func TestRequestExportConsent_OwnerOnly(t *testing.T) {
	h := newTestHarness(t)
	owner := createUser(t, h.store, "Owner")
	notOwner := createUser(t, h.store, "NotOwner")
	subject := createUser(t, h.store, "Subject")
	photoID := createPhotoAsset(t, h.store, owner)

	if err := h.svc.RequestExportConsent(context.Background(), notOwner, photoID, []uuid.UUID{subject}); !errors.Is(err, ErrNotPhotoOwner) {
		t.Fatalf("RequestExportConsent(non-owner): got error %v, want ErrNotPhotoOwner", err)
	}

	gate, err := h.svc.ExportAllowed(context.Background(), owner, photoID)
	if err != nil {
		t.Fatalf("ExportAllowed: unexpected error: %v", err)
	}
	if !gate.Allowed || len(gate.AwaitingSubjectIDs) != 0 {
		t.Errorf("ExportAllowed after a rejected non-owner request = %+v, want Allowed=true, no awaiting subjects (nothing recorded)", gate)
	}

	if err := h.svc.RequestExportConsent(context.Background(), owner, photoID, []uuid.UUID{subject}); err != nil {
		t.Fatalf("RequestExportConsent(owner): unexpected error: %v", err)
	}
}

// TestGrantExportConsent_SubjectOnly asserts GrantExportConsent applies only to the exact subject
// named in the call -- a different user's own grant call does not open the gate on someone else's
// behalf.
func TestGrantExportConsent_SubjectOnly(t *testing.T) {
	h := newTestHarness(t)
	owner := createUser(t, h.store, "Owner")
	subject := createUser(t, h.store, "Subject")
	someoneElse := createUser(t, h.store, "SomeoneElse")
	photoID := createPhotoAsset(t, h.store, owner)

	if err := h.svc.RequestExportConsent(context.Background(), owner, photoID, []uuid.UUID{subject}); err != nil {
		t.Fatalf("RequestExportConsent: unexpected error: %v", err)
	}

	if err := h.svc.GrantExportConsent(context.Background(), someoneElse, photoID); !errors.Is(err, ErrExportConsentMissing) {
		t.Fatalf("GrantExportConsent(wrong subject): got error %v, want ErrExportConsentMissing (no pending row for someoneElse)", err)
	}

	if err := h.svc.GrantExportConsent(context.Background(), subject, photoID); err != nil {
		t.Fatalf("GrantExportConsent(real subject): unexpected error: %v", err)
	}

	gate, err := h.svc.ExportAllowed(context.Background(), owner, photoID)
	if err != nil {
		t.Fatalf("ExportAllowed: unexpected error: %v", err)
	}
	if !gate.Allowed {
		t.Errorf("ExportAllowed after the real subject granted = %+v, want Allowed=true", gate)
	}
}

// TestExportAllowed_PartialGrantsLeaveGateClosed requests consent from two subjects, grants only
// one, and asserts the gate stays closed and names the still-outstanding subject.
func TestExportAllowed_PartialGrantsLeaveGateClosed(t *testing.T) {
	h := newTestHarness(t)
	owner := createUser(t, h.store, "Owner")
	subjectA := createUser(t, h.store, "SubjectA")
	subjectB := createUser(t, h.store, "SubjectB")
	photoID := createPhotoAsset(t, h.store, owner)

	if err := h.svc.RequestExportConsent(context.Background(), owner, photoID, []uuid.UUID{subjectA, subjectB}); err != nil {
		t.Fatalf("RequestExportConsent: unexpected error: %v", err)
	}
	if err := h.svc.GrantExportConsent(context.Background(), subjectA, photoID); err != nil {
		t.Fatalf("GrantExportConsent(subjectA): unexpected error: %v", err)
	}

	gate, err := h.svc.ExportAllowed(context.Background(), owner, photoID)
	if err != nil {
		t.Fatalf("ExportAllowed: unexpected error: %v", err)
	}
	if gate.Allowed {
		t.Fatal("ExportAllowed.Allowed = true, want false -- subjectB has not yet granted")
	}
	if len(gate.AwaitingSubjectIDs) != 1 || gate.AwaitingSubjectIDs[0] != subjectB {
		t.Errorf("AwaitingSubjectIDs = %v, want exactly [%s]", gate.AwaitingSubjectIDs, subjectB)
	}
}

// TestExportAllowed_FullGrantsOpenGate requests consent from two subjects, has both grant, and
// asserts the gate opens.
func TestExportAllowed_FullGrantsOpenGate(t *testing.T) {
	h := newTestHarness(t)
	owner := createUser(t, h.store, "Owner")
	subjectA := createUser(t, h.store, "SubjectA")
	subjectB := createUser(t, h.store, "SubjectB")
	photoID := createPhotoAsset(t, h.store, owner)

	if err := h.svc.RequestExportConsent(context.Background(), owner, photoID, []uuid.UUID{subjectA, subjectB}); err != nil {
		t.Fatalf("RequestExportConsent: unexpected error: %v", err)
	}
	if err := h.svc.GrantExportConsent(context.Background(), subjectA, photoID); err != nil {
		t.Fatalf("GrantExportConsent(subjectA): unexpected error: %v", err)
	}
	if err := h.svc.GrantExportConsent(context.Background(), subjectB, photoID); err != nil {
		t.Fatalf("GrantExportConsent(subjectB): unexpected error: %v", err)
	}

	gate, err := h.svc.ExportAllowed(context.Background(), owner, photoID)
	if err != nil {
		t.Fatalf("ExportAllowed: unexpected error: %v", err)
	}
	if !gate.Allowed || len(gate.AwaitingSubjectIDs) != 0 {
		t.Errorf("ExportAllowed after both subjects granted = %+v, want Allowed=true, no awaiting subjects", gate)
	}
}

// TestExportAllowed_BystanderDenied asserts CR-01's fix: a caller who is neither the photo's
// owner nor one of its recorded subjects -- including a group member who can see the photo's
// completion but has no stake in the photo itself, and a former group member who has since left
// -- cannot learn the export-consent status (in particular, cannot enumerate which specific users
// have not yet granted consent). Both get ErrNotPhotoOwner, matching every other non-owner path in
// this file, mapped to 403 by statusForFeedError -- never the actual consent data.
func TestExportAllowed_BystanderDenied(t *testing.T) {
	h := newTestHarness(t)
	owner := createUser(t, h.store, "Owner")
	subject := createUser(t, h.store, "Subject")
	bystander := createUser(t, h.store, "Bystander")
	formerSubject := createUser(t, h.store, "FormerSubject")
	photoID := createPhotoAsset(t, h.store, owner)

	if err := h.svc.RequestExportConsent(context.Background(), owner, photoID, []uuid.UUID{subject}); err != nil {
		t.Fatalf("RequestExportConsent: unexpected error: %v", err)
	}

	if _, err := h.svc.ExportAllowed(context.Background(), bystander, photoID); !errors.Is(err, ErrNotPhotoOwner) {
		t.Fatalf("ExportAllowed(bystander): got error %v, want ErrNotPhotoOwner", err)
	}

	// A user who was never recorded as owner or subject at all -- standing in for a departed group
	// member reachable via events.Completions -- is denied identically, with no membership check
	// of any kind involved (there is nothing for one to gate on: recorded-subject status is the
	// only durable grant this file makes).
	if _, err := h.svc.ExportAllowed(context.Background(), formerSubject, photoID); !errors.Is(err, ErrNotPhotoOwner) {
		t.Fatalf("ExportAllowed(never-recorded caller): got error %v, want ErrNotPhotoOwner", err)
	}

	// Sanity: the real subject and owner are still let through, unaffected by the new check.
	if _, err := h.svc.ExportAllowed(context.Background(), subject, photoID); err != nil {
		t.Fatalf("ExportAllowed(recorded subject): unexpected error: %v", err)
	}
	if _, err := h.svc.ExportAllowed(context.Background(), owner, photoID); err != nil {
		t.Fatalf("ExportAllowed(owner): unexpected error: %v", err)
	}
}

// TestExportAllowed_NoSubjectsRecordedIsAllowedImmediately asserts a photo with no recorded
// subjects (the default badge template case, or a solo shot) is allowed immediately -- no request
// was ever made.
func TestExportAllowed_NoSubjectsRecordedIsAllowedImmediately(t *testing.T) {
	h := newTestHarness(t)
	owner := createUser(t, h.store, "Owner")
	photoID := createPhotoAsset(t, h.store, owner)

	gate, err := h.svc.ExportAllowed(context.Background(), owner, photoID)
	if err != nil {
		t.Fatalf("ExportAllowed: unexpected error: %v", err)
	}
	if !gate.Allowed || len(gate.AwaitingSubjectIDs) != 0 {
		t.Errorf("ExportAllowed(no subjects recorded) = %+v, want Allowed=true, no awaiting subjects", gate)
	}
}
