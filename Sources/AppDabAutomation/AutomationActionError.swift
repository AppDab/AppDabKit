import AppDabServices
import Foundation

public enum AutomationActionError: Error, Equatable, LocalizedError, Sendable {
    case accountNotFound(String)
    case appNotFound(String, diagnostics: ServiceErrorDiagnostics? = nil)
    case invalidArguments(String, diagnostics: ServiceErrorDiagnostics? = nil)
    case invalidLimit(Int)
    case authentication(String, diagnostics: ServiceErrorDiagnostics? = nil)
    case permissionDenied(String, diagnostics: ServiceErrorDiagnostics? = nil)
    case network(String, diagnostics: ServiceErrorDiagnostics? = nil)
    case upstream(String, diagnostics: ServiceErrorDiagnostics? = nil)

    public var diagnostics: ServiceErrorDiagnostics? {
        switch self {
        case .appNotFound(_, let diagnostics), .invalidArguments(_, let diagnostics),
             .authentication(_, let diagnostics), .permissionDenied(_, let diagnostics),
             .network(_, let diagnostics), .upstream(_, let diagnostics):
            diagnostics
        case .accountNotFound, .invalidLimit:
            nil
        }
    }

    public var code: String {
        switch self {
        case .accountNotFound: "account_not_found"
        case .appNotFound: "app_not_found"
        case .invalidArguments, .invalidLimit: "invalid_arguments"
        case .authentication: "authentication_failed"
        case .permissionDenied: "permission_denied"
        case .network: "network_error"
        case .upstream: "upstream_error"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .accountNotFound(let accountID):
            "Could not find account \(accountID)."
        case .appNotFound(let appID, _):
            "Could not find app \(appID)."
        case .invalidArguments(let message, _):
            message
        case .invalidLimit(let limit):
            "The review limit \(limit) is invalid. Use a value between 1 and 200."
        case .authentication(let message, _), .permissionDenied(let message, _), .network(let message, _), .upstream(let message, _):
            message
        }
    }

    static func from(serviceError: ServiceError) -> Self {
        switch serviceError {
        case .accountNotFound(let accountID): .accountNotFound(accountID)
        case .appNotFound(let appID, let diagnostics): .appNotFound(appID, diagnostics: diagnostics)
        case .invalidArguments(let message, let diagnostics): .invalidArguments(message, diagnostics: diagnostics)
        case .invalidLimit(let limit): .invalidLimit(limit)
        case .authentication(let message, let diagnostics): .authentication(message, diagnostics: diagnostics)
        case .permissionDenied(let message, let diagnostics): .permissionDenied(message, diagnostics: diagnostics)
        case .network(let message, let diagnostics): .network(message, diagnostics: diagnostics)
        case .upstream(let message, let diagnostics): .upstream(message, diagnostics: diagnostics)
        }
    }
}
