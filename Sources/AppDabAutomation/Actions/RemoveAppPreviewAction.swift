import AppDabServices

public struct RemoveAppPreviewAction: VersionMediaWriteAction {
    public typealias Input = RemoveAppPreviewInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .removeAppPreview, kind: .appPreview, operation: .remove)
    public init() {}
}
