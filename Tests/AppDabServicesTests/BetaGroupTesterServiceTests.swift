@testable import AppDabServices
import BagbutikCore
import Testing

struct BetaGroupTesterServiceTests {
    @Test func membershipLookupTargetsOneTesterInOneGroup() {
        let request = BetaGroupTesterService.membershipRequest(betaGroupID: "group-1", testerID: "tester-1")

        #expect(request.path == "/v1/betaTesters")
        #expect(request.parameters?.filters?.map(\.caseName) == ["betaGroups", "id"])
        #expect(request.parameters?.filters?.map(\.value) == ["group-1", "tester-1"])
        #expect(request.parameters?.limits?.first?.value == 1)
    }
}
