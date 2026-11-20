import AppDabServices

public struct ReorderScreenshotsAction: VersionMediaWriteAction {
    public typealias Input = ReorderScreenshotsInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .reorderScreenshots, kind: .screenshot, operation: .reorder)
    public init() {}
}
