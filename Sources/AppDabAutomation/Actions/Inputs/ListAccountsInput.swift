import AppDabServices

public struct ListAccountsInput: AutomationActionInput {
    public init() {}

    public init(arguments: [String: JSONValue]) throws(AutomationActionError) {
        _ = try Arguments(arguments, allowedKeys: [])
    }
}
