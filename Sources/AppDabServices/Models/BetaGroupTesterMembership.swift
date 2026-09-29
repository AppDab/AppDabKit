public struct BetaGroupTesterMembership: Codable, Equatable, Sendable {
    public let betaGroupID: String
    public let betaGroupName: String
    public let testerID: String
    public let isMember: Bool

    public init(betaGroupID: String, betaGroupName: String, testerID: String, isMember: Bool) {
        self.betaGroupID = betaGroupID
        self.betaGroupName = betaGroupName
        self.testerID = testerID
        self.isMember = isMember
    }
}

public enum BetaGroupTesterMutation: Sendable {
    case add(testerID: String)
    case remove(testerID: String)
}
