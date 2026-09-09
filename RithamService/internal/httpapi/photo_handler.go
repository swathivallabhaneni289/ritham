package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/photo"
)

// maxPhotoUploadBytes bounds the entire multipart request body for POST /v1/photos. It sits just
// above photo.maxUploadBytes (8 MiB) so a legitimate upload at that cap still fits once multipart
// boundary markers and part headers are added, while remaining a hard, explicit reject far below
// anything that could tie up the server (T-04.1-18). Deliberately NOT the pre-existing
// maxRequestBodyBytes (64 KiB) -- that bound is sized for a three-field JSON body and would 413
// every real photo upload.
const maxPhotoUploadBytes = 9 << 20

// maxMultipartMemory bounds how much of the parsed multipart form ParseMultipartForm holds in
// memory before spilling the rest to a temp file; sized to the same 8 MiB a legitimate upload
// needs, so no real photo forces a temp-file round trip.
const maxMultipartMemory = 8 << 20

// sharedURLTTL is how long a presigned shared-tier URL remains valid. Short-lived by design
// (T-04.1-20): every read mints a fresh URL rather than any URL being valid indefinitely.
const sharedURLTTL = 15 * time.Minute

// photoIngester is the minimal capability the photo handlers need from internal/photo.Service --
// a structural interface so photo_handler_test.go can substitute a stub with no database or
// object-storage backend, mirroring internal/httpapi/middleware.go's authenticator precedent and
// internal/photo/service.go's objectWriter precedent (both from this same phase).
type photoIngester interface {
	Ingest(ctx context.Context, ownerUserID uuid.UUID, raw []byte, declaredContentType string) (photo.Asset, error)
	Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (photo.Asset, error)
}

// sharedURLSigner is the minimal capability the photo handlers need from internal/photo.ObjectStore
// -- just enough to mint the presigned URL returned to the client, so tests never need a running
// S3-compatible backend.
type sharedURLSigner interface {
	SharedURL(ctx context.Context, key string, ttl time.Duration) (string, error)
}

// PhotoUploadResponse is returned by both POST /v1/photos and GET /v1/photos/{id}. It is declared
// here, alongside the handlers that produce it, rather than in contract.go -- contract.go stays
// scoped to the pre-existing locked workout-plan boundary and its own reflection test
// (04.1-RESEARCH.md Pitfall 4); this type has no such lock and does not belong in that file.
type PhotoUploadResponse struct {
	PhotoAssetID string `json:"photoAssetId"`
	SharedURL    string `json:"sharedUrl"`
}

// handleUploadPhoto reads a multipart form with exactly one part named "photo" and routes it
// through photo.Service.Ingest -- never touching object storage directly. This is what keeps the
// EXIF-strip pipeline unbypassable at the HTTP layer: there is no code path in this handler that
// can reach shared storage except through Ingest, which itself can only reach it through
// StripAndReencode's output.
func handleUploadPhoto(svc photoIngester, signer sharedURLSigner) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, maxPhotoUploadBytes)
		if err := r.ParseMultipartForm(maxMultipartMemory); err != nil {
			writeJSONError(w, http.StatusRequestEntityTooLarge, "upload too large")
			return
		}
		defer func() {
			if r.MultipartForm != nil {
				_ = r.MultipartForm.RemoveAll()
			}
		}()

		file, header, err := r.FormFile("photo")
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "missing \"photo\" form part")
			return
		}
		defer file.Close()

		raw, err := io.ReadAll(file)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "failed to read \"photo\" form part")
			return
		}

		asset, err := svc.Ingest(r.Context(), userID, raw, header.Header.Get("Content-Type"))
		if err != nil {
			writeJSONError(w, statusForPhotoError(err), photoErrorMessage(err))
			return
		}

		writePhotoUploadResponse(w, r, signer, asset)
	}
}

// handleFetchPhoto resolves the asset for the authenticated requester and returns a freshly
// presigned, short-lived shared URL -- never a cached or indefinitely valid one (T-04.1-20).
func handleFetchPhoto(svc photoIngester, signer sharedURLSigner) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		assetID, err := uuid.Parse(r.PathValue("id"))
		if err != nil {
			writeJSONError(w, http.StatusNotFound, photoErrorMessage(photo.ErrAssetNotFound))
			return
		}

		asset, err := svc.Asset(r.Context(), userID, assetID)
		if err != nil {
			writeJSONError(w, statusForPhotoError(err), photoErrorMessage(err))
			return
		}

		writePhotoUploadResponse(w, r, signer, asset)
	}
}

func writePhotoUploadResponse(w http.ResponseWriter, r *http.Request, signer sharedURLSigner, asset photo.Asset) {
	sharedURL, err := signer.SharedURL(r.Context(), asset.SharedKey, sharedURLTTL)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, "internal error")
		return
	}

	body, err := json.Marshal(PhotoUploadResponse{
		PhotoAssetID: asset.ID.String(),
		SharedURL:    sharedURL,
	})
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, "failed to encode response")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

// statusForPhotoError maps photo's exported sentinel errors to an HTTP status, mirroring
// statusForGenerateError/statusForIdentityError's pattern.
func statusForPhotoError(err error) int {
	switch {
	case errors.Is(err, photo.ErrUnsupportedFormat), errors.Is(err, photo.ErrDecodeFailed):
		return http.StatusUnsupportedMediaType
	case errors.Is(err, photo.ErrImageTooLarge):
		return http.StatusRequestEntityTooLarge
	case errors.Is(err, photo.ErrAssetNotFound):
		return http.StatusNotFound
	default:
		return http.StatusInternalServerError
	}
}

// photoErrorMessage returns a response body message for a photo error. ErrUnsupportedFormat gets
// a specific, actionable message so the client knows to transcode HEIC to JPEG before retrying --
// every other case gets a short, generic description; none of these leak internal detail.
func photoErrorMessage(err error) string {
	switch {
	case errors.Is(err, photo.ErrUnsupportedFormat):
		return "unsupported image format -- please convert HEIC/HEIF photos to JPEG before uploading"
	case errors.Is(err, photo.ErrDecodeFailed):
		return "could not decode image"
	case errors.Is(err, photo.ErrImageTooLarge):
		return "image too large"
	case errors.Is(err, photo.ErrAssetNotFound):
		return "photo not found"
	default:
		return "internal error"
	}
}
