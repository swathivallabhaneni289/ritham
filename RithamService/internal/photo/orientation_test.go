package photo

import (
	"fmt"
	"image"
	"image/color"
	"testing"
)

// asymmetricTestImage returns a 3x2 image with a distinct, recognizable color at each of its four
// corners, so a transpose/rotate/flip transform is verifiable by checking exactly those four
// pixels rather than the whole image.
func asymmetricTestImage() *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, 3, 2))
	fill := color.RGBA{128, 128, 128, 255}
	for y := 0; y < 2; y++ {
		for x := 0; x < 3; x++ {
			img.Set(x, y, fill)
		}
	}
	img.Set(0, 0, red)
	img.Set(2, 0, green)
	img.Set(0, 1, blue)
	img.Set(2, 1, yellow)
	return img
}

var (
	red    = color.RGBA{255, 0, 0, 255}
	green  = color.RGBA{0, 255, 0, 255}
	blue   = color.RGBA{0, 0, 255, 255}
	yellow = color.RGBA{255, 255, 0, 255}
)

func sameColor(t *testing.T, got color.Color, want color.RGBA, label string) {
	t.Helper()
	gr, gg, gb, ga := got.RGBA()
	wr, wg, wb, wa := want.RGBA()
	if gr != wr || gg != wg || gb != wb || ga != wa {
		t.Errorf("%s: got RGBA(%d,%d,%d,%d), want RGBA(%d,%d,%d,%d)", label, gr, gg, gb, ga, wr, wg, wb, wa)
	}
}

// TestApplyOrientation_AllEightCasesMatchDocumentedTransform verifies every EXIF orientation value
// (1-8) against the exact pixel-index table documented in applyOrientation's doc comment, derived
// independently two ways before being pinned there. The source image is deliberately non-square
// (3x2) so a dimension swap (orientations 5-8) is distinguishable from a same-dimension transform
// (orientations 1-4).
func TestApplyOrientation_AllEightCasesMatchDocumentedTransform(t *testing.T) {
	cases := []struct {
		orientation                    int
		wantW, wantH                   int
		wantTL, wantTR, wantBL, wantBR color.RGBA
	}{
		{1, 3, 2, red, green, blue, yellow},
		{2, 3, 2, green, red, yellow, blue},
		{3, 3, 2, yellow, blue, green, red},
		{4, 3, 2, blue, yellow, red, green},
		{5, 2, 3, red, blue, green, yellow},
		{6, 2, 3, blue, red, yellow, green},
		{7, 2, 3, yellow, green, blue, red},
		{8, 2, 3, green, yellow, red, blue},
	}

	for _, c := range cases {
		src := asymmetricTestImage()
		out := applyOrientation(src, c.orientation)
		b := out.Bounds()
		w, h := b.Dx(), b.Dy()
		if w != c.wantW || h != c.wantH {
			t.Errorf("orientation %d: got dims %dx%d, want %dx%d", c.orientation, w, h, c.wantW, c.wantH)
			continue
		}
		minX, minY := b.Min.X, b.Min.Y
		sameColor(t, out.At(minX, minY), c.wantTL, fmt.Sprintf("orientation %d top-left", c.orientation))
		sameColor(t, out.At(minX+w-1, minY), c.wantTR, fmt.Sprintf("orientation %d top-right", c.orientation))
		sameColor(t, out.At(minX, minY+h-1), c.wantBL, fmt.Sprintf("orientation %d bottom-left", c.orientation))
		sameColor(t, out.At(minX+w-1, minY+h-1), c.wantBR, fmt.Sprintf("orientation %d bottom-right", c.orientation))
	}
}

// TestApplyOrientation_InvalidValueIsIdentity confirms an out-of-range value (never actually
// reachable from readOrientationOnly, which clamps to 1) is still handled safely by
// applyOrientation itself.
func TestApplyOrientation_InvalidValueIsIdentity(t *testing.T) {
	src := asymmetricTestImage()
	out := applyOrientation(src, 99)
	b := out.Bounds()
	if b.Dx() != 3 || b.Dy() != 2 {
		t.Fatalf("invalid orientation: got dims %dx%d, want 3x2 (identity)", b.Dx(), b.Dy())
	}
	sameColor(t, out.At(b.Min.X, b.Min.Y), red, "invalid orientation top-left")
}

// TestReadOrientationOnly_OrientedFixtureReturnsSix is the positive control for the strip
// pipeline's orientation behavior: the committed fixture must actually carry orientation tag 6,
// or the pipeline test that depends on it would pass for the wrong reason.
func TestReadOrientationOnly_OrientedFixtureReturnsSix(t *testing.T) {
	raw := loadFixture(t, "oriented-6.jpg")
	got := readOrientationOnly(raw)
	if got != 6 {
		t.Fatalf("readOrientationOnly(oriented-6.jpg) = %d, want 6 (fixture generation may be broken)", got)
	}
}

// TestReadOrientationOnly_GPSFixtureHasNoOrientationTag confirms the GPS fixture (which carries no
// Orientation tag) fails soft to identity, matching a real photo with no orientation metadata.
func TestReadOrientationOnly_GPSFixtureHasNoOrientationTag(t *testing.T) {
	raw := loadFixture(t, "gps-exif.jpg")
	got := readOrientationOnly(raw)
	if got != 1 {
		t.Fatalf("readOrientationOnly(gps-exif.jpg) = %d, want 1 (no orientation tag present)", got)
	}
}

// TestReadOrientationOnly_NonImageBytesFailSoft confirms garbage bytes never produce an error path
// here -- only StripAndReencode's decode step is responsible for rejecting non-image input.
func TestReadOrientationOnly_NonImageBytesFailSoft(t *testing.T) {
	got := readOrientationOnly([]byte("not an image"))
	if got != 1 {
		t.Fatalf("readOrientationOnly(garbage) = %d, want 1 (fail soft to identity)", got)
	}
}
