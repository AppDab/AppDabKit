import AppDabServices

public struct DownloadAppPreviewAction: VersionMediaDownloadAction {
    public typealias Input = DownloadAppPreviewInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .downloadAppPreview, kind: .appPreview, operation: .download)
    public init() {}
}
