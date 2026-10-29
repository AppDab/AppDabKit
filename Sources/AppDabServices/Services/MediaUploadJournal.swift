import CryptoKit
import Darwin
import Foundation

/// Durable checkpoints complement the final automation receipt. No signed URLs are stored.
actor MediaUploadJournal {
    struct Entry: Codable {
        let scope: VersionMediaScope
        let fingerprint: MediaFileFingerprint
        let placementGroup: String
        var assetCreationRetryable: Bool? = true
        var assetID: String?
        var uploadComplete = false
        var placementStarted = false
        var placementID: String?
    }

    let directory: URL
    init(directory: URL) {
        self.directory = directory
    }

    func claim(_ operationID: String) throws -> MediaUploadLease {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return try MediaUploadLease(url: file(operationID).appendingPathExtension("lock"))
    }

    func load(_ operationID: String) throws -> Entry? {
        let file = file(operationID)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONDecoder().decode(Entry.self, from: Data(contentsOf: file))
    }

    func save(_ entry: Entry, operationID: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(entry).write(to: file(operationID), options: .atomic)
    }

    private func file(_ operationID: String) -> URL {
        let name = SHA256.hash(data: Data(operationID.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".json")
    }
}

/// Holds an exclusive process lock throughout transfer and placement creation, even if an audit lease expires.
final class MediaUploadLease: @unchecked Sendable {
    private let descriptor: Int32

    init(url: URL) throws {
        let descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ServiceError.upstream("Cannot open the upload recovery lock.") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw ServiceError.upstream("This upload is still running in another execution. Wait before reconciling it.")
        }
        self.descriptor = descriptor
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
