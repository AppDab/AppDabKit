public enum AutomationExecutionMode: String, Codable, Equatable, Hashable, Sendable {
    case execute
    case preview
    case commit
    case reconcile
}
