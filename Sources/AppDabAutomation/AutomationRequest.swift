import AppDabServices

public struct AutomationRequest: Equatable, Sendable {
    public let actionID: AutomationActionID
    public let arguments: [String: JSONValue]
    public let surface: AutomationSurface
    public let executionContext: AutomationExecutionContext

    public init(
        actionID: AutomationActionID,
        arguments: [String: JSONValue],
        surface: AutomationSurface,
        executionContext: AutomationExecutionContext = .init()
    ) {
        self.actionID = actionID
        self.arguments = arguments
        self.surface = surface
        self.executionContext = executionContext
    }
}
