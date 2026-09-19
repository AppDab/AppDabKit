public enum AutomationCommitClaim: Equatable, Sendable {
    case execute(claimID: String)
    case replay(AutomationMutationReceipt)
}
