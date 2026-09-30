import AppDabServices

public struct GetBetaLicenseAgreementAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getBetaLicenseAgreement, title: "Get Beta License Agreement",
        description: "Read the beta testing license agreement for an app.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: ["licenseAgreement": Schema.betaLicenseAgreementOutput], required: ["licenseAgreement"]),
        outputType: "betaLicenseAgreement", safety: .read,
    )

    public init() {}
    public func perform(input: GetAppInput, dataProvider: any AutomationDataProviding) async throws -> JSONValue {
        let agreement = try await dataProvider.getBetaLicenseAgreement(accountID: input.accountID, appID: input.appID)
        return try .object(["licenseAgreement": .fromEncodable(agreement)])
    }

    public func summary(for _: JSONValue) -> String {
        "Read beta license agreement."
    }

    public func data(for output: JSONValue) throws -> JSONValue {
        output
    }
}
