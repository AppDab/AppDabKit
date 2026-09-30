import BagbutikCore
import Foundation

public enum ServiceError: Error, Equatable, LocalizedError {
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
        case let .accountNotFound(accountID):
            "Could not find account \(accountID)."
        case let .appNotFound(appID, _):
            "Could not find app \(appID)."
        case let .invalidArguments(message, _):
            message
        case let .invalidLimit(limit):
            "The limit (\(limit)) is invalid."
        case let .authentication(message, _), let .permissionDenied(message, _), let .network(message, _), let .upstream(message, _):
            message
        }
    }

    static func classify(_ error: Error) throws -> Self {
        if error is CancellationError || (error as NSError).domain == NSURLErrorDomain
            && (error as NSError).code == URLError.cancelled.rawValue
        {
            throw error
        }
        if let serviceError = error as? Self {
            return serviceError
        }
        if let sdkError = error as? BagbutikCore.ServiceError {
            switch sdkError {
            case let .badRequest(response):
                return remote(status: 400, response: response)
            case let .unauthorized(response):
                return remote(status: 401, response: response)
            case let .forbidden(response):
                return remote(status: 403, response: response)
            case let .notFound(response):
                return remote(status: 404, response: response)
            case let .conflict(response):
                return remote(status: 409, response: response)
            case let .unprocessableEntity(response):
                return remote(status: 422, response: response)
            case let .unknownHTTPError(status, data):
                return remote(status: status, response: try? JSONDecoder().decode(ErrorResponse.self, from: data), body: data)
            case .wrongDateFormat:
                return .upstream(sdkError.description ?? "App Store Connect returned an invalid date.")
            case let .unknown(data):
                return .upstream("App Store Connect returned an unknown error.", diagnostics: .init(responseBody: data))
            }
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return .network(error.localizedDescription)
        }
        return .upstream(error.localizedDescription)
    }

    private static func remote(status: Int, response: ErrorResponse?, body: Data? = nil) -> Self {
        let diagnostics = ServiceErrorDiagnostics(httpStatusCode: status, response: response, responseBody: body)
        let message = response?.errors?.first?.detail ?? response?.errors?.first?.title
            ?? "App Store Connect returned HTTP \(status)."
        switch status {
        case 400, 422: return .invalidArguments(message, diagnostics: diagnostics)
        case 401: return .authentication(message, diagnostics: diagnostics)
        case 403: return .permissionDenied(message, diagnostics: diagnostics)
        default: return .upstream(message, diagnostics: diagnostics)
        }
    }
}
