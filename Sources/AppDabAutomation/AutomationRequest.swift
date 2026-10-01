import AppDabServices

/// An action identifier, its JSON arguments, and the requested execution mode.
public struct AutomationRequest: Equatable, Sendable {
    public let actionID: AutomationActionID
    public let arguments: [String: JSONValue]
    public let executionContext: AutomationExecutionContext

    public init(
        actionID: AutomationActionID,
        arguments: [String: JSONValue],
        executionContext: AutomationExecutionContext = .init(),
    ) {
        self.actionID = actionID
        self.arguments = arguments
        self.executionContext = executionContext
    }
}
