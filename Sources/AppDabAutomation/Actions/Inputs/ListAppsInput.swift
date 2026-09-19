import AppDabServices

public struct ListAppsInput: AutomationActionInput {
    public let accountID: String
    public let pagination: PaginationRequest

    public init(accountID: String, pagination: PaginationRequest = .init()) {
        self.accountID = accountID
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["account_id", "cursor", "limit"])
        accountID = try arguments.requiredString("account_id")
        pagination = .init(
            cursor: try arguments.optionalString("cursor"),
            limit: try arguments.optionalInteger("limit")
        )
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw AutomationActionError.invalidArguments("Argument account_id must be a nonempty string.")
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
