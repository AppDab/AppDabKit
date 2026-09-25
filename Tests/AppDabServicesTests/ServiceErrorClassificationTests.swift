@testable import AppDabServices
import BagbutikCore
import Foundation
import Testing

struct ServiceErrorClassificationTests {
    @Test func classifiesURLFailuresAsNetworkErrors() throws {
        guard case .network = try AppDabServices.ServiceError.classify(URLError(.timedOut)) else {
            Issue.record("Expected a network error.")
            return
        }
    }

    @Test func distinguishesTypedAuthenticationAndPermissionFailures() throws {
        // Deliberately misleading descriptions must not override the SDK case.
        let response = ErrorResponse(errors: [.init(
            code: "OTHER", detail: "Resource not found (404); credentials forbidden",
            status: "500", title: "Unrelated text"
        )])
        let authentication = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.unauthorized(response))
        let permission = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.forbidden(response))
        guard case .authentication = authentication, case .permissionDenied = permission else {
            Issue.record("Expected typed authentication and permission errors.")
            return
        }
        #expect(authentication.diagnostics?.httpStatusCode == 401)
        #expect(permission.diagnostics?.httpStatusCode == 403)
        #expect(authentication.diagnostics?.response?.errors?.first?.code == "OTHER")
    }

    @Test(arguments: [400, 401, 403, 404, 409, 422, 429, 503])
    func preservesHTTPStatusAndResponseBody(status: Int) throws {
        let body = Data(#"{"errors":[{"code":"REMOTE_CODE","status":"503","title":"Remote error","detail":"Details"}]}"#.utf8)
        let mapped = try AppDabServices.ServiceError.classify(
            BagbutikCore.ServiceError.unknownHTTPError(statusCode: status, data: body)
        )
        switch (status, mapped) {
        case (400, .invalidArguments), (422, .invalidArguments),
             (401, .authentication), (403, .permissionDenied),
             (404, .upstream), (409, .upstream), (429, .upstream), (503, .upstream): break
        default: Issue.record("Incorrect classification for HTTP \(status).")
        }
        #expect(mapped.diagnostics?.httpStatusCode == status)
        #expect(mapped.diagnostics?.responseBody == body)
        #expect(mapped.diagnostics?.response?.errors?.first?.code == "REMOTE_CODE")
    }

    @Test func preservesAllStructuredErrorsAndSources() throws {
        let response = ErrorResponse(errors: [
            .init(code: "INVALID_RELATIONSHIP", detail: "Invalid relationship", id: "trace",
                  meta: .init(additionalProperties: ["key": "value"]),
                  source: .jsonPointer(.init(pointer: "/data/relationships/app")), status: "409", title: "Conflict"),
            .init(code: "INVALID_PARAMETER", source: .parameter(.init(parameter: "filter")), status: "409", title: "Filter")
        ])
        let mapped = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.conflict(response))
        guard case .upstream = mapped else {
            Issue.record("Expected an upstream conflict.")
            return
        }
        let errors = try #require(mapped.diagnostics?.response?.errors)
        #expect(errors.map(\.code) == ["INVALID_RELATIONSHIP", "INVALID_PARAMETER"])
        #expect(errors.first?.id == "trace")
        #expect(errors.first?.meta?.additionalProperties == ["key": "value"])
        guard case .jsonPointer(let pointer) = errors[0].source,
              case .parameter(let parameter) = errors[1].source else {
            Issue.record("Expected both structured error sources.")
            return
        }
        #expect(pointer.pointer == "/data/relationships/app")
        #expect(parameter.parameter == "filter")
        #expect(try AppDabServices.ServiceError.classify(mapped) == mapped)
    }

    @Test func mapsOtherKnownSDKCases() throws {
        let response = ErrorResponse()
        guard case .invalidArguments = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.badRequest(response)),
              case .invalidArguments = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.unprocessableEntity(response)),
              case .upstream = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.notFound(response)),
              case .upstream = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.wrongDateFormat(dateString: "invalid")) else {
            Issue.record("Incorrect SDK case mapping.")
            return
        }
        let body = Data([0xFF, 0x00])
        let unknown = try AppDabServices.ServiceError.classify(BagbutikCore.ServiceError.unknown(data: body))
        #expect(unknown.diagnostics?.responseBody == body)
    }

    @Test func preservesCancellation() {
        #expect(throws: CancellationError.self) {
            try AppDabServices.ServiceError.classify(CancellationError())
        }
        #expect(throws: URLError(.cancelled)) {
            try AppDabServices.ServiceError.classify(URLError(.cancelled))
        }
        let cancelled = NSError(domain: NSURLErrorDomain, code: URLError.cancelled.rawValue)
        #expect(throws: cancelled) {
            try AppDabServices.ServiceError.classify(cancelled)
        }
    }

    @Test func doesNotInferClassificationFromLocalizedText() throws {
        guard case .upstream = try AppDabServices.ServiceError.classify(
            FixtureError(message: "HTTP status code 401: forbidden; permission denied; not found 404")
        ) else {
            Issue.record("Unstructured errors must remain upstream failures.")
            return
        }
    }
}

private struct FixtureError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
