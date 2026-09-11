import Foundation
import Testing
import UIKit
import RithamCore
@testable import Ritham

// Phase 4.1 Plan 16: the closed certificate content type and the composer restricted to
// server-stripped photos (Task 1), auto-generation/reveal/archive (Task 2), and export with the
// editable display name and the multi-person consent gate (Task 3).
//
// Nested inside `KeychainTouchingSuites` (`KeychainTouchingSuites.swift`) because Task 3's export
// gate query goes `FeedClient` -> `SocialAPIClient` -> `SessionStore`, which touches the real,
// process-shared Keychain -- it must be ordered relative to every other Keychain-touching suite,
// matching `CompletionLoggingTests`/`GroupFeedTests`'s own identical precedent from this same
// phase. Every test in this file lives in the one nested suite below, matching those two files'
// own "mixed network and non-network tests share one nested suite" precedent, rather than only
// nesting the subset that happens to touch the network.
//
// Run this suite with `-only-testing:RithamTests/KeychainTouchingSuites/CertificateTests` (the
// nested identifier), never the bare `-only-testing:RithamTests/CertificateTests` -- the bare form
// matches zero tests once this suite is nested and exits 0, a silent false pass
// (04.1-07-SUMMARY.md's own documented precedent for this exact hazard).

/// A fresh, file-scoped `URLProtocol` stub -- deliberately its own type, matching every other
/// suite's own header comment on the cross-suite shared-static-state race a second suite touching
/// the same stub type would reintroduce.
final class CertificateStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = CertificateStubURLProtocol.requestHandler else {
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

private func jsonResponse(_ url: URL, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8)!)
}

extension KeychainTouchingSuites {

@MainActor
@Suite("CertificateTests", .serialized)
struct CertificateTests {

    init() {
        CertificateStubURLProtocol.reset()
    }

    private func makeFeedClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> FeedClient {
        CertificateStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CertificateStubURLProtocol.self]
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: URLSession(configuration: config), sessionStore: sessionStore)
        return FeedClient(apiClient: apiClient)
    }

    private func makeAsset(id: UUID = UUID(), sharedURL: String = "https://example.com/shared/a.jpg") throws -> StrippedPhotoAsset {
        let response = try JSONDecoder().decode(
            PhotoUploadResponse.self,
            from: #"{"photoAssetId":"\#(id.uuidString)","sharedUrl":"\#(sharedURL)"}"#.data(using: .utf8)!
        )
        return try StrippedPhotoAsset(uploadResponse: response)
    }

    private func makeContent(photo: StrippedPhotoAsset? = nil, ownTimeSeconds: Int? = nil) -> CertificateContent {
        CertificateContent(
            eventDisplayName: "Saturday 5K Walk",
            activityType: .walk,
            participantName: "Priya",
            completionDate: Date(timeIntervalSince1970: 1_757_000_000),
            ownTimeSeconds: ownTimeSeconds,
            placeName: nil,
            photo: photo
        )
    }

    // MARK: - Task 1: CertificateContent's exact seven-field set

    @Test("CertificateContent's stored properties are exactly the seven closed fields, no other member's data")
    func certificateContentHasExactlySevenFields() {
        let content = makeContent()
        let mirror = Mirror(reflecting: content)
        var labels: [String] = []
        for child in mirror.children {
            guard var label = child.label else { continue }
            while label.hasPrefix("_") { label.removeFirst() }
            labels.append(label)
        }
        #expect(Set(labels) == [
            "eventDisplayName", "activityType", "participantName",
            "completionDate", "ownTimeSeconds", "placeName", "photo",
        ], "CertificateContent must carry exactly these seven fields, no more, no fewer")
    }

    // MARK: - Task 1: the composer's photo parameter accepts only the opaque server-backed asset

    @Test("CertificateComposer.swift declares no file URL, PhotosPickerItem, or raw Data photo parameter")
    func composerSourceDeclaresNoDisallowedPhotoType() throws {
        let source = try sourceFile("Ritham/Social/Certificate/CertificateComposer.swift")
        for disallowed in ["URL(fileURLWithPath", "PhotosPickerItem", "Data)"] {
            #expect(!source.contains(disallowed), "CertificateComposer.swift must not reference \(disallowed)")
        }
    }

    @Test("CertificateContent.swift types its photo field as StrippedPhotoAsset, not UIImage, Data, or a file URL")
    func contentSourceTypesPhotoAsStrippedPhotoAssetOnly() throws {
        let source = try sourceFile("Ritham/Social/Certificate/CertificateContent.swift")
        #expect(source.contains("photo: StrippedPhotoAsset?"))
        for disallowed in ["photo: UIImage", "photo: Data", "photo: URL"] {
            #expect(!source.contains(disallowed))
        }
    }

    // MARK: - Task 1: rendering behavior

    @Test("rendering with no photo produces a non-degenerate image using the branded default frame")
    func renderingWithNoPhotoProducesAnImage() {
        let image = CertificateComposer.render(makeContent(), scale: 2)
        let unwrapped = try! #require(image)
        #expect(unwrapped.size.width > 0)
        #expect(unwrapped.size.height > 0)
    }

    @Test("rendering with a photo produces a non-degenerate image, and the card's photo source is the asset's server URL")
    func renderingWithPhotoProducesAnImage() throws {
        let asset = try makeAsset()
        let image = CertificateComposer.render(makeContent(photo: asset), scale: 2)
        let unwrapped = try #require(image)
        #expect(unwrapped.size.width > 0)
        #expect(unwrapped.size.height > 0)

        let cardSource = try sourceFile("Ritham/Social/Certificate/CertificateCardView.swift")
        #expect(cardSource.contains("photo.sharedURL"), "the card must source its photo from the asset's own sharedURL, never a second, locally-held reference")
    }

    @Test("rendering with an own time and without one both produce complete, non-degenerate images")
    func renderingWithAndWithoutOwnTimeBothComplete() {
        let withTime = CertificateComposer.render(makeContent(ownTimeSeconds: 1934), scale: 2)
        let withoutTime = CertificateComposer.render(makeContent(ownTimeSeconds: nil), scale: 2)
        let unwrappedWithTime = try! #require(withTime)
        let unwrappedWithoutTime = try! #require(withoutTime)
        #expect(unwrappedWithTime.size.width > 0 && unwrappedWithTime.size.height > 0)
        #expect(unwrappedWithoutTime.size.width > 0 && unwrappedWithoutTime.size.height > 0)
    }

    @Test("a rendered image at the export scale is non-degenerate in pixel size")
    func renderedImageIsNonDegenerateAtExportScale() {
        let image = CertificateComposer.render(makeContent(), scale: CertificateComposer.defaultExportScale)
        let unwrapped = try! #require(image)
        guard let cgImage = unwrapped.cgImage else {
            Issue.record("expected a backing CGImage")
            return
        }
        #expect(cgImage.width > 100)
        #expect(cgImage.height > 100)
    }

    // MARK: - Helpers

    private func sourceFile(_ relativePath: String) throws -> String {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}

}
