import AppDabServices

public struct ListAppVersionsAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listAppVersions,
        title: "List App Versions",
        description: "List authoritative app versions, including older and replaced versions. Follow pagination to read every match.",
        inputSchema: Schema.object(
            properties: [
                "account_id": Schema.string(description: "The AppDab account identifier."),
                "app_id": Schema.string(description: "The App Store Connect app identifier."),
                "platforms": .object(["type": .string("array"), "items": Schema.string(description: "Platform raw value.")]),
                "states": .object(["type": .string("array"), "items": Schema.string(description: "App version state raw value.")]),
                "versions": .object(["type": .string("array"), "items": Schema.string(description: "Version string.")]),
                "version_ids": .object(["type": .string("array"), "items": Schema.string(description: "Version identifier.")]),
                "cursor": Schema.paginationCursor,
                "limit": Schema.integer(
                    description: "Maximum versions to return, from 1 through 200.",
                    minimum: 1,
                    maximum: PaginationRequest.maximumLimit,
                    default: PaginationRequest.defaultLimit
                )
            ],
            required: ["account_id", "app_id"]
        ),
        outputSchema: Schema.object(
            properties: [
                "app_id": Schema.string(description: "The App Store Connect app identifier."),
                "versions": .object(["type": .string("array")]),
                "pagination": Schema.paginationOutput
            ],
            required: ["app_id", "versions", "pagination"]
        ),
        outputType: "app_versions",
        safety: .read
    )

    public init() {}

    public func perform(
        input: ListAppVersionsInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AppVersionList {
        try await dataProvider.listAppVersions(
            accountID: input.accountID,
            appID: input.appID,
            filter: input.filter,
            pagination: input.pagination
        )
    }

    public func summary(for output: AppVersionList) -> String {
        "Found \(output.versions.count) versions."
    }

    public func data(for output: AppVersionList) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
