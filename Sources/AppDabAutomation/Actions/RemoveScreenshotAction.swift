import AppDabServices

public struct RemoveScreenshotAction: VersionMediaWriteAction {
    public typealias Input = RemoveScreenshotInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .removeScreenshot, kind: .screenshot, operation: .remove)
    public init() {}
}
