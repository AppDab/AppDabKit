import AppDabServices

public struct DownloadAppPreviewAction: VersionMediaWriteAction {
    public typealias Input = DownloadAppPreviewInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .downloadAppPreview, kind: .appPreview, operation: .download)
    public init() {}
}
