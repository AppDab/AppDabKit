import AppDabServices

public struct GetScreenshotAction: VersionMediaReadAction {
    public typealias Input = GetScreenshotInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .getScreenshot, kind: .screenshot, operation: .get)
    public init() {}
}
