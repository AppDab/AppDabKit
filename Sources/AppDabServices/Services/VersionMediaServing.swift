public protocol VersionMediaServing: Sendable {
    func get(scope: VersionMediaScope, placementID: String) async throws -> VersionMediaPlacement
    func list(scope: VersionMediaScope, placementGroup: String?) async throws -> VersionMediaList
    func upload(scope: VersionMediaScope, request: VersionMediaUpload, operationID: String) async throws -> VersionMediaResult
    func recoverUpload(scope: VersionMediaScope, request: VersionMediaUpload, operationID: String) async throws -> VersionMediaResult?
    func validateDownload(scope: VersionMediaScope, placementID: String, destinationPath: String) async throws
    func download(scope: VersionMediaScope, placementID: String, destinationPath: String) async throws -> VersionMediaResult
    func remove(scope: VersionMediaScope, placementID: String) async throws -> VersionMediaResult
    func reorder(scope: VersionMediaScope, placementGroup: String, placementIDs: [String]) async throws -> VersionMediaResult
}

public extension VersionMediaServing {
    func validateDownload(scope: VersionMediaScope, placementID: String, destinationPath _: String) async throws {
        _ = try await get(scope: scope, placementID: placementID)
    }

    func recoverUpload(scope _: VersionMediaScope, request _: VersionMediaUpload, operationID _: String) async throws -> VersionMediaResult? {
        nil
    }

    func get(scope: VersionMediaScope, placementID: String) async throws -> VersionMediaPlacement {
        guard let placement = try await list(scope: scope, placementGroup: nil).placements.first(where: { $0.id == placementID }) else {
            throw ServiceError.invalidArguments("The placement does not belong to this version localization and media type.")
        }
        return placement
    }
}

/// Keeps existing service collections source compatible until they opt into media support.
public struct UnavailableVersionMediaService: VersionMediaServing {
    public init() {}
    public func list(scope _: VersionMediaScope, placementGroup _: String?) async throws -> VersionMediaList {
        throw unavailable
    }

    public func upload(scope _: VersionMediaScope, request _: VersionMediaUpload, operationID _: String) async throws -> VersionMediaResult {
        throw unavailable
    }

    public func download(scope _: VersionMediaScope, placementID _: String, destinationPath _: String) async throws -> VersionMediaResult {
        throw unavailable
    }

    public func remove(scope _: VersionMediaScope, placementID _: String) async throws -> VersionMediaResult {
        throw unavailable
    }

    public func reorder(scope _: VersionMediaScope, placementGroup _: String, placementIDs _: [String]) async throws -> VersionMediaResult {
        throw unavailable
    }

    private var unavailable: ServiceError {
        .upstream("Version media is unavailable for this provider.")
    }
}
