import AppDabServices

enum Schema {
    static func object(
        properties: [String: JSONValue],
        required: [String] = []
    ) -> JSONValue {
        .object([
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(required.map(JSONValue.string)),
            "additionalProperties": .bool(false)
        ])
    }

    static func string(description: String) -> JSONValue {
        .object([
            "type": .string("string"),
            "description": .string(description)
        ])
    }

    static func integer(
        description: String,
        minimum: Int,
        maximum: Int,
        default defaultValue: Int
    ) -> JSONValue {
        .object([
            "type": .string("integer"),
            "description": .string(description),
            "minimum": .integer(minimum),
            "maximum": .integer(maximum),
            "default": .integer(defaultValue)
        ])
    }

    static let paginationCursor = string(description: "Opaque pagination token returned by a previous list response.")

    static let paginationLimit = integer(
        description: "Maximum items to return, from 1 through 200.",
        minimum: 1,
        maximum: PaginationRequest.maximumLimit,
        default: PaginationRequest.defaultLimit
    )

    static let paginationOutput = object(properties: [
        "limit": .object(["type": .string("integer")]),
        "total": .object(["type": .string("integer")]),
        "has_more": .object(["type": .string("boolean")]),
        "next_cursor": .object(["type": .string("string")])
    ], required: ["limit", "total", "has_more"])
}
