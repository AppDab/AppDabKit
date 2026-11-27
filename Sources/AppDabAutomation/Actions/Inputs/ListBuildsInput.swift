import AppDabServices

public struct ListBuildsInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let pagination: PaginationRequest
    public let sort: BuildListSort

    public init(accountID: String, appID: String, pagination: PaginationRequest = .init(), sort: BuildListSort = .uploadedDate) {
        self.accountID = accountID
        self.appID = appID
        self.pagination = pagination
        self.sort = sort
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "appID", "cursor", "limit", "sort"])
        accountID = try arguments.requiredString("accountID")
        appID = try arguments.requiredString("appID")
        pagination = try .init(cursor: arguments.optionalString("cursor"), limit: arguments.optionalInteger("limit"))
        let sortValue = try arguments.optionalString("sort") ?? BuildListSort.uploadedDate.rawValue
        guard let sort = BuildListSort(rawValue: sortValue) else {
            throw .invalidArguments("Argument sort must be uploadedDate or version.")
        }
        self.sort = sort
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw .invalidArguments("Argument appID must be a nonempty string.")
        }
        do {
            try pagination.validate()
        } catch {
            switch error {
            case let .invalidLimit(limit): throw .invalidLimit(limit)
            default: throw .invalidArguments(error.localizedDescription)
            }
        }
    }
}
