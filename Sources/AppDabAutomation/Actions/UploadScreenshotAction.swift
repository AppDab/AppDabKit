import AppDabServices

public struct UploadScreenshotAction: VersionMediaWriteAction {
    public typealias Input = UploadScreenshotInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .uploadScreenshot, kind: .screenshot, operation: .upload)
    public init() {}
}
