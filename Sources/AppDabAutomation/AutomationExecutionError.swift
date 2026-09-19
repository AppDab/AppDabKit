import Foundation

public enum AutomationExecutionError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedExecutionMode(action: String, mode: AutomationExecutionMode)
    case invalidExecutionContext(String)
    case confirmationRequired
    case previewNotFound
    case previewExpired
    case inputChanged
    case actionChanged
    case preconditionFailed(String)
    case idempotencyCollision
    case commitBlocked(AutomationAuditStatus)
    case indeterminate
    case reconciliationUnresolved
    case persistence(String)

    public var code: String {
        switch self {
        case .unsupportedExecutionMode: "unsupported_execution_mode"
        case .invalidExecutionContext: "invalid_arguments"
        case .confirmationRequired: "confirmation_required"
        case .previewNotFound: "preview_not_found"
        case .previewExpired: "preview_expired"
        case .inputChanged: "input_changed"
        case .actionChanged: "action_changed"
        case .preconditionFailed: "precondition_failed"
        case .idempotencyCollision: "idempotency_collision"
        case .commitBlocked: "commit_blocked"
        case .indeterminate: "indeterminate_outcome"
        case .reconciliationUnresolved: "reconciliation_unresolved"
        case .persistence: "audit_store_error"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .unsupportedExecutionMode(let action, let mode):
            "Action \(action) does not support \(mode.rawValue) execution."
        case .invalidExecutionContext(let message):
            message
        case .confirmationRequired:
            "A confirmation fingerprint and idempotency key are required."
        case .previewNotFound:
            "The confirmed mutation preview could not be found."
        case .previewExpired:
            "The confirmed mutation preview has expired. Create a new preview."
        case .inputChanged:
            "The action arguments changed after preview. Create a new preview."
        case .actionChanged:
            "The confirmed preview belongs to a different action."
        case .preconditionFailed(let message):
            message
        case .idempotencyCollision:
            "The idempotency key was already used with different input."
        case .commitBlocked(let status):
            "The idempotency key has a \(status.rawValue) outcome and must be reconciled before retrying."
        case .indeterminate:
            "The mutation outcome is indeterminate. Reconcile remote state before retrying."
        case .reconciliationUnresolved:
            "Remote state did not resolve the indeterminate mutation outcome."
        case .persistence(let message):
            "The automation audit store failed: \(message)"
        }
    }
}
