import Foundation

public struct AutomationMutationPlan: Codable, Equatable, Sendable {
    public let planID: String
    public let actionID: AutomationActionID
    public let targetIdentifiers: [String]
    public let redactedSummary: String
    public let canonicalInputHash: String
    public let confirmationFingerprint: String
    public let remotePreconditions: [String: AutomationValue]
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        planID: String,
        actionID: AutomationActionID,
        targetIdentifiers: [String],
        redactedSummary: String,
        canonicalInputHash: String,
        confirmationFingerprint: String,
        remotePreconditions: [String: AutomationValue],
        createdAt: Date,
        expiresAt: Date
    ) {
        self.planID = planID
        self.actionID = actionID
        self.targetIdentifiers = targetIdentifiers
        self.redactedSummary = redactedSummary
        self.canonicalInputHash = canonicalInputHash
        self.confirmationFingerprint = confirmationFingerprint
        self.remotePreconditions = remotePreconditions
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}
