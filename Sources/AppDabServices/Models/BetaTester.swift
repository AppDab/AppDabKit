import BagbutikTestFlightModels
import Foundation

public enum BetaTesterScope: Sendable {
    case app(String)
    case betaGroup(String)
    case build(String)
}

public enum BetaTesterDestination: Sendable {
    case betaGroup(String)
    case build(String)
}

public struct BetaTesterSummary: Codable, Equatable, Sendable {
    public let betaTesterID: String
    public let email: String
    public let firstName: String?
    public let lastName: String?
    public let inviteType: String?
    public let state: String?
    public let betaGroupIDs: [String]

    public init(betaTesterID: String, email: String, firstName: String? = nil, lastName: String? = nil,
                inviteType: String? = nil, state: String? = nil, betaGroupIDs: [String] = [])
    {
        self.betaTesterID = betaTesterID
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.inviteType = inviteType
        self.state = state
        self.betaGroupIDs = betaGroupIDs.sorted()
    }

    init(_ tester: BetaTester, betaGroupIDs: [String] = []) {
        self.init(
            betaTesterID: tester.id,
            email: tester.attributes?.email ?? "",
            firstName: tester.attributes?.firstName,
            lastName: tester.attributes?.lastName,
            inviteType: tester.attributes?.inviteType?.rawValue,
            state: tester.attributes?.state?.rawValue,
            betaGroupIDs: betaGroupIDs,
        )
    }
}

public struct BetaTesterList: Codable, Equatable, Sendable {
    public let scopeID: String
    public let testers: [BetaTesterSummary]
    public let pagination: PaginationMetadata

    public init(scopeID: String, testers: [BetaTesterSummary], pagination: PaginationMetadata) {
        self.scopeID = scopeID
        self.testers = testers
        self.pagination = pagination
    }
}
