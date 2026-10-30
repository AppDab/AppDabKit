@testable import AppDabServices
import Foundation
import Testing

struct MediaTransferTransportTests {
    @Test func stagesOnlyTheRequestedBytesWithoutChangingTheSource() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source")
        let part = directory.appendingPathComponent("part")
        try Data("abcdefghij".utf8).write(to: file)
        try URLSessionMediaTransferTransport.stageRange(file: file, operation: .init(url: #require(URL(string: "https://uploads.example/part")), method: "PUT", headers: ["X-Signature": "signed"], offset: 3, length: 4), destination: part)
        #expect(try Data(contentsOf: part) == Data("defg".utf8))
        #expect(try Data(contentsOf: file) == Data("abcdefghij".utf8))
        for (offset, length) in [(-1, 2), (9, 2), (0, 0), (11, 1)] {
            #expect(throws: Error.self) { try URLSessionMediaTransferTransport.stageRange(file: file, operation: .init(url: #require(URL(string: "https://uploads.example/part")), method: "PUT", headers: [:], offset: offset, length: length), destination: part) }
        }
    }

    @Test func cancellationPreventsAByteRangeFromBeingStaged() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let part = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: part) }
        try Data("abcdef".utf8).write(to: file)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try URLSessionMediaTransferTransport.stageRange(file: file, operation: .init(url: URL(string: "https://uploads.example/part")!, method: "PUT", headers: [:], offset: 0, length: 6), destination: part)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect((try? Data(contentsOf: part).isEmpty) != false)
    }
}

private final class MediaURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "transfer.example"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let status: Int = if request.url?.path == "/failed" {
            500
        } else if request.url?.path == "/upload" {
            request.httpMethod == "PUT" && request.value(forHTTPHeaderField: "X-Signature") == "signed" && request.value(forHTTPHeaderField: "Authorization") == nil ? 200 : 403
        } else {
            200
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("downloaded media".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension MediaTransferTransportTests {
    private var stubbedTransport: URLSessionMediaTransferTransport {
        .init(configuration: {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MediaURLProtocol.self]
            return configuration
        })
    }

    @Test func transportHonorsUploadHeadersAndCleansUpFailedDownloads() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source")
        let destination = directory.appendingPathComponent("destination")
        try Data("abcdef".utf8).write(to: source)
        try await stubbedTransport.upload(file: source, operation: .init(url: #require(URL(string: "https://transfer.example/upload")), method: "PUT", headers: ["X-Signature": "signed"], offset: 1, length: 4))
        await #expect(throws: Error.self) { try await stubbedTransport.download(url: #require(URL(string: "https://transfer.example/failed")), destination: destination) }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["source"])
        try await stubbedTransport.download(url: #require(URL(string: "https://transfer.example/media")), destination: destination)
        #expect(try Data(contentsOf: destination) == Data("downloaded media".utf8))
        await #expect(throws: Error.self) { try await stubbedTransport.download(url: #require(URL(string: "https://transfer.example/media")), destination: destination) }
        #expect(try Data(contentsOf: destination) == Data("downloaded media".utf8))
    }

    @Test func recoveryLocksExcludeConcurrentUploadExecutions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = MediaUploadJournal(directory: directory)
        let lease = try await journal.claim("operation")
        await #expect(throws: ServiceError.self) { try await journal.claim("operation") }
        withExtendedLifetime(lease) {}
    }
}
