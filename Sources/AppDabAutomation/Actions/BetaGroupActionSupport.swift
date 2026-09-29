import AppDabServices
import Foundation

func decodeBetaGroup(_ data: JSONValue) throws -> BetaGroupSummary {
    guard let value = data.objectValue?["betaGroup"] else { throw AutomationActionError.invalidArguments("Beta group replay data is missing.") }
    return try JSONDecoder().decode(BetaGroupSummary.self, from: JSONEncoder().encode(value))
}
