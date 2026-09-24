public enum AutomationActionSummary {
    public static func foundAccounts(_ count: Int) -> String {
        "Found \(count) accounts."
    }

    public static func foundApps(_ count: Int) -> String {
        "Found \(count) apps."
    }

    public static func fetchedApp(name: String) -> String {
        "Fetched app \(name)."
    }

    public static func foundReviews(_ count: Int) -> String {
        "Found \(count) reviews."
    }

    public static func fetchedReview(title: String) -> String {
        "Fetched customer review titled \"\(title)\"."
    }
}
