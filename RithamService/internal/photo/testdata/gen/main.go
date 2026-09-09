// Command gen produces the four fixtures committed under internal/photo/testdata/, so the exact
// bytes of every fixture can be regenerated rather than trusted as an opaque binary blob. This
// file lives under testdata/ specifically so the Go toolchain's package-pattern matching (which
// always skips directories named "testdata") never treats it as part of the photo package; it is
// run only manually, via `go run internal/photo/testdata/gen/main.go` from RithamService/.
//
// How each fixture is produced:
//
//   - gps-exif.jpg: a baseline JPEG (image/jpeg, 6x4px) with a hand-built APP1 "Exif\0\0" + TIFF
//     segment inserted immediately after SOI. The TIFF contains an IFD0 with a single GPSInfo IFD
//     pointer tag, and a GPS IFD with GPSVersionID/GPSLatitudeRef/GPSLatitude/GPSLongitudeRef/
//     GPSLongitude (rational-encoded, "36 deg 58' 30\" N, 110 deg 4' 0\" W" -- Four Corners area, an
//     arbitrary but structurally valid coordinate).
//   - oriented-6.jpg: a baseline JPEG (6x4px, non-square so the strip pipeline's "dimensions
//     transposed" behavior is detectable) with a hand-built APP1 Exif segment carrying only an
//     IFD0 Orientation tag (SHORT, value 6 -- "rotate 90 CW to be upright"). No GPS data.
//   - text-chunks.png: a baseline PNG (image/png, 4x4px) with a hand-inserted tEXt chunk (keyword
//     "Comment") carrying a unique marker string, inserted between IHDR and IDAT.
//   - iphone-capture.heic: NOT produced by this generator. Per 04.1-04-PLAN.md Task 1's action
//     text, this repo's environment has no reachable genuine iPhone-captured HEIC file that is
//     safe to commit (real device photos under ~/Downloads carry the owner's actual GPS/location
//     metadata -- committing one to source control permanently would itself be exactly the kind of
//     metadata leak this plan exists to prevent). The documented fallback route was used instead:
//     `sips -s format heic <synthetic-source.jpg> --out iphone-capture.heic`, transcoding a
//     synthetic (non-personal) JPEG produced by this same generator into a genuine HEIF container
//     via macOS's own ImageIO-backed sips tool. See this plan's SUMMARY.md for the exact commands
//     run and the reasoning for not using a real device file.
package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
)

const (
	tiffTypeByte     = 1
	tiffTypeASCII    = 2
	tiffTypeShort    = 3
	tiffTypeLong     = 4
	tiffTypeRational = 5
)

// tiffEntry is one 12-byte IFD entry plus its payload. Payloads of 4 bytes or fewer are stored
// inline in the entry's value field (TIFF spec); longer payloads (e.g. RATIONAL arrays) are
// written to an overflow area and the entry's value field holds that area's offset instead.
type tiffEntry struct {
	tag   uint16
	typ   uint16
	count uint32
	data  []byte
}

func u16(v uint16) []byte {
	b := make([]byte, 2)
	binary.LittleEndian.PutUint16(b, v)
	return b
}

func u32(v uint32) []byte {
	b := make([]byte, 4)
	binary.LittleEndian.PutUint32(b, v)
	return b
}

func rational(num, den uint32) []byte {
	return append(u32(num), u32(den)...)
}

// layoutIFD writes one IFD's fixed 12-byte-per-entry block, given the byte offset (from the start
// of the TIFF header) at which this IFD's fixed block begins. It returns the fixed block and a
// separate overflow block (payloads that didn't fit inline); the caller is responsible for
// placing the overflow block immediately after the fixed block when assembling the final buffer,
// since that placement is exactly what the offsets written here assume.
func layoutIFD(ifdOffset uint32, entries []tiffEntry, nextIFDOffset uint32) (fixed, overflow []byte) {
	fixedLen := 2 + 12*len(entries) + 4
	var buf bytes.Buffer
	buf.Write(u16(uint16(len(entries))))

	var ov bytes.Buffer
	runningOverflowOffset := ifdOffset + uint32(fixedLen)
	for _, e := range entries {
		buf.Write(u16(e.tag))
		buf.Write(u16(e.typ))
		buf.Write(u32(e.count))
		if len(e.data) <= 4 {
			v := make([]byte, 4)
			copy(v, e.data)
			buf.Write(v)
		} else {
			buf.Write(u32(runningOverflowOffset))
			ov.Write(e.data)
			runningOverflowOffset += uint32(len(e.data))
		}
	}
	buf.Write(u32(nextIFDOffset))
	return buf.Bytes(), ov.Bytes()
}

// buildGPSExifTIFF assembles a full little-endian TIFF byte stream: header, IFD0 (a single
// GPSInfo pointer), and a GPS IFD carrying a real, parseable coordinate.
func buildGPSExifTIFF() []byte {
	const headerLen = 8
	const ifd0Offset = headerLen

	// IFD0 has exactly one entry (GPSInfo pointer) with no overflow, so its fixed length is
	// fully deterministic: 2 (count) + 12 (one entry) + 4 (next-IFD offset) = 18.
	const ifd0FixedLen = 2 + 12 + 4
	gpsIFDOffset := ifd0Offset + ifd0FixedLen

	ifd0Entries := []tiffEntry{
		{tag: 0x8825, typ: tiffTypeLong, count: 1, data: u32(uint32(gpsIFDOffset))},
	}
	ifd0Fixed, ifd0Overflow := layoutIFD(uint32(ifd0Offset), ifd0Entries, 0)
	if len(ifd0Overflow) != 0 {
		panic("gen: IFD0 was expected to have no overflow")
	}

	gpsEntries := []tiffEntry{
		{tag: 0x0000, typ: tiffTypeByte, count: 4, data: []byte{2, 3, 0, 0}}, // GPSVersionID
		{tag: 0x0001, typ: tiffTypeASCII, count: 2, data: []byte("N\x00")},   // GPSLatitudeRef
		{tag: 0x0002, typ: tiffTypeRational, count: 3, data: bytes.Join([][]byte{ // GPSLatitude
			rational(36, 1), rational(58, 1), rational(30, 1),
		}, nil)},
		{tag: 0x0003, typ: tiffTypeASCII, count: 2, data: []byte("W\x00")}, // GPSLongitudeRef
		{tag: 0x0004, typ: tiffTypeRational, count: 3, data: bytes.Join([][]byte{ // GPSLongitude
			rational(110, 1), rational(4, 1), rational(0, 1),
		}, nil)},
	}
	gpsFixed, gpsOverflow := layoutIFD(uint32(gpsIFDOffset), gpsEntries, 0)

	var tiff bytes.Buffer
	tiff.WriteString("II")
	tiff.Write(u16(0x002A))
	tiff.Write(u32(uint32(ifd0Offset)))
	tiff.Write(ifd0Fixed)
	tiff.Write(gpsFixed)
	tiff.Write(gpsOverflow)
	return tiff.Bytes()
}

// buildOrientationTIFF assembles a TIFF byte stream carrying only an IFD0 Orientation tag, no GPS
// data.
func buildOrientationTIFF(orientation uint16) []byte {
	const headerLen = 8
	const ifd0Offset = headerLen

	ifd0Entries := []tiffEntry{
		{tag: 0x0112, typ: tiffTypeShort, count: 1, data: u16(orientation)},
	}
	ifd0Fixed, ifd0Overflow := layoutIFD(uint32(ifd0Offset), ifd0Entries, 0)
	if len(ifd0Overflow) != 0 {
		panic("gen: IFD0 was expected to have no overflow")
	}

	var tiff bytes.Buffer
	tiff.WriteString("II")
	tiff.Write(u16(0x002A))
	tiff.Write(u32(uint32(ifd0Offset)))
	tiff.Write(ifd0Fixed)
	return tiff.Bytes()
}

// jpegWithAPP1 encodes img as a baseline JPEG, then inserts an "Exif\0\0"-prefixed APP1 segment
// (wrapping tiffData) immediately after the SOI marker -- before any segment the encoder itself
// wrote.
func jpegWithAPP1(img image.Image, tiffData []byte) ([]byte, error) {
	var base bytes.Buffer
	if err := jpeg.Encode(&base, img, &jpeg.Options{Quality: 90}); err != nil {
		return nil, err
	}
	raw := base.Bytes()
	if len(raw) < 2 || raw[0] != 0xFF || raw[1] != 0xD8 {
		return nil, fmt.Errorf("gen: encoded JPEG missing SOI marker")
	}

	exifPayload := append([]byte("Exif\x00\x00"), tiffData...)
	if len(exifPayload)+2 > 0xFFFF {
		return nil, fmt.Errorf("gen: APP1 payload too large")
	}
	segLen := uint16(len(exifPayload) + 2)

	var out bytes.Buffer
	out.Write(raw[:2]) // SOI
	out.Write([]byte{0xFF, 0xE1})
	out.Write(u16be(segLen))
	out.Write(exifPayload)
	out.Write(raw[2:]) // everything the encoder wrote after SOI
	return out.Bytes(), nil
}

func u16be(v uint16) []byte {
	b := make([]byte, 2)
	binary.BigEndian.PutUint16(b, v)
	return b
}

// asymmetricImage returns a small, deliberately non-square (w != h) image with distinct corner
// colors, so a dimension-transpose (or a future pixel-level orientation check) is detectable.
func asymmetricImage(w, h int) *image.RGBA {
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	corners := map[[2]int]color.RGBA{
		{0, 0}:         {255, 0, 0, 255},   // top-left: red
		{w - 1, 0}:     {0, 255, 0, 255},   // top-right: green
		{0, h - 1}:     {0, 0, 255, 255},   // bottom-left: blue
		{w - 1, h - 1}: {255, 255, 0, 255}, // bottom-right: yellow
	}
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			if c, ok := corners[[2]int{x, y}]; ok {
				img.Set(x, y, c)
			} else {
				img.Set(x, y, color.RGBA{128, 128, 128, 255})
			}
		}
	}
	return img
}

// pngWithTextChunk encodes img as a PNG, then inserts a tEXt chunk (keyword "Comment", value
// marker) immediately after the IHDR chunk.
func pngWithTextChunk(img image.Image, marker string) ([]byte, error) {
	var base bytes.Buffer
	if err := png.Encode(&base, img); err != nil {
		return nil, err
	}
	raw := base.Bytes()

	const sigLen = 8
	if len(raw) < sigLen+8 {
		return nil, fmt.Errorf("gen: encoded PNG too short")
	}
	// IHDR is always the first chunk and always 13 bytes of data: 4 (len) + 4 (type) + 13 (data)
	// + 4 (crc) = 25 bytes, immediately after the 8-byte signature.
	ihdrEnd := sigLen + 25
	if !bytes.Equal(raw[sigLen+4:sigLen+8], []byte("IHDR")) {
		return nil, fmt.Errorf("gen: expected IHDR as first chunk")
	}

	chunkData := append([]byte("Comment\x00"), []byte(marker)...)
	chunk := buildPNGChunk("tEXt", chunkData)

	var out bytes.Buffer
	out.Write(raw[:ihdrEnd])
	out.Write(chunk)
	out.Write(raw[ihdrEnd:])
	return out.Bytes(), nil
}

func buildPNGChunk(chunkType string, data []byte) []byte {
	var buf bytes.Buffer
	length := make([]byte, 4)
	binary.BigEndian.PutUint32(length, uint32(len(data)))
	buf.Write(length)

	typeAndData := append([]byte(chunkType), data...)
	buf.Write(typeAndData)

	crc := crc32.ChecksumIEEE(typeAndData)
	crcBytes := make([]byte, 4)
	binary.BigEndian.PutUint32(crcBytes, crc)
	buf.Write(crcBytes)
	return buf.Bytes()
}

func main() {
	outDir := "internal/photo/testdata"
	if len(os.Args) > 1 {
		outDir = os.Args[1]
	}

	gpsImg := asymmetricImage(6, 4)
	gpsJPEG, err := jpegWithAPP1(gpsImg, buildGPSExifTIFF())
	must(err)
	must(os.WriteFile(filepath.Join(outDir, "gps-exif.jpg"), gpsJPEG, 0o644))

	orientedImg := asymmetricImage(6, 4)
	orientedJPEG, err := jpegWithAPP1(orientedImg, buildOrientationTIFF(6))
	must(err)
	must(os.WriteFile(filepath.Join(outDir, "oriented-6.jpg"), orientedJPEG, 0o644))

	textImg := asymmetricImage(4, 4)
	textPNG, err := pngWithTextChunk(textImg, "RithamTestMarkerXYZ123")
	must(err)
	must(os.WriteFile(filepath.Join(outDir, "text-chunks.png"), textPNG, 0o644))

	// A plain synthetic JPEG (no APP1) that the caller transcodes to HEIC via
	// `sips -s format heic` -- see this file's header comment.
	synthImg := asymmetricImage(6, 4)
	var synthBuf bytes.Buffer
	must(jpeg.Encode(&synthBuf, synthImg, &jpeg.Options{Quality: 90}))
	must(os.WriteFile(filepath.Join(outDir, "gen", "heic-source.jpg"), synthBuf.Bytes(), 0o644))

	fmt.Println("wrote gps-exif.jpg, oriented-6.jpg, text-chunks.png, gen/heic-source.jpg")
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}
