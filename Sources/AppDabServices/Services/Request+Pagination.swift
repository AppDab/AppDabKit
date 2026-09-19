import BagbutikCore

extension Request {
    func withPaginationCursor(_ cursor: String?) -> Request<ResponseType, ErrorResponseType> {
        guard let cursor else { return self }
        let existing = parameters
        var customs = existing?.customs ?? [:]
        customs["cursor"] = cursor
        return .init(
            path: path,
            method: method,
            parameters: .init(
                fields: existing?.fields,
                filters: existing?.filters,
                exists: existing?.exists,
                includes: existing?.includes,
                sorts: existing?.sorts,
                limits: existing?.limits,
                limit: existing?.limit,
                customs: customs
            ),
            requestBody: requestBody
        )
    }
}
