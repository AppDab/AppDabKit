import AppDabServices

public protocol AutomationActionInput: Codable, Equatable, Sendable {
    init(arguments: [String: JSONValue]) throws(AutomationActionError)
    func validate() throws(AutomationActionError)
}

public extension AutomationActionInput {
    func validate() throws(AutomationActionError) {}
}
