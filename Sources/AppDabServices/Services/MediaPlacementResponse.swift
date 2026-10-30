import BagbutikAppStoreModels
import BagbutikCore

/// Apple also returns placement states, such as PENDING, that the SDK does not yet model.
struct MediaPlacementResource: Decodable, Sendable {
    struct Attributes: Decodable, Sendable {
        let placementType: AppAssetLibraryPlacementType?
        let placementGroup: String?
        let state: String?
        let stateDetails: [JSONValue]?
    }

    let id: String
    let attributes: Attributes?
    let relationships: AppAssetLibraryPlacement.Relationships?
}

struct MediaPlacementResponse: Decodable, Sendable {
    let data: MediaPlacementResource
}

struct MediaPlacementsResponse: Decodable, PagedResponse, Sendable {
    let data: [MediaPlacementResource]
    let links: PagedDocumentLinks
    let meta: PagingInformation?
}

extension Request {
    func decodingMediaResponse<T>(_: T.Type) -> Request<T, ErrorResponseType> {
        .init(path: path, method: method, parameters: parameters, requestBody: requestBody)
    }
}
