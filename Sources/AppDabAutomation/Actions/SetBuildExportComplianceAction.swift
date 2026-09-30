import AppDabServices
import Foundation

public struct SetBuildExportComplianceAction: GuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .setBuildExportCompliance,
        title: "Set Build Export Compliance",
        description: "Set a build's export compliance answer and upload its required PDF or ZIP document.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "buildID": Schema.string(description: "The App Store Connect build identifier."),
            "needsDocuments": .object(["type": .string("boolean"), "description": .string("Whether export compliance documents are required.")]),
            "availableOnFrenchStore": .object(["type": .string("boolean"), "description": .string("Whether the app is available on the French App Store.")]),
            "containsProprietaryCryptography": .object(["type": .string("boolean"), "description": .string("Whether the app contains proprietary cryptography.")]),
            "containsThirdPartyCryptography": .object(["type": .string("boolean"), "description": .string("Whether the app contains third party cryptography.")]),
            "purpose": Schema.string(description: "The app's cryptography purpose, up to 300 characters."),
            "documentPath": Schema.string(description: "Path to a PDF or ZIP compliance document on the machine running AppDabKit."),
        ], required: ["accountID", "appID", "buildID", "needsDocuments", "availableOnFrenchStore", "containsProprietaryCryptography", "containsThirdPartyCryptography"]),
        outputSchema: Schema.object(properties: ["build": Schema.buildSummaryOutput, "declarationID": Schema.string(description: "Created App Store Connect declaration identifier."), "documentID": Schema.string(description: "Created App Store Connect document identifier.")], required: ["build"]),
        outputType: "build_export_compliance",
        safety: .write,
    )

    public init() {}

    public func perform(input _: SetBuildExportComplianceInput, dataProvider _: any AutomationDataProviding) async throws -> BuildExportComplianceResult {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: SetBuildExportComplianceInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let build = try await dataProvider.getBuild(accountID: input.accountID, buildID: input.buildID)
        return try .init(targetIdentifiers: [input.accountID, input.appID, input.buildID], redactedSummary: "Set export compliance for build \(build.version).", remotePreconditions: ["build": .fromEncodable(build)])
    }

    public func validateMutation(input: SetBuildExportComplianceInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let build = try await dataProvider.getBuild(accountID: input.accountID, buildID: input.buildID)
        guard try plan.remotePreconditions["build"] == JSONValue.fromEncodable(build) else { throw AutomationExecutionError.preconditionFailed("Build state changed after preview.") }
    }

    public func commitMutation(input: SetBuildExportComplianceInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BuildExportComplianceResult {
        try await dataProvider.setBuildExportCompliance(accountID: input.accountID, request: input.request)
    }

    public func summary(for output: BuildExportComplianceResult) -> String {
        "Set export compliance for build \(output.build.version)."
    }

    public func data(for output: BuildExportComplianceResult) throws -> JSONValue {
        try .fromEncodable(output)
    }

    public func redactedReplayData(for output: BuildExportComplianceResult) throws -> JSONValue {
        try data(for: output)
    }
}
