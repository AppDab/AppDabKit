import AppDabServices

public enum AddBuildToBetaGroupSpec: BetaGroupBuildActionSpec {
    public static let id: AutomationActionID = .addBuildToBetaGroup
    public static let title = "Add Build to Beta Group"
    public static let adding = true
}

public typealias AddBuildToBetaGroupAction = BetaGroupBuildAction<AddBuildToBetaGroupSpec>
