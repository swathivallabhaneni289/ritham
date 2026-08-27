import SwiftUI

/// One diagonal band of the header motif. Delegates entirely to `BandGeometry` for its polygon
/// coordinates -- `path(in:)` performs no arithmetic on literal coordinates of its own. A host
/// view draws one `BandMotif` per band index, each filled with a different palette token.
struct BandMotif: Shape {
    /// Which band, in `0..<bandCount`, this instance draws.
    var band: Int

    /// How many bands divide the composition. Defaults to 3 to match sketch 003's three-band
    /// composition (coral broadest, lime medium, off-white thin sliver).
    var bandCount: Int = 3

    /// The pure geometry this shape delegates to.
    var geometry: BandGeometry = BandGeometry()

    func path(in rect: CGRect) -> Path {
        let edges = geometry.bandEdges(in: rect, bandCount: bandCount)
        guard band >= 0, band + 1 < edges.count else { return Path() }

        let leading = edges[band]
        let trailing = edges[band + 1]

        var path = Path()
        path.move(to: leading.top)
        path.addLine(to: trailing.top)
        path.addLine(to: trailing.bottom)
        path.addLine(to: leading.bottom)
        path.closeSubpath()
        return path
    }
}
