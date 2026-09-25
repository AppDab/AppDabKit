import BagbutikCore
import Foundation

/// Structured remote diagnostics, kept separate from the user facing message.
public struct ServiceErrorDiagnostics: Equatable, Sendable {
    public let httpStatusCode: Int?
    public let response: ErrorResponse?
    public let responseBody: Data?

    public init(httpStatusCode: Int? = nil, response: ErrorResponse? = nil, responseBody: Data? = nil) {
        self.httpStatusCode = httpStatusCode
        self.response = response
        self.responseBody = responseBody
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Bagbutik response models are Codable but do not conform to Equatable.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return lhs.httpStatusCode == rhs.httpStatusCode
            && lhs.responseBody == rhs.responseBody
            && (try? encoder.encode(lhs.response)) == (try? encoder.encode(rhs.response))
    }
}
