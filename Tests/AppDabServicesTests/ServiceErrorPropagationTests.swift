@testable import AppDabServices
import BagbutikCore
import Foundation
import Testing

struct ServiceErrorPropagationTests {
    @Test(arguments: ["listApps", "getApp", "createVersion", "listReviews", "getReview", "verify"])
    func servicesPreserveTypedPermissionFailures(operation: String) async throws {
        do {
            try await invoke(operation, failure: BagbutikCore.ServiceError.forbidden(.init(errors: [
                .init(code: "FORBIDDEN", detail: "Resource not found 404", status: "403", title: "Denied")
            ])))
            Issue.record("Expected a permission failure.")
        } catch let error as AppDabServices.ServiceError {
            guard case .permissionDenied = error else {
                Issue.record("Expected permissionDenied, received \(error).")
                return
            }
            #expect(error.diagnostics?.httpStatusCode == 403)
            #expect(error.diagnostics?.response?.errors?.first?.code == "FORBIDDEN")
        }
    }

    @Test(arguments: ["listApps", "getApp", "createVersion", "listReviews", "getReview", "verify"])
    func servicesPreserveCancellation(operation: String) async throws {
        await #expect(throws: CancellationError.self) {
            try await invoke(operation, failure: CancellationError())
        }
        await #expect(throws: URLError(.cancelled)) {
            try await invoke(operation, failure: URLError(.cancelled))
        }
    }

    @Test func appLookupMapsOnlyTypedNotFound() async throws {
        do {
            try await invoke("getApp", failure: BagbutikCore.ServiceError.notFound(.init()))
            Issue.record("Expected appNotFound.")
        } catch let error as AppDabServices.ServiceError {
            guard case .appNotFound(let appID, _) = error else {
                Issue.record("Expected appNotFound.")
                return
            }
            #expect(appID == "app")
            #expect(error.diagnostics?.httpStatusCode == 404)
        }
    }

    private func invoke(_ operation: String, failure: any Error) async throws {
        let key = try previewAPIKey()
        let provider = StoredAccountProvider(loadAPIKeys: { [key] }, verifyAPIKeyHandler: { _ in throw failure })
        let apps = AppCatalogService(
            accountProvider: provider, fetchAppsHandler: { _, _ in throw failure },
            fetchAppHandler: { _, _ in throw failure }, createAppVersionHandler: { _, _, _, _ in throw failure }
        )
        let reviews = CustomerReviewService(
            accountProvider: provider, listReviewsHandler: { _, _, _ in throw failure },
            getReviewHandler: { _, _ in throw failure }
        )
        switch operation {
        case "listApps": _ = try await apps.listApps(accountID: key.id)
        case "getApp": _ = try await apps.getApp(accountID: key.id, appID: "app")
        case "createVersion": _ = try await apps.createAppVersion(accountID: key.id, appID: "app", platform: "IOS", version: "2.0")
        case "listReviews": _ = try await reviews.listCustomerReviews(accountID: key.id, appID: "app")
        case "getReview": _ = try await reviews.getCustomerReview(accountID: key.id, reviewID: "review")
        default: _ = try await provider.verifyAccount(accountID: key.id)
        }
    }
}
