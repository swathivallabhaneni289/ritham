package photo

import (
	"bytes"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"image"
	"os"
	"path/filepath"
	"testing"

	"github.com/rwcarlsen/goexif/exif"
)

// Fixtures under testdata/ are generated, not hand-authored -- see
// testdata/gen/main.go's header comment for exactly how each one was produced and the command to
// regenerate them: `go run internal/photo/testdata/gen/main.go internal/photo/testdata` from
// RithamService/.
const (
	fixtureGPSExif     = "gps-exif.jpg"
	fixtureOriented6   = "oriented-6.jpg"
	fixtureTextChunks  = "text-chunks.png"
	fixtureHEICCapture = "iphone-capture.heic"
	textChunkMarker    = "RithamTestMarkerXYZ123"
)

func loadFixture(t *testing.T, name string) []byte {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		t.Fatalf("loadFixture(%q): %v", name, err)
	}
	if len(raw) == 0 {
		t.Fatalf("loadFixture(%q): fixture is empty", name)
	}
	return raw
}

// hasNonJFIFAPPSegment walks a JPEG byte stream's marker segments and reports whether any APPn
// segment other than APP0 (JFIF) is present. It stops at the first Start-of-Scan (SOS) marker,
// since only header segments before the entropy-coded data can be APPn markers.
func hasNonJFIFAPPSegment(t *testing.T, jpegBytes []byte) bool {
	t.Helper()
	if len(jpegBytes) < 2 || jpegBytes[0] != 0xFF || jpegBytes[1] != 0xD8 {
		t.Fatalf("hasNonJFIFAPPSegment: input is not a JPEG (missing SOI)")
	}
	i := 2
	for i+4 <= len(jpegBytes) {
		if jpegBytes[i] != 0xFF {
			t.Fatalf("hasNonJFIFAPPSegment: expected marker byte 0xFF at offset %d", i)
		}
		marker := jpegBytes[i+1]
		switch {
		case marker == 0xD8 || marker == 0xD9 || marker == 0x01:
			i += 2
			continue
		case marker >= 0xD0 && marker <= 0xD7:
			i += 2
			continue
		}
		if marker == 0xDA {
			// Start of scan -- entropy-coded data follows; no more marker segments to check.
			return false
		}
		segLen := int(jpegBytes[i+2])<<8 | int(jpegBytes[i+3])
		if marker >= 0xE0 && marker <= 0xEF && marker != 0xE0 {
			return true
		}
		i += 2 + segLen
	}
	return false
}

// hasGPSIFD reports whether raw contains a parseable GPS IFD, using the same read-only EXIF
// reader (goexif) the orientation path uses -- the belt-and-suspenders check 04.1-RESEARCH.md's
// tightened negative-test description calls for, independent of the structural APPn-segment walk.
func hasGPSIFD(t *testing.T, raw []byte) bool {
	t.Helper()
	x, err := exif.Decode(bytes.NewReader(raw))
	if err != nil {
		return false
	}
	_, _, err = x.LatLong()
	return err == nil
}

// --- Positive controls: prove the fixtures themselves actually carry the metadata this pipeline
// is supposed to strip, before trusting any "output has none" assertion. A malformed fixture that
// silently lost its metadata at generation time would otherwise make the real tests below pass
// for the wrong reason.

func TestFixture_GPSExifHasParseableGPSIFD(t *testing.T) {
	raw := loadFixture(t, fixtureGPSExif)
	if !hasGPSIFD(t, raw) {
		t.Fatal("gps-exif.jpg fixture does not carry a parseable GPS IFD -- fixture generation is broken")
	}
}

func TestFixture_TextChunksContainsMarker(t *testing.T) {
	raw := loadFixture(t, fixtureTextChunks)
	if !bytes.Contains(raw, []byte(textChunkMarker)) {
		t.Fatal("text-chunks.png fixture does not contain its own marker string -- fixture generation is broken")
	}
}

// TestHasNonJFIFAPPSegment_DetectsAPP1OnTheInputFixture is the positive control for the scanner
// used by TestStripAndReencode_NoMetadataSegments itself, not just for the fixtures. Go's
// image/jpeg encoder never emits an APP0/JFIF marker, so on every StripAndReencode output the
// walk goes SOI -> DQT -> SOF0 -> DHT -> SOS -> false: the `marker >= 0xE0 && marker <= 0xEF`
// branch is evaluated but has never once been exercised as true by that test alone. Without this
// separate check, a broken walker (wrong marker range, an off-by-one on the length field, an
// early exit) would make the negative test pass silently, leaving T-04.1-16's central mitigation
// unverified. gps-exif.jpg is SOI + a hand-built APP1 Exif segment + encoder output, so it is
// exactly the positive input the walker must detect.
func TestHasNonJFIFAPPSegment_DetectsAPP1OnTheInputFixture(t *testing.T) {
	raw := loadFixture(t, fixtureGPSExif)
	if !hasNonJFIFAPPSegment(t, raw) {
		t.Fatal("hasNonJFIFAPPSegment failed to detect the APP1 Exif segment gps-exif.jpg is known to carry -- " +
			"TestStripAndReencode_NoMetadataSegments's APPn assertion is vacuous until this passes")
	}
}

func TestFixture_HEICCaptureIsGenuineHEIFContainer(t *testing.T) {
	raw := loadFixture(t, fixtureHEICCapture)
	if !isHEIC(raw) {
		t.Fatal("iphone-capture.heic fixture is not recognized as a genuine HEIF container")
	}
}

// TestStripAndReencode_NoMetadataSegments is the required structural negative test
// (04.1-VALIDATION.md, 04.1-RESEARCH.md Pattern 2): it scans the OUTPUT bytes structurally rather
// than substring-searching for one metadata signature, since the same segment type can carry
// other metadata formats under different signatures.
func TestStripAndReencode_NoMetadataSegments(t *testing.T) {
	t.Run("JPEG with GPS IFD", func(t *testing.T) {
		raw := loadFixture(t, fixtureGPSExif)
		out, err := StripAndReencode(raw)
		if err != nil {
			t.Fatalf("StripAndReencode: unexpected error: %v", err)
		}
		if hasNonJFIFAPPSegment(t, out.Bytes()) {
			t.Error("output contains an APPn segment other than APP0/JFIF -- metadata was not fully stripped")
		}
		if hasGPSIFD(t, out.Bytes()) {
			t.Error("output contains a parseable GPS IFD -- structural stripping guarantee violated")
		}
	})

	t.Run("PNG with textual chunks", func(t *testing.T) {
		raw := loadFixture(t, fixtureTextChunks)
		out, err := StripAndReencode(raw)
		if err != nil {
			t.Fatalf("StripAndReencode: unexpected error: %v", err)
		}
		if out.ContentType() != "image/jpeg" {
			t.Errorf("output content type = %q, want image/jpeg (pipeline always re-encodes as JPEG)", out.ContentType())
		}
		if hasNonJFIFAPPSegment(t, out.Bytes()) {
			t.Error("output contains an APPn segment other than APP0/JFIF")
		}
		if bytes.Contains(out.Bytes(), []byte(textChunkMarker)) {
			t.Error("output contains the input PNG's text-chunk marker -- metadata leaked through re-encoding")
		}
	})
}

// TestStripAndReencode_HEICFixtureRejected asserts against a real iPhone-captured-shape HEIC
// file, not a renamed JPEG, matching 04.1-RESEARCH.md Pitfall 2's own named warning sign.
func TestStripAndReencode_HEICFixtureRejected(t *testing.T) {
	raw := loadFixture(t, fixtureHEICCapture)
	out, err := StripAndReencode(raw)
	if !errors.Is(err, ErrUnsupportedFormat) {
		t.Fatalf("StripAndReencode(HEIC): got error %v, want ErrUnsupportedFormat", err)
	}
	if !out.isZero() {
		t.Fatal("StripAndReencode(HEIC): expected a zero StrippedImage on rejection")
	}
}

func TestStripAndReencode_NonImageBytesRejected(t *testing.T) {
	out, err := StripAndReencode([]byte("this is definitely not an image, just plain text bytes"))
	if !errors.Is(err, ErrDecodeFailed) {
		t.Fatalf("StripAndReencode(garbage): got error %v, want ErrDecodeFailed", err)
	}
	if !out.isZero() {
		t.Fatal("StripAndReencode(garbage): expected a zero StrippedImage on rejection")
	}
}

func TestStripAndReencode_OversizedInputRejected(t *testing.T) {
	oversized := make([]byte, maxUploadBytes+1)
	out, err := StripAndReencode(oversized)
	if !errors.Is(err, ErrImageTooLarge) {
		t.Fatalf("StripAndReencode(oversized): got error %v, want ErrImageTooLarge", err)
	}
	if !out.isZero() {
		t.Fatal("StripAndReencode(oversized): expected a zero StrippedImage on rejection")
	}
}

// TestStripAndReencode_PixelCapRejectsBeforeFullDecode builds a PNG whose IHDR declares
// dimensions far over maxPixels but whose IDAT is deliberately garbage -- if StripAndReencode
// only checked the pixel count after a full decode, this input would fail with ErrDecodeFailed
// (from the garbage IDAT) rather than ErrImageTooLarge, revealing the check ran too late.
func TestStripAndReencode_PixelCapRejectsBeforeFullDecode(t *testing.T) {
	raw := buildPNGWithDeclaredDimensions(t, 10000, 10000) // 100,000,000 px > maxPixels (40,000,000)
	out, err := StripAndReencode(raw)
	if !errors.Is(err, ErrImageTooLarge) {
		t.Fatalf("StripAndReencode(huge declared dims): got error %v, want ErrImageTooLarge", err)
	}
	if !out.isZero() {
		t.Fatal("StripAndReencode(huge declared dims): expected a zero StrippedImage on rejection")
	}
}

func buildPNGWithDeclaredDimensions(t *testing.T, width, height uint32) []byte {
	t.Helper()
	var buf bytes.Buffer
	buf.Write([]byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'})

	var ihdr bytes.Buffer
	_ = binary.Write(&ihdr, binary.BigEndian, width)
	_ = binary.Write(&ihdr, binary.BigEndian, height)
	ihdr.Write([]byte{8, 2, 0, 0, 0}) // bit depth 8, color type 2 (truecolor), no interlace
	writePNGChunk(&buf, "IHDR", ihdr.Bytes())
	writePNGChunk(&buf, "IDAT", []byte{0x00, 0x01, 0x02, 0x03}) // deliberately not valid zlib data
	writePNGChunk(&buf, "IEND", nil)
	return buf.Bytes()
}

func writePNGChunk(buf *bytes.Buffer, chunkType string, data []byte) {
	length := make([]byte, 4)
	binary.BigEndian.PutUint32(length, uint32(len(data)))
	buf.Write(length)
	typeAndData := append([]byte(chunkType), data...)
	buf.Write(typeAndData)
	crc := crc32.ChecksumIEEE(typeAndData)
	crcBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(crcBytes, crc)
	buf.Write(crcBytes)
}

// TestStripAndReencode_OrientedFixtureComesOutTransposed proves the rotation actually ran: the
// oriented-6.jpg fixture is 6x4 (width x height) with orientation tag 6 (rotate 90 CW), so the
// stripped output must be 4x6.
func TestStripAndReencode_OrientedFixtureComesOutTransposed(t *testing.T) {
	raw := loadFixture(t, fixtureOriented6)
	inCfg, _, err := image.DecodeConfig(bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("decoding fixture header: %v", err)
	}

	out, err := StripAndReencode(raw)
	if err != nil {
		t.Fatalf("StripAndReencode: unexpected error: %v", err)
	}
	outCfg, _, err := image.DecodeConfig(bytes.NewReader(out.Bytes()))
	if err != nil {
		t.Fatalf("decoding output header: %v", err)
	}

	if outCfg.Width != inCfg.Height || outCfg.Height != inCfg.Width {
		t.Fatalf("output dims %dx%d, want %dx%d (transposed relative to input %dx%d)",
			outCfg.Width, outCfg.Height, inCfg.Height, inCfg.Width, inCfg.Width, inCfg.Height)
	}
}

// TestStripAndReencode_NoOrientationTagKeepsDimensions confirms a photo with no orientation tag
// (the gps-exif.jpg fixture) is not rotated -- dimensions must stay exactly as they were.
func TestStripAndReencode_NoOrientationTagKeepsDimensions(t *testing.T) {
	raw := loadFixture(t, fixtureGPSExif)
	inCfg, _, err := image.DecodeConfig(bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("decoding fixture header: %v", err)
	}

	out, err := StripAndReencode(raw)
	if err != nil {
		t.Fatalf("StripAndReencode: unexpected error: %v", err)
	}
	outCfg, _, err := image.DecodeConfig(bytes.NewReader(out.Bytes()))
	if err != nil {
		t.Fatalf("decoding output header: %v", err)
	}

	if outCfg.Width != inCfg.Width || outCfg.Height != inCfg.Height {
		t.Fatalf("output dims %dx%d, want unchanged %dx%d", outCfg.Width, outCfg.Height, inCfg.Width, inCfg.Height)
	}
}
