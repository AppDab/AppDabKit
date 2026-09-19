@testable import AppDabAutomation
import Foundation
import Testing

struct AutomationOpenRequestTests {
    @Test func parsesAppOpenUrl() throws {
        let request = AutomationOpenRequest(
            requestID: "request-1",
            destination: .app,
            accountID: "account-1",
            appID: "app-1"
        )
        let url = try #require(request.url)

        let parsed = AutomationOpenRequest.parse(url: url)

        #expect(parsed == request)
    }

    @Test func storesAndTakesPendingRequest() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "AutomationOpenRequestTests"))
        userDefaults.removePersistentDomain(forName: "AutomationOpenRequestTests")
        let request = AutomationOpenRequest(destination: .customerReviews, accountID: "account-1", appID: "app-1")

        try AutomationOpenRequestStore.savePendingRequest(request, userDefaults: userDefaults)

        #expect(AutomationOpenRequestStore.takePendingRequest(userDefaults: userDefaults) == request)
        #expect(AutomationOpenRequestStore.takePendingRequest(userDefaults: userDefaults) == nil)
    }

    @Test func matchingURLDeliveryConsumesItsPendingRequest() throws {
        let userDefaults = try #require(UserDefaults(suiteName: "AutomationOpenRequestMatchingTests"))
        userDefaults.removePersistentDomain(forName: "AutomationOpenRequestMatchingTests")
        let request = AutomationOpenRequest(
            requestID: "request-1",
            destination: .app,
            accountID: "account-1",
            appID: "app-1"
        )

        try AutomationOpenRequestStore.savePendingRequest(request, userDefaults: userDefaults)

        #expect(AutomationOpenRequestStore.takePendingRequest(
            matching: "request-1",
            userDefaults: userDefaults
        ) == request)
        #expect(AutomationOpenRequestStore.takePendingRequest(
            matching: "request-1",
            userDefaults: userDefaults
        ) == nil)
    }

    @Test func latestPendingRequestReplacesAnEarlierRequest() throws {
        let suiteName = "AutomationOpenRequestLatestTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let first = AutomationOpenRequest(
            requestID: "request-1",
            destination: .app,
            accountID: "account-1",
            appID: "app-1"
        )
        let second = AutomationOpenRequest(
            requestID: "request-2",
            destination: .customerReviews,
            accountID: "account-1",
            appID: "app-2"
        )

        try AutomationOpenRequestStore.savePendingRequest(first, userDefaults: userDefaults)
        try AutomationOpenRequestStore.savePendingRequest(second, userDefaults: userDefaults)

        #expect(AutomationOpenRequestStore.takePendingRequest(
            matching: "request-1",
            userDefaults: userDefaults
        ) == nil)
        #expect(AutomationOpenRequestStore.takePendingRequest(
            matching: "request-2",
            userDefaults: userDefaults
        ) == second)
    }

    @Test func sceneActivationConsumesTheLatestPendingRequest() throws {
        let suiteName = "AutomationOpenRequestActivationTests"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let request = AutomationOpenRequest(
            requestID: "request-1",
            destination: .app,
            accountID: "account-1",
            appID: "app-1"
        )

        try AutomationOpenRequestStore.savePendingRequest(request, userDefaults: userDefaults)

        #expect(AutomationOpenRequestStore.takePendingRequest(userDefaults: userDefaults) == request)
    }
}
