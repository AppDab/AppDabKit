@testable import AppDabAutomation
import AppDabServices
import Foundation

actor CreateVersionDataProvider: AutomationDataProviding {
    private var versions: [String]
    private let failure: CreateVersionFailure?
    private(set) var createAttempts = 0

    init(
        versions: [String] = ["1.0"],
        failure: CreateVersionFailure? = nil
    ) {
        self.versions = versions
        self.failure = failure
    }

    func addVersion(_ version: String) {
        versions.append(version)
    }

    func listAccounts() async throws -> [AccountSummary] { [] }
    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        .init(apps: [], pagination: .init(limit: try pagination.resolvedLimit(), total: 0, nextCursor: nil))
    }

    func getApp(accountID: String, appID: String) async throws -> AppDetail {
        .init(
            appID: appID,
            name: "AppDab",
            bundleID: "app.appdab",
            sku: "APPDAB",
            primaryLocale: "en-US",
            iconURL: nil,
            contentRightsDeclaration: nil,
            versions: versions.enumerated().map { index, version in
                .init(
                    versionID: "version-\(index)",
                    platform: "iOS",
                    state: "Ready for Distribution",
                    version: version,
                    createdDate: Date(timeIntervalSince1970: TimeInterval(index)),
                    isFirstVersion: index == 0
                )
            }
        )
    }

    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        throw ServiceError.upstream("Customer review lookup is unavailable in this fixture.")
    }

    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion {
        if failure == .beforeCreating {
            throw ServiceError.upstream("The create request failed before applying.")
        }
        createAttempts += 1
        versions.append(version)
        if failure == .afterCreating {
            throw ServiceError.upstream("The create response was lost.")
        }
        return .init(
            versionID: "version-\(versions.count - 1)",
            platform: "iOS",
            state: "Prepare for Submission",
            version: version,
            createdDate: Date(timeIntervalSince1970: TimeInterval(versions.count)),
            isFirstVersion: false
        )
    }

    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        .init(
            appID: appID,
            reviews: [],
            pagination: .init(limit: try pagination.resolvedLimit(), total: 0, nextCursor: nil)
        )
    }
}

public extension AutomationDataProviding {
    func accountStore() throws -> any AutomationAccountStoring {
        throw AutomationActionError.invalidArguments("Account storage is unavailable for this automation data provider.")
    }

    func verifyAccount(accountID: String) async throws -> AccountVerification {
        throw ServiceError.accountNotFound(accountID)
    }

    func createAppVersion(
        accountID: String,
        appID: String,
        platform: String,
        version: String
    ) async throws -> AppVersion {
        throw ServiceError.upstream("Creating app versions is unavailable for this data provider.")
    }
}
