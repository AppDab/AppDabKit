import Foundation

public enum AutomationOpenRequestStore {
    private static let pendingRequestKey = "appdab.automation.pendingOpenRequest"

    /// Stores one pending request. A newer request replaces an earlier request.
    public static func savePendingRequest(_ request: AutomationOpenRequest, userDefaults: UserDefaults = .standard) throws {
        let data = try JSONEncoder().encode(request)
        userDefaults.set(data, forKey: pendingRequestKey)
    }

    public static func takePendingRequest(userDefaults: UserDefaults = .standard) -> AutomationOpenRequest? {
        takeRequest(forKey: pendingRequestKey, userDefaults: userDefaults)
    }

    public static func takePendingRequest(
        matching requestID: String,
        userDefaults: UserDefaults = .standard
    ) -> AutomationOpenRequest? {
        guard let data = userDefaults.data(forKey: pendingRequestKey),
              let request = try? JSONDecoder().decode(AutomationOpenRequest.self, from: data),
              request.requestID == requestID else {
            return nil
        }
        userDefaults.removeObject(forKey: pendingRequestKey)
        return request
    }

    private static func takeRequest(forKey key: String, userDefaults: UserDefaults) -> AutomationOpenRequest? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        userDefaults.removeObject(forKey: key)
        return try? JSONDecoder().decode(AutomationOpenRequest.self, from: data)
    }
}
