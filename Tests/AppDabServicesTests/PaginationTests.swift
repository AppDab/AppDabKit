@testable import AppDabServices
import BagbutikCore
import Testing

struct PaginationTests {
    @Test func extractsAppleCursorTokenFromAnEncodedContinuationURL() throws {
        let url = "https://api.appstoreconnect.apple.com/v1/apps?filter%5BappStoreVersions.appStoreState%5D=ACCEPTED%2CDEVELOPER_REJECTED&include=appStoreVersions%2CappStoreIcon&limit%5BappStoreVersions%5D=50&sort=name&cursor=AoIsVUNwQVBpcE9XZ0E9KjY0NDQzMzg2MzA%3D&limit=10"

        #expect(try PaginationCursor.extract(from: url) == "AoIsVUNwQVBpcE9XZ0E9KjY0NDQzMzg2MzA=")
    }

    @Test func rejectsInvalidUpstreamContinuationURLs() {
        for url in [
            "https://api.appstoreconnect.apple.com/v1/apps?limit=10",
            "https://api.appstoreconnect.apple.com/v1/apps?cursor=",
            "https://api.appstoreconnect.apple.com/v1/apps?cursor=one&cursor=two",
            "https://[invalid"
        ] {
            #expect(throws: ServiceError.upstream("App Store Connect returned an invalid pagination cursor.")) {
                try PaginationCursor.extract(from: url)
            }
        }
    }

    @Test func acceptsOpaqueTokensAndRejectsWhitespace() throws {
        #expect(try PaginationRequest(cursor: "AoIsVUNwQVBpcE9XZ0E9KjY0NDQzMzg2MzA=", limit: 10).validatedCursor() == "AoIsVUNwQVBpcE9XZ0E9KjY0NDQzMzg2MzA=")
        #expect(try PaginationRequest(cursor: "opaque:token", limit: 10).validatedCursor() == "opaque:token")
        #expect(try PaginationRequest(cursor: "https://api.appstoreconnect.apple.com/v1/apps", limit: 10).validatedCursor() == "https://api.appstoreconnect.apple.com/v1/apps")

        for cursor in ["", "has space", " https://api.appstoreconnect.apple.com/v1/apps"] {
            #expect(throws: ServiceError.invalidArguments("Argument cursor must be an opaque pagination token.")) {
                try PaginationRequest(cursor: cursor, limit: 10).validate()
            }
        }
    }

    @Test func addsTheCursorWithoutChangingTheOriginalRequestConfiguration() {
        let original = Request<String, String>(
            path: "/v1/apps",
            method: .get,
            parameters: .init(limit: 10, customs: ["existing": "value"])
        )
        let continuation = original.withPaginationCursor("opaque=value")

        #expect(continuation.path == "/v1/apps")
        #expect(continuation.method == .get)
        #expect(continuation.parameters?.limit == 10)
        #expect(continuation.parameters?.customs?["existing"] == "value")
        #expect(continuation.parameters?.customs?["cursor"] == "opaque=value")
    }
}
