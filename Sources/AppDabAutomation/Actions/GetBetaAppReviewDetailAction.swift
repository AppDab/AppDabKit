import AppDabServices
import Foundation

public struct GetBetaAppReviewDetailAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getBetaAppReviewDetail, title: "Get Beta App Review Detail",
        description: "Read the beta app review contact and demo account details.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "appID": Schema.string(description: "The App Store Connect app identifier."),
        ], required: ["accountID", "appID"]),
        outputSchema: Schema.object(properties: ["reviewDetail": Schema.betaAppReviewDetailOutput], required: ["reviewDetail"]),
        outputType: "betaAppReviewDetail", safety: .read,
    )

    public init() {}
    public func perform(input: GetAppInput, dataProvider: any AutomationDataProviding) async throws -> JSONValue {
        let detail = try await dataProvider.getBetaAppReviewDetail(accountID: input.accountID, appID: input.appID)
        let value = BetaAppReviewDetailSummary(reviewDetailID: detail.reviewDetailID,
                                               contactFirstName: detail.contactFirstName, contactLastName: detail.contactLastName,
                                               contactPhone: detail.contactPhone, contactEmail: detail.contactEmail,
                                               demoAccountRequired: detail.demoAccountRequired, demoAccountName: detail.demoAccountName,
                                               demoAccountPassword: "", notes: detail.notes)
        var object = try JSONValue.fromEncodable(value).objectValue ?? [:]
        object.removeValue(forKey: "demoAccountPassword")
        return .object(["reviewDetail": .object(object)])
    }

    public func summary(for _: JSONValue) -> String {
        "Read beta app review details."
    }

    public func data(for output: JSONValue) throws -> JSONValue {
        output
    }
}
