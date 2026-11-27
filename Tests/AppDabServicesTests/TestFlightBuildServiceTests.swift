@testable import AppDabServices
import BagbutikAppStoreModels
import Foundation
import Testing

struct TestFlightBuildServiceTests {
    @Test func detailsRequireTheSelectedApp() throws {
        let response = try JSONDecoder().decode(BuildResponse.self, from: Data("""
        {
          "data": {
            "type": "builds", "id": "build-1", "attributes": { "version": "42" },
            "relationships": {
              "app": { "data": { "type": "apps", "id": "app-1" } },
              "preReleaseVersion": { "data": { "type": "preReleaseVersions", "id": "version-1" } }
            }
          },
          "included": [{
            "type": "preReleaseVersions", "id": "version-1",
            "attributes": { "version": "2.1", "platform": "IOS" }
          }],
          "links": { "self": "https://api.appstoreconnect.apple.com/v1/builds/build-1" }
        }
        """.utf8))

        let detail = try TestFlightBuildService.detail(response, appID: "app-1")
        #expect(detail.build.buildNumber == "42")
        #expect(detail.build.version == "2.1")
        #expect(detail.build.platform == "IOS")
        #expect(throws: ServiceError.invalidArguments("The build is unavailable for the selected app.")) {
            try TestFlightBuildService.detail(response, appID: "app-2")
        }
    }
}
