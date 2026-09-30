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
    public static let listBetaGroups = AutomationActionID(rawValue: "list_beta_groups")
    public static let getBetaGroup = AutomationActionID(rawValue: "get_beta_group")
    public static let createBetaGroup = AutomationActionID(rawValue: "create_beta_group")
    public static let updateBetaGroup = AutomationActionID(rawValue: "update_beta_group")
    public static let deleteBetaGroup = AutomationActionID(rawValue: "delete_beta_group")
    public static let addBuildToBetaGroup = AutomationActionID(rawValue: "add_build_to_beta_group")
    public static let removeBuildFromBetaGroup = AutomationActionID(rawValue: "remove_build_from_beta_group")
    public static let addIndividualTesterToBuild = AutomationActionID(rawValue: "add_individual_tester_to_build")
    public static let removeIndividualTesterFromBuild = AutomationActionID(rawValue: "remove_individual_tester_from_build")
    public static let addBetaGroupToBuild = AutomationActionID(rawValue: "add_beta_group_to_build")
    public static let removeBetaGroupFromBuild = AutomationActionID(rawValue: "remove_beta_group_from_build")
    public static let addTesterToBetaGroup = AutomationActionID(rawValue: "add_tester_to_beta_group")
    public static let removeTesterFromBetaGroup = AutomationActionID(rawValue: "remove_tester_from_beta_group")
    public static let listBetaTesters = AutomationActionID(rawValue: "list_beta_testers")
    public static let inviteBetaTester = AutomationActionID(rawValue: "invite_beta_tester")
    public static let sendBetaTesterInvitation = AutomationActionID(rawValue: "send_beta_tester_invitation")
    public static let submitBuildForBetaReview = AutomationActionID(rawValue: "create_beta_app_review_submission")
    public static let expireBuild = AutomationActionID(rawValue: "expire_build")
    public static let updateBetaBuildLocalization = AutomationActionID(rawValue: "update_beta_build_localization")
    public static let getAppVersion = AutomationActionID(rawValue: "get_app_version")
    public static let getCustomerReview = AutomationActionID(rawValue: "get_customer_review")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
