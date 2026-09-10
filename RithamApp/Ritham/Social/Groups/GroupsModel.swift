import Foundation
import RithamCore

/// Drives the group list and a single group's detail/member roster at the model level, following
/// `FriendsModel`'s `@Observable`-load-from-source shape. Converts `GroupsClient`'s wire types
/// into `RithamCore`'s already-existing pure-domain types (`SocialGroup`/`GroupMembership`,
/// plan 04.1-02) rather than declaring a second, parallel set of domain types -- those types were
/// purpose-built for this exact feature and this is their first real consumer.
///
/// `state`'s `.failed` case is load-bearing, matching `FriendsModel`'s own doc comment: an
/// unreachable service or a 404 on a group detail must read as an error, never as an empty
/// result or an empty group. `groups` is left untouched on a failed `load()`; `selectedGroup`/
/// `members` are left untouched (never partially populated) on a failed `loadDetail(groupID:)` --
/// both follow `FriendsModel.load()`'s "assignment only runs once the source call has fully
/// succeeded" discipline.
///
/// **Known gap, not a defect in this plan:** `groups_handler.go` exposes exactly nine routes
/// (04.1-08-SUMMARY.md). There is no route to list a user's own pending invitations, and
/// `groups.Service` has no method to produce that list at all -- not merely unexposed over HTTP,
/// like `DeclineInvitation` is, but nonexistent. Without a way to discover a group id a user was
/// invited to, `join(groupID:)`-from-a-list and a decline action are both unreachable from any
/// screen this plan can build. This model therefore carries no `pendingInvitations` property and
/// no `declineInvitation` method -- rendering an "Invitations" section that can never populate
/// would be exactly the hardcoded-empty-value stub this project's own SUMMARY convention flags.
/// `join(groupID:)` is still implemented on `GroupsClient` (full route coverage) but has no UI
/// caller in this plan. See `04.1-11-SUMMARY.md`'s Known Stubs for the full record; a future plan
/// needs a new Go route (and, for decline, a new HTTP handler over the already-existing
/// `groups.Service.DeclineInvitation`) before either can be built.
@MainActor
@Observable
final class GroupsModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(SocialAPIError)
    }

    private(set) var groups: [SocialGroup] = []
    private(set) var selectedGroup: SocialGroup?
    private(set) var members: [GroupMembership] = []
    private(set) var state: LoadState = .idle

    private let client: GroupsClient
    private let viewerUserID: String?

    private static let dateFormatter = ISO8601DateFormatter()

    init(
        client: GroupsClient = GroupsClient(apiClient: SocialAPIClient(sessionStore: SessionStore())),
        viewerUserID: String? = SessionStore().currentUserID
    ) {
        self.client = client
        self.viewerUserID = viewerUserID
    }

    /// True when the signed-in viewer is `selectedGroup`'s organizer. `false` whenever no group
    /// is loaded or no viewer id is known -- never assumed `true` as a fallback, since an
    /// unknown-organizer state must never read as "the viewer has organizer standing."
    var viewerIsOrganizer: Bool {
        guard let selectedGroup, let viewerUserID else { return false }
        return selectedGroup.organizerUserID.value == viewerUserID
    }

    /// Whether the viewer may remove another member from `selectedGroup`, derived purely from the
    /// group's own stated `memberRemovalPolicy` plus the viewer's own organizer status -- never
    /// from a client-side assumption that the organizer can always remove (T-04.1-64). Under
    /// `.anyMember`, every member (the viewer reached this screen only by being one, via the
    /// server's own `RequireMember` gate) may remove; under `.organizerOnly`, only the organizer
    /// may. The server independently re-checks this on every removal request -- this property is
    /// convenience for what the UI offers, never the authorization boundary itself.
    var viewerCanRemoveMembers: Bool {
        guard let selectedGroup else { return false }
        switch selectedGroup.memberRemovalPolicy {
        case .anyMember:
            return true
        case .organizerOnly:
            return viewerIsOrganizer
        }
    }

    /// Loads every group the viewer is currently a member of. A throw leaves `groups` exactly as
    /// it was before this call.
    func load() async {
        state = .loading
        do {
            let responses = try await client.list()
            groups = responses.compactMap(Self.socialGroup)
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Loads one group's detail and member roster together. A throw (including the 404 a
    /// non-member or unknown group id returns) leaves `selectedGroup`/`members` exactly as they
    /// were before this call -- `selectedGroup` is never assigned a partially decoded or
    /// default-constructed value, so a failed load can never render as an empty group.
    func loadDetail(groupID: UUID) async {
        state = .loading
        do {
            async let detailTask = client.detail(groupID: groupID.uuidString)
            async let membersTask = client.members(groupID: groupID.uuidString)
            let (detailResponse, memberResponses) = try await (detailTask, membersTask)
            guard let group = Self.socialGroup(detailResponse) else {
                throw SocialAPIError.decoding
            }
            selectedGroup = group
            members = memberResponses.compactMap { Self.groupMembership(groupID: groupID, $0) }
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Creates a group, then reloads the group list so `groups` reflects the new row. Returns the
    /// newly created group's domain value, or `nil` on any failure (moving `state` to `.failed`)
    /// or an undecodable response.
    @discardableResult
    func create(name: String, policy: MemberRemovalPolicy?) async -> SocialGroup? {
        do {
            let response = try await client.create(name: name, policy: policy?.rawValue)
            guard let group = Self.socialGroup(response) else { return nil }
            await load()
            return group
        } catch {
            state = .failed(Self.socialError(error))
            return nil
        }
    }

    /// Invites `userID` (who must already be the caller's friend) into `groupID` (which the
    /// caller must already be a member of) -- both preconditions are enforced server-side only.
    func invite(groupID: UUID, userID: String) async {
        do {
            _ = try await client.invite(groupID: groupID.uuidString, userID: userID)
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Accepts a pending invitation addressed to the caller for `groupID`. Implemented for full
    /// route coverage (see this type's header comment); no screen in this plan calls it, since no
    /// screen can discover a `groupID` to pass in without the still-missing invitations-list
    /// route.
    func join(groupID: UUID) async {
        do {
            try await client.join(groupID: groupID.uuidString)
            await load()
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Leaves `groupID` with the given `disposition`, then reloads the group list -- the reload
    /// is what makes the left group absent from `groups` afterward, matching `FriendsModel`'s
    /// reload-driven-removal precedent rather than this method mutating `groups` itself.
    func leave(groupID: UUID, disposition: GroupLeaveDisposition) async {
        do {
            try await client.leave(groupID: groupID.uuidString, disposition: disposition.rawValue)
            await load()
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Removes `userID` from `groupID` at the viewer's request. Removed from `members` locally on
    /// success -- matching `FriendsModel.decline(_:)`'s no-reload-needed reasoning, since removal
    /// changes only the roster this model already holds in full.
    func removeMember(groupID: UUID, userID: String) async {
        do {
            try await client.removeMember(groupID: groupID.uuidString, userID: userID)
            members.removeAll { $0.user.id.value == userID }
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Changes `groupID`'s removal policy, then reloads its detail so `selectedGroup` reflects
    /// the change. Implemented for full route coverage; no screen in this plan calls it (see
    /// `04.1-UI-SPEC.md`'s Groups section: a policy explanation is plain body text, not an
    /// interactive editor, in this plan).
    func setRemovalPolicy(groupID: UUID, policy: MemberRemovalPolicy) async {
        do {
            try await client.setRemovalPolicy(groupID: groupID.uuidString, policy: policy.rawValue)
            await loadDetail(groupID: groupID)
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    // MARK: - Wire -> domain conversion

    private static func socialGroup(_ response: GroupResponse) -> SocialGroup? {
        guard
            let id = UUID(uuidString: response.id),
            let createdAt = dateFormatter.date(from: response.createdAt),
            let policy = MemberRemovalPolicy(rawValue: response.removalPolicy)
        else { return nil }
        return SocialGroup(
            id: id,
            name: response.name,
            organizerUserID: SocialUserID(value: response.organizerUserId),
            memberRemovalPolicy: policy,
            createdAt: createdAt
        )
    }

    private static func socialGroup(_ response: GroupDetailResponse) -> SocialGroup? {
        guard
            let id = UUID(uuidString: response.id),
            let createdAt = dateFormatter.date(from: response.createdAt),
            let policy = MemberRemovalPolicy(rawValue: response.removalPolicy)
        else { return nil }
        return SocialGroup(
            id: id,
            name: response.name,
            organizerUserID: SocialUserID(value: response.organizerUserId),
            memberRemovalPolicy: policy,
            createdAt: createdAt
        )
    }

    private static func groupMembership(groupID: UUID, _ response: MemberResponse) -> GroupMembership? {
        guard let joinedAt = dateFormatter.date(from: response.joinedAt) else { return nil }
        return GroupMembership(
            groupID: groupID,
            user: SocialUser(id: SocialUserID(value: response.userId), displayName: response.displayName),
            joinedAt: joinedAt
        )
    }

    private static func socialError(_ error: Error) -> SocialAPIError {
        (error as? SocialAPIError) ?? .transport
    }
}
