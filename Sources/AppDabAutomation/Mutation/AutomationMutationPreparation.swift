public struct AutomationMutationPreparation: Codable, Equatable, Sendable {
    public let targetIdentifiers: [String]
    public let redactedSummary: String
    public let remotePreconditions: [String: AutomationValue]

    public init(
        targetIdentifiers: [String],
        redactedSummary: String,
        remotePreconditions: [String: AutomationValue]
    ) {
        self.targetIdentifiers = targetIdentifiers
        self.redactedSummary = redactedSummary
        self.remotePreconditions = remotePreconditions
    }
}
