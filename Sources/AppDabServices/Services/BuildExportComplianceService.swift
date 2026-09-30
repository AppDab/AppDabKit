import BagbutikAppStore
import BagbutikAppStoreModels
import BagbutikCore
import ConnectAccounts
import CryptoKit
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public final class BuildExportComplianceService: BuildExportComplianceServing, @unchecked Sendable {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    #if compiler(>=6.4)
        @diagnose(DeprecatedDeclaration, as: ignored, reason: "Apple marks the required app encryption declaration relationship deprecated.")
    #endif
    public func setBuildExportCompliance(accountID: String, request: BuildExportComplianceRequest) async throws -> BuildExportComplianceResult {
        guard !request.appID.isEmpty, !request.buildID.isEmpty else { throw ServiceError.invalidArguments("appID and buildID must be nonempty.") }
        if request.needsDocuments, request.purpose?.isEmpty != false {
            throw ServiceError.invalidArguments("A purpose is required when export compliance documents are needed.")
        }
        if let purpose = request.purpose, purpose.count > 300 {
            throw ServiceError.invalidArguments("purpose must be 300 characters or fewer.")
        }
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        do {
            let service = BagbutikService(jwt: key.jwt)
            var declarationID: String?
            var documentID: String?
            if request.needsDocuments {
                guard let path = request.documentPath, !path.isEmpty else { throw ServiceError.invalidArguments("A PDF or ZIP document path is required when export compliance documents are needed.") }
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                guard !data.isEmpty else { throw ServiceError.invalidArguments("The export compliance document is empty.") }
                let fileName = URL(fileURLWithPath: path).lastPathComponent
                guard ["pdf", "zip"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) else { throw ServiceError.invalidArguments("The export compliance document must be a PDF or ZIP file.") }
                let declaration = try await service.request(.createAppEncryptionDeclarationV1(requestBody: .init(data: .init(
                    attributes: .init(appDescription: request.purpose ?? "", availableOnFrenchStore: request.availableOnFrenchStore, containsProprietaryCryptography: request.containsProprietaryCryptography, containsThirdPartyCryptography: request.containsThirdPartyCryptography),
                    relationships: .init(app: .init(data: .init(id: request.appID))),
                )))).data
                declarationID = declaration.id
                let document = try await service.request(.createAppEncryptionDeclarationDocumentV1(requestBody: .init(data: .init(
                    attributes: .init(fileName: fileName, fileSize: data.count), relationships: .init(appEncryptionDeclaration: .init(data: .init(id: declaration.id))),
                )))).data
                documentID = document.id
                guard let operations = document.attributes?.uploadOperations, !operations.isEmpty else { throw ServiceError.upstream("App Store Connect did not provide upload operations for the compliance document.") }
                try await Self.upload(data, operations: operations)
                let md5 = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
                _ = try await service.request(.updateAppEncryptionDeclarationDocumentV1(id: document.id, requestBody: .init(data: .init(id: document.id, attributes: .init(sourceFileChecksum: md5, uploaded: true)))))
            }
            let update = BuildUpdateRequest(data: .init(id: request.buildID, attributes: .init(usesNonExemptEncryption: request.needsDocuments), relationships: declarationID.map { .init(appEncryptionDeclaration: .init(data: .init(id: $0))) }))
            _ = try await service.request(.updateBuildV1(id: request.buildID, requestBody: update))
            let buildResponse = try await service.request(.getBuildV1(id: request.buildID, includes: [.preReleaseVersion]))
            return .init(build: .init(build: buildResponse.data, platform: buildResponse.getPreReleaseVersion()?.attributes?.platform?.prettyName), declarationID: declarationID, documentID: documentID)
        } catch {
            throw try ServiceError.classify(error)
        }
    }

    private static func upload(_ data: Data, operations: [UploadOperation]) async throws {
        for operation in operations {
            guard let offset = operation.offset, let length = operation.length, offset >= 0, length >= 0, offset <= data.count, length <= data.count - offset,
                  let urlString = operation.url, let url = URL(string: urlString), url.scheme == "https", let method = operation.method, let headers = operation.requestHeaders
            else {
                throw ServiceError.upstream("App Store Connect returned invalid compliance document upload instructions.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = method
            for header in headers {
                guard let name = header.name, let value = header.value else { throw ServiceError.upstream("App Store Connect returned an invalid upload header.") }
                request.setValue(value, forHTTPHeaderField: name)
            }
            let (body, response) = try await URLSession.shared.upload(for: request, from: data.subdata(in: offset ..< offset + length))
            guard let response = response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
                throw ServiceError.upstream("Compliance document upload failed with response \(String(describing: response)).")
            }
            _ = body
        }
    }
}
