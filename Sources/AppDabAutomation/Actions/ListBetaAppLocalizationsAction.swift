import AppDabServices

public struct ListBetaAppLocalizationsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listBetaAppLocalizations, title: "List Beta App Localizations",
        description: "List the localized beta testing details for an app.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: ["localizations": Schema.array(items: Schema.betaAppLocalizationOutput)], required: ["localizations"]),
        outputType: "betaAppLocalizations", safety: .read,
    )

    public init() {}
    public func perform(input: GetAppInput, dataProvider: any AutomationDataProviding) async throws -> JSONValue {
        let localizations = try await dataProvider.listBetaAppLocalizations(accountID: input.accountID, appID: input.appID)
        return try .fromEncodable(["localizations": localizations])
    }

    public func summary(for _: JSONValue) -> String {
        "Listed beta app localizations."
    }

    public func data(for output: JSONValue) throws -> JSONValue {
        output
    }
}
