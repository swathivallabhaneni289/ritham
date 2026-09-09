package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/photo"
)

// stubPhotoIngester lets the photo handler tests exercise every response-shaping branch (200,
// 415, 413, 404) with no database and no object-storage backend, mirroring
// middleware_test.go's stubAuthenticator precedent.
type stubPhotoIngester struct {
	ingestAsset photo.Asset
	ingestErr   error
	assetAsset  photo.Asset
	assetErr    error

	lastIngestOwner uuid.UUID
	lastIngestRaw   []byte
}

func (s *stubPhotoIngester) Ingest(ctx context.Context, ownerUserID uuid.UUID, raw []byte, declaredContentType string) (photo.Asset, error) {
	s.lastIngestOwner = ownerUserID
	s.lastIngestRaw = raw
	return s.ingestAsset, s.ingestErr
}

func (s *stubPhotoIngester) Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (photo.Asset, error) {
	return s.assetAsset, s.assetErr
}

// stubSharedURLSigner is a no-network sharedURLSigner.
type stubSharedURLSigner struct {
	url string
	err error
}

func (s stubSharedURLSigner) SharedURL(ctx context.Context, key string, ttl time.Duration) (string, error) {
	return s.url, s.err
}

// multipartPhotoRequest builds a POST /v1/photos-shaped request with exactly one "photo" form
// part carrying content.
func multipartPhotoRequest(t *testing.T, content []byte) *http.Request {
	t.Helper()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	part, err := w.CreateFormFile("photo", "upload.jpg")
	if err != nil {
		t.Fatalf("CreateFormFile: %v", err)
	}
	if _, err := part.Write(content); err != nil {
		t.Fatalf("write photo part: %v", err)
	}
	if err := w.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/v1/photos", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	return req
}

func TestHandleUploadPhoto_UnauthenticatedReturns401(t *testing.T) {
	svc := &stubPhotoIngester{}
	signer := stubSharedURLSigner{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleUploadPhoto(svc, signer))

	req := multipartPhotoRequest(t, []byte("fake photo bytes"))
	// Deliberately no Authorization header.
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("got status %d, want 401 (no Authorization header)", rec.Code)
	}
	if svc.lastIngestRaw != nil {
		t.Error("Ingest must not be reached when authentication fails")
	}
}

func TestHandleUploadPhoto_ValidUploadReturns200WithAssetID(t *testing.T) {
	assetID := uuid.New()
	userID := uuid.New()
	svc := &stubPhotoIngester{ingestAsset: photo.Asset{ID: assetID, OwnerUserID: userID, SharedKey: "shared-key-1"}}
	signer := stubSharedURLSigner{url: "https://example.test/signed-url"}
	auth := stubAuthenticator{userID: userID}
	handler := RequireSession(auth, handleUploadPhoto(svc, signer))

	req := multipartPhotoRequest(t, []byte("fake photo bytes"))
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200; body: %s", rec.Code, rec.Body.String())
	}
	var resp PhotoUploadResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.PhotoAssetID != assetID.String() {
		t.Errorf("PhotoAssetID = %q, want %q", resp.PhotoAssetID, assetID.String())
	}
	if resp.SharedURL != "https://example.test/signed-url" {
		t.Errorf("SharedURL = %q, want the presigned URL", resp.SharedURL)
	}
	if svc.lastIngestOwner != userID {
		t.Errorf("Ingest called with owner %v, want authenticated user %v", svc.lastIngestOwner, userID)
	}
}

func TestHandleUploadPhoto_UnsupportedFormatReturns415WithTranscodeGuidance(t *testing.T) {
	svc := &stubPhotoIngester{ingestErr: photo.ErrUnsupportedFormat}
	signer := stubSharedURLSigner{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleUploadPhoto(svc, signer))

	req := multipartPhotoRequest(t, []byte("heic-shaped bytes"))
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("got status %d, want 415", rec.Code)
	}
	if !strings.Contains(strings.ToUpper(rec.Body.String()), "HEIC") {
		t.Errorf("body %q does not mention HEIC transcode guidance", rec.Body.String())
	}
}

func TestHandleUploadPhoto_OversizedBodyReturns413(t *testing.T) {
	svc := &stubPhotoIngester{}
	signer := stubSharedURLSigner{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleUploadPhoto(svc, signer))

	oversized := make([]byte, maxPhotoUploadBytes+1)
	req := multipartPhotoRequest(t, oversized)
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Fatalf("got status %d, want 413", rec.Code)
	}
	if svc.lastIngestRaw != nil {
		t.Error("Ingest must not be reached when the request body exceeds the photo upload cap")
	}
}

func TestHandleFetchPhoto_AnotherUsersAssetReturns404(t *testing.T) {
	svc := &stubPhotoIngester{assetErr: photo.ErrAssetNotFound}
	signer := stubSharedURLSigner{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleFetchPhoto(svc, signer))

	assetID := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/v1/photos/"+assetID.String(), nil)
	req.SetPathValue("id", assetID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("got status %d, want 404", rec.Code)
	}
}

func TestHandleFetchPhoto_ValidRequestReturns200WithFreshSignedURL(t *testing.T) {
	assetID := uuid.New()
	userID := uuid.New()
	svc := &stubPhotoIngester{assetAsset: photo.Asset{ID: assetID, OwnerUserID: userID, SharedKey: "shared-key-2"}}
	signer := stubSharedURLSigner{url: "https://example.test/fresh-signed-url"}
	auth := stubAuthenticator{userID: userID}
	handler := RequireSession(auth, handleFetchPhoto(svc, signer))

	req := httptest.NewRequest(http.MethodGet, "/v1/photos/"+assetID.String(), nil)
	req.SetPathValue("id", assetID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200; body: %s", rec.Code, rec.Body.String())
	}
	var resp PhotoUploadResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.SharedURL != "https://example.test/fresh-signed-url" {
		t.Errorf("SharedURL = %q, want the freshly presigned URL", resp.SharedURL)
	}
}
