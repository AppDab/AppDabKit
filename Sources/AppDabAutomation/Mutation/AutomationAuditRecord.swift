public struct AutomationAuditRecord: Codable, Equatable, Sendable {
    public let actionID: AutomationActionID
    public let confirmationFingerprint: String
    public let idempotencyKey: String
    public let status: AutomationAuditStatus
    public let receipt: AutomationMutationReceipt?

    public init(
        actionID: AutomationActionID,
        confirmationFingerprint: String,
        idempotencyKey: String,
        status: AutomationAuditStatus,
        receipt: AutomationMutationReceipt? = nil
    ) {
        self.actionID = actionID
        self.confirmationFingerprint = confirmationFingerprint
        self.idempotencyKey = idempotencyKey
        self.status = status
        self.receipt = receipt
    }
}
