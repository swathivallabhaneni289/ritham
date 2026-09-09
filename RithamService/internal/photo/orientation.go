package photo

import (
	"bytes"
	"image"
	"image/color"

	"github.com/rwcarlsen/goexif/exif"
)

// readOrientationOnly is the single narrow, read-only use of rwcarlsen/goexif on this codebase's
// entire photo path (T-04.1-22): it reads the EXIF Orientation tag alone and nothing else -- never
// GPS, never any other tag -- and is never involved in the metadata-removal guarantee itself (that
// guarantee comes from StripAndReencode's decode/re-encode round trip, which is metadata-blind by
// construction regardless of what this function returns).
//
// It fails soft: a missing EXIF segment (the common case -- most uploads won't carry one), a
// corrupt one, or an out-of-range value (valid EXIF orientation values are 1-8) all return 1
// (identity -- "already upright"), never an error. A photo pipeline must never fail an otherwise
// valid upload just because it lacks orientation metadata.
func readOrientationOnly(raw []byte) int {
	x, err := exif.Decode(bytes.NewReader(raw))
	if err != nil {
		return 1
	}
	tag, err := x.Get(exif.Orientation)
	if err != nil {
		return 1
	}
	v, err := tag.Int(0)
	if err != nil || v < 1 || v > 8 {
		return 1
	}
	return v
}

// applyOrientation returns a new image with the EXIF orientation transform for the given value
// (1-8) applied to img, correcting it to upright. Any value outside 1-8 is treated as 1 (identity)
// -- readOrientationOnly already guarantees this, but applyOrientation re-validates so it is safe
// to call directly with any int.
//
// This is a deliberate, reviewed exception to this codebase's general "don't hand-roll" discipline
// (04.1-RESEARCH.md's Don't Hand-Roll table): the two available third-party rotation libraries are
// both stale (2018/2019, low ongoing adoption) for a security-relevant code path, and the 8-case
// pixel transform below is simple enough to review directly rather than trust to a
// barely-maintained dependency.
//
// The mapping (EXIF orientation -> transform) was independently derived two ways (direct
// pixel-index derivation, and composition from flipH/flipV/transpose primitives), cross-checked
// against exiftool's own documented descriptions, and pinned here once so no other file re-derives
// it from memory:
//
//	1: identity                              -- no change
//	2: flip horizontal                       -- mirror left-right, dimensions unchanged
//	3: rotate 180                            -- dimensions unchanged
//	4: flip vertical                         -- mirror top-bottom, dimensions unchanged
//	5: transpose                             -- mirror across the top-left/bottom-right diagonal, dimensions swap
//	6: rotate 90 clockwise                   -- dimensions swap
//	7: transverse                            -- mirror across the other diagonal, dimensions swap
//	8: rotate 90 counter-clockwise (270 CW)  -- dimensions swap
//
// For a source image of width W and height H, with source pixel src(x,y), and output pixel
// out(x,y):
//
//	1: out(x,y) = src(x,y)                 dims (W,H)
//	2: out(x,y) = src(W-1-x, y)            dims (W,H)
//	3: out(x,y) = src(W-1-x, H-1-y)        dims (W,H)
//	4: out(x,y) = src(x, H-1-y)            dims (W,H)
//	5: out(x,y) = src(y, x)                dims (H,W)
//	6: out(x,y) = src(y, H-1-x)            dims (H,W)
//	7: out(x,y) = src(W-1-y, H-1-x)        dims (H,W)
//	8: out(x,y) = src(W-1-y, x)            dims (H,W)
func applyOrientation(img image.Image, orientation int) image.Image {
	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	minX, minY := bounds.Min.X, bounds.Min.Y

	get := func(x, y int) color.Color {
		return img.At(minX+x, minY+y)
	}

	switch orientation {
	case 2:
		return remap(w, h, get, func(x, y int) (int, int) { return w - 1 - x, y })
	case 3:
		return remap(w, h, get, func(x, y int) (int, int) { return w - 1 - x, h - 1 - y })
	case 4:
		return remap(w, h, get, func(x, y int) (int, int) { return x, h - 1 - y })
	case 5:
		return remap(h, w, get, func(x, y int) (int, int) { return y, x })
	case 6:
		return remap(h, w, get, func(x, y int) (int, int) { return y, h - 1 - x })
	case 7:
		return remap(h, w, get, func(x, y int) (int, int) { return w - 1 - y, h - 1 - x })
	case 8:
		return remap(h, w, get, func(x, y int) (int, int) { return w - 1 - y, x })
	default:
		// 1, or any invalid value: identity.
		return remap(w, h, get, func(x, y int) (int, int) { return x, y })
	}
}

// remap builds a new outW x outH image by, for every output pixel (x,y), calling srcCoord to find
// which source pixel to read via get.
func remap(outW, outH int, get func(x, y int) color.Color, srcCoord func(x, y int) (int, int)) image.Image {
	out := image.NewRGBA(image.Rect(0, 0, outW, outH))
	for y := 0; y < outH; y++ {
		for x := 0; x < outW; x++ {
			sx, sy := srcCoord(x, y)
			out.Set(x, y, get(sx, sy))
		}
	}
	return out
}
