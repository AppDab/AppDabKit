import BagbutikAppStoreModels

public extension CustomerReviewResponseV1.Attributes.State {
    var prettyName: String {
        switch self {
        case .pendingPublish:
            return "Pending"
        case .published:
            return "Published"
        @unknown default: fatalError()
        }
    }
}
