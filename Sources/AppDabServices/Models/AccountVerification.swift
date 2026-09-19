import Foundation

public struct AccountVerification: Codable, Equatable, Sendable {
    public let account: AccountSummary
    public let issue: AccountVerificationIssue?

    public init(account: AccountSummary, issue: AccountVerificationIssue? = nil) {
        self.account = account
        self.issue = issue
    }
}

public struct AccountAddition: Codable, Equatable, Sendable {
    public let account: AccountSummary
    public let issue: AccountVerificationIssue?

    public init(account: AccountSummary, issue: AccountVerificationIssue? = nil) {
        self.account = account
        self.issue = issue
    }
}

public struct AccountVerificationIssue: Codable, Equatable, Sendable {
    public let message: String
    public let resolutionURL: URL?

    public init(message: String, resolutionURL: URL?) {
        self.message = message
        self.resolutionURL = resolutionURL
    }
}
