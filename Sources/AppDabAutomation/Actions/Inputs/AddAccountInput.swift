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
            allowedKeys: ["name", "keyID", "issuerID", "privateKeyFile"]
        )
        name = try arguments.requiredString("name").trimmingCharacters(in: .whitespacesAndNewlines)
        keyID = try arguments.requiredString("keyID").trimmingCharacters(in: .whitespacesAndNewlines)
        issuerID = try (arguments.optionalString("issuerID") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        privateKeyFile = try arguments.requiredString("privateKeyFile")
    }

    public func validate() throws(AutomationActionError) {
        guard !name.isEmpty else {
            throw .invalidArguments("Argument name must be a nonempty string.")
        }
        guard !keyID.isEmpty else {
            throw .invalidArguments("Argument keyID must be a nonempty string.")
        }
        guard !privateKeyFile.isEmpty, privateKeyFile != "-" else {
            throw .invalidArguments("Argument privateKeyFile must name a local file.")
        }
    }
}
