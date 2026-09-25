import AppDabServices
import BagbutikCore
import Foundation

public struct CreateAppVersionAction: ReplayableGuardedAutomationAction {
    public static let descriptor = AutomationActionDescriptor(
        id: .createAppVersion,
        title: "Create App Version",
        description: "Create a new App Store Connect version for one app and platform.",
        inputSchema: Schema.object(
            properties: [
                "accountID": Schema.string(description: "The AppDab account identifier."),
                "appID": Schema.string(description: "The App Store Connect app identifier."),
                "platform": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect platform."),
                    "enum": .array(Platform.allCases.map { .string($0.rawValue) }),
                ]),
                "version": Schema.string(description: "The new version string.")
            ],
            required: ["accountID", "appID", "platform", "version"]
        ),
        outputSchema: Schema.object(properties: [
            "version": .object(["type": .string("object")])
        ], required: ["version"]),
        outputType: "version",
        safety: .write
    )

    public init() {}

    public func perform(
        input: CreateAppVersionInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AppVersion {
        throw AutomationExecutionError.unsupportedExecutionMode(
            action: Self.descriptor.id.rawValue,
            mode: .execute
        )
    }

    public func prepareMutation(
        input: CreateAppVersionInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationPreparation {
        let app = try await dataProvider.getApp(accountID: input.accountID, appID: input.appID)
        let targetVersions = try await targetVersions(input: input, dataProvider: dataProvider)
        guard !targetVersions.contains(where: { $0.version == input.version }) else {
            throw AutomationActionError.invalidArguments(
                "Version \(input.version) already exists for \(input.platform.prettyName) on \(app.name)."
            )
        }
        return .init(
            targetIdentifiers: [input.accountID, input.appID, input.platform.rawValue],
            redactedSummary: "Create version \(input.version) for \(input.platform.prettyName) on \(app.name).",
            remotePreconditions: try remotePreconditions(for: targetVersions, input: input)
        )
    }

    public func validateMutation(
        input: CreateAppVersionInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws {
        let app = try await dataProvider.getApp(accountID: input.accountID, appID: input.appID)
        let currentPreconditions = try remotePreconditions(
            for: try await targetVersions(input: input, dataProvider: dataProvider),
            input: input
        )
        guard plan.remotePreconditions == currentPreconditions else {
            throw AutomationExecutionError.preconditionFailed(
                "The \(input.platform.prettyName) versions for \(app.name) changed after preview."
            )
        }
    }

    public func commitMutation(
        input: CreateAppVersionInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> AppVersion {
        try await dataProvider.createAppVersion(
            accountID: input.accountID,
            appID: input.appID,
            platform: input.platform.rawValue,
            version: input.version
        )
    }

    public func reconcileMutation(
        input: CreateAppVersionInput,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationReconciliation<AppVersion> {
        let targetVersions = try await targetVersions(input: input, dataProvider: dataProvider)
        if let version = targetVersions.first(where: { $0.version == input.version }) {
            return .succeeded(version)
        }
        if plan.remotePreconditions == (try remotePreconditions(for: targetVersions, input: input)) {
            return .notApplied
        }
        return .unresolved
    }

    public func summary(for output: AppVersion) -> String {
        "Created version \(output.version) for \(output.platform)."
    }

    public func data(for output: AppVersion) throws -> JSONValue {
        .object(["version": try JSONValue.fromEncodable(output)])
    }

    public func redactedReplayData(for output: AppVersion) throws -> JSONValue {
        try data(for: output)
    }

    public func output(fromReplayData data: JSONValue) throws -> AppVersion {
        struct Replay: Decodable {
            let version: AppVersion
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Replay.self, from: JSONEncoder().encode(data)).version
    }

    private func targetVersions(
        input: CreateAppVersionInput,
        dataProvider: any AutomationDataProviding
    ) async throws -> [AppVersion] {
        var versions = [AppVersion]()
        var cursor: String?
        var seenCursors = Set<String>()
        repeat {
            let page = try await dataProvider.listAppVersions(
                accountID: input.accountID, appID: input.appID,
                filter: .init(platforms: [input.platform]),
                pagination: .init(cursor: cursor, limit: PaginationRequest.maximumLimit)
            )
            versions.append(contentsOf: page.versions)
            cursor = page.pagination.nextCursor
            if let cursor, !seenCursors.insert(cursor).inserted {
                throw ServiceError.upstream("App Store Connect returned a repeated version cursor.")
            }
        } while cursor != nil
        return versions.sorted { $0.versionID < $1.versionID }
    }

    private func remotePreconditions(
        for targetVersions: [AppVersion],
        input: CreateAppVersionInput
    ) throws -> [String: JSONValue] {
        [
            "platform": .string(input.platform.rawValue),
            "versions": try JSONValue.fromEncodable(targetVersions),
        ]
    }
}
