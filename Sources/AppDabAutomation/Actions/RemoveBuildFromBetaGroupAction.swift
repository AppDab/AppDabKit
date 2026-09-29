import AppDabServices

public enum RemoveBuildFromBetaGroupSpec: BetaGroupBuildActionSpec {
    public static let id: AutomationActionID = .removeBuildFromBetaGroup
    public static let title = "Remove Build from Beta Group"
    public static let adding = false
}

public typealias RemoveBuildFromBetaGroupAction = BetaGroupBuildAction<RemoveBuildFromBetaGroupSpec>
