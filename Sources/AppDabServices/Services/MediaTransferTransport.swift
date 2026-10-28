import Darwin
import Foundation

public struct MediaUploadOperation: Sendable {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let offset: Int
    public let length: Int

    public init(url: URL, method: String, headers: [String: String], offset: Int, length: Int) {
        self.url = url
        self.method = method
        self.headers = headers
        self.offset = offset
        self.length = length
    }
}

public protocol MediaTransferTransport: Sendable {
    func upload(file: URL, operation: MediaUploadOperation) async throws
    func download(url: URL, destination: URL) async throws
}

/// Uses a separate ephemeral session, without App Store Connect authentication.
public final class URLSessionMediaTransferTransport: NSObject, MediaTransferTransport, URLSessionTaskDelegate, Sendable {
    private let configuration: @Sendable () -> URLSessionConfiguration

    public init(configuration: @escaping @Sendable () -> URLSessionConfiguration = { .ephemeral }) {
        self.configuration = configuration
        super.init()
    }

    public func urlSession(_: URLSession, task: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse, newRequest: URLRequest) async -> URLRequest? {
        // CDN downloads may redirect, but signed upload headers must stay on the original host.
        guard task is URLSessionDownloadTask, newRequest.url?.scheme == "https" else { return nil }
        var request = newRequest
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        request.setValue(nil, forHTTPHeaderField: "Cookie")
        return request
    }

    public func upload(file: URL, operation: MediaUploadOperation) async throws {
        guard operation.url.scheme == "https", operation.offset >= 0, operation.length > 0 else {
            throw ServiceError.upstream("Apple returned an invalid upload operation.")
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Self.stageRange(file: file, operation: operation, destination: temporary)
        var request = URLRequest(url: operation.url)
        request.httpMethod = operation.method
        request.allHTTPHeaderFields = operation.headers
        let session = URLSession(configuration: configuration(), delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (_, response) = try await session.upload(for: request, fromFile: temporary)
        try Self.validate(response)
    }

    static func stageRange(file: URL, operation: MediaUploadOperation, destination temporary: URL) throws {
        guard operation.offset >= 0, operation.length > 0 else { throw ServiceError.upstream("Invalid upload byte range.") }
        let source = try FileHandle(forReadingFrom: file)
        defer { try? source.close() }
        let size = try source.seekToEnd()
        guard UInt64(operation.offset) <= size, UInt64(operation.length) <= size - UInt64(operation.offset) else {
            throw ServiceError.upstream("Apple requested bytes outside the media file.")
        }
        try source.seek(toOffset: UInt64(operation.offset))
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil) else { throw ServiceError.upstream("Cannot create upload buffer.") }
        let output = try FileHandle(forWritingTo: temporary)
        do {
            var remaining = operation.length
            while remaining > 0 {
                try Task.checkCancellation()
                guard let bytes = try source.read(upToCount: min(remaining, 1024 * 1024)), !bytes.isEmpty else {
                    throw ServiceError.invalidArguments("The media file changed during upload.")
                }
                try output.write(contentsOf: bytes)
                remaining -= bytes.count
            }
            try output.close()
        } catch {
            try? output.close()
            throw error
        }
    }

    public func download(url: URL, destination: URL) async throws {
        guard url.scheme == "https" else { throw ServiceError.upstream("Apple returned an invalid download URL.") }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw ServiceError.invalidArguments("The destination already exists.") }
        let session = URLSession(configuration: configuration(), delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (temporary, response) = try await session.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Self.validate(response)
        try Task.checkCancellation()
        // Copy to the destination volume before the atomic, exclusive rename.
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).download")
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.copyItem(at: temporary, to: staging)
        let status = staging.withUnsafeFileSystemRepresentation { source in
            destination.withUnsafeFileSystemRepresentation { target in
                renameatx_np(AT_FDCWD, source!, AT_FDCWD, target!, UInt32(RENAME_EXCL))
            }
        }
        guard status == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ServiceError.network("Media transfer failed. No transfer credentials were logged.")
        }
    }
}
