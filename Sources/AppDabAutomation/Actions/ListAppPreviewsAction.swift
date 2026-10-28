import AppDabServices

public struct ListAppPreviewsAction: VersionMediaReadAction {
    public typealias Input = ListAppPreviewsInput
    public static let descriptor = VersionMediaActionSupport.descriptor(id: .listAppPreviews, kind: .appPreview, operation: .list)
    public init() {}
}
