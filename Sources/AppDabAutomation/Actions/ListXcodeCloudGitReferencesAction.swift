import AppDabServices

public struct ListXcodeCloudGitReferencesAction: AutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .listXcodeCloudGitReferences, title: "List Xcode Cloud Git References",
        description: "List branch and tag references in a repository. Use a gitReferenceID as sourceBranchOrTagID when starting a build.",
        inputSchema: Schema.object(properties: [
            "accountID": Schema.string(description: "The AppDab account identifier."),
            "repositoryID": Schema.string(description: "The repositoryID resource identifier."),
            "cursor": Schema.paginationCursor,
            "limit": Schema.paginationLimit,
        ], required: ["accountID", "repositoryID"]),
        outputSchema: Schema.object(properties: ["repositoryID": Schema.outputString, "gitReferences": Schema.array(items: Schema.xcodeCloudGitReferenceOutput), "pagination": Schema.paginationOutput], required: ["repositoryID", "gitReferences", "pagination"]),
        outputType: "gitReferences", safety: .read,
    )

    public init() {}

    public func perform(input: ListXcodeCloudGitReferencesInput, dataProvider: any AutomationDataProviding) async throws -> XcodeCloudGitReferenceList {
        try await dataProvider.listXcodeCloudGitReferences(accountID: input.accountID, repositoryID: input.repositoryID, pagination: input.pagination)
    }

    public func summary(for output: XcodeCloudGitReferenceList) -> String {
        "Found \(output.gitReferences.count) Xcode Cloud Git references."
    }

    public func data(for output: XcodeCloudGitReferenceList) throws -> JSONValue {
        try .fromEncodable(output)
    }
}
