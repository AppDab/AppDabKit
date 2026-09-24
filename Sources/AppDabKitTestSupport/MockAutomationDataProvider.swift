import AppDabAutomation
import AppDabServices
import BagbutikAppStoreModels
import ConnectAccounts
import Foundation

public struct MockAutomationDataProvider: AutomationDataProviding {
    public let appError: ServiceError?
    public let returnsEmptyCollections: Bool
    public let includesReviewResponse: Bool
    public let reviewRating: Int

    public init(
        appError: ServiceError? = nil,
        returnsEmptyCollections: Bool = false,
        includesReviewResponse: Bool = true,
        reviewRating: Int = 5
    ) {
        self.appError = appError
        self.returnsEmptyCollections = returnsEmptyCollections
        self.includesReviewResponse = includesReviewResponse
        self.reviewRating = reviewRating
    }

    public func accountStore() throws -> any AppDabAutomation.AutomationAccountStoring {
        return MockAutomationAccountStore()
    }

    public func listAccounts() async throws -> [AccountSummary] {
        guard !returnsEmptyCollections else {
            return []
        }
        return [.init(accountID: "account-1", name: "Primary")]
    }

    public func verifyAccount(accountID: String) async throws -> AccountVerification {
        guard !returnsEmptyCollections else {
            throw ServiceError.accountNotFound(accountID)
        }
        return .init(account: .init(accountID: accountID, name: "Primary"))
    }

    public func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        if let appError {
            throw appError
        }
        let limit = try pagination.resolvedLimit()
        guard !returnsEmptyCollections else {
            return .init(apps: [], pagination: .init(limit: limit, total: 0, nextCursor: nil))
        }
        let apps: [AppSummary] = [
            .init(
                    appID: "app-1",
                    name: "AppDab",
                    bundleID: "app.appdab",
                    sku: "APPDAB",
                    primaryLocale: "en-US",
                    iconURL: nil,
                    versions: [appVersion]
            )
        ]
        return .init(
            apps: apps,
            pagination: .init(
                limit: limit,
                total: limit == 1 ? 2 : apps.count,
                nextCursor: limit == 1 ? "next-app" : nil
            )
        )
    }

    public func getApp(accountID: String, appID: String) async throws -> AppDetail {
        .init(
            appID: appID,
            name: "AppDab",
            bundleID: "app.appdab",
            sku: "APPDAB",
            primaryLocale: "en-US",
            iconURL: nil,
            contentRightsDeclaration: "doesNotUseThirdPartyContent",
            versions: [appVersion]
        )
    }

    public func createAppVersion(accountID: String, appID: String, platform: String, version: String) async throws -> AppDabServices.AppVersion {
        return .init(versionID: UUID().uuidString, platform: platform, state: AppVersionState.prepareForSubmission.prettyName, version: version, createdDate: .now, isFirstVersion: false)
    }

    public func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        let limit = try pagination.resolvedLimit()
        guard !returnsEmptyCollections else {
            return .init(appID: appID, reviews: [], pagination: .init(limit: limit, total: 0, nextCursor: nil))
        }
        let response = includesReviewResponse
            ? CustomerReviewResponse(
                responseID: "response-1",
                lastModifiedDate: Date(timeIntervalSince1970: 300),
                responseBody: "Thank you!",
                state: "PUBLISHED"
            )
            : nil
        return .init(appID: appID, reviews: [
            .init(
                reviewID: "review-1",
                title: "Great",
                body: "Love it",
                createdDate: Date(timeIntervalSince1970: 100),
                rating: reviewRating,
                reviewerNickname: "Taylor",
                territory: "USA",
                response: response
            )
        ], pagination: .init(
            limit: limit,
            total: limit == 1 ? 2 : 1,
            nextCursor: limit == 1 ? "next-review" : nil
        ))
    }

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> AppDabServices.CustomerReview {
        .init(
            reviewID: reviewID,
            title: "Great",
            body: "Love it",
            createdDate: Date(timeIntervalSince1970: 100),
            rating: reviewRating,
            reviewerNickname: "Taylor",
            territory: "USA",
            response: includesReviewResponse
                ? .init(
                    responseID: "response-1",
                    lastModifiedDate: Date(timeIntervalSince1970: 300),
                    responseBody: "Thank you!",
                    state: "PUBLISHED"
                )
                : nil
        )
    }

    private var appVersion: AppVersion {
        .init(
            versionID: "version-1",
            platform: "IOS",
            state: "READY_FOR_SALE",
            version: "1.2.3",
            createdDate: Date(timeIntervalSince1970: 200),
            isFirstVersion: false
        )
    }
}
