import AppDabBagbutikExtensions
import BagbutikAppStoreModels
import Foundation

public struct CustomerReviewResponse: Codable, Equatable, Hashable, Sendable {
    public let responseID: String
    public let lastModifiedDate: Date
    public let responseBody: String
    public let state: String

    public init(responseID: String, lastModifiedDate: Date, responseBody: String, state: String) {
        self.responseID = responseID
        self.lastModifiedDate = lastModifiedDate
        self.responseBody = responseBody
        self.state = state
    }

    init(response: CustomerReviewResponseV1) {
        self.init(
            responseID: response.id,
            lastModifiedDate: response.attributes?.lastModifiedDate ?? .distantPast,
            responseBody: response.attributes?.responseBody ?? "",
            state: (response.attributes?.state ?? .pendingPublish).prettyName
        )
    }
}
