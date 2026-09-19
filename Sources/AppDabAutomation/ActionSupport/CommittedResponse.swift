import AppDabServices

struct CommittedResponse: Sendable {
    let response: AutomationResponse
    let redactedReplayData: JSONValue
}
