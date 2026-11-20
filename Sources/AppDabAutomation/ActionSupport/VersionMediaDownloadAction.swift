import AppDabServices
import Foundation

/// Writes a new local file directly, without creating a remote mutation plan.
public protocol VersionMediaDownloadAction: AutomationAction where Input: VersionMediaActionInput, Output == VersionMediaActionOutput {}

public extension VersionMediaDownloadAction {
    static var supportsDirectWriteExecution: Bool {
        true
    }

    func perform(input: Input, dataProvider: any AutomationDataProviding) async throws -> VersionMediaActionOutput {
        let arguments = input.mediaArguments
        guard let placementID = arguments.placementID, let destinationPath = arguments.destinationPath else {
            throw AutomationActionError.invalidArguments("A placement and destination are required for download.")
        }
        guard !FileManager.default.fileExists(atPath: destinationPath) else {
            throw AutomationActionError.invalidArguments("The destination already exists.")
        }
        let service = try dataProvider.versionMedia()
        try await service.validateDownload(scope: arguments.scope, placementID: placementID, destinationPath: destinationPath)
        return try await .init(result: service.download(scope: arguments.scope, placementID: placementID, destinationPath: destinationPath))
    }

    func summary(for output: VersionMediaActionOutput) -> String {
        VersionMediaActionSupport.summary(output, actionID: Self.descriptor.id)
    }

    func data(for output: VersionMediaActionOutput) throws -> JSONValue {
        try JSONValue.fromEncodable(output)
    }
}
