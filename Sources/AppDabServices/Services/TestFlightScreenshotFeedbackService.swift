import BagbutikAppStore
import BagbutikAppStoreModels
import BagbutikCore
import BagbutikModelsShared
import BagbutikTestFlight
import BagbutikTestFlightModels
import ConnectAccounts
import Foundation

public struct TestFlightScreenshotFeedback: Codable, Equatable, Identifiable, Sendable {
    public struct Attachment: Codable, Equatable, Sendable {
        public let url: URL?
        public let width: Int?
        public let height: Int?
    }

    public let id: String
    public let comment: String?
    public let createdDate: Date?
    public let buildID: String?
    public let buildNumber: String?
    public let version: String?
    public let deviceModel: String?
    public let osVersion: String?
    public let attachments: [Attachment]
}

public struct TestFlightScreenshotFeedbackList: Codable, Equatable, Sendable {
    public let appID: String
    public let submissions: [TestFlightScreenshotFeedback]
    public let pagination: PaginationMetadata

    public init(appID: String, submissions: [TestFlightScreenshotFeedback], pagination: PaginationMetadata) {
        self.appID = appID
        self.submissions = submissions
        self.pagination = pagination
    }
}

public struct TestFlightScreenshotFeedbackDetail: Codable, Equatable, Sendable {
    public let appID: String
    public let submission: TestFlightScreenshotFeedback
}

public protocol TestFlightScreenshotFeedbackServing: Sendable {
    func listSubmissions(
        accountID: String, appID: String, pagination: PaginationRequest,
    ) async throws -> TestFlightScreenshotFeedbackList

    func getSubmission(
        accountID: String, submissionID: String,
    ) async throws -> TestFlightScreenshotFeedbackDetail
}

public struct TestFlightScreenshotFeedbackService: TestFlightScreenshotFeedbackServing {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    public func listSubmissions(
        accountID: String, appID: String, pagination: PaginationRequest = .init(),
    ) async throws -> TestFlightScreenshotFeedbackList {
        guard !appID.isEmpty else { throw ServiceError.invalidArguments("Argument appID must be a nonempty string.") }
        let request = try Self.listRequest(appID: appID, pagination: pagination)
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            let response = try await BagbutikService(jwt: key.jwt).request(request)
            return try .init(
                appID: appID,
                submissions: response.data.map { Self.submission($0, build: response.getBuild(for: $0)) },
                pagination: BuildService.paginationMetadata(
                    limit: pagination.resolvedLimit(), total: response.meta?.paging.total,
                    nextCursor: PaginationCursor.extract(from: response.links.next),
                ),
            )
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    public func getSubmission(
        accountID: String, submissionID: String,
    ) async throws -> TestFlightScreenshotFeedbackDetail {
        guard !submissionID.isEmpty else {
            throw ServiceError.invalidArguments("Argument submissionID must be a nonempty string.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        let service = BagbutikService(jwt: key.jwt)
        do {
            let feedback = try await service.request(.getBetaFeedbackScreenshotSubmissionV1(id: submissionID, includes: [.build]))
            guard let buildID = feedback.data.relationships?.build?.data?.id ?? feedback.getBuild()?.id else {
                throw ServiceError.upstream("App Store Connect did not return the screenshot feedback’s build.")
            }
            let build = try await service.request(.getBuildV1(id: buildID, includes: [.app, .preReleaseVersion]))
            return try .init(
                appID: Self.owningAppID(of: build),
                submission: Self.submission(feedback.data, build: build.data, version: build.getPreReleaseVersion()?.attributes?.version),
            )
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    static func listRequest(
        appID: String, pagination: PaginationRequest,
    ) throws -> Request<BetaFeedbackScreenshotSubmissionsResponse, ErrorResponse> {
        let request: Request<BetaFeedbackScreenshotSubmissionsResponse, ErrorResponse> = try .listBetaFeedbackScreenshotSubmissionsForAppV1(
            id: appID, includes: [.build], sorts: [.createdDateDescending], limit: pagination.resolvedLimit(),
        )
        return try request.withPaginationCursor(pagination.validatedCursor())
    }

    static func owningAppID(of build: BuildResponse) throws -> String {
        guard let appID = build.data.relationships?.app?.data?.id ?? build.getApp()?.id, !appID.isEmpty else {
            throw ServiceError.upstream("App Store Connect did not return the screenshot feedback’s app.")
        }
        return appID
    }

    private static func submission(
        _ resource: BetaFeedbackScreenshotSubmission, build: Build?, version: String? = nil,
    ) -> TestFlightScreenshotFeedback {
        let attributes = resource.attributes
        return .init(
            id: resource.id, comment: attributes?.comment, createdDate: attributes?.createdDate,
            buildID: resource.relationships?.build?.data?.id ?? build?.id, buildNumber: build?.attributes?.version,
            version: version, deviceModel: attributes?.deviceModel, osVersion: attributes?.osVersion,
            attachments: (attributes?.screenshots ?? []).map { screenshot in
                let url = screenshot.url.flatMap { URL(string: $0) }
                return .init(url: url?.scheme == "https" ? url : nil, width: screenshot.width, height: screenshot.height)
            },
        )
    }
}
