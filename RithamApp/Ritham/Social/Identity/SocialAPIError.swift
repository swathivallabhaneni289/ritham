import Foundation

/// Every failure mode `SocialAPIClient` can surface. Generalizes `WorkoutPlanClientError`'s
/// three-case shape (`RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift`) with the one case
/// social features need that the plan endpoint did not: an authenticated call can be rejected for
/// identity reasons specifically -- an expired, revoked, or never-issued session -- and the UI must
/// be able to route that to a re-sign-in rather than to a generic failure.
///
/// An unreachable Ritham backend must read as an error here, never as an empty or zero result --
/// a group feed rendering "no posts yet" when the network actually failed is exactly the bug this
/// enum exists to prevent (T-04.1-26, the same rule `WorkoutPlanClientError`'s own doc comment
/// states for the plan-generation endpoint).
enum SocialAPIError: Error, Equatable {
    /// The request never reached the service, or no response came back at all.
    case transport

    /// The server rejected the request specifically because the session token was missing,
    /// expired, or revoked (HTTP 401 from any Ritham identity-gated route). The caller routes this
    /// to a re-sign-in prompt, never a generic error banner.
    case unauthenticated

    /// The service responded with a non-2xx, non-401 status code.
    case httpStatus(Int)

    /// The response body did not decode into the expected shape.
    case decoding
}
