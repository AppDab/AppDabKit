import Foundation

public enum ServiceError: Error, Equatable, LocalizedError {
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
        case .invalidArguments: "invalid_arguments"
        case .invalidLimit: "invalid_arguments"
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
            "The limit (\(limit)) is invalid."
        case .authentication(let message), .permissionDenied(let message), .network(let message), .upstream(let message):
            message
        }
    }

    static func classify(_ error: Error) -> Self {
        if let serviceError = error as? Self {
            return serviceError
        }

        let diagnostic = error.localizedDescription
        let loweredDiagnostic = diagnostic.lowercased()
        if error is URLError || (error as NSError).domain == NSURLErrorDomain {
            return .network(diagnostic)
        }
        if containsHTTPStatus(403, in: loweredDiagnostic)
            || loweredDiagnostic.contains("forbidden")
            || loweredDiagnostic.contains("permission")
            || loweredDiagnostic.contains("access denied") {
            return .permissionDenied(diagnostic)
        }
        if containsHTTPStatus(401, in: loweredDiagnostic)
            || loweredDiagnostic.contains("unauthorized")
            || loweredDiagnostic.contains("authenticate")
            || loweredDiagnostic.contains("credentials") {
            return .authentication(diagnostic)
        }
        return .upstream(diagnostic)
    }

    private static func containsHTTPStatus(_ status: Int, in diagnostic: String) -> Bool {
        diagnostic.contains("status code \(status)")
            || diagnostic.contains("status: \(status)")
            || diagnostic.contains("http \(status)")
            || diagnostic.contains("\"status\":\"\(status)\"")
            || diagnostic.contains("\"status\" : \"\(status)\"")
    }
}
