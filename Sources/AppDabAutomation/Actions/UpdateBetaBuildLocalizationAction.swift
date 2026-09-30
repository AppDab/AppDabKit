import AppDabServices
import Foundation

public struct UpdateBetaBuildLocalizationAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .updateBetaBuildLocalization,
        title: "Update Beta Build Localization",
        description: "Update the localized What to Test text for a TestFlight build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "localizationID": Schema.string(description: "The beta build localization identifier."),
            "whatsNew": Schema.string(description: "The What to Test text, up to 4000 characters."),
        ], required: ["accountID", "localizationID", "whatsNew"]),
        outputSchema: Schema.object(properties: ["localization": Schema.betaBuildLocalizationOutput], required: ["localization"]),
        outputType: "betaBuildLocalization",
        safety: .write,
    )

    public init() {}

    public func perform(input _: UpdateBetaBuildLocalizationInput, dataProvider _: any AutomationDataProviding) async throws -> BetaBuildLocalizationSummary {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: UpdateBetaBuildLocalizationInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let current = try await dataProvider.getBetaBuildLocalization(accountID: input.accountID, localizationID: input.localizationID)
        return try .init(
            targetIdentifiers: [input.accountID, input.localizationID],
            redactedSummary: "Update What to Test text for \(current.locale).",
            remotePreconditions: ["localization": .fromEncodable(current)],
        )
    }

    public func validateMutation(input: UpdateBetaBuildLocalizationInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let current = try await dataProvider.getBetaBuildLocalization(accountID: input.accountID, localizationID: input.localizationID)
        guard try plan.remotePreconditions["localization"] == JSONValue.fromEncodable(current) else {
            throw AutomationExecutionError.preconditionFailed("Beta build localization changed after preview.")
        }
    }

    public func commitMutation(input: UpdateBetaBuildLocalizationInput, plan _: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> BetaBuildLocalizationSummary {
        try await dataProvider.updateBetaBuildLocalization(accountID: input.accountID, localizationID: input.localizationID, whatsNew: input.whatsNew)
    }

    public func reconcileMutation(input: UpdateBetaBuildLocalizationInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<BetaBuildLocalizationSummary> {
        let current = try await dataProvider.getBetaBuildLocalization(accountID: input.accountID, localizationID: input.localizationID)
        if current.whatsNew == input.whatsNew {
            return .succeeded(current)
        }
        return try plan.remotePreconditions["localization"] == JSONValue.fromEncodable(current) ? .notApplied : .unresolved
    }

    public func summary(for output: BetaBuildLocalizationSummary) -> String {
        "Updated What to Test text for \(output.locale)."
    }

    public func data(for output: BetaBuildLocalizationSummary) throws -> JSONValue {
        try .object(["localization": .fromEncodable(output)])
    }

    public func redactedReplayData(for output: BetaBuildLocalizationSummary) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> BetaBuildLocalizationSummary {
        guard let localization = data.objectValue?["localization"] else {
            throw AutomationActionError.invalidArguments("Beta build localization replay data is missing.")
        }
        return try JSONDecoder().decode(BetaBuildLocalizationSummary.self, from: JSONEncoder().encode(localization))
    }
}
