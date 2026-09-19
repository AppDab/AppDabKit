public struct AutomationExecutionContext: Codable, Equatable, Sendable {
    public let mode: AutomationExecutionMode
    public let confirmationFingerprint: String?
    public let idempotencyKey: String?

    public init(
        mode: AutomationExecutionMode = .execute,
        confirmationFingerprint: String? = nil,
        idempotencyKey: String? = nil
    ) {
        self.mode = mode
        self.confirmationFingerprint = confirmationFingerprint
        self.idempotencyKey = idempotencyKey
    }
}
