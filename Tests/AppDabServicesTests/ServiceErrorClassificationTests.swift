@testable import AppDabServices
import Foundation
import Testing

struct ServiceErrorClassificationTests {
    @Test func classifiesURLFailuresAsNetworkErrors() {
        let error = ServiceError.classify(URLError(.timedOut))

        #expect(error.code == "network_error")
    }

    @Test func distinguishesAuthenticationFromPermissionFailures() {
        let authentication = ServiceError.classify(FixtureError(message: "HTTP status code 401"))
        let permission = ServiceError.classify(FixtureError(message: "HTTP status code 403"))

        #expect(authentication.code == "authentication_failed")
        #expect(permission.code == "permission_denied")
    }
}

private struct FixtureError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
