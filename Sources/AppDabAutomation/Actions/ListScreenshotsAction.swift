import AppDabServices

public struct ListScreenshotsAction: VersionMediaReadAction {
    public typealias Input = ListScreenshotsInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .listScreenshots, kind: .screenshot, operation: .list)
    public init() {}
}
