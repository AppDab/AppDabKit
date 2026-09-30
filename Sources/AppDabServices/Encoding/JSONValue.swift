import Foundation

public enum JSONValue: Codable, Equatable, Hashable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var value = [String: JSONValue]()
            for key in container.allKeys {
                value[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
            }
            self = .object(value)
            return
        }
        if var container = try? decoder.unkeyedContainer() {
            var values = [JSONValue]()
            while !container.isAtEnd {
                try values.append(container.decode(JSONValue.self))
            }
            self = .array(values)
            return
        }
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else {
            self = try .string(container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .object(object):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in object {
                try container.encode(value, forKey: DynamicCodingKey(stringValue: key)!)
            }
        case let .array(array):
            var container = encoder.unkeyedContainer()
            for value in array {
                try container.encode(value)
            }
        case let .string(string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case let .integer(integer):
            var container = encoder.singleValueContainer()
            try container.encode(integer)
        case let .double(double):
            var container = encoder.singleValueContainer()
            try container.encode(double)
        case let .bool(bool):
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }

    public var objectValue: [String: JSONValue]? {
        guard case let .object(object) = self else { return nil }
        return object
    }

    public var stringValue: String? {
        guard case let .string(string) = self else { return nil }
        return string
    }

    public var intValue: Int? {
        switch self {
        case let .integer(integer): integer
        case let .double(double): Int(double)
        default: nil
        }
    }

    public static func fromEncodable(_ value: some Encodable, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601) throws -> JSONValue {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        let data = try encoder.encode(AnyEncodable(value))
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }
}
