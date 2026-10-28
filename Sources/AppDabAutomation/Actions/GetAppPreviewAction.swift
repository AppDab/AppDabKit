import AppDabServices

public struct GetAppPreviewAction: VersionMediaReadAction {
    public typealias Input = GetAppPreviewInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .getAppPreview, kind: .appPreview, operation: .get)
    public init() {}
}
