import Foundation
import Testing
import RithamCore
@testable import Ritham

// Phase 4.1 Plan 11's group surface. Task 1 covers GroupsClient's exact wire contract and
// GroupsModel's behaviors, with no real network access, against a file-scoped stubbed
// `URLProtocol` (FriendsUITests's own pattern for this phase). Tasks 2/3 extend this same file
// with source-level structural assertions in the style `Phase4CoverageTests` already uses.

/// A fresh, file-scoped `URLProtocol` stub -- deliberately its own type, not
/// `FriendsStubURLProtocol` or any other suite's stub. Every one of those types' own header
/// comments documents the cross-suite shared-static-state race a second suite touching the same
/// stub type would reintroduce (the class of bug that cost plan 02-16 ten verification runs).
/// `.serialized` on the suite below is what keeps this file's own tests from interleaving with
/// each other.
final class GroupsStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = GroupsStubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [GroupsStubURLProtocol.self]
    return URLSession(configuration: config)
}

private func jsonResponse(_ url: URL, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8)!)
}

@MainActor
@Suite("GroupsUITests", .serialized)
struct GroupsUITests {

    init() {
        GroupsStubURLProtocol.reset()
        SessionStore().clear()
    }

    private func makeClientAndSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> (GroupsClient, SessionStore) {
        GroupsStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        return (GroupsClient(apiClient: apiClient), sessionStore)
    }

    // MARK: - Wire contract: exact key sets (mirrors FriendsUITests' own D2-style assertions)

    @Test("CreateGroupRequest encodes exactly the two keys the Go contract declares")
    func createGroupRequestEncodesExactKeys() throws {
        let request = CreateGroupRequest(name: "Saturday Crew", removalPolicy: "anyMember")
        #expect(try encodedKeys(request) == ["name", "removalPolicy"])
    }

    @Test("InviteToGroupRequest encodes exactly the one key the Go contract declares")
    func inviteToGroupRequestEncodesExactKeys() throws {
        let request = InviteToGroupRequest(inviteeUserId: "user-2")
        #expect(try encodedKeys(request) == ["inviteeUserId"])
    }

    @Test("LeaveGroupRequest's encoded body carries exactly one key: disposition")
    func leaveGroupRequestBodyHasExactlyOneKey() throws {
        let request = LeaveGroupRequest(disposition: "keepPosts")
        #expect(try encodedKeys(request) == ["disposition"])
    }

    @Test("SetRemovalPolicyRequest encodes exactly the one key the Go contract declares")
    func setRemovalPolicyRequestEncodesExactKeys() throws {
        let request = SetRemovalPolicyRequest(removalPolicy: "organizerOnly")
        #expect(try encodedKeys(request) == ["removalPolicy"])
    }

    /// No request struct in `GroupsClient.swift` declares a field naming the acting user -- every
    /// encoded key set above is checked against a banned-name list, the same class of mistake
    /// `groups_handler.go`'s own header comment (T-04.1-35) forbids server-side.
    @Test("no request struct's key set names the acting user")
    func noRequestStructNamesTheActingUser() throws {
        let bannedNames: Set<String> = ["userId", "actorId", "callerId", "requesterId", "organizerId"]
        let allKeySets = [
            try encodedKeys(CreateGroupRequest(name: "n", removalPolicy: "")),
            try encodedKeys(InviteToGroupRequest(inviteeUserId: "u")),
            try encodedKeys(LeaveGroupRequest(disposition: "keepPosts")),
            try encodedKeys(SetRemovalPolicyRequest(removalPolicy: "anyMember")),
        ]
        for keys in allKeySets {
            #expect(bannedNames.isDisjoint(with: keys), "a request struct's key set \(keys) names the acting user")
        }
    }

    private func encodedKeys<Body: Encodable>(_ body: Body) throws -> Set<String> {
        let data = try JSONEncoder().encode(body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set(object.map { Array($0.keys) } ?? [])
    }

    // MARK: - Transport failure never reads as an empty result (T-04.1-26, matching FriendsModel)

    @Test("a transport failure during list load leaves the groups array unchanged and the state failed")
    func aTransportFailureDuringListLoadLeavesGroupsUnchangedAndStateFailed() async throws {
        let (client, _) = makeClientAndSession { _ in throw URLError(.cannotConnectToHost) }
        let model = GroupsModel(client: client, viewerUserID: "user-1")

        await model.load()

        #expect(model.groups.isEmpty)
        #expect(model.state == .failed(.transport))
    }

    // MARK: - A 404 on group detail never renders as an empty group (this plan's own must_haves)

    @Test("a failed group detail load moves state to failed and never populates selectedGroup as an empty group")
    func aFailedGroupDetailLoadDoesNotRenderAsAnEmptyGroup() async throws {
        let groupID = UUID()
        let (client, _) = makeClientAndSession { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        let model = GroupsModel(client: client, viewerUserID: "user-1")

        await model.loadDetail(groupID: groupID)

        #expect(model.selectedGroup == nil, "a failed detail load populated selectedGroup -- a 404 must never render as an empty group")
        #expect(model.state == .failed(.httpStatus(404)))
    }

    // MARK: - Leaving removes the group from the reloaded list (this plan's own behavior list)

    @Test("after a successful leave, the group is absent from the reloaded list")
    func afterASuccessfulLeaveTheGroupIsAbsentFromTheReloadedList() async throws {
        let groupID = UUID()
        nonisolated(unsafe) var listCallCount = 0
        let (client, _) = makeClientAndSession { request in
            let path = request.url!.path
            if path.hasSuffix("/leave") {
                return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
            }
            if path == "/v1/groups" {
                listCallCount += 1
                if listCallCount == 1 {
                    return jsonResponse(request.url!, body: #"{"groups":[{"id":"\#(groupID.uuidString)","name":"Saturday Crew","organizerUserId":"user-1","removalPolicy":"anyMember","createdAt":"2026-01-01T00:00:00Z"}]}"#)
                }
                return jsonResponse(request.url!, body: #"{"groups":[]}"#)
            }
            Issue.record("unexpected request to \(path)")
            return jsonResponse(request.url!, status: 500, body: "{}")
        }
        let model = GroupsModel(client: client, viewerUserID: "user-1")

        await model.load()
        #expect(model.groups.map(\.id) == [groupID])

        await model.leave(groupID: groupID, disposition: .keepPastPosts)

        #expect(model.groups.isEmpty, "the left group is still present in the reloaded list")
    }

    // MARK: - viewerCanRemoveMembers/viewerIsOrganizer are policy-derived, never an organizer-always assumption (T-04.1-64)

    @Test("under an anyMember policy, any member (including a non-organizer) may remove")
    func underAnyMemberPolicyAnyMemberMayRemove() async throws {
        let groupID = UUID()
        let (client, _) = makeClientAndSession { request in
            let path = request.url!.path
            if path == "/v1/groups/\(groupID.uuidString)" {
                return jsonResponse(request.url!, body: #"{"id":"\#(groupID.uuidString)","name":"Crew","organizerUserId":"organizer-1","removalPolicy":"anyMember","createdAt":"2026-01-01T00:00:00Z","memberCount":2}"#)
            }
            return jsonResponse(request.url!, body: #"{"members":[]}"#)
        }
        let model = GroupsModel(client: client, viewerUserID: "non-organizer-user")

        await model.loadDetail(groupID: groupID)

        #expect(model.viewerIsOrganizer == false)
        #expect(model.viewerCanRemoveMembers == true, "anyMember policy must permit any member to remove, regardless of organizer status")
    }

    @Test("under an organizerOnly policy, only the organizer may remove")
    func underOrganizerOnlyPolicyOnlyTheOrganizerMayRemove() async throws {
        let groupID = UUID()
        let (client, _) = makeClientAndSession { request in
            let path = request.url!.path
            if path == "/v1/groups/\(groupID.uuidString)" {
                return jsonResponse(request.url!, body: #"{"id":"\#(groupID.uuidString)","name":"Crew","organizerUserId":"organizer-1","removalPolicy":"organizerOnly","createdAt":"2026-01-01T00:00:00Z","memberCount":2}"#)
            }
            return jsonResponse(request.url!, body: #"{"members":[]}"#)
        }
        let nonOrganizerModel = GroupsModel(client: client, viewerUserID: "non-organizer-user")
        await nonOrganizerModel.loadDetail(groupID: groupID)
        #expect(nonOrganizerModel.viewerCanRemoveMembers == false, "organizerOnly policy must not permit a non-organizer to remove")

        let organizerModel = GroupsModel(client: client, viewerUserID: "organizer-1")
        await organizerModel.loadDetail(groupID: groupID)
        #expect(organizerModel.viewerIsOrganizer == true)
        #expect(organizerModel.viewerCanRemoveMembers == true, "organizerOnly policy must permit the organizer to remove")
    }

    // MARK: - The transient group-selection carrier (Task 1's own behavior list)

    @Test("selectedGroupID defaults to nil, is settable, and appends nothing to the navigation path by itself")
    func selectedGroupIDDefaultsNilIsSettableAndAppendsNothingToPath() {
        let flow = OnboardingFlow()
        #expect(flow.selectedGroupID == nil)

        let groupID = UUID()
        flow.selectedGroupID = groupID

        #expect(flow.selectedGroupID == groupID)
        #expect(flow.path.isEmpty, "setting selectedGroupID must not append to the navigation path by itself")
    }

    // MARK: - Source-level assertions added by later tasks in this same plan (Phase4CoverageTests
    // style, matching FriendsUITests's own Task-1-then-Task-3-extends-the-same-file precedent)

    /// Resolves `RithamApp/Ritham/` relative to this file's own `#filePath`, the same technique
    /// `FriendsUITests.rithamDirectory`/`Phase4CoverageTests.rithamDirectory` use.
    private var rithamDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    private func nonCommentSource(of relativePath: String) throws -> String {
        let fileURL = rithamDirectory.appendingPathComponent(relativePath)
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}
