import AppDabServices

public struct SetBuildExportComplianceInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let buildID: String
    public let needsDocuments: Bool
    public let availableOnFrenchStore: Bool
    public let containsProprietaryCryptography: Bool
    public let containsThirdPartyCryptography: Bool
    public let purpose: String?
    public let documentPath: String?

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "appID", "buildID", "needsDocuments", "availableOnFrenchStore", "containsProprietaryCryptography", "containsThirdPartyCryptography", "purpose", "documentPath"])
        accountID = try arguments.requiredString("accountID")
        appID = try arguments.requiredString("appID")
        buildID = try arguments.requiredString("buildID")
        needsDocuments = try Self.requiredBool("needsDocuments", in: arguments)
        availableOnFrenchStore = try Self.requiredBool("availableOnFrenchStore", in: arguments)
        containsProprietaryCryptography = try Self.requiredBool("containsProprietaryCryptography", in: arguments)
        containsThirdPartyCryptography = try Self.requiredBool("containsThirdPartyCryptography", in: arguments)
        purpose = try arguments.optionalString("purpose")
        documentPath = try arguments.optionalString("documentPath")
    }

    private static func requiredBool(_ key: String, in arguments: Arguments) throws(AutomationActionError) -> Bool {
        guard let value = arguments.value(key), case let .bool(result) = value else { throw .invalidArguments("Argument \(key) must be a boolean.") }
        return result
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty, !appID.isEmpty, !buildID.isEmpty else { throw .invalidArguments("Account, app, and build identifiers must be nonempty.") }
        if needsDocuments, documentPath?.isEmpty != false {
            throw .invalidArguments("documentPath is required when needsDocuments is true.")
        }
        if needsDocuments, purpose?.isEmpty != false {
            throw .invalidArguments("purpose is required when export compliance documents are needed.")
        }
        if let purpose, purpose.count > 300 {
            throw .invalidArguments("purpose must be 300 characters or fewer.")
        }
    }

    public var request: BuildExportComplianceRequest {
        .init(appID: appID, buildID: buildID, needsDocuments: needsDocuments, availableOnFrenchStore: availableOnFrenchStore, containsProprietaryCryptography: containsProprietaryCryptography, containsThirdPartyCryptography: containsThirdPartyCryptography, purpose: purpose, documentPath: documentPath)
    }
}
