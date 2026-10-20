import AppDabServices

public struct ListXcodeCloudGitReferencesInput: AutomationActionInput {
    public let accountID: String
    public let repositoryID: String
    public let pagination: PaginationRequest

    public init(accountID: String, repositoryID: String, pagination: PaginationRequest = .init()) {
        self.accountID = accountID
        self.repositoryID = repositoryID
        self.pagination = pagination
    }

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        let arguments = try Arguments(arguments, allowedKeys: ["accountID", "repositoryID", "cursor", "limit"])
        accountID = try arguments.requiredString("accountID")
        repositoryID = try arguments.requiredString("repositoryID")
        pagination = try .init(cursor: arguments.optionalString("cursor"), limit: arguments.optionalInteger("limit"))
    }

    public func validate() throws(AutomationActionError) {
        guard !accountID.isEmpty else {
            throw .invalidArguments("Argument accountID must be a nonempty string.")
        }
        guard !repositoryID.isEmpty else {
            throw .invalidArguments("Argument repositoryID must be a nonempty string.")
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
