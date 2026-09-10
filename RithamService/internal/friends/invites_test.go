package friends

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestCreateInvite_ReturnsTokenOnceAndStoresOnlyADigest(t *testing.T) {
	h := newTestHarness(t)
	issuer := createUser(t, h.store, "Issuer")

	invite, err := h.svc.CreateInvite(context.Background(), issuer)
	if err != nil {
		t.Fatalf("CreateInvite: unexpected error: %v", err)
	}
	if invite.Token == "" {
		t.Fatalf("CreateInvite: got empty Token")
	}
	if !invite.ExpiresAt.After(h.now()) {
		t.Errorf("CreateInvite: ExpiresAt %v is not after now %v", invite.ExpiresAt, h.now())
	}

	var tokenSHA256 []byte
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT token_sha256 FROM invite_tokens WHERE issuer_user_id = $1", issuer,
	).Scan(&tokenSHA256)
	if err != nil {
		t.Fatalf("querying invite_tokens row: %v", err)
	}
	if len(tokenSHA256) != 32 {
		t.Errorf("token_sha256 has %d bytes, want exactly 32 (a SHA-256 digest)", len(tokenSHA256))
	}
	if string(tokenSHA256) == invite.Token {
		t.Errorf("token_sha256 column literally equals the plaintext token")
	}
}

func TestRedeemInvite_ValidInviteCreatesRequestFromIssuerToRedeemerAndMarksConsumed(t *testing.T) {
	h := newTestHarness(t)
	issuer := createUser(t, h.store, "Issuer")
	redeemer := createUser(t, h.store, "Redeemer")

	invite, err := h.svc.CreateInvite(context.Background(), issuer)
	if err != nil {
		t.Fatalf("CreateInvite: unexpected error: %v", err)
	}

	req, err := h.svc.RedeemInvite(context.Background(), redeemer, invite.Token)
	if err != nil {
		t.Fatalf("RedeemInvite: unexpected error: %v", err)
	}
	if req.FromUserID != issuer || req.ToUserID != redeemer {
		t.Errorf("RedeemInvite: got request %+v, want FromUserID=%s ToUserID=%s", req, issuer, redeemer)
	}
	if req.ConnectionPath != PathInviteLink {
		t.Errorf("RedeemInvite: got ConnectionPath %q, want %q", req.ConnectionPath, PathInviteLink)
	}

	var consumedAt *time.Time
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT consumed_at FROM invite_tokens WHERE issuer_user_id = $1", issuer,
	).Scan(&consumedAt)
	if err != nil {
		t.Fatalf("querying invite_tokens row: %v", err)
	}
	if consumedAt == nil {
		t.Errorf("invite_tokens.consumed_at is nil after redemption, want set")
	}
}

func TestRedeemInvite_SecondRedemptionFailsWithConsumedSentinelAndCreatesNothing(t *testing.T) {
	h := newTestHarness(t)
	issuer := createUser(t, h.store, "Issuer")
	redeemer := createUser(t, h.store, "Redeemer")
	secondRedeemer := createUser(t, h.store, "SecondRedeemer")

	invite, err := h.svc.CreateInvite(context.Background(), issuer)
	if err != nil {
		t.Fatalf("CreateInvite: unexpected error: %v", err)
	}

	if _, err := h.svc.RedeemInvite(context.Background(), redeemer, invite.Token); err != nil {
		t.Fatalf("RedeemInvite (first): unexpected error: %v", err)
	}

	_, err = h.svc.RedeemInvite(context.Background(), secondRedeemer, invite.Token)
	if !errors.Is(err, ErrInviteConsumed) {
		t.Fatalf("RedeemInvite (second): got error %v, want ErrInviteConsumed", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM friend_requests WHERE to_user_id = $1", secondRedeemer,
	).Scan(&count)
	if err != nil {
		t.Fatalf("counting friend_requests rows: %v", err)
	}
	if count != 0 {
		t.Errorf("got %d friend_requests rows for the second (consumed) redemption, want 0", count)
	}
}

func TestRedeemInvite_ExpiredInviteFailsWithExpiredSentinelAgainstInjectedClock(t *testing.T) {
	h := newTestHarness(t)
	issuer := createUser(t, h.store, "Issuer")
	redeemer := createUser(t, h.store, "Redeemer")

	invite, err := h.svc.CreateInvite(context.Background(), issuer)
	if err != nil {
		t.Fatalf("CreateInvite: unexpected error: %v", err)
	}

	h.advance(inviteTTL + time.Hour)

	_, err = h.svc.RedeemInvite(context.Background(), redeemer, invite.Token)
	if !errors.Is(err, ErrInviteExpired) {
		t.Fatalf("RedeemInvite after expiry: got error %v, want ErrInviteExpired", err)
	}
}

func TestRedeemInvite_UnknownTokenFailsWithUnknownSentinel(t *testing.T) {
	h := newTestHarness(t)
	redeemer := createUser(t, h.store, "Redeemer")

	_, err := h.svc.RedeemInvite(context.Background(), redeemer, "this-token-was-never-issued-by-anyone")
	if !errors.Is(err, ErrInviteUnknown) {
		t.Fatalf("RedeemInvite for an unknown token: got error %v, want ErrInviteUnknown", err)
	}
}

func TestRedeemInvite_IssuerRedeemingOwnInviteFails(t *testing.T) {
	h := newTestHarness(t)
	issuer := createUser(t, h.store, "Issuer")

	invite, err := h.svc.CreateInvite(context.Background(), issuer)
	if err != nil {
		t.Fatalf("CreateInvite: unexpected error: %v", err)
	}

	_, err = h.svc.RedeemInvite(context.Background(), issuer, invite.Token)
	if !errors.Is(err, ErrInviteSelfRedeem) {
		t.Fatalf("RedeemInvite by the issuer themselves: got error %v, want ErrInviteSelfRedeem", err)
	}
}
