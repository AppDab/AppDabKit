public struct AutomationActionID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public static let listAccounts = AutomationActionID(rawValue: "list_accounts")
    public static let addAccount = AutomationActionID(rawValue: "add_account")
    public static let removeAccount = AutomationActionID(rawValue: "remove_account")
    public static let verifyAccount = AutomationActionID(rawValue: "verify_account")
    public static let listApps = AutomationActionID(rawValue: "list_apps")
    public static let getApp = AutomationActionID(rawValue: "get_app")
    public static let createAppVersion = AutomationActionID(rawValue: "create_app_version")
    public static let listCustomerReviews = AutomationActionID(rawValue: "list_customer_reviews")
    public static let listAppVersions = AutomationActionID(rawValue: "list_app_versions")
    public static let listBuilds = AutomationActionID(rawValue: "list_builds")
    public static let getBuild = AutomationActionID(rawValue: "get_build")
    public static let addIndividualTesterToBuild = AutomationActionID(rawValue: "add_individual_tester_to_build")
    public static let removeIndividualTesterFromBuild = AutomationActionID(rawValue: "remove_individual_tester_from_build")
    public static let addBetaGroupToBuild = AutomationActionID(rawValue: "add_beta_group_to_build")
    public static let removeBetaGroupFromBuild = AutomationActionID(rawValue: "remove_beta_group_from_build")
    public static let submitBuildForBetaReview = AutomationActionID(rawValue: "create_beta_app_review_submission")
    public static let expireBuild = AutomationActionID(rawValue: "expire_build")
    public static let getAppVersion = AutomationActionID(rawValue: "get_app_version")
    public static let getCustomerReview = AutomationActionID(rawValue: "get_customer_review")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
