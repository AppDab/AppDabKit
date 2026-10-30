@testable import AppDabServices
import ConnectAccounts
import Foundation
import Testing

private struct MediaAccounts: APIKeyProviding {
    func apiKey(forAccountID _: String) async throws -> APIKey {
        try previewAPIKey()
    }
}

private actor MediaTransferSpy: MediaTransferTransport {
    var operations: [MediaUploadOperation] = []
    var downloadURLs: [URL] = []
    var mutableSource: URL?
    var stagedBytes = Data()
    func editSourceBetweenRanges(_ source: URL) {
        mutableSource = source
    }

    var fail = false
    func setFailure(_ value: Bool) {
        fail = value
    }

    func upload(file: URL, operation: MediaUploadOperation) async throws {
        operations.append(operation)
        if let mutableSource {
            let bytes = try Data(contentsOf: file)
            stagedBytes.append(bytes.subdata(in: operation.offset ..< (operation.offset + operation.length)))
            try Data((operations.count == 1 ? "abcXYZ" : "abcdef").utf8).write(to: mutableSource)
        }
        if fail {
            throw URLError(.networkConnectionLost)
        }
    }

    func download(url: URL, destination: URL) async throws {
        downloadURLs.append(url)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw ServiceError.invalidArguments("Destination exists.") }
        try Data("download".utf8).write(to: destination, options: .withoutOverwriting)
    }
}

private actor MediaAPI {
    var delayedVideoURLReads = 0
    var missingVideoURLReads = 0
    var videoDownloadURL = "https://cdn.example/preview.mp4"
    func delayVideoURL() {
        delayedVideoURLReads = 2
    }

    func useHLSVideoURL() {
        videoDownloadURL = "https://cdn.example/preview.m3u8"
    }

    var videoMode = false
    func useVideo() {
        videoMode = true
    }

    var requiresExplicitPlacementIncludes = false
    func requirePlacementIncludes() {
        requiresExplicitPlacementIncludes = true
    }

    var placementState = "ACTIVE"
    var pendingPlacementReads = 0
    func setPlacementState(_ value: String) {
        placementState = value
    }

    func startWithPendingPlacement() {
        pendingPlacementReads = 1
    }

    var requests: [(String, String)] = []
    var removed = Set<String>()
    var uploaded = false
    var created = false
    var attached = false
    var failCompletion = false
    func setCompletionFailure() {
        failCompletion = true
    }

    var rejectCreationOnce = false
    var rejectPlacementOnce = false
    func rejectNextCreation(placement: Bool) {
        if placement {
            rejectPlacementOnce = true
        } else {
            rejectCreationOnce = true
        }
    }

    var failCreation = false
    var failPlacement = false
    var invalidNext = false
    var order = ["p2", "p1"]
    var waiting = false
    var delayProcessingPoll = false
    var cancelledPolls = 0
    func stallProcessingPoll() {
        delayProcessingPoll = true
    }

    func setCreationFailure() {
        failCreation = true
    }

    func setPlacementFailure() {
        failPlacement = true
    }

    func setInvalidNext() {
        invalidNext = true
    }

    func setWaiting() {
        waiting = true
    }

    func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let url = request.url!
        let path = url.path.replacingOccurrences(of: "appAssetLibraryVideos", with: "appAssetLibraryImages").replacingOccurrences(of: "/videos", with: "/images")
        let method = request.httpMethod ?? "GET"
        requests.append((path, method))
        if delayProcessingPoll, attached, path == "/v1/appStoreVersions/version" {
            do { try await Task.sleep(for: .seconds(10)) }
            catch { cancelledPolls += 1; throw error }
        }
        let body: [String: Any]
        let second = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "cursor" }) == true
        func page(_ values: [[String: Any]], next: String? = nil) -> [String: Any] {
            var links = ["self": url.absoluteString]
            if let next {
                links["next"] = next
            }
            return ["data": values, "links": links]
        }
        func asset(_ id: String) -> [String: Any] {
            let state = id == "new" && !uploaded ? "AWAITING_UPLOAD" : waiting && id == "new" ? "UPLOAD_COMPLETE" : "COMPLETE"
            var attributes: [String: Any] = ["state": state, "category": "APP_SCREENSHOTS_AND_PREVIEWS", "fileName": "screen.png", "fileSize": 6, "imageAsset": ["templateUrl": "https://cdn.example/{w}x{h}{c}.{f}", "width": 100, "height": 200]]
            if videoMode, state == "COMPLETE" {
                if id == "new", attached, delayedVideoURLReads > 0 {
                    delayedVideoURLReads -= 1
                    missingVideoURLReads += 1
                } else {
                    attributes["videoAsset"] = videoDownloadURL
                }
            }
            if state == "AWAITING_UPLOAD" {
                attributes["uploadOperations"] = [["url": "https://uploads.example/file", "method": "PUT", "offset": 0, "length": 3, "requestHeaders": [["name": "X-Signature", "value": "secret"]]], ["url": "https://uploads.example/file2", "method": "PUT", "offset": 3, "length": 3]]
            }
            return ["id": id, "type": "appAssetLibraryImages", "attributes": attributes]
        }
        func placement(_ id: String, asset: String = "a2", locale: String = "loc", state: String? = nil) -> [String: Any] {
            ["id": id, "type": "appAssetLibraryPlacements", "attributes": ["placementType": "APP_SCREENSHOT", "placementGroup": "IPHONE", "mediaType": "IMAGE", "state": state ?? placementState, "stateDetails": [["code": "PROCESSING", "description": "Asset processing information"]]], "relationships": ["appStoreVersionLocalization": ["data": ["id": locale, "type": "appStoreVersionLocalizations"]], "image": ["data": ["id": asset, "type": "appAssetLibraryImages"]]]]
        }
        switch (path, method) {
        case ("/v1/appStoreVersions/version", "GET"):
            body = ["data": ["id": "version", "type": "appStoreVersions", "attributes": ["platform": "IOS"], "relationships": ["app": ["data": ["id": "app", "type": "apps"]]]]]
        case ("/v1/appStoreVersions/version/appStoreVersionLocalizations", "GET"):
            body = page([["id": "loc", "type": "appStoreVersionLocalizations", "attributes": ["locale": "en-US"]]])
        case ("/v1/apps/app/assetLibrary", "GET"):
            body = ["data": ["id": "library", "type": "appAssetLibraries"]]
        case ("/v1/appAssetLibraries/library/images", "GET"):
            body = second ? page([asset("a2")] + (created ? [asset("new")] : [])) : page([asset("a1")], next: invalidNext ? "https://untrusted.example/v1/appAssetLibraries/library/images?cursor=2" : "https://api.appstoreconnect.apple.com/v1/appAssetLibraries/library/images?cursor=2")
        case ("/v1/appAssetLibraryImages/a1/placements", "GET"):
            body = page([placement("old", asset: "a1", locale: "other")])
        case ("/v1/appAssetLibraryImages/a2/placements", "GET"):
            body = second ? page([placement("p2")].filter { !removed.contains($0["id"] as! String) }) : page([placement("p1")].filter { !removed.contains($0["id"] as! String) }, next: "https://api.appstoreconnect.apple.com/v1/appAssetLibraryImages/a2/placements?cursor=2")
        case ("/v1/appAssetLibraryImages/new/placements", "GET"):
            body = page(attached ? [placement("newp", asset: "new")] : [])
        case ("/v1/appStoreVersionLocalizations/loc/placements", "GET"):
            var placements = order.filter { !removed.contains($0) }.map { placement($0) } + (attached ? [placement("newp", asset: "new")] : [])
            let include = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "include" }?.value ?? ""
            if requiresExplicitPlacementIncludes {
                let requested = Set(include.split(separator: ",").map(String.init))
                placements = placements.map { original in
                    var value = original
                    let relationships = original["relationships"] as! [String: Any]
                    value["relationships"] = relationships.filter { requested.contains($0.key == "image" && videoMode ? "video" : $0.key) }
                    return value
                }
            }
            let next = "https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/loc/placements?cursor=2&include=\(include)"
            body = second ? page(Array(placements.dropFirst())) : page(Array(placements.prefix(1)), next: invalidNext ? "https://untrusted.example/v1/appStoreVersionLocalizations/loc/placements?cursor=2" : next)
        case ("/v1/appAssetLibraryRefData", "GET"):
            body = page([["id": "ref", "type": "appAssetLibraryRefData", "attributes": ["placementProfileGroups": [["placementProfileGroupId": "IPHONE", "platform": "IPHONE_APP_STORE"]], "placementTypes": [["placementTypeId": "APP_SCREENSHOT", "specMappings": [["placementGroupId": "IPHONE", "specs": ["spec"]]]]], "imageSpecs": [["specId": "spec", "fileExtensions": ["png"], "maxFileSize": 100]], "features": [["featureId": "APP_STORE_VERSIONS", "placementPolicies": [["placementType": "APP_SCREENSHOT", "groupLimits": [["groupIds": ["IPHONE"], "maxCount": 10]]]]]]]]])
        case ("/v1/appAssetLibraryImages", "POST"):
            if rejectCreationOnce {
                rejectCreationOnce = false
                return (Data(#"{"errors":[{"status":"400","code":"INVALID","title":"Rejected","detail":"Not applied"}]}"#.utf8), HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!)
            }
            created = true
            if failCreation {
                throw URLError(.networkConnectionLost)
            }
            body = ["data": asset("new")]
        case ("/v1/appAssetLibraryImages/new", "GET"):
            body = ["data": asset("new")]
        case ("/v1/appAssetLibraryPlacements/p1", "GET"):
            body = ["data": placement("p1")]
        case ("/v1/appAssetLibraryPlacements/p2", "GET"):
            body = ["data": placement("p2")]
        case ("/v1/appAssetLibraryPlacements/old", "GET"):
            body = ["data": placement("old", asset: "a1", locale: "other")]
        case ("/v1/appAssetLibraryPlacements/newp", "GET"):
            let state = pendingPlacementReads > 0 ? "PENDING" : placementState
            pendingPlacementReads = max(0, pendingPlacementReads - 1)
            body = ["data": placement("newp", asset: "new", state: state)]
        case ("/v1/appAssetLibraryImages/a2", "GET"):
            body = ["data": asset("a2")]
        case ("/v1/appAssetLibraryImages/new", "PATCH"):
            uploaded = true
            if failCompletion {
                throw URLError(.networkConnectionLost)
            }
            body = ["data": asset("new")]
        case ("/v1/appAssetLibraryPlacements", "POST"):
            if rejectPlacementOnce {
                rejectPlacementOnce = false
                return (Data(#"{"errors":[{"status":"400","code":"INVALID","title":"Rejected","detail":"Not applied"}]}"#.utf8), HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!)
            }
            attached = true
            if failPlacement {
                throw URLError(.networkConnectionLost)
            }
            body = ["data": placement("newp", asset: "new", state: "PENDING")]
        case ("/v1/appAssetLibraryPlacementOrderingRequests", "POST"):
            let input = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let data = input["data"] as! [String: Any]
            let relationships = data["relationships"] as! [String: Any]
            let ordered = relationships["orderedPlacements"] as! [String: Any]
            order = (ordered["data"] as! [[String: String]]).map { $0["id"]! }
            body = ["data": ["id": "ordering", "type": "appAssetLibraryPlacementOrderingRequests"]]
        default:
            if method == "DELETE", path.hasPrefix("/v1/appAssetLibraryPlacements/") {
                removed.insert(url.lastPathComponent)
                return (Data(), HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!)
            }
            throw ServiceError.upstream("Unexpected fixture request: \(method) \(path)")
        }
        var responseBody = body
        if responseBody["links"] == nil {
            responseBody["links"] = ["self": url.absoluteString]
        }
        var encoded = try String(decoding: JSONSerialization.data(withJSONObject: responseBody, options: [.withoutEscapingSlashes]), as: UTF8.self)
        if videoMode {
            encoded = encoded.replacingOccurrences(of: "appAssetLibraryImages", with: "appAssetLibraryVideos").replacingOccurrences(of: "/images", with: "/videos").replacingOccurrences(of: "\"APP_SCREENSHOT\"", with: "\"APP_PREVIEW\"").replacingOccurrences(of: "\"IMAGE\"", with: "\"VIDEO\"").replacingOccurrences(of: "\"image\"", with: "\"video\"").replacingOccurrences(of: "imageSpecs", with: "videoSpecs").replacingOccurrences(of: "\"png\"", with: "\"mov\"")
        }
        return (Data(encoded.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

struct VersionMediaServiceTests {
    private let scope = VersionMediaScope(accountID: "account", versionID: "version", locale: "en-US", kind: .screenshot)

    private func service(_ api: MediaAPI, transport: MediaTransferSpy = .init(), directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) -> VersionMediaService {
        VersionMediaService(accountProvider: MediaAccounts(), transport: transport, journalDirectory: directory, fetchData: { request, _ in try await api.fetch(request) })
    }

    @Test func uploadTransfersConfirmedBytesWhenOriginalIsEditedAndRestored() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("screen.png")
        try Data("abcdef".utf8).write(to: source)
        let transport = MediaTransferSpy()
        await transport.editSourceBetweenRanges(source)
        let request = try VersionMediaUpload(filePath: source.path, placementGroup: "IPHONE", fingerprint: .read(path: source.path))
        let result = try await service(MediaAPI(), transport: transport, directory: directory.appendingPathComponent("journal")).upload(scope: scope, request: request, operationID: "snapshot")
        #expect(result.uploadComplete == true)
        #expect(await transport.stagedBytes == Data("abcdef".utf8))
    }

    @Test func discoversAllPagesFiltersLocalizationAndPreservesDisplayOrder() async throws {
        let api = MediaAPI()
        let list = try await service(api).list(scope: scope, placementGroup: nil)
        #expect(list.placements.map(\.id) == ["p2", "p1"])
        #expect(list.requirements.first?.placementGroup == "IPHONE")
        #expect(list.requirements.first?.maximumCount == 10)
        #expect(list.requirements.first?.specs.count == 1)
        let requests = await api.requests
        #expect(requests.filter { $0.0 == "/v1/appStoreVersionLocalizations/loc/placements" }.count == 2)
        #expect(requests.filter { $0.0 == "/v1/appAssetLibraryImages/a2" }.count == 1)
        #expect(!requests.contains { $0.0 == "/v1/appAssetLibraries/library/images" })
        #expect(!requests.contains { $0.0.hasPrefix("/v1/appAssetLibraryImages/a1") || $0.0.hasSuffix("/a2/placements") })
    }

    @Test(arguments: [VersionMediaKind.screenshot, .appPreview])
    func listsSparsePlacementsByRequestingOwnershipAndAssetRelationships(kind: VersionMediaKind) async throws {
        let api = MediaAPI()
        await api.requirePlacementIncludes()
        if kind == .appPreview {
            await api.useVideo()
        }
        let scope = VersionMediaScope(accountID: "account", versionID: "version", locale: "en-US", kind: kind)
        let list = try await service(api).list(scope: scope, placementGroup: nil)
        #expect(list.placements.map(\.id) == ["p2", "p1"])
        #expect(list.placements.allSatisfy { $0.assetID == "a2" })
    }

    @Test func rejectsForeignPlacementsMissingLocalesAndUntrustedPagination() async throws {
        let api = MediaAPI()
        let service = service(api)
        await #expect(throws: ServiceError.self) { try await service.get(scope: scope, placementID: "old") }
        await #expect(throws: ServiceError.self) { try await service.list(scope: .init(accountID: "account", versionID: "version", locale: "da", kind: .screenshot), placementGroup: nil) }
        await api.setInvalidNext()
        await #expect(throws: ServiceError.self) { try await service.list(scope: scope, placementGroup: nil) }
        #expect(await api.requests.allSatisfy { !$0.0.contains("untrusted") })
    }

    @Test func removesOnlyPlacementAndReordersExactlyTheSelectedGroup() async throws {
        let api = MediaAPI()
        let service = service(api)
        for ids in [["p1"], ["p1", "p1"], ["p1", "foreign"]] {
            await #expect(throws: ServiceError.self) { try await service.reorder(scope: scope, placementGroup: "IPHONE", placementIDs: ids) }
        }
        let reordered = try await service.reorder(scope: scope, placementGroup: "IPHONE", placementIDs: ["p1", "p2"])
        #expect(reordered.placements.map(\.id) == ["p1", "p2"])
        _ = try await service.remove(scope: scope, placementID: "p1")
        #expect(try await service.list(scope: scope, placementGroup: nil).placements.map(\.id) == ["p2"])
        #expect(await api.requests.filter { $0.1 == "DELETE" }.map(\.0) == ["/v1/appAssetLibraryPlacements/p1"])
    }

    @Test func interruptedUploadResumesTheRecordedAssetAndNeverStoresSignedHeaders() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("screen.png")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        let transport = MediaTransferSpy()
        await transport.setFailure(true)
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", fingerprint: .read(path: file.path))
        let service = service(api, transport: transport, directory: directory.appendingPathComponent("journal"))
        await #expect(throws: Error.self) { try await service.upload(scope: scope, request: request, operationID: "operation") }
        await transport.setFailure(false)
        let result = try await service.recoverUpload(scope: scope, request: request, operationID: "operation")
        #expect(result?.assetID == "new")
        #expect(result?.uploadComplete == true)
        #expect(result?.placements.first?.id == "newp")
        #expect(await api.requests.filter { $0 == ("/v1/appAssetLibraryImages", "POST") }.count == 1)
        let operations = await transport.operations
        #expect(operations.last?.offset == 3)
        #expect(operations.first?.headers["X-Signature"] == "secret")
        for url in try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("journal"), includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            let journal = try String(contentsOf: url, encoding: .utf8)
            #expect(!journal.contains("secret"))
            #expect(!journal.contains("uploads.example"))
        }
        try Data("changed".utf8).write(to: file)
        await #expect(throws: ServiceError.self) { try await service.upload(scope: scope, request: request, operationID: "operation") }
    }

    @Test func ambiguousCreationDoesNotCreateDuplicatesAndPlacementFailureIsRecovered() async throws {
        for failAsset in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let file = directory.appendingPathComponent("screen.png")
            try Data("abcdef".utf8).write(to: file)
            let api = MediaAPI()
            if failAsset {
                await api.setCreationFailure()
            } else {
                await api.setPlacementFailure()
            }
            let service = service(api, directory: directory.appendingPathComponent("journal"))
            let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", fingerprint: .read(path: file.path))
            await #expect(throws: Error.self) { try await service.upload(scope: scope, request: request, operationID: "operation") }
            let recovered = try await service.recoverUpload(scope: scope, request: request, operationID: "operation")
            #expect((recovered == nil) == failAsset)
            #expect(await api.requests.filter { $0 == ("/v1/appAssetLibraryImages", "POST") }.count == 1)
            #expect(await api.requests.filter { $0.1 == "DELETE" }.isEmpty)
        }
    }

    @Test(arguments: [VersionMediaKind.screenshot, .appPreview])
    func uploadsPendingPlacementsWithoutReconciliation(kind: VersionMediaKind) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent(kind == .screenshot ? "screen.png" : "preview.mov")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        if kind == .appPreview {
            await api.useVideo()
        }
        await api.startWithPendingPlacement()
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", wait: true, timeout: 10, fingerprint: .read(path: file.path))
        let scope = VersionMediaScope(accountID: "account", versionID: "version", locale: "en-US", kind: kind)
        let result = try await service(api, directory: directory.appendingPathComponent("journal")).upload(scope: scope, request: request, operationID: "pending")
        #expect(result.placements.first?.placementState == "ACTIVE")
        #expect(result.uploadComplete == true)
        #expect(await api.requests.filter { $0 == ("/v1/appAssetLibraryPlacements", "POST") }.count == 1)
    }

    @Test(arguments: ["PENDING", "FUTURE_STATE"])
    func preservesUnmodeledPlacementStatesAndDetails(state: String) async throws {
        let api = MediaAPI()
        await api.setPlacementState(state)
        let service = service(api)
        let placement = try await service.get(scope: scope, placementID: "p1")
        let list = try await service.list(scope: scope, placementGroup: nil)
        #expect(placement.placementState == state)
        #expect(placement.stateDetails.first?["code"].stringValue == "PROCESSING")
        #expect(list.placements.count == 2)
        #expect(list.placements.allSatisfy { $0.placementState == state })
    }

    @Test func downloadProtectsExistingFileAndReplayChecksContent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("download.png")
        let transport = MediaTransferSpy()
        let service = service(MediaAPI(), transport: transport)
        let result = try await service.download(scope: scope, placementID: "p1", destinationPath: file.path)
        #expect(await transport.downloadURLs.first?.absoluteString == "https://cdn.example/100x200bb.png")
        try result.validateDownloadedFile()
        await #expect(throws: ServiceError.self) { try await service.download(scope: scope, placementID: "p1", destinationPath: file.path) }
        try Data("modified".utf8).write(to: file)
        #expect(throws: ServiceError.self) { try result.validateDownloadedFile() }
    }

    @Test func appPreviewsUploadAndProcessingTimeoutPreserveTheCompletedTransfer() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("preview.mov")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        await api.useVideo()
        await api.setWaiting()
        let transport = MediaTransferSpy()
        let service = service(api, transport: transport, directory: directory.appendingPathComponent("journal"))
        let scope = VersionMediaScope(accountID: "account", versionID: "version", locale: "en-US", kind: .appPreview)
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", previewFrameTimeCode: "00:00:01.000", wait: true, timeout: 1, fingerprint: .read(path: file.path))
        await #expect(throws: ServiceError.self) { try await service.upload(scope: scope, request: request, operationID: "video") }
        #expect(await transport.operations.count == 2)
        #expect(await api.requests.filter { $0 == ("/v1/appAssetLibraryPlacements/newp", "GET") }.count == 1)
        let noWait = VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", fingerprint: request.fingerprint)
        let recovered = try await service.recoverUpload(scope: scope, request: noWait, operationID: "video")
        #expect(recovered?.uploadComplete == true)
        #expect(await transport.operations.count == 2)
        await #expect(throws: ServiceError.self) { try await service.download(scope: scope, placementID: "newp", destinationPath: directory.appendingPathComponent("missing.mov").path) }
    }

    @Test func waitingForPreviewUploadAlsoWaitsForItsDownloadURL() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("preview.mov")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        await api.useVideo()
        await api.delayVideoURL()
        let transport = MediaTransferSpy()
        let service = service(api, transport: transport, directory: directory.appendingPathComponent("journal"))
        let scope = VersionMediaScope(accountID: "account", versionID: "version", locale: "en-US", kind: .appPreview)
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", wait: true, timeout: 10, fingerprint: .read(path: file.path))
        let result = try await service.upload(scope: scope, request: request, operationID: "late-video-url")
        #expect(result.uploadComplete == true)
        #expect(await api.missingVideoURLReads == 2)
        let destination = directory.appendingPathComponent("download.mp4")
        _ = try await service.download(scope: scope, placementID: "newp", destinationPath: destination.path)
        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(await transport.operations.count == 2)
    }

    @Test func streamingPreviewRequiresAnHonestFileExtension() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let api = MediaAPI()
        await api.useVideo()
        await api.useHLSVideoURL()
        let transport = MediaTransferSpy()
        let service = service(api, transport: transport)
        let scope = VersionMediaScope(accountID: "account", versionID: "version", locale: "en-US", kind: .appPreview)
        let movie = directory.appendingPathComponent("preview.mp4")
        await #expect(throws: ServiceError.self) {
            try await service.validateDownload(scope: scope, placementID: "p1", destinationPath: movie.path)
        }
        await #expect(throws: ServiceError.self) {
            try await service.download(scope: scope, placementID: "p1", destinationPath: movie.path)
        }
        #expect(await transport.downloadURLs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: movie.path))
        let playlist = directory.appendingPathComponent("preview.m3u8")
        try await service.validateDownload(scope: scope, placementID: "p1", destinationPath: playlist.path)
        _ = try await service.download(scope: scope, placementID: "p1", destinationPath: playlist.path)
        #expect(FileManager.default.fileExists(atPath: playlist.path))
        #expect(await transport.downloadURLs.first?.pathExtension == "m3u8")
    }

    @Test func lostCompletionResponseDoesNotRetransferTheFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("screen.png")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        await api.setCompletionFailure()
        let transport = MediaTransferSpy()
        let service = service(api, transport: transport, directory: directory.appendingPathComponent("journal"))
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", fingerprint: .read(path: file.path))
        await #expect(throws: Error.self) { try await service.upload(scope: scope, request: request, operationID: "completion") }
        let recovered = try await service.recoverUpload(scope: scope, request: request, operationID: "completion")
        #expect(recovered?.uploadComplete == true)
        #expect(await transport.operations.count == 2)
    }

    @Test(arguments: [false, true])
    func definitiveRejectionCanBeReconciledWithoutDuplicatingSuccessfulSteps(placement: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("screen.png")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        await api.rejectNextCreation(placement: placement)
        let service = service(api, directory: directory.appendingPathComponent("journal"))
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", fingerprint: .read(path: file.path))
        await #expect(throws: ServiceError.self) { try await service.upload(scope: scope, request: request, operationID: "rejected") }
        let result = try await service.recoverUpload(scope: scope, request: request, operationID: "rejected")
        #expect(result?.placements.first?.id == "newp")
        #expect(await api.requests.filter { $0 == ("/v1/appAssetLibraryImages", "POST") }.count == (placement ? 1 : 2))
        #expect(await api.requests.filter { $0 == ("/v1/appAssetLibraryPlacements", "POST") }.count == (placement ? 2 : 1))
    }

    @Test func checkpointKnownToPrecedeSendingCanResumeAssetCreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("screen.png")
        try Data("abcdef".utf8).write(to: file)
        let fingerprint = try MediaFileFingerprint.read(path: file.path)
        let journalDirectory = directory.appendingPathComponent("journal")
        let journal = MediaUploadJournal(directory: journalDirectory)
        try await journal.save(.init(scope: scope, fingerprint: fingerprint, placementGroup: "IPHONE"), operationID: "not-sent")
        let result = try await service(MediaAPI(), directory: journalDirectory).recoverUpload(scope: scope, request: .init(filePath: file.path, placementGroup: "IPHONE", fingerprint: fingerprint), operationID: "not-sent")
        #expect(result?.uploadComplete == true)
    }

    @Test func processingDeadlineCancelsAStalledPoll() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("screen.png")
        try Data("abcdef".utf8).write(to: file)
        let api = MediaAPI()
        await api.stallProcessingPoll()
        let service = service(api, directory: directory.appendingPathComponent("journal"))
        let request = try VersionMediaUpload(filePath: file.path, placementGroup: "IPHONE", wait: true, timeout: 1, fingerprint: .read(path: file.path))
        let started = ContinuousClock.now
        await #expect(throws: ServiceError.self) { try await service.upload(scope: scope, request: request, operationID: "deadline") }
        #expect(started.duration(to: .now) < .seconds(4))
        #expect(await api.cancelledPolls == 1)
        #expect(await api.requests.filter { $0 == ("/v1/appStoreVersions/version", "GET") }.count == 3)
    }

    @Test func rejectsIncompleteAndOutOfRangeUploadOperations() throws {
        func operation(offset: Int, length: Int) -> JSONValue {
            .object(["url": .string("https://uploads.example/file"), "method": .string("PUT"), "offset": .integer(offset), "length": .integer(length)])
        }
        for operations in [[operation(offset: 0, length: 2)], [operation(offset: 0, length: 7)], [operation(offset: 0, length: 4), operation(offset: 3, length: 3)]] {
            #expect(throws: ServiceError.self) { try VersionMediaService.uploadOperations(.array(operations), fileSize: 6) }
        }
    }
}
