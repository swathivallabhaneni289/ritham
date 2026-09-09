// Package photo is the server-side photo pipeline whose whole purpose is that a shared or
// exportable image cannot carry metadata, no matter what the client sent or claimed
// (GROUPEVENTS-03). StripAndReencode is the only function in this codebase permitted to produce a
// StrippedImage, and StrippedImage's unexported fields mean no other package can construct a
// populated one -- objectstore.go's shared-tier writer therefore cannot be handed unstripped bytes
// even by mistake (T-04.1-16).
package photo

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	_ "image/jpeg" // registers the JPEG decoder with image.Decode/image.DecodeConfig
	_ "image/png"  // registers the PNG decoder with image.Decode/image.DecodeConfig
)

// maxUploadBytes bounds the raw input this pipeline will even attempt to decode. 8 MiB comfortably
// covers a real phone-camera JPEG (even an uncompressed-ish one) while remaining far below anything
// that could tie up memory or CPU on a hostile upload (T-04.1-18).
const maxUploadBytes = 8 << 20

// maxPixels bounds the decoded image's pixel count (width * height), checked against the image
// header BEFORE the full pixel buffer is allocated -- the decompression-bomb mitigation a byte-size
// cap alone cannot provide, since a small file can still declare enormous dimensions (T-04.1-18).
const maxPixels = 40_000_000

// ErrUnsupportedFormat is returned when the input is a real, recognizable image format this
// pipeline does not decode -- today, specifically HEIC/HEIF, the format iPhones capture by
// default. This is a hard, total reject: StripAndReencode never falls back to writing the
// undecoded original bytes through on this or any other error path. If HEIC uploads start failing
// in practice, the fix is the client-side HEIC->JPEG transcode this pipeline already assumes
// (04.1-RESEARCH.md Pattern 2), never a server-side passthrough -- a passthrough here would defeat
// this entire package's reason to exist.
var ErrUnsupportedFormat = errors.New("photo: unsupported image format")

// ErrImageTooLarge is returned both when the raw input exceeds maxUploadBytes and when the
// decoded (or header-declared) pixel count exceeds maxPixels.
var ErrImageTooLarge = errors.New("photo: image too large")

// ErrDecodeFailed is returned when the input cannot be decoded as any format this pipeline
// recognizes and it is not a case covered by ErrUnsupportedFormat -- e.g. arbitrary non-image
// bytes, or a corrupt JPEG/PNG.
var ErrDecodeFailed = errors.New("photo: failed to decode image")

// ErrNotStripped is returned by PutShared (objectstore.go) when handed a zero-value StrippedImage
// -- one that was never produced by StripAndReencode -- rather than silently writing an empty
// object.
var ErrNotStripped = errors.New("photo: image was not produced by StripAndReencode")

// StrippedImage is the opaque result of a successful StripAndReencode call. Every field is
// unexported and there is no exported constructor: a caller in another package cannot build a
// populated value by any means other than calling StripAndReencode, which is the whole
// enforcement mechanism behind objectstore.go's PutShared accepting only this type, never a raw
// []byte (T-04.1-16's key_links).
type StrippedImage struct {
	bytes       []byte
	contentType string
}

// Bytes returns the stripped, re-encoded image bytes. Zero-length for a zero-value StrippedImage.
func (s StrippedImage) Bytes() []byte { return s.bytes }

// ContentType returns the MIME type of the stripped bytes (always "image/jpeg" today, since
// StripAndReencode always re-encodes as JPEG regardless of the input format).
func (s StrippedImage) ContentType() string { return s.contentType }

// isZero reports whether s is the zero value -- never produced by StripAndReencode.
func (s StrippedImage) isZero() bool { return len(s.bytes) == 0 && s.contentType == "" }

// heicBrands lists the ISO-BMFF "ftyp" major-brand values this pipeline recognizes as HEIC/HEIF,
// so a genuine HEIC upload is rejected with the specific ErrUnsupportedFormat sentinel rather than
// falling through to the generic ErrDecodeFailed a naive image.Decode call would otherwise return
// -- Go's image.Decode returns the identical image.ErrFormat ("unknown format") for both a real
// HEIC file and arbitrary non-image garbage, so this pipeline cannot tell the two apart without
// sniffing the container signature itself before calling image.Decode.
var heicBrands = map[string]bool{
	"heic": true, "heix": true, "hevc": true, "heim": true,
	"heis": true, "hevm": true, "hevs": true, "mif1": true, "msf1": true,
}

// isHEIC reports whether raw begins with an ISO-BMFF "ftyp" box carrying a recognized HEIC/HEIF
// major brand.
func isHEIC(raw []byte) bool {
	if len(raw) < 12 {
		return false
	}
	if string(raw[4:8]) != "ftyp" {
		return false
	}
	return heicBrands[string(raw[8:12])]
}

// StripAndReencode is the ONLY code path in this codebase permitted to produce a populated
// StrippedImage, and therefore the only path that can write an image to group-visible or
// exportable storage (GROUPEVENTS-03, via objectstore.go's PutShared). It never receives special
// treatment for any input: every caller, present or future, goes through exactly this function.
//
// The metadata-removal guarantee is structural, not a filter: raw is decoded into an image.Image
// (which has no field that could carry an EXIF/XMP/PNG-text segment) and re-encoded from scratch
// as JPEG using only the Go standard library, so the output cannot contain metadata regardless of
// what was in the source bytes (04.1-RESEARCH.md Pattern 2). A dedicated metadata-stripping
// library would be structurally weaker here -- it would have to know about every metadata format
// to remove it, where the stdlib round trip simply never carries any format-metadata field at all.
//
// A decode failure is always a hard reject with a sentinel and a zero StrippedImage. THERE IS NO
// PATH THAT RETURNS THE INPUT BYTES ON FAILURE. This is the specific thing a future maintainer
// must not "fix" when HEIC uploads start failing: the correct fix is the client-side HEIC->JPEG
// transcode this pipeline already assumes, never a passthrough that would defeat this package's
// entire purpose (04.1-RESEARCH.md Pitfall 2).
func StripAndReencode(raw []byte) (StrippedImage, error) {
	if len(raw) > maxUploadBytes {
		return StrippedImage{}, ErrImageTooLarge
	}

	if isHEIC(raw) {
		return StrippedImage{}, ErrUnsupportedFormat
	}

	// Read the orientation tag before anything else discards it. This is a narrow, read-only
	// EXIF read (T-04.1-22) -- it never influences whether the image is accepted, only how it is
	// rotated after decode.
	orientation := readOrientationOnly(raw)

	// Check the header-declared pixel count BEFORE allocating the full pixel buffer
	// (decompression-bomb mitigation, T-04.1-18) -- a small file can still declare enormous
	// dimensions.
	cfg, _, err := image.DecodeConfig(bytes.NewReader(raw))
	if err != nil {
		return StrippedImage{}, fmt.Errorf("%w: %v", ErrDecodeFailed, err)
	}
	if int64(cfg.Width)*int64(cfg.Height) > maxPixels {
		return StrippedImage{}, ErrImageTooLarge
	}

	// image.Decode is metadata-blind by construction: the decoded image.Image has no field that
	// could carry an EXIF/XMP segment or a PNG text chunk. This is the structural guarantee, not
	// a filter applied afterward.
	img, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil {
		return StrippedImage{}, fmt.Errorf("%w: %v", ErrDecodeFailed, err)
	}

	if int64(img.Bounds().Dx())*int64(img.Bounds().Dy()) > maxPixels {
		return StrippedImage{}, ErrImageTooLarge
	}

	img = applyOrientation(img, orientation)

	var out bytes.Buffer
	if err := jpeg.Encode(&out, img, &jpeg.Options{Quality: 85}); err != nil {
		return StrippedImage{}, fmt.Errorf("%w: %v", ErrDecodeFailed, err)
	}

	return StrippedImage{bytes: out.Bytes(), contentType: "image/jpeg"}, nil
}
