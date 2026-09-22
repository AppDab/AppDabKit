@testable import AppDabAutomation
import AppDabServices
import Foundation

public actor CreateVersionDataProvider: AutomationDataProviding {
    private var versions: [String]
    private let failure: CreateVersionFailure?
    public private(set) var createAttempts = 0

    public init(
        versions: [String] = ["1.0"],
        failure: CreateVersionFailure? = nil
    ) {
        self.versions = versions
        self.failure = failure
    }

    public func addVersion(_ version: String) {
        versions.append(version)
    }

    public func listAccounts() async throws -> [AccountSummary] {
        []
    }

    public func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        try .init(apps: [], pagination: .init(limit: pagination.resolvedLimit(), total: 0, nextCursor: nil))
    }

    public func getApp(accountID: String, appID: String) async throws -> AppDetail {
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

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        throw ServiceError.upstream("Customer review lookup is unavailable in this fixture.")
    }

    public func createAppVersion(
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

    public func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        try .init(
            appID: appID,
            reviews: [],
            pagination: .init(limit: pagination.resolvedLimit(), total: 0, nextCursor: nil)
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
