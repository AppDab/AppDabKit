import BagbutikAppStoreModels

public extension CustomerReviewResponseV1.Attributes.State {
    /// A human readable English name for the customer review response state.
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
