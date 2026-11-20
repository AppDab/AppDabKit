import Foundation

/// A private copy binds every uploaded range to the confirmed file contents.
struct MediaUploadSnapshot {
    let file: URL
    private let directory: URL

    init(source: URL, fingerprint: MediaFileFingerprint) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        file = directory.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            try FileManager.default.copyItem(at: source, to: file)
            guard try MediaFileFingerprint.read(path: file.path) == fingerprint else {
                throw ServiceError.invalidArguments("The media file changed while preparing the upload snapshot.")
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
