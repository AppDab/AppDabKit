@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

private actor MediaActionFixture: VersionMediaServing {
    var mutations = 0
    var placements = [VersionMediaPlacement(id: "placement", assetID: "asset", placementGroup: "IPHONE", fileName: "screen.png", assetState: "COMPLETE", placementState: "ACTIVE")]
    func changePlacement() {
        placements = []
    }

    func list(scope _: VersionMediaScope, placementGroup _: String?) async throws -> VersionMediaList {
        .init(appID: "app", localizationID: "localization", placements: placements, requirements: [.init(placementGroup: "IPHONE")])
    }

    func upload(scope _: VersionMediaScope, request _: VersionMediaUpload, operationID _: String) async throws -> VersionMediaResult {
        mutations += 1
        return .init(placements: placements, assetID: "asset", uploadComplete: true)
    }

    func download(scope _: VersionMediaScope, placementID _: String, destinationPath: String) async throws -> VersionMediaResult {
        mutations += 1
        try Data("download".utf8).write(to: URL(fileURLWithPath: destinationPath), options: .withoutOverwriting)
        return try .init(destinationPath: destinationPath, fingerprint: .read(path: destinationPath))
    }

    func remove(scope _: VersionMediaScope, placementID _: String) async throws -> VersionMediaResult {
        mutations += 1
        placements = []
        return .init()
    }

    func reorder(scope _: VersionMediaScope, placementGroup _: String, placementIDs _: [String]) async throws -> VersionMediaResult {
        mutations += 1
        return .init(placements: placements)
    }
}

struct VersionMediaActionTests {
    private func executor(_ service: MediaActionFixture) -> Executor {
        .init(dataProvider: MockAutomationDataProvider(mediaService: service), auditStore: AutomationSQLiteAuditStore(databaseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("audit.sqlite")))
    }

    @Test func uploadPreviewReadsOnlyAndChangedFilesCannotCommit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("screen.png")
        try Data("original".utf8).write(to: file)
        let fixture = MediaActionFixture()
        let executor = executor(fixture)
        let input = UploadScreenshotInput(accountID: "account", versionID: "version", locale: "en-US", filePath: file.path, placementGroup: "IPHONE")
        let plan = try await executor.preview(UploadScreenshotAction.self, input: input)
        #expect(await fixture.mutations == 0)
        #expect(plan.remotePreconditions["file"]?.objectValue?["size"] == .integer(8))
        try Data("modified".utf8).write(to: file)
        await #expect(throws: AutomationExecutionError.self) {
            try await executor.commit(UploadScreenshotAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "changed")
        }
        #expect(await fixture.mutations == 0)
    }

    @Test func removalReplaysWithoutASecondMutationAndRejectsStalePreviews() async throws {
        let fixture = MediaActionFixture()
        let executor = executor(fixture)
        let input = RemoveScreenshotInput(accountID: "account", versionID: "version", locale: "en-US", placementID: "placement")
        let plan = try await executor.preview(RemoveScreenshotAction.self, input: input)
        let result = try await executor.commit(RemoveScreenshotAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "remove")
        let replay = try await executor.commit(RemoveScreenshotAction.self, input: input, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "remove")
        #expect(replay == result)
        #expect(await fixture.mutations == 1)
        let another = MediaActionFixture()
        let anotherExecutor = self.executor(another)
        let reorder = ReorderScreenshotsInput(accountID: "account", versionID: "version", locale: "en-US", placementGroup: "IPHONE", placementIDs: ["placement"])
        let stalePlan = try await anotherExecutor.preview(ReorderScreenshotsAction.self, input: reorder)
        await another.changePlacement()
        await #expect(throws: Error.self) {
            try await anotherExecutor.commit(ReorderScreenshotsAction.self, input: reorder, confirmationFingerprint: stalePlan.confirmationFingerprint, idempotencyKey: "stale")
        }
        #expect(await another.mutations == 0)
    }

    @Test func untypedDownloadReplayVerifiesTheActualFile() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let fixture = MediaActionFixture()
        let executor = executor(fixture)
        let arguments: [String: JSONValue] = ["accountID": .string("account"), "versionID": .string("version"), "locale": .string("en-US"), "placementID": .string("placement"), "destinationPath": .string(file.path)]
        let preview = try await executor.execute(.init(actionID: .downloadScreenshot, arguments: arguments, executionContext: .init(mode: .preview)))
        let plan = try #require(preview.plan)
        let request = AutomationRequest(actionID: .downloadScreenshot, arguments: arguments, executionContext: .init(mode: .commit, confirmationFingerprint: plan.confirmationFingerprint, idempotencyKey: "download"))
        _ = try await executor.execute(request)
        _ = try await executor.execute(request)
        try Data("changed".utf8).write(to: file)
        await #expect(throws: Error.self) { try await executor.execute(request) }
        #expect(await fixture.mutations == 1)
    }

    @Test func rejectsUnknownArgumentsWrongTypesAndDuplicateOrdering() throws {
        let arguments: [String: JSONValue] = ["accountID": .string("account"), "versionID": .string("version"), "locale": .string("en-US")]
        #expect(throws: AutomationActionError.self) { try ListScreenshotsInput(arguments: arguments.merging(["unexpected": .string("x")]) { _, new in new }) }
        #expect(throws: AutomationActionError.self) { try UploadAppPreviewInput(arguments: arguments.merging(["filePath": .string("x"), "placementGroup": .string("group"), "wait": .string("true")]) { _, new in new }) }
        #expect(throws: AutomationActionError.self) { try ReorderScreenshotsInput(accountID: "account", versionID: "version", locale: "en-US", placementGroup: "group", placementIDs: ["same", "same"]).validate() }
    }
}
