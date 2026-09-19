import AppDabServices
import Foundation

public enum AutomationActionError: Error, Equatable, LocalizedError, Sendable {
    case accountNotFound(String)
    case appNotFound(String)
    case invalidArguments(String)
    case invalidLimit(Int)
    case authentication(String)
    case permissionDenied(String)
    case network(String)
    case upstream(String)

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
        case .appNotFound(let appID):
            "Could not find app \(appID)."
        case .invalidArguments(let message):
            message
        case .invalidLimit(let limit):
            "The review limit \(limit) is invalid. Use a value between 1 and 200."
        case .authentication(let message), .permissionDenied(let message), .network(let message), .upstream(let message):
            message
        }
    }

    static func from(serviceError: ServiceError) -> Self {
        switch serviceError {
        case .accountNotFound(let accountID): .accountNotFound(accountID)
        case .appNotFound(let appID): .appNotFound(appID)
        case .invalidArguments(let message): .invalidArguments(message)
        case .invalidLimit(let limit): .invalidLimit(limit)
        case .authentication(let message): .authentication(message)
        case .permissionDenied(let message): .permissionDenied(message)
        case .network(let message): .network(message)
        case .upstream(let message): .upstream(message)
        }
    }
}
