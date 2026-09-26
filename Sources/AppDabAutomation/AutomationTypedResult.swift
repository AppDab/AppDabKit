import AppDabServices

public struct AutomationTypedResult<Output: Sendable>: Sendable {
    public let response: AutomationResponse
    public let output: Output?

    public init(response: AutomationResponse, output: Output?) {
        self.response = response
        self.output = output
    }
}
