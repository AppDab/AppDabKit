import AppDabServices

public struct GetXcodeCloudBuildAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .getXcodeCloudBuild, title: "Get Xcode Cloud Build",
        description: "Read the current progress and completion status of an Xcode Cloud build run.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "buildRunID": Schema.string(description: "The buildRunID resource identifier."),
        ], required: ["accountID", "buildRunID"]),
        outputSchema: Schema.object(properties: ["buildRun": Schema.xcodeCloudBuildRunOutput], required: ["buildRun"]),
        outputType: "buildRun", safety: .read,
    )

    public init() {}

    public func perform(input: GetXcodeCloudBuildInput, dataProvider: any AutomationDataProviding) async throws -> XcodeCloudBuildRun {
        try await dataProvider.getXcodeCloudBuild(accountID: input.accountID, buildRunID: input.buildRunID)
    }

    public func summary(for output: XcodeCloudBuildRun) -> String {
        "Xcode Cloud build \(output.buildRunID): \(output.executionProgress ?? "unknown")."
    }

    public func data(for output: XcodeCloudBuildRun) throws -> JSONValue {
        try .object(["buildRun": .fromEncodable(output)])
    }
}
