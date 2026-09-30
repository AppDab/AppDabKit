public protocol BuildExportComplianceServing: Sendable {
    func setBuildExportCompliance(accountID: String, request: BuildExportComplianceRequest) async throws -> BuildExportComplianceResult
}
