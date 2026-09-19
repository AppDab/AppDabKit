import Foundation

public protocol AutomationAuditStoring: Sendable {
    func savePreview(_ plan: AutomationMutationPlan) async throws
    func preview(confirmationFingerprint: String, now: Date) async throws -> AutomationMutationPlan?
    func removePreview(confirmationFingerprint: String) async throws
    func beginCommit(
        actionID: AutomationActionID,
        confirmationFingerprint: String,
        idempotencyKey: String,
        now: Date
    ) async throws -> AutomationCommitClaim
    func completeCommit(_ receipt: AutomationMutationReceipt, claimID: String) async throws
    func markIndeterminate(
        actionID: AutomationActionID,
        confirmationFingerprint: String,
        idempotencyKey: String,
        claimID: String
    ) async throws
    func beginReconciliation(
        confirmationFingerprint: String,
        idempotencyKey: String,
        now: Date,
        pendingLeaseDuration: TimeInterval
    ) async throws -> AutomationReconciliationClaim
    func completeReconciliation(
        _ receipt: AutomationMutationReceipt,
        claimID: String
    ) async throws
    func auditRecord(idempotencyKey: String) async throws -> AutomationAuditRecord?
    func resolveNotApplied(
        confirmationFingerprint: String,
        idempotencyKey: String,
        claimID: String
    ) async throws
    func releaseReconciliation(idempotencyKey: String, claimID: String) async throws
    func auditRecords() async throws -> [AutomationAuditRecord]
    func clear() async throws
}
