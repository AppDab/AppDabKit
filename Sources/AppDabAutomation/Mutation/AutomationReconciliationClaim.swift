public enum AutomationReconciliationClaim: Equatable, Sendable {
    case reconcile(claimID: String)
    case replay(AutomationMutationReceipt)
}
