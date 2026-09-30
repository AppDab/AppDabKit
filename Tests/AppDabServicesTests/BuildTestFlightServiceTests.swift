@testable import AppDabServices
import BagbutikCore
import Testing

struct BuildTestFlightServiceTests {
    @Test func erMembershipUsesBoundedServerSideFilters() {
        let request = BuildTestFlightService.testerMembershipRequest(buildID: "build-1", testerID: "tester-1")

        #expect(request.path == "/v1/betaTesters")
        #expect(request.parameters?.filters?.map(\.caseName) == ["builds", "id"])
        #expect(request.parameters?.filters?.map(\.value) == ["build-1", "tester-1"])
        #expect(request.parameters?.limits?.first?.value == 1)
    }

    @Test func groupMembershipUsesBoundedServerSideFilters() {
        let request = BuildTestFlightService.groupMembershipRequest(buildID: "build-1", groupID: "group-1")

        #expect(request.path == "/v1/betaGroups")
        #expect(request.parameters?.filters?.map(\.caseName) == ["builds", "id"])
        #expect(request.parameters?.filters?.map(\.value) == ["build-1", "group-1"])
        #expect(request.parameters?.limits?.first?.value == 1)
    }
}
