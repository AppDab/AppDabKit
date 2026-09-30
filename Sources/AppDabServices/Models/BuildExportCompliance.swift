import Foundation

public struct BuildExportComplianceRequest: Sendable {
    public let appID: String
    public let buildID: String
    public let needsDocuments: Bool
    public let availableOnFrenchStore: Bool
    public let containsProprietaryCryptography: Bool
    public let containsThirdPartyCryptography: Bool
    public let purpose: String?
    public let documentPath: String?

    public init(appID: String, buildID: String, needsDocuments: Bool, availableOnFrenchStore: Bool, containsProprietaryCryptography: Bool, containsThirdPartyCryptography: Bool, purpose: String? = nil, documentPath: String? = nil) {
        self.appID = appID
        self.buildID = buildID
        self.needsDocuments = needsDocuments
        self.availableOnFrenchStore = availableOnFrenchStore
        self.containsProprietaryCryptography = containsProprietaryCryptography
        self.containsThirdPartyCryptography = containsThirdPartyCryptography
        self.purpose = purpose
        self.documentPath = documentPath
    }
}

public struct BuildExportComplianceResult: Codable, Equatable, Sendable {
    public let build: BuildSummary
    public let declarationID: String?
    public let documentID: String?

    public init(build: BuildSummary, declarationID: String?, documentID: String?) {
        self.build = build
        self.declarationID = declarationID
        self.documentID = documentID
    }
}
