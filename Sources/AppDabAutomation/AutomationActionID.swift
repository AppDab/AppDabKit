public struct AutomationActionID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public static let listAccounts = AutomationActionID(rawValue: "list_accounts")
    public static let addAccount = AutomationActionID(rawValue: "add_account")
    public static let removeAccount = AutomationActionID(rawValue: "remove_account")
    public static let verifyAccount = AutomationActionID(rawValue: "verify_account")
    public static let listApps = AutomationActionID(rawValue: "list_apps")
    public static let getApp = AutomationActionID(rawValue: "get_app")
    public static let createAppVersion = AutomationActionID(rawValue: "create_app_version")
    public static let listCustomerReviews = AutomationActionID(rawValue: "list_customer_reviews")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
