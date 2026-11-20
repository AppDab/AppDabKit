@testable import AppDabServices
import Foundation
import Testing

private actor DeadlineRequests {
    var count = 0
    func record() {
        count += 1
    }
}

struct MediaRequestDeadlineTests {
    @Test func anExpiredBudgetDoesNotStartAnotherRequest() async throws {
        let requests = DeadlineRequests()
        let request = try URLRequest(url: #require(URL(string: "https://api.appstoreconnect.apple.com/v1/apps")))
        await #expect(throws: ServiceError.self) {
            try await MediaRequestDeadline.fetch(request, delegate: nil, deadline: .now.advanced(by: .seconds(-1))) { request, _ in
                await requests.record()
                return (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
            }
        }
        #expect(await requests.count == 0)
    }
}
