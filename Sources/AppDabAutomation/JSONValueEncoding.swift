import AppDabServices
import Foundation

public enum JSONValueEncoding {
    public static func string(from value: JSONValue, prettyPrinted: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    public static func value(from encodable: some Encodable) throws -> JSONValue {
        try JSONValue.fromEncodable(encodable)
    }

    public static func string(fromEncodable encodable: some Encodable, prettyPrinted: Bool = true) throws -> String {
        try string(from: value(from: encodable), prettyPrinted: prettyPrinted)
    }
}
