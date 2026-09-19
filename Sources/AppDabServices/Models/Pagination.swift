import Foundation

public struct PaginationRequest: Codable, Equatable, Hashable, Sendable {
    public static let defaultLimit = 50
    public static let maximumLimit = 200

    public let cursor: String?
    public let limit: Int?

    public init(cursor: String? = nil, limit: Int? = nil) {
        self.cursor = cursor
        self.limit = limit
    }

    public func resolvedLimit() throws(ServiceError) -> Int {
        if cursor != nil, limit == nil {
            throw .invalidArguments("Argument limit is required when cursor is provided.")
        }
        let resolvedLimit = limit ?? Self.defaultLimit
        guard (1 ... Self.maximumLimit).contains(resolvedLimit) else {
            throw .invalidLimit(resolvedLimit)
        }
        return resolvedLimit
    }

    public func validatedCursor() throws(ServiceError) -> String? {
        guard let cursor else { return nil }
        guard !cursor.isEmpty,
              cursor.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else {
            throw .invalidArguments("Argument cursor must be an opaque pagination token.")
        }
        return cursor
    }

    public func validate() throws(ServiceError) {
        _ = try resolvedLimit()
        _ = try validatedCursor()
    }
}

enum PaginationCursor {
    static func extract(from continuationURL: String?) throws(ServiceError) -> String? {
        guard let continuationURL else { return nil }
        guard let components = URLComponents(string: continuationURL) else {
            throw .upstream("App Store Connect returned an invalid pagination cursor.")
        }
        let cursors = (components.queryItems ?? []).filter { $0.name == "cursor" }
        guard cursors.count == 1,
              let cursor = cursors.first?.value,
              !cursor.isEmpty
        else {
            throw .upstream("App Store Connect returned an invalid pagination cursor.")
        }
        return cursor
    }
}

public struct PaginationMetadata: Codable, Equatable, Hashable, Sendable {
    public let limit: Int
    public let total: Int
    public let hasMore: Bool
    public let nextCursor: String?

    public init(limit: Int, total: Int, nextCursor: String?) {
        self.limit = limit
        self.total = total
        self.nextCursor = nextCursor
        hasMore = nextCursor != nil
    }
}

public struct CursorPage<Item: Sendable>: Sendable {
    public let items: [Item]
    public let total: Int
    public let nextCursor: String?

    public init(items: [Item], total: Int, nextCursor: String?) {
        self.items = items
        self.total = total
        self.nextCursor = nextCursor
    }
}
