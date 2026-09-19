public enum AutomationMutationReconciliation<Output: Sendable>: Sendable {
    case succeeded(Output)
    /// The remote operation definitively did not apply and cannot still apply later.
    /// An unchanged snapshot or an expired local lease alone is insufficient evidence.
    case notApplied
    case unresolved
}
