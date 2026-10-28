import BagbutikAppStore
import BagbutikAppStoreModels
import BagbutikCore
import Foundation

public final class VersionMediaService: VersionMediaServing, Sendable {
    private let accountProvider: any APIKeyProviding
    private let transport: any MediaTransferTransport
    private let fetchData: FetchData
    private let journal: MediaUploadJournal

    public init(accountProvider: any APIKeyProviding, transport: any MediaTransferTransport = URLSessionMediaTransferTransport(), journalDirectory: URL? = nil, fetchData: @escaping FetchData = URLSession.shared.data(for:delegate:)) {
        self.accountProvider = accountProvider
        self.transport = transport
        self.fetchData = fetchData
        journal = MediaUploadJournal(directory: journalDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("AppDab/MediaUploads"))
    }

    private func service(_ scope: VersionMediaScope) async throws -> BagbutikService {
        guard !scope.accountID.isEmpty, !scope.versionID.isEmpty, !scope.locale.isEmpty else {
            throw ServiceError.invalidArguments("Account, version, and locale are required.")
        }
        let key = try await accountProvider.apiKey(forAccountID: scope.accountID)
        return BagbutikService(jwt: key.jwt, fetchData: fetchData)
    }

    private struct Context {
        let appID: String
        let localizationID: String
        let libraryID: String
        let platform: String
    }

    private func context(_ scope: VersionMediaScope, service: BagbutikService) async throws -> Context {
        let version = try await service.request(.getAppStoreVersionV1(id: scope.versionID, includes: [.app]))
        guard let appID = version.data.relationships?.app?.data?.id else { throw ServiceError.upstream("The version has no owning app.") }
        let localizations = try await pages(service, .listAppStoreVersionLocalizationsForAppStoreVersionV1(id: scope.versionID))
        guard let localization = localizations.first(where: { $0.attributes?.locale == scope.locale }) else {
            throw ServiceError.invalidArguments("No existing localization for \(scope.locale). Available locales: \(localizations.compactMap { $0.attributes?.locale }.sorted().joined(separator: ", ")).")
        }
        let library = try await service.request(.getAssetLibraryForAppV1(id: appID))
        return .init(appID: appID, localizationID: localization.id, libraryID: library.data.id, platform: version.data.attributes?.platform?.rawValue ?? "")
    }

    private func pages<T: Decodable & PagedResponse & Sendable>(_ service: BagbutikService, _ request: Request<T, ErrorResponse>) async throws -> [T.Data] where T.Data: Sendable {
        var page = try await service.request(request)
        var result = page.data
        var seen = Set<String>()
        while let next = page.links.next {
            try Task.checkCancellation()
            guard let url = URL(string: next), url.scheme == "https", url.host == "api.appstoreconnect.apple.com", url.path == request.path, seen.insert(next).inserted else {
                throw ServiceError.upstream("Apple returned an invalid or repeated media pagination link.")
            }
            guard let following = try await service.requestNextPage(for: page) else { break }
            page = following
            result += page.data
        }
        return result
    }

    private func placementType(_ kind: VersionMediaKind) -> AppAssetLibraryPlacementType {
        kind == .screenshot ? .appScreenshot : .appPreview
    }

    public func get(scope: VersionMediaScope, placementID: String) async throws -> VersionMediaPlacement {
        do {
            let service = try await service(scope)
            let context = try await context(scope, service: service)
            let placement = try await service.request(.getAppAssetLibraryPlacementV1(id: placementID, includes: [.appStoreVersionLocalization, scope.kind == .screenshot ? .image : .video])).data
            guard matches(placement, context: context, kind: scope.kind, group: nil),
                  let assetID = scope.kind == .screenshot ? placement.relationships?.image?.data?.id : placement.relationships?.video?.data?.id
            else {
                throw ServiceError.invalidArguments("The placement does not belong to this version localization and media type.")
            }
            return try await normalized(placement, asset: asset(scope: scope, id: assetID, service: service))
        } catch { throw try ServiceError.classify(error) }
    }

    public func list(scope: VersionMediaScope, placementGroup: String? = nil) async throws -> VersionMediaList {
        do {
            let service = try await service(scope)
            let context = try await context(scope, service: service)
            var placements: [String: VersionMediaPlacement] = [:]
            if scope.kind == .screenshot {
                let assets = try await pages(service, .listImagesForAppAssetLibraryV1(id: context.libraryID, filters: [.category([.appScreenshotsAndPreviews])]))
                for asset in assets {
                    let related = try await pages(service, .listPlacementsForAppAssetLibraryImageV1(id: asset.id))
                    for placement in related where matches(placement, context: context, kind: scope.kind, group: placementGroup) {
                        placements[placement.id] = try normalized(placement, asset: asset)
                    }
                }
            } else {
                let assets = try await pages(service, .listVideosForAppAssetLibraryV1(id: context.libraryID, filters: [.category([.appScreenshotsAndPreviews])]))
                for asset in assets {
                    let related = try await pages(service, .listPlacementsForAppAssetLibraryVideoV1(id: asset.id))
                    for placement in related where matches(placement, context: context, kind: scope.kind, group: placementGroup) {
                        placements[placement.id] = try normalized(placement, asset: asset)
                    }
                }
            }
            // The localization endpoint supplies display order, which is absent from asset relationships.
            var filters: [ListPlacementsForAppStoreVersionLocalizationV1.Filter] = [.placementType([placementType(scope.kind)])]
            if let placementGroup {
                filters.append(.placementGroup([placementGroup]))
            }
            let ordered = try await pages(service, .listPlacementsForAppStoreVersionLocalizationV1(id: context.localizationID, filters: filters, sorts: [.placementGroupPositionAscending]))
            guard Set(ordered.map(\.id)) == Set(placements.keys) else {
                throw ServiceError.upstream("Version placements changed during discovery. Retry the command.")
            }
            let requirements = try await requirements(scope: scope, context: context, service: service)
            if let placementGroup {
                try Self.validateGroup(placementGroup, requirements: requirements)
            }
            return .init(appID: context.appID, localizationID: context.localizationID, placements: ordered.compactMap { placements[$0.id] }, requirements: requirements)
        } catch { throw try ServiceError.classify(error) }
    }

    private func matches(_ placement: AppAssetLibraryPlacement, context: Context, kind: VersionMediaKind, group: String?) -> Bool {
        placement.relationships?.appStoreVersionLocalization?.data?.id == context.localizationID
            && placement.attributes?.placementType == placementType(kind)
            && (group == nil || placement.attributes?.placementGroup == group)
    }

    private func normalized(_ placement: AppAssetLibraryPlacement, asset: some Encodable) throws -> VersionMediaPlacement {
        let value = try JSONValue.fromEncodable(asset)
        let attributes = value["attributes"]
        return try .init(id: placement.id, assetID: value["id"].stringValue ?? "", placementGroup: placement.attributes?.placementGroup ?? "", fileName: attributes["fileName"].stringValue ?? "", fileSize: attributes["fileSize"].intValue, assetState: attributes["state"].stringValue ?? "UNKNOWN", placementState: placement.attributes?.state?.rawValue ?? "UNKNOWN", stateDetails: attributes["stateDetails"].elements + (JSONValue.fromEncodable(placement)["attributes"]["stateDetails"].elements))
    }

    private func requirements(scope: VersionMediaScope, context: Context, service: BagbutikService) async throws -> [VersionMediaRequirement] {
        let references = try await pages(service, .listAppAssetLibraryRefDataV1())
        var result: [VersionMediaRequirement] = []
        for reference in references {
            let attributes = try JSONValue.fromEncodable(reference)["attributes"]
            let specs = attributes[scope.kind == .screenshot ? "imageSpecs" : "videoSpecs"].elements
            let platforms: Set<String> = switch context.platform {
            case "IOS": ["IPHONE_APP_STORE", "IPAD_APP_STORE", "WATCH_APP_STORE", "ANY"]
            case "MAC_OS": ["MAC_APP_STORE", "ANY"]
            case "TV_OS": ["TV_APP_STORE", "ANY"]
            case "VISION_OS": ["VISION_PRO_APP_STORE", "ANY"]
            default: ["ANY"]
            }
            let validGroupIDs = Set(attributes["placementProfileGroups"].elements.filter { platforms.contains($0["platform"].stringValue ?? "") }.compactMap { $0["placementProfileGroupId"].stringValue })
            for type in attributes["placementTypes"].elements where type["placementTypeId"].stringValue == placementType(scope.kind).rawValue {
                for mapping in type["specMappings"].elements {
                    guard let group = mapping["placementGroupId"].stringValue, validGroupIDs.contains(group) else { continue }
                    let specIDs = Set(mapping["specs"].elements.compactMap(\.stringValue))
                    let limits = attributes["features"].elements.filter { $0["featureId"].stringValue == "APP_STORE_VERSIONS" }.flatMap { $0["placementPolicies"].elements }.filter { $0["placementType"].stringValue == placementType(scope.kind).rawValue }.flatMap { $0["groupLimits"].elements }.filter { $0["groupIds"].elements.contains(.string(group)) }.compactMap { $0["maxCount"].intValue }
                    result.append(.init(placementGroup: group, specs: specs.filter { specIDs.contains($0["specId"].stringValue ?? "") }, maximumCount: limits.min()))
                }
            }
        }
        return result.sorted { $0.placementGroup < $1.placementGroup }
    }

    static func validateGroup(_ group: String, requirements: [VersionMediaRequirement]) throws {
        guard requirements.contains(where: { $0.placementGroup == group }) else {
            throw ServiceError.invalidArguments("Invalid placement group \(group). Valid groups: \(requirements.map(\.placementGroup).joined(separator: ", ")).")
        }
    }

    public func remove(scope: VersionMediaScope, placementID: String) async throws -> VersionMediaResult {
        do {
            let placement = try await get(scope: scope, placementID: placementID)
            let service = try await service(scope)
            _ = try await service.request(.deleteAppAssetLibraryPlacementV1(id: placementID))
            return .init(placements: [placement])
        } catch { throw try ServiceError.classify(error) }
    }

    public func reorder(scope: VersionMediaScope, placementGroup: String, placementIDs: [String]) async throws -> VersionMediaResult {
        do {
            let current = try await list(scope: scope, placementGroup: placementGroup)
            try Self.validateOrder(placementIDs, current: current.placements)
            let service = try await service(scope)
            _ = try await service.request(.createAppAssetLibraryPlacementOrderingRequestV1(requestBody: .init(data: .init(
                attributes: .init(placementGroup: placementGroup),
                relationships: .init(appStoreVersionLocalization: .init(data: .init(id: current.localizationID)), orderedPlacements: .init(data: placementIDs.map { .init(id: $0) })),
            ))))
            return .init(placements: placementIDs.compactMap { id in current.placements.first { $0.id == id } })
        } catch { throw try ServiceError.classify(error) }
    }

    static func validateOrder(_ ids: [String], current: [VersionMediaPlacement]) throws {
        guard !ids.isEmpty, Set(ids).count == ids.count, Set(ids) == Set(current.map(\.id)) else {
            throw ServiceError.invalidArguments("Supply every placement in this group exactly once, in the desired order.")
        }
    }

    public func download(scope: VersionMediaScope, placementID: String, destinationPath: String) async throws -> VersionMediaResult {
        do {
            let placement = try await get(scope: scope, placementID: placementID)
            let service = try await service(scope)
            let asset = try await asset(scope: scope, id: placement.assetID, service: service)
            let attributes = asset["attributes"]
            let url: URL?
            if scope.kind == .screenshot {
                let image = attributes["imageAsset"]
                if let template = image["templateUrl"].stringValue, let width = image["width"].intValue, let height = image["height"].intValue {
                    url = URL(string: template.replacingOccurrences(of: "{w}", with: String(width)).replacingOccurrences(of: "{h}", with: String(height)).replacingOccurrences(of: "{c}", with: "bb").replacingOccurrences(of: "{f}", with: "png"))
                } else {
                    url = nil
                }
            } else {
                url = attributes["videoAsset"].stringValue.flatMap(URL.init(string:))
            }
            guard let url, !url.absoluteString.lowercased().contains("%7b"), !url.absoluteString.contains("{") else { throw ServiceError.invalidArguments("Apple has not supplied downloadable media for this placement.") }
            let destination = URL(fileURLWithPath: destinationPath).standardizedFileURL
            try await transport.download(url: url, destination: destination)
            return try .init(placements: [placement], destinationPath: destination.path, fingerprint: MediaFileFingerprint.read(path: destination.path))
        } catch { throw try ServiceError.classify(error) }
    }

    private func asset(scope: VersionMediaScope, id: String, service: BagbutikService) async throws -> JSONValue {
        if scope.kind == .screenshot {
            return try await JSONValue.fromEncodable(service.request(.getAppAssetLibraryImageV1(id: id)).data)
        }
        return try await JSONValue.fromEncodable(service.request(.getAppAssetLibraryVideoV1(id: id)).data)
    }

    public func recoverUpload(scope: VersionMediaScope, request: VersionMediaUpload, operationID: String) async throws -> VersionMediaResult? {
        guard let entry = try await journal.load(operationID), entry.assetID != nil else { return nil }
        return try await upload(scope: scope, request: request, operationID: operationID)
    }

    public func upload(scope: VersionMediaScope, request: VersionMediaUpload, operationID: String) async throws -> VersionMediaResult {
        do {
            try Task.checkCancellation()
            guard !operationID.isEmpty, request.timeout > 0, request.timeout <= 3600, request.fingerprint.size > 0,
                  try MediaFileFingerprint.read(path: request.filePath) == request.fingerprint
            else {
                throw ServiceError.invalidArguments("The upload file changed or the upload options are invalid.")
            }
            let lease = try await journal.claim(operationID)
            defer { withExtendedLifetime(lease) {} }
            let service = try await service(scope)
            let current = try await list(scope: scope, placementGroup: request.placementGroup)
            let context = try await context(scope, service: service)
            guard let requirement = current.requirements.first(where: { $0.placementGroup == request.placementGroup }) else { throw ServiceError.invalidArguments("The placement group has no media requirements.") }
            try VersionMediaUpload.validateFile(path: request.filePath, fingerprint: request.fingerprint, requirement: requirement)
            let existing = try await journal.load(operationID)
            var progress = existing ?? .init(scope: scope, fingerprint: request.fingerprint, placementGroup: request.placementGroup)
            guard progress.scope == scope, progress.fingerprint == request.fingerprint, progress.placementGroup == request.placementGroup else { throw ServiceError.invalidArguments("Upload recovery does not match the original file and destination.") }
            if existing == nil {
                if let maximum = current.requirements.first(where: { $0.placementGroup == request.placementGroup })?.maximumCount, current.placements.count >= maximum {
                    throw ServiceError.invalidArguments("The placement group has reached Apple's limit of \(maximum).")
                }
                // Persist intent first. A crash before the returned ID is saved requires manual reconciliation.
                try await journal.save(progress, operationID: operationID)
                try Task.checkCancellation()
                let created: JSONValue = if scope.kind == .screenshot {
                    try await JSONValue.fromEncodable(service.request(.createAppAssetLibraryImageV1(requestBody: .init(data: .init(attributes: .init(category: .appScreenshotsAndPreviews, fileName: URL(fileURLWithPath: request.filePath).lastPathComponent, fileSize: request.fingerprint.size), relationships: .init(assetLibrary: .init(data: .init(id: context.libraryID))))))).data)
                } else {
                    try await JSONValue.fromEncodable(service.request(.createAppAssetLibraryVideoV1(requestBody: .init(data: .init(attributes: .init(category: .appScreenshotsAndPreviews, fileName: URL(fileURLWithPath: request.filePath).lastPathComponent, fileSize: request.fingerprint.size, previewFrameTimeCode: request.previewFrameTimeCode), relationships: .init(assetLibrary: .init(data: .init(id: context.libraryID))))))).data)
                }
                progress.assetID = created["id"].stringValue
                try await journal.save(progress, operationID: operationID)
            }
            guard let assetID = progress.assetID else { throw ServiceError.upstream("The asset creation outcome is unknown. Reconcile manually before uploading again.") }
            if !progress.uploadComplete {
                let remote = try await asset(scope: scope, id: assetID, service: service)
                if remote["attributes"]["state"].stringValue == "AWAITING_UPLOAD" {
                    let operations = try Self.uploadOperations(remote["attributes"]["uploadOperations"], fileSize: request.fingerprint.size)
                    for operation in operations {
                        try Task.checkCancellation(); try await transport.upload(file: URL(fileURLWithPath: request.filePath), operation: operation)
                    }
                    guard try MediaFileFingerprint.read(path: request.filePath) == request.fingerprint else { throw ServiceError.invalidArguments("The file changed during transfer. Upload was not completed.") }
                    try Task.checkCancellation()
                    if scope.kind == .screenshot {
                        _ = try await service.request(.updateAppAssetLibraryImageV1(id: assetID, requestBody: .init(data: .init(id: assetID, attributes: .init(uploaded: true)))))
                    } else {
                        _ = try await service.request(.updateAppAssetLibraryVideoV1(id: assetID, requestBody: .init(data: .init(id: assetID, attributes: .init(uploaded: true)))))
                    }
                } else {
                    guard let state = remote["attributes"]["state"].stringValue, !["UNKNOWN", "FAILED", "ARCHIVED"].contains(state) else { throw ServiceError.upstream("The upload cannot be recovered in its current state.") }
                }
                progress.uploadComplete = true
                try await journal.save(progress, operationID: operationID)
            }
            if progress.placementID == nil {
                if progress.placementStarted {
                    let matches = current.placements.filter { $0.assetID == assetID }
                    guard matches.count == 1 else { throw ServiceError.upstream("The placement creation outcome is unresolved. No duplicate was created.") }
                    progress.placementID = matches[0].id
                } else {
                    progress.placementStarted = true
                    try await journal.save(progress, operationID: operationID)
                    let relationships: AppAssetLibraryPlacementCreateRequest.Data.Relationships = if scope.kind == .screenshot {
                        .init(appStoreVersionLocalization: .init(data: .init(id: context.localizationID)), image: .init(data: .init(id: assetID)))
                    } else {
                        .init(appStoreVersionLocalization: .init(data: .init(id: context.localizationID)), video: .init(data: .init(id: assetID)))
                    }
                    try Task.checkCancellation()
                    let created = try await service.request(.createAppAssetLibraryPlacementV1(requestBody: .init(data: .init(attributes: .init(placementGroup: request.placementGroup, placementType: placementType(scope.kind)), relationships: relationships))))
                    progress.placementID = created.data.id
                }
                try await journal.save(progress, operationID: operationID)
            }
            guard let placementID = progress.placementID else { throw ServiceError.upstream("Missing placement after upload.") }
            let deadline = Date().addingTimeInterval(TimeInterval(request.timeout))
            while true {
                let placement = try await get(scope: scope, placementID: placementID)
                if !request.wait {
                    return .init(placements: [placement], assetID: assetID, uploadComplete: true)
                }
                if ["FAILED", "REJECTED", "ARCHIVED"].contains(placement.assetState) || ["FAILED", "REJECTED"].contains(placement.placementState) {
                    throw ServiceError.upstream("Apple could not process the media: \(placement.assetState), \(placement.placementState). Inspect the placement for details.")
                }
                if ["COMPLETE", "ACCEPTED", "APPROVED", "READY_FOR_REVIEW", "PREPARE_FOR_SUBMISSION", "IN_REVIEW", "WAITING_FOR_REVIEW"].contains(placement.assetState), !["ASSET_PROCESSING", "UNKNOWN"].contains(placement.placementState) {
                    return .init(placements: [placement], assetID: assetID, uploadComplete: true)
                }
                guard Date() < deadline else { throw ServiceError.upstream("Timed out waiting for Apple to process placement \(placementID). The upload and placement are saved; inspect or reconcile this operation.") }
                try await Task.sleep(for: .seconds(min(2, max(0, deadline.timeIntervalSinceNow))))
            }
        } catch { throw try ServiceError.classify(error) }
    }

    static func uploadOperations(_ value: JSONValue, fileSize: Int) throws -> [MediaUploadOperation] {
        var covered = 0
        let operations = try value.elements.map { value -> MediaUploadOperation in
            guard let url = value["url"].stringValue.flatMap(URL.init(string:)), url.scheme == "https", let method = value["method"].stringValue,
                  let offset = value["offset"].intValue, let length = value["length"].intValue, offset >= 0, length > 0, offset <= fileSize, length <= fileSize - offset else { throw ServiceError.upstream("Invalid upload operation returned by Apple.") }
            let headers = try value["requestHeaders"].elements.reduce(into: [String: String]()) { result, header in
                guard let name = header["name"].stringValue, let value = header["value"].stringValue else { throw ServiceError.upstream("Invalid upload header returned by Apple.") }
                result[name] = value
            }
            return .init(url: url, method: method, headers: headers, offset: offset, length: length)
        }
        for operation in operations.sorted(by: { $0.offset < $1.offset }) {
            guard operation.offset == covered else { throw ServiceError.upstream("Upload operations do not cover the file exactly once.") }
            covered += operation.length
        }
        guard covered == fileSize else { throw ServiceError.upstream("Upload operations do not cover the entire file.") }
        return operations
    }
}

extension JSONValue {
    subscript(_ key: String) -> JSONValue {
        objectValue?[key] ?? .null
    }

    var elements: [JSONValue] {
        if case let .array(values) = self {
            values
        } else {
            []
        }
    }
}
