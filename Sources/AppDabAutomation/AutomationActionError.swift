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
        case let .appNotFound(_, diagnostics), let .invalidArguments(_, diagnostics),
             let .authentication(_, diagnostics), let .permissionDenied(_, diagnostics),
             let .network(_, diagnostics), let .upstream(_, diagnostics):
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
        case let .accountNotFound(accountID):
            "Could not find account \(accountID)."
        case let .appNotFound(appID, _):
            "Could not find app \(appID)."
        case let .invalidArguments(message, _):
            message
        case let .invalidLimit(limit):
            "The review limit \(limit) is invalid. Use a value between 1 and 200."
        case let .authentication(message, _), let .permissionDenied(message, _), let .network(message, _), let .upstream(message, _):
            message
        }
    }

    static func from(serviceError: ServiceError) -> Self {
        switch serviceError {
        case let .accountNotFound(accountID): .accountNotFound(accountID)
        case let .appNotFound(appID, diagnostics): .appNotFound(appID, diagnostics: diagnostics)
        case let .invalidArguments(message, diagnostics): .invalidArguments(message, diagnostics: diagnostics)
        case let .invalidLimit(limit): .invalidLimit(limit)
        case let .authentication(message, diagnostics): .authentication(message, diagnostics: diagnostics)
        case let .permissionDenied(message, diagnostics): .permissionDenied(message, diagnostics: diagnostics)
        case let .network(message, diagnostics): .network(message, diagnostics: diagnostics)
        case let .upstream(message, diagnostics): .upstream(message, diagnostics: diagnostics)
        }
    }
}
