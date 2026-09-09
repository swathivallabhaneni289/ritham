import Foundation

/// UI-SPEC Cheer Reaction Component: the fixed, non-ranked cheer set, exactly two, transcribed
/// verbatim from REQUIREMENTS.md's `HOUSEHOLD-01` wording ("nice work"/"keep going"). This is
/// Ritham's first implementation of this mechanic (see 04.1-UI-SPEC.md's Cheer Reaction Component
/// section) -- `HOUSEHOLD-01` (Phase 4 round 2) should reuse this exact type and copy, not build a
/// second one.
public enum Cheer: String, CaseIterable, Sendable, Equatable, Codable {
    case niceWork
    case keepGoing
}

/// A single member's cheer on a completion. No numeric field of any kind -- `sentByMe` is a
/// per-viewer boolean, so no surface downstream can compute or display a cheer count or a
/// "most-cheered" ranking.
public struct CheerReaction: Sendable, Equatable, Codable {
    public var completionID: UUID
    public var cheer: Cheer
    public var sentByMe: Bool

    public init(completionID: UUID, cheer: Cheer, sentByMe: Bool) {
        self.completionID = completionID
        self.cheer = cheer
        self.sentByMe = sentByMe
    }
}
