import BagbutikCore
import Foundation

/// Applies one monotonic budget across all requests in a processing poll.
enum MediaRequestDeadline {
    static func check(_ deadline: ContinuousClock.Instant) throws {
        try Task.checkCancellation()
        guard ContinuousClock.now < deadline else { throw timeout }
    }

    static var timeout: ServiceError {
        .upstream("Timed out waiting for Apple to process the media. The upload and placement are saved; inspect or reconcile this operation.")
    }

    static func fetch(_ request: URLRequest, delegate: URLSessionTaskDelegate?, deadline: ContinuousClock.Instant, using fetch: @escaping FetchData) async throws -> (Data, URLResponse) {
        try check(deadline)
        let remaining = ContinuousClock.now.duration(to: deadline)
        var bounded = request
        bounded.timeoutInterval = min(request.timeoutInterval, Double(remaining.components.seconds) + Double(remaining.components.attoseconds) / 1e18)
        let outgoing = bounded
        return try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            defer { group.cancelAll() }
            group.addTask { try await fetch(outgoing, delegate) }
            group.addTask {
                try await ContinuousClock().sleep(until: deadline)
                throw timeout
            }
            guard let result = try await group.next() else { throw timeout }
            try check(deadline)
            return result
        }
    }
}
