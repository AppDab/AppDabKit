import AppDabServices

public struct UploadAppPreviewAction: VersionMediaWriteAction {
    public typealias Input = UploadAppPreviewInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .uploadAppPreview, kind: .appPreview, operation: .upload)
    public init() {}
}
