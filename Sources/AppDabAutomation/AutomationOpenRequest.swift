import Foundation

public struct AutomationOpenRequest: Codable, Equatable, Hashable, Sendable {
    public let requestID: String?
    public let destination: AutomationOpenDestination
    public let accountID: String
    public let appID: String

    public init(
        requestID: String? = nil,
        destination: AutomationOpenDestination,
        accountID: String,
        appID: String
    ) {
        self.requestID = requestID
        self.destination = destination
        self.accountID = accountID
        self.appID = appID
    }

    public var url: URL? {
        var components = URLComponents()
        components.scheme = "appdab"
        components.host = "automation"
        components.path = switch destination {
        case .app: "/open-app"
        case .customerReviews: "/open-customer-reviews"
        }
        var queryItems = [
            URLQueryItem(name: "account_id", value: accountID),
            URLQueryItem(name: "app_id", value: appID)
        ]
        if let requestID {
            queryItems.append(URLQueryItem(name: "request_id", value: requestID))
        }
        components.queryItems = queryItems
        return components.url
    }

    public static func parse(url: URL) -> AutomationOpenRequest? {
        guard url.scheme == "appdab",
              url.host == "automation",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let destination: AutomationOpenDestination
        switch components.path {
        case "/open-app":
            destination = .app
        case "/open-customer-reviews":
            destination = .customerReviews
        default:
            return nil
        }
        let queryItems = components.queryItems ?? []
        guard let accountID = queryItems.first(where: { $0.name == "account_id" })?.value,
              let appID = queryItems.first(where: { $0.name == "app_id" })?.value,
              !accountID.isEmpty,
              !appID.isEmpty else {
            return nil
        }
        return .init(
            requestID: queryItems.first(where: { $0.name == "request_id" })?.value,
            destination: destination,
            accountID: accountID,
            appID: appID
        )
    }
}
