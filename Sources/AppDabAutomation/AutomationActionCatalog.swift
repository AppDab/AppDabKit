public enum AutomationActionCatalog {
    public static let all = AutomationRegistry.standard.descriptors

    public static func descriptor(for id: AutomationActionID) -> AutomationActionDescriptor? {
        AutomationRegistry.standard.descriptor(for: id)
    }

    public static func descriptor(named name: String) -> AutomationActionDescriptor? {
        descriptor(for: AutomationActionID(rawValue: name))
    }
}
