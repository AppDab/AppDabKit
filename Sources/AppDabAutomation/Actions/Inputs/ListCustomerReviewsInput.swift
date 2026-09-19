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
            allowedKeys: ["account_id", "app_id", "cursor", "limit"]
        )
        accountID = try arguments.requiredString("account_id")
        appID = try arguments.requiredString("app_id")
        pagination = .init(
            cursor: try arguments.optionalString("cursor"),
            limit: try arguments.optionalInteger("limit")
        )
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
        }
        guard !appID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument app_id must be a nonempty string.")
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
