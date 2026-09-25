import AppDabServices

struct Arguments {
    private let values: [String: JSONValue]

    init(_ values: [String: JSONValue], allowedKeys: Set<String>) throws(AutomationActionError) {
        let unknownKeys = Set(values.keys).subtracting(allowedKeys).sorted()
        guard unknownKeys.isEmpty else {
            throw AutomationActionError.invalidArguments(
                "Unknown argument\(unknownKeys.count == 1 ? "" : "s") \(unknownKeys.joined(separator: ", "))."
            )
        }
        self.values = values
    }

    func requiredString(_ key: String) throws(AutomationActionError) -> String {
        guard let value = values[key] else {
            throw AutomationActionError.invalidArguments("Missing required argument \(key).")
        }
        guard case .string(let string) = value, !string.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument \(key) must be a nonempty string.")
        }
        return string
    }

    func optionalString(_ key: String) throws(AutomationActionError) -> String? {
        guard let value = values[key], value != .null else {
            return nil
        }
        guard case .string(let string) = value else {
            throw AutomationActionError.invalidArguments("Argument \(key) must be a string.")
        }
        return string
    }

    func optionalStrings(_ key: String) throws(AutomationActionError) -> [String] {
        guard let value = values[key], value != .null else { return [] }
        guard case .array(let values) = value else {
            throw .invalidArguments("Argument \(key) must be an array of strings.")
        }
        return try values.map { value throws(AutomationActionError) -> String in
            guard case .string(let string) = value, !string.isEmpty else {
                throw .invalidArguments("Argument \(key) must contain nonempty strings.")
            }
            return string
        }
    }

    func optionalInteger(_ key: String) throws(AutomationActionError) -> Int? {
        guard let value = values[key], value != .null else {
            return nil
        }
        guard case .integer(let integer) = value else {
            throw AutomationActionError.invalidArguments("Argument \(key) must be an integer.")
        }
        return integer
    }
}
