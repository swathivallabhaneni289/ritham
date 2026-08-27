import CoreGraphics
import Foundation

/// Pure geometry for the diagonal "band motif" header ornament -- no SwiftUI dependency, so its
/// behaviour is unit-testable without rendering.
///
/// Any hardcoded numeric coordinate in this file is a defect: sketch 003's `background.svg` was
/// solved for its own 1440x720 landscape canvas (~25% flat charcoal on the left, ~20% on the
/// right, verified by computing exact edge-crossing x-positions -- see
/// `.planning/sketches/003-band-motif-asset/README.md`, "Geometry note"). Slice-cropping that
/// same coordinate space into a ~390x844 portrait viewport keeps the middle of the composition
/// and discards both flat margins -- a real, already-verified bug, not a hypothetical one
/// (01-UI-SPEC.md, Visual Motif). The only fixed input this type accepts is the band angle;
/// every position returned below is re-derived from the caller's own `rect` at call time using
/// the same edge-crossing method, not ported.
///
/// Derivation: at `angleDegrees` from horizontal, a line crossing the full height of `rect`
/// travels `span = rect.height / tan(angleDegrees)` horizontally -- this is the horizontal
/// "room" the diagonal composition needs for this rect's own aspect ratio. The remaining width
/// `remaining = rect.width - span` is split so the band zone itself occupies half of it
/// (`remaining / 2`) and each flat margin gets a quarter (`remaining / 4`) -- `1/2` and `1/4` are
/// dimensionless proportion divisors of a value computed from `rect`, not coordinates carried
/// over from sketch 003.
struct BandGeometry {
    /// Degrees measured from horizontal. 57 matches sketch 003's "steep, not a literal 45
    /// degrees" composition.
    let angleDegrees: Double

    init(angleDegrees: Double = 57) {
        self.angleDegrees = angleDegrees
    }

    /// The horizontal distance a line at `angleDegrees` travels crossing the full height of
    /// `rect`.
    private func diagonalSpan(in rect: CGRect) -> Double {
        let radians = angleDegrees * .pi / 180
        let tangent = tan(radians)
        guard tangent.isFinite, tangent != 0 else { return 0 }
        return abs(Double(rect.height) / tangent)
    }

    /// The fraction of `rect.width` that stays flat and free of any diagonal band at every
    /// visible row, on the leading and trailing sides. Both values are always equal by
    /// construction (a symmetric split of the space left over once the diagonal's own slant is
    /// reserved) -- returned as a pair because callers reason about "leading" and "trailing"
    /// independently.
    func flatMarginFractions(in rect: CGRect) -> (leading: Double, trailing: Double) {
        guard rect.width > 0 else { return (0, 0) }
        let span = diagonalSpan(in: rect)
        let remaining = Double(rect.width) - span
        guard remaining > 0 else { return (0, 0) }
        let margin = remaining / 4
        let fraction = margin / Double(rect.width)
        return (fraction, fraction)
    }

    /// Where each of `bandCount + 1` band-boundary lines crosses `rect`'s top (`rect.minY`) and
    /// bottom (`rect.maxY`) edges. Boundary `0` is the composition's leading edge; boundary
    /// `bandCount` is its trailing edge; consecutive boundaries bound one band each.
    func bandEdges(in rect: CGRect, bandCount: Int) -> [(top: CGPoint, bottom: CGPoint)] {
        guard bandCount > 0, rect.width > 0, rect.height > 0 else { return [] }
        let span = diagonalSpan(in: rect)
        let remaining = Double(rect.width) - span
        guard remaining > 0 else { return [] }

        let zoneWidth = remaining / 2
        let margin = remaining / 4
        let leadingX = Double(rect.minX) + margin

        return (0...bandCount).map { index in
            let bottomX = leadingX + zoneWidth * Double(index) / Double(bandCount)
            let topX = bottomX + span
            return (
                top: CGPoint(x: topX, y: Double(rect.minY)),
                bottom: CGPoint(x: bottomX, y: Double(rect.maxY))
            )
        }
    }
}
