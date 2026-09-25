import AppDabServices

public struct ListCustomerReviewsInput: AutomationActionInput {
    public let accountID: String
    public let appID: String
    public let pagination: PaginationRequest

    public init(accountID: String, appID: String, pagination: PaginationRequest = .init()) {
        self.accountID = accountID
        self.appID = appID
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(
            arguments,
            allowedKeys: ["accountID", "appID", "cursor", "limit"]
        )
        accountID = try arguments.requiredString("accountID")
        appID = try arguments.requiredString("appID")
        pagination = .init(
            cursor: try arguments.optionalString("cursor"),
            limit: try arguments.optionalInteger("limit")
        )
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument appID must be a nonempty string.")
        }
        do {
            try pagination.validate()
        } catch let error {
            switch error {
            case .invalidLimit(let limit):
                throw .invalidLimit(limit)
            default:
                throw .invalidArguments(error.localizedDescription)
            }
        }
    }
}
