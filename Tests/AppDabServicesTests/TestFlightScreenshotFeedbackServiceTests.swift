@testable import AppDabServices
import BagbutikAppStoreModels
import Foundation
import Testing

struct TestFlightScreenshotFeedbackServiceTests {
    @Test func detailIdentifiesTheOwningApp() throws {
        let response = try JSONDecoder().decode(BuildResponse.self, from: Data("""
        {
          "data": {
            "type": "builds", "id": "build-1",
            "relationships": { "app": { "data": { "type": "apps", "id": "app-1" } } }
          },
          "links": { "self": "https://api.appstoreconnect.apple.com/v1/builds/build-1" }
        }
        """.utf8))

        #expect(try TestFlightScreenshotFeedbackService.owningAppID(of: response) == "app-1")
        let missingOwner = BuildResponse(data: .init(id: "build-2"), links: response.links)
        #expect(throws: ServiceError.upstream("App Store Connect did not return the screenshot feedback’s app.")) {
            try TestFlightScreenshotFeedbackService.owningAppID(of: missingOwner)
        }
    }
}
