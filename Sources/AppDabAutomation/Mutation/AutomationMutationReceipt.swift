import AppDabServices
import Foundation

public struct AutomationMutationReceipt: Codable, Equatable, Sendable {
    public let actionID: AutomationActionID
    public let confirmationFingerprint: String
    public let idempotencyKey: String
    public let canonicalInputHash: String
    public let redactedSummary: String
    public let redactedReplayData: JSONValue
    public let committedAt: Date

    public init(
        actionID: AutomationActionID,
        confirmationFingerprint: String,
        idempotencyKey: String,
        canonicalInputHash: String,
        redactedSummary: String,
        redactedReplayData: JSONValue,
        committedAt: Date
    ) {
        self.actionID = actionID
        self.confirmationFingerprint = confirmationFingerprint
        self.idempotencyKey = idempotencyKey
        self.canonicalInputHash = canonicalInputHash
        self.redactedSummary = redactedSummary
        self.redactedReplayData = redactedReplayData
        self.committedAt = committedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actionID = try container.decode(AutomationActionID.self, forKey: .actionID)
        confirmationFingerprint = try container.decode(String.self, forKey: .confirmationFingerprint)
        idempotencyKey = try container.decode(String.self, forKey: .idempotencyKey)
        canonicalInputHash = try container.decodeIfPresent(String.self, forKey: .canonicalInputHash) ?? ""
        redactedSummary = try container.decode(String.self, forKey: .redactedSummary)
        redactedReplayData = try container.decode(JSONValue.self, forKey: .redactedReplayData)
        committedAt = try container.decode(Date.self, forKey: .committedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case actionID
        case confirmationFingerprint
        case idempotencyKey
        case canonicalInputHash
        case redactedSummary
        case redactedReplayData
        case committedAt
    }
}
