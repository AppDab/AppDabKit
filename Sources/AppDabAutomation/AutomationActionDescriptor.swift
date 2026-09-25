import AppDabServices

public struct AutomationActionDescriptor: Codable, Equatable, Sendable {
    public let id: AutomationActionID
    public let title: String
    public let description: String
    public let inputSchema: JSONValue
    public let outputSchema: JSONValue
    public let outputType: String
    public let safety: AutomationExecutionSafety

    public init(
        id: AutomationActionID,
        title: String,
        description: String,
        inputSchema: JSONValue,
        outputSchema: JSONValue,
        outputType: String,
        safety: AutomationExecutionSafety
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
        self.outputType = outputType
        self.safety = safety
    }
}
