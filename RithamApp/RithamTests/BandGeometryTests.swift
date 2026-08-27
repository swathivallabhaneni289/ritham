import Testing
import CoreGraphics
@testable import Ritham

@Suite("BandGeometryTests")
struct BandGeometryTests {

    // MARK: - Flat margins are strictly positive at real portrait header sizes

    @Test("flat margins are strictly positive at 390x250")
    func flatMarginsPositiveAt390x250() {
        assertPositiveMargins(width: 390, height: 250)
    }

    @Test("flat margins are strictly positive at 393x280")
    func flatMarginsPositiveAt393x280() {
        assertPositiveMargins(width: 393, height: 280)
    }

    @Test("flat margins are strictly positive at 430x220")
    func flatMarginsPositiveAt430x220() {
        assertPositiveMargins(width: 430, height: 220)
    }

    private func assertPositiveMargins(width: CGFloat, height: CGFloat) {
        let geometry = BandGeometry()
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let margins = geometry.flatMarginFractions(in: rect)
        #expect(margins.leading > 0)
        #expect(margins.trailing > 0)
    }

    // MARK: - Computed band edges stay within the rect's bounds

    @Test("band edges stay within the rect's bounds at every portrait header size")
    func bandEdgesStayWithinBounds() {
        let geometry = BandGeometry()
        let sizes: [(CGFloat, CGFloat)] = [(390, 250), (393, 280), (430, 220)]
        for size in sizes {
            let rect = CGRect(x: 0, y: 0, width: size.0, height: size.1)
            let edges = geometry.bandEdges(in: rect, bandCount: 3)
            #expect(!edges.isEmpty)
            for edge in edges {
                #expect(edge.top.x >= rect.minX && edge.top.x <= rect.maxX)
                #expect(edge.bottom.x >= rect.minX && edge.bottom.x <= rect.maxX)
                #expect(edge.top.y == rect.minY)
                #expect(edge.bottom.y == rect.maxY)
            }
        }
    }

    // MARK: - Determinism across repeated calls with the same rect

    @Test("geometry is deterministic across repeated calls with the same rect")
    func geometryIsDeterministic() {
        let geometry = BandGeometry()
        let rect = CGRect(x: 0, y: 0, width: 390, height: 250)

        let firstMargins = geometry.flatMarginFractions(in: rect)
        let secondMargins = geometry.flatMarginFractions(in: rect)
        #expect(firstMargins.leading == secondMargins.leading)
        #expect(firstMargins.trailing == secondMargins.trailing)

        let firstEdges = geometry.bandEdges(in: rect, bandCount: 3)
        let secondEdges = geometry.bandEdges(in: rect, bandCount: 3)
        #expect(firstEdges.count == secondEdges.count)
        for (a, b) in zip(firstEdges, secondEdges) {
            #expect(a.top == b.top)
            #expect(a.bottom == b.bottom)
        }
    }

    // MARK: - Scaling width while holding height constant changes the fractions

    @Test("scaling the rect's width while holding height constant changes the fractions")
    func scalingWidthChangesFractions() {
        let geometry = BandGeometry()
        let narrow = geometry.flatMarginFractions(in: CGRect(x: 0, y: 0, width: 390, height: 250))
        let wide = geometry.flatMarginFractions(in: CGRect(x: 0, y: 0, width: 600, height: 250))
        #expect(narrow.leading != wide.leading)
        #expect(narrow.trailing != wide.trailing)
    }

    // MARK: - Sketch 003's landscape rect yields different fractions than the portrait rects,
    // which directly detects a port of its solved figures.

    @Test("sketch 003's 1440x720 landscape rect yields different fractions than the portrait rects")
    func landscapeRectDiffersFromPortraitRects() {
        let geometry = BandGeometry()
        let landscape = geometry.flatMarginFractions(in: CGRect(x: 0, y: 0, width: 1440, height: 720))

        // A generous epsilon: at these two portrait aspect ratios the gap against the landscape
        // rect is several percentage points, so this is not a knife-edge floating point check.
        // (430x220's aspect ratio is close enough to 1440x720's that the gap there is too small
        // to be a meaningful port-detection signal, so it is deliberately excluded here.)
        let epsilon = 0.01
        let portraitSizes: [(CGFloat, CGFloat)] = [(390, 250), (393, 280)]
        for size in portraitSizes {
            let portrait = geometry.flatMarginFractions(in: CGRect(x: 0, y: 0, width: size.0, height: size.1))
            #expect(abs(portrait.leading - landscape.leading) > epsilon)
        }
    }
}
