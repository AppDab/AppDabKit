import AppDabServices
import Foundation

public enum VersionMediaOperation: String, Sendable {
    case list, get, upload, download, remove, reorder
}

public struct VersionMediaArguments: Sendable {
    public let scope: VersionMediaScope
    public let operation: VersionMediaOperation
    public var placementID: String?
    public var filePath: String?
    public var placementGroup: String?
    public var previewFrameTimeCode: String?
    public var wait = false
    public var timeout = 300
    public var destinationPath: String?
    public var placementIDs: [String] = []
}

public protocol VersionMediaActionInput: AutomationActionInput {
    var mediaArguments: VersionMediaArguments { get }
}

public extension VersionMediaActionInput {
    func validate() throws(AutomationActionError) {
        let a = mediaArguments
        guard [a.scope.accountID, a.scope.versionID, a.scope.locale].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw .invalidArguments("Account, version, and locale must be nonempty.") }
        for value in [a.placementID, a.filePath, a.placementGroup, a.destinationPath, a.previewFrameTimeCode].compactMap(\.self) {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .invalidArguments("Media arguments must not be empty.") }
        }
        guard (1 ... 3600).contains(a.timeout) else { throw .invalidArguments("Timeout must be between 1 and 3600 seconds.") }
        if a.operation == .reorder {
            guard !a.placementIDs.isEmpty, a.placementIDs.allSatisfy({ !$0.isEmpty }), Set(a.placementIDs).count == a.placementIDs.count else { throw .invalidArguments("Supply distinct placement IDs in their desired order.") }
        }
    }
}

public struct VersionMediaActionOutput: Codable, Equatable, Sendable {
    public let list: VersionMediaList?
    public let result: VersionMediaResult?
    public init(list: VersionMediaList? = nil, result: VersionMediaResult? = nil) {
        self.list = list
        self.result = result
    }
}

public protocol VersionMediaReadAction: AutomationAction where Input: VersionMediaActionInput, Output == VersionMediaActionOutput {}
public protocol VersionMediaWriteAction: ReplayableGuardedAutomationAction where Input: VersionMediaActionInput, Output == VersionMediaActionOutput {}

public extension VersionMediaReadAction {
    func perform(input: Input, dataProvider: any AutomationDataProviding) async throws -> VersionMediaActionOutput {
        let a = input.mediaArguments
        let service = try dataProvider.versionMedia()
        if a.operation == .list {
            return try await .init(list: service.list(scope: a.scope, placementGroup: a.placementGroup))
        }
        return try await .init(result: .init(placements: [service.get(scope: a.scope, placementID: a.placementID!)]))
    }

    func summary(for output: VersionMediaActionOutput) -> String {
        VersionMediaActionSupport.summary(output, actionID: Self.descriptor.id)
    }

    func data(for output: VersionMediaActionOutput) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}

public extension VersionMediaWriteAction {
    func perform(input _: Input, dataProvider _: any AutomationDataProviding) async throws -> VersionMediaActionOutput {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .execute)
    }

    func prepareMutation(input: Input, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        let a = input.mediaArguments
        let service = try dataProvider.versionMedia()
        let list = try await service.list(scope: a.scope, placementGroup: a.placementGroup)
        var preconditions: [String: JSONValue] = try ["placements": .fromEncodable(list.placements), "requirements": .fromEncodable(list.requirements)]
        if let placementID = a.placementID {
            guard let placement = list.placements.first(where: { $0.id == placementID }) else { throw AutomationActionError.invalidArguments("The placement does not belong to this version localization and media type.") }
            preconditions["placement"] = try .fromEncodable(placement)
        }
        if a.operation == .upload {
            let fingerprint = try MediaFileFingerprint.read(path: a.filePath!)
            guard fingerprint.size > 0 else { throw AutomationActionError.invalidArguments("The upload file must not be empty.") }
            guard let requirement = list.requirements.first(where: { $0.placementGroup == a.placementGroup }) else { throw AutomationActionError.invalidArguments("Invalid placement group. Valid groups: \(list.requirements.map(\.placementGroup).joined(separator: ", ")).") }
            if let maximum = requirement.maximumCount, list.placements.count >= maximum {
                throw AutomationActionError.invalidArguments("The placement group has reached Apple's limit of \(maximum).")
            }
            try VersionMediaUpload.validateFile(path: a.filePath!, fingerprint: fingerprint, requirement: requirement)
            preconditions["file"] = try .fromEncodable(fingerprint)
        }
        if a.operation == .download, FileManager.default.fileExists(atPath: a.destinationPath!) {
            throw AutomationActionError.invalidArguments("The destination already exists.")
        }
        if a.operation == .reorder, Set(a.placementIDs) != Set(list.placements.map(\.id)) {
            throw AutomationActionError.invalidArguments("Supply every placement in this group exactly once.")
        }
        return .init(targetIdentifiers: [a.scope.accountID, a.scope.versionID, list.localizationID] + (a.placementID.map { [$0] } ?? []), redactedSummary: "\(a.operation.rawValue.capitalized) \(a.scope.kind == .screenshot ? "screenshots" : "app previews") for \(a.scope.locale) on version \(a.scope.versionID).", remotePreconditions: preconditions)
    }

    func validateMutation(input: Input, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        let preparation = try await prepareMutation(input: input, dataProvider: dataProvider)
        guard preparation.remotePreconditions == plan.remotePreconditions, preparation.targetIdentifiers == plan.targetIdentifiers else { throw AutomationExecutionError.preconditionFailed("The media, destination, requirements, or upload file changed since preview.") }
    }

    func commitMutation(input: Input, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> VersionMediaActionOutput {
        let a = input.mediaArguments
        let service = try dataProvider.versionMedia()
        let result: VersionMediaResult
        switch a.operation {
        case .upload:
            guard let file = plan.remotePreconditions["file"] else { throw AutomationExecutionError.preconditionFailed("Missing upload fingerprint.") }
            let fingerprint = try JSONDecoder().decode(MediaFileFingerprint.self, from: JSONEncoder().encode(file))
            result = try await service.upload(scope: a.scope, request: .init(filePath: a.filePath!, placementGroup: a.placementGroup!, previewFrameTimeCode: a.previewFrameTimeCode, wait: a.wait, timeout: a.timeout, fingerprint: fingerprint), operationID: plan.planID)
        case .download:
            result = try await service.download(scope: a.scope, placementID: a.placementID!, destinationPath: a.destinationPath!)
        case .remove:
            result = try await service.remove(scope: a.scope, placementID: a.placementID!)
        case .reorder:
            result = try await service.reorder(scope: a.scope, placementGroup: a.placementGroup!, placementIDs: a.placementIDs)
        case .list, .get:
            throw AutomationExecutionError.unsupportedExecutionMode(action: Self.descriptor.id.rawValue, mode: .commit)
        }
        return .init(result: result)
    }

    func reconcileMutation(input: Input, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<VersionMediaActionOutput> {
        let a = input.mediaArguments
        let service = try dataProvider.versionMedia()
        if a.operation == .upload {
            // The upload journal permits continuation only when a definite asset ID was recorded.
            guard let file = plan.remotePreconditions["file"] else { return .unresolved }
            let fingerprint = try JSONDecoder().decode(MediaFileFingerprint.self, from: JSONEncoder().encode(file))
            guard let result = try await service.recoverUpload(scope: a.scope, request: .init(filePath: a.filePath!, placementGroup: a.placementGroup!, previewFrameTimeCode: a.previewFrameTimeCode, wait: a.wait, timeout: a.timeout, fingerprint: fingerprint), operationID: plan.planID) else { return .unresolved }
            return .succeeded(.init(result: result))
        }
        let list = try await service.list(scope: a.scope, placementGroup: a.placementGroup)
        if a.operation == .remove, !list.placements.contains(where: { $0.id == a.placementID }) {
            return .succeeded(.init(result: .init()))
        }
        if a.operation == .reorder, list.placements.map(\.id) == a.placementIDs {
            return .succeeded(.init(result: .init(placements: list.placements)))
        }
        return .unresolved
    }

    func summary(for output: VersionMediaActionOutput) -> String {
        VersionMediaActionSupport.summary(output, actionID: Self.descriptor.id)
    }

    func data(for output: VersionMediaActionOutput) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }

    func redactedReplayData(for output: VersionMediaActionOutput) throws -> JSONValue {
        try data(for: output)
    }

    func output(fromReplayData data: JSONValue) throws -> VersionMediaActionOutput {
        let output = try JSONDecoder().decode(VersionMediaActionOutput.self, from: JSONEncoder().encode(data))
        try output.result?.validateDownloadedFile()
        return output
    }

    func validateReplayData(_ data: JSONValue) throws {
        _ = try output(fromReplayData: data)
    }
}

enum VersionMediaActionSupport {
    static func summary(_ output: VersionMediaActionOutput, actionID: AutomationActionID) -> String {
        if actionID.rawValue.hasPrefix("remove_") {
            return "Removed the version media placement. The reusable asset was retained."
        }
        if actionID.rawValue.hasPrefix("reorder_") {
            return "Reordered \(output.result?.placements.count ?? 0) media placements."
        }
        if actionID.rawValue.hasPrefix("upload_") {
            return "Uploaded media and attached placement \(output.result?.placements.first?.id ?? "")."
        }
        if let path = output.result?.destinationPath {
            return "Downloaded media to \(path)."
        }
        return "Found \((output.list?.placements ?? output.result?.placements ?? []).count) media placements."
    }

    static func descriptor(id: AutomationActionID, kind: VersionMediaKind, operation: VersionMediaOperation) -> AutomationActionDescriptor {
        var properties: [String: JSONValue] = ["accountID": Schema.string(description: "AppDab account identifier."), "versionID": Schema.string(description: "App Store version identifier."), "locale": Schema.string(description: "Existing version localization locale.")]
        var required = ["accountID", "versionID", "locale"]
        if [.get, .download, .remove].contains(operation) {
            properties["placementID"] = Schema.string(description: "Version placement identifier.")
            required.append("placementID")
        }
        if [.list, .upload, .reorder].contains(operation) {
            properties["placementGroup"] = Schema.string(description: "Apple placement group. List displays valid choices.")
            if operation != .list {
                required.append("placementGroup")
            }
        }
        if operation == .upload {
            properties["filePath"] = Schema.string(description: "Local file to upload.")
            properties["wait"] = .object(["type": .string("boolean")])
            properties["timeout"] = Schema.integer(description: "Processing timeout in seconds.", minimum: 1, maximum: 3600, default: 300)
            required.append("filePath")
            if kind == .appPreview {
                properties["previewFrameTimeCode"] = Schema.string(description: "Preview frame time code.")
            }
        }
        if operation == .download {
            properties["destinationPath"] = Schema.string(description: "New local destination file.")
            required.append("destinationPath")
        }
        if operation == .reorder {
            properties["placementIDs"] = .object(["type": .string("array"), "items": .object(["type": .string("string")])])
            required.append("placementIDs")
        }
        return .init(id: id, title: "\(operation.rawValue.capitalized) \(kind == .screenshot ? "Screenshots" : "App Previews")", description: "\(operation.rawValue.capitalized) \(kind == .screenshot ? "screenshots" : "app previews") for an existing App Store version localization.", inputSchema: Schema.object(properties: properties, required: required), outputSchema: outputSchema, outputType: "versionMedia", safety: [.list, .get].contains(operation) ? .read : .write)
    }

    private static let string = Schema.string(description: "Media value.")
    private static let strings: JSONValue = .object(["type": .string("array"), "items": string])
    private static let integer: JSONValue = .object(["type": .string("integer")])
    private static let placement = Schema.object(properties: ["id": string, "assetID": string, "placementGroup": string, "fileName": string, "fileSize": integer, "assetState": string, "placementState": string, "stateDetails": .object(["type": .string("array"), "items": .object(["type": .string("object")])])], required: ["id", "assetID", "placementGroup", "fileName", "assetState", "placementState", "stateDetails"])
    private static let placements: JSONValue = .object(["type": .string("array"), "items": placement])
    private static let requirements: JSONValue = .object(["type": .string("array"), "items": Schema.object(properties: ["placementGroup": string, "maximumCount": integer, "specs": .object(["type": .string("array"), "items": .object(["type": .string("object")])])], required: ["placementGroup", "specs"])])
    static let outputSchema = Schema.object(properties: [
        "list": Schema.object(properties: ["appID": string, "localizationID": string, "placements": placements, "requirements": requirements], required: ["appID", "localizationID", "placements", "requirements"]),
        "result": Schema.object(properties: ["placements": placements, "assetID": string, "uploadComplete": .object(["type": .string("boolean")]), "destinationPath": string, "fingerprint": Schema.object(properties: ["size": integer, "sha256": string], required: ["size", "sha256"])], required: ["placements"]),
    ])
}
