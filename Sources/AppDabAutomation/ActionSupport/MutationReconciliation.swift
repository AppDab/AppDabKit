enum MutationReconciliation: Sendable {
    case succeeded(CommittedResponse)
    case notApplied
    case unresolved
}
