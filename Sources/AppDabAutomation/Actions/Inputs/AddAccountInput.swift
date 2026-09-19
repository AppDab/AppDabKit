import AppDabServices

public struct AddAccountInput: AutomationActionInput {
    public let name: String
    public let keyID: String
    public let issuerID: String
    public let privateKeyFile: String

    public init(name: String, keyID: String, issuerID: String = "", privateKeyFile: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.keyID = keyID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.issuerID = issuerID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.privateKeyFile = privateKeyFile
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(
            arguments,
            allowedKeys: ["name", "key_id", "issuer_id", "private_key_file"]
        )
        name = try arguments.requiredString("name").trimmingCharacters(in: .whitespacesAndNewlines)
        keyID = try arguments.requiredString("key_id").trimmingCharacters(in: .whitespacesAndNewlines)
        issuerID = try (arguments.optionalString("issuer_id") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        privateKeyFile = try arguments.requiredString("private_key_file")
    }

    public func validate() throws(AutomationActionError) {
        guard !name.isEmpty else {
            throw .invalidArguments("Argument name must be a nonempty string.")
        }
        guard !keyID.isEmpty else {
            throw .invalidArguments("Argument key_id must be a nonempty string.")
        }
        guard !privateKeyFile.isEmpty, privateKeyFile != "-" else {
            throw .invalidArguments("Argument private_key_file must name a local file.")
        }
    }
}
