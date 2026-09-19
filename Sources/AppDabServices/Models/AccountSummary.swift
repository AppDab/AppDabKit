import Foundation

public struct AccountSummary: Codable, Equatable, Hashable, Sendable {
    public let accountID: String
    public let name: String

    public init(accountID: String, name: String) {
        self.accountID = accountID
        self.name = name
    }
}
