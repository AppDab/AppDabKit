@testable import AppDabServices
import BagbutikCore
import Testing

struct BetaGroupServiceTests {
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
