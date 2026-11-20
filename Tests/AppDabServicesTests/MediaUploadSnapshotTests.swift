@testable import AppDabServices
import Foundation
import Testing

struct MediaUploadSnapshotTests {
    @Test func editsAndRestorationCannotMixUploadedRanges() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: source) }
        try Data("abcdef".utf8).write(to: source)
        let snapshot = try MediaUploadSnapshot(source: source, fingerprint: .read(path: source.path))
        defer { snapshot.remove() }
        let first = try Data(contentsOf: snapshot.file).prefix(3)
        try Data("abcXYZ".utf8).write(to: source)
        let second = try Data(contentsOf: snapshot.file).suffix(3)
        try Data("abcdef".utf8).write(to: source)
        #expect(first + second == Data("abcdef".utf8))
        let path = snapshot.file.path
        snapshot.remove()
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func refusesACopyThatDoesNotMatchTheConfirmedFingerprint() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: source) }
        try Data("abcdef".utf8).write(to: source)
        let confirmed = try MediaFileFingerprint.read(path: source.path)
        try Data("abcXYZ".utf8).write(to: source)
        #expect(throws: ServiceError.self) { try MediaUploadSnapshot(source: source, fingerprint: confirmed) }
    }
}
