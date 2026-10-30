import AppDabServices

public struct DownloadScreenshotAction: VersionMediaWriteAction {
    public typealias Input = DownloadScreenshotInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .downloadScreenshot, kind: .screenshot, operation: .download)
    public init() {}
}
