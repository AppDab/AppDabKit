public struct AutomationRegistry: Sendable {
    public static let standard: AutomationRegistry = {
        do {
            return try AutomationRegistry(actions: [
                AnyAutomationAction(ListAccountsAction.self),
                AnyAutomationAction.guarded(AddAccountAction.self),
                AnyAutomationAction.guarded(RemoveAccountAction.self),
                AnyAutomationAction(VerifyAccountAction.self),
                AnyAutomationAction(ListAppsAction.self),
                AnyAutomationAction(GetAppAction.self),
                AnyAutomationAction(ListAppVersionsAction.self),
                AnyAutomationAction(GetAppVersionAction.self),
                AnyAutomationAction.guarded(CreateAppVersionAction.self),
                AnyAutomationAction(ListCustomerReviewsAction.self),
                AnyAutomationAction(GetCustomerReviewAction.self)
            ])
        } catch {
            preconditionFailure("Invalid standard automation registry: \(error.localizedDescription)")
        }
    }()

    private let actionsByID: [AutomationActionID: AnyAutomationAction]
    private let registeredActions: [AnyAutomationAction]

    public init(actions: [AnyAutomationAction]) throws(AutomationActionError) {
        var actionsByID = [AutomationActionID: AnyAutomationAction]()
        for action in actions {
            guard actionsByID[action.descriptor.id] == nil else {
                throw AutomationActionError.invalidArguments(
                    "Duplicate automation action \(action.descriptor.id.rawValue)."
                )
            }
            switch action.descriptor.safety {
            case .write:
                guard action.supportsGuardedMutation else {
                    throw AutomationActionError.invalidArguments(
                        "Write action \(action.descriptor.id.rawValue) must be registered with AnyAutomationAction.guarded."
                    )
                }
            case .read, .draft:
                guard !action.supportsGuardedMutation else {
                    throw AutomationActionError.invalidArguments(
                        "Read or draft action \(action.descriptor.id.rawValue) must not conform to GuardedAutomationAction."
                    )
                }
            }
            actionsByID[action.descriptor.id] = action
        }
        self.actionsByID = actionsByID
        registeredActions = actions
    }

    public var descriptors: [AutomationActionDescriptor] {
        registeredActions.map(\.descriptor)
    }

    public func descriptor(for id: AutomationActionID) -> AutomationActionDescriptor? {
        actionsByID[id]?.descriptor
    }

    public func descriptor(named name: String) -> AutomationActionDescriptor? {
        let id = AutomationActionID(rawValue: name)
        return actionsByID[id]?.descriptor
    }

    func action(for id: AutomationActionID) throws(AutomationActionError) -> AnyAutomationAction {
        guard let action = actionsByID[id] else {
            throw AutomationActionError.invalidArguments("Unknown automation action \(id.rawValue).")
        }
        return action
    }
}
