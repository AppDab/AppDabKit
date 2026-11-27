@testable import AppDabServices
import BagbutikAppStoreModels
import Foundation
import Testing

struct BuildDetailTests {
    @Test func detailIdentifiesTheOwningApp() throws {
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

        let build = BuildService.buildDetails(response)
        #expect(build.testFlight?.appID == "app-1")
        #expect(build.buildNumber == "42")
        #expect(build.prereleaseVersion == "2.1")
        #expect(build.testFlight?.localizations == [])
        #expect(build.testFlight?.bundles == [])

        let missingOwner = BuildResponse(data: .init(id: "build-2"), links: response.links)
        #expect(BuildService.buildDetails(missingOwner).testFlight?.appID == nil)
    }
}
