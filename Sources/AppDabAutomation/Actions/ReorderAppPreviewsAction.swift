import AppDabServices

public struct ReorderAppPreviewsAction: VersionMediaWriteAction {
    public typealias Input = ReorderAppPreviewsInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .reorderAppPreviews, kind: .appPreview, operation: .reorder)
    public init() {}
}
