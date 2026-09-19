import AppDabServices

public struct AutomationResponse: Equatable, Sendable {
    public let actionID: AutomationActionID
    public let summary: String
    public let data: JSONValue
    public let plan: AutomationMutationPlan?
    public let receipt: AutomationMutationReceipt?

    public init(
        actionID: AutomationActionID,
        summary: String,
        data: JSONValue,
        plan: AutomationMutationPlan? = nil,
        receipt: AutomationMutationReceipt? = nil
    ) {
        self.actionID = actionID
        self.summary = summary
        self.data = data
        self.plan = plan
        self.receipt = receipt
    }

    public var envelope: JSONValue {
        var values: [String: JSONValue] = [
            "action": .string(actionID.rawValue),
            "summary": .string(summary),
            "data": data
        ]
        if let plan, let value = try? JSONValue.fromEncodable(plan) {
            values["plan"] = value
        }
        if let receipt, let value = try? JSONValue.fromEncodable(receipt) {
            values["receipt"] = value
        }
        return .object(values)
    }

    public var text: String {
        summary
    }

    public var structuredContent: JSONValue {
        data
    }
}
