@testable import AppDabServices
import BagbutikCore
import Foundation
import Testing

struct BetaGroupServiceTests {
    @Test func updateRequestOmitsUnspecifiedFieldsAndPreservesFalse() throws {
        let body = BetaGroupService.updateRequestBody(
            betaGroupID: "group-1", changes: .init(name: "Renamed", feedbackEnabled: false)
        )
        let payload = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(body))
        let data = try #require(payload.objectValue?["data"]?.objectValue)
        let attributes = try #require(data["attributes"]?.objectValue)

        #expect(data["id"] == .string("group-1"))
        #expect(attributes == ["name": .string("Renamed"), "feedbackEnabled": .bool(false)])
    }

    @Test func listRequestScopesToAppAndPreservesCursor() throws {
        let request = try BetaGroupService.listRequest(appID: "app-1", pagination: .init(cursor: "next-page", limit: 25))
        #expect(request.path == "/v1/betaGroups")
        #expect(request.parameters?.filters?.map(\.caseName) == ["app"])
        #expect(request.parameters?.filters?.map(\.value) == ["app-1"])
        #expect(request.parameters?.limits?.first?.value == 25)
    }

    @Test func membershipRequestChecksOneBuildAndOneGroup() {
        let request = BetaGroupService.membershipRequest(betaGroupID: "group-1", buildID: "build-1")
        #expect(request.path == "/v1/betaGroups")
        #expect(request.parameters?.filters?.map(\.caseName) == ["id", "builds"])
        #expect(request.parameters?.filters?.map(\.value) == ["group-1", "build-1"])
        #expect(request.parameters?.limits?.first?.value == 1)
    }
}
