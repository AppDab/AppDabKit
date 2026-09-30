import AppDabServices
import Foundation

public struct AutomationRegistry: Sendable {
    public static let standard: AutomationRegistry = {
        do {
            return try AutomationRegistry(actions: [
                AnyAutomationAction(ListAccountsAction.self),
                AnyAutomationAction(AddAccountAction.self),
                AnyAutomationAction(RemoveAccountAction.self),
                AnyAutomationAction(VerifyAccountAction.self),
                AnyAutomationAction(ListAppsAction.self),
                AnyAutomationAction(GetAppAction.self),
                AnyAutomationAction(ListAppVersionsAction.self),
                AnyAutomationAction(GetAppVersionAction.self),
                AnyAutomationAction(ListBuildsAction.self),
                AnyAutomationAction(GetBuildAction.self),
                AnyAutomationAction(ListBetaGroupsAction.self),
                AnyAutomationAction(GetBetaGroupAction.self),
                AnyAutomationAction.guarded(CreateBetaGroupAction.self),
                AnyAutomationAction.guarded(UpdateBetaGroupAction.self),
                AnyAutomationAction.guarded(DeleteBetaGroupAction.self),
                AnyAutomationAction.guarded(AddBuildToBetaGroupAction.self),
                AnyAutomationAction.guarded(RemoveBuildFromBetaGroupAction.self),
                AnyAutomationAction.guarded(AddIndividualTesterToBuildAction.self),
                AnyAutomationAction.guarded(RemoveIndividualTesterFromBuildAction.self),
                AnyAutomationAction.guarded(AddBetaGroupToBuildAction.self),
                AnyAutomationAction.guarded(RemoveBetaGroupFromBuildAction.self),
                AnyAutomationAction.guarded(AddTesterToBetaGroupAction.self),
                AnyAutomationAction.guarded(RemoveTesterFromBetaGroupAction.self),
                AnyAutomationAction.guarded(SubmitBuildForBetaReviewAction.self),
                AnyAutomationAction.guarded(ExpireBuildAction.self),
                AnyAutomationAction.guarded(UpdateBetaBuildLocalizationAction.self),
                AnyAutomationAction(ListBetaAppLocalizationsAction.self),
                AnyAutomationAction.guarded(CreateBetaAppLocalizationAction.self),
                AnyAutomationAction.guarded(UpdateBetaAppLocalizationAction.self),
                AnyAutomationAction.guarded(DeleteBetaAppLocalizationAction.self),
                AnyAutomationAction(GetBetaAppReviewDetailAction.self),
                AnyAutomationAction.guarded(UpdateBetaAppReviewDetailAction.self),
                AnyAutomationAction(GetBetaLicenseAgreementAction.self),
                AnyAutomationAction.guarded(UpdateBetaLicenseAgreementAction.self),
                AnyAutomationAction(ListBetaTestersAction.self),
                AnyAutomationAction.guarded(InviteBetaTesterAction.self),
                AnyAutomationAction.guarded(SendBetaTesterInvitationAction.self),
                AnyAutomationAction.guarded(CreateAppVersionAction.self),
                AnyAutomationAction(ListCustomerReviewsAction.self),
                AnyAutomationAction(GetCustomerReviewAction.self),
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
            try Self.validate(action.descriptor)
            guard actionsByID[action.descriptor.id] == nil else {
                throw AutomationActionError.invalidArguments(
                    "Duplicate automation action \(action.descriptor.id.rawValue).",
                )
            }
            switch action.descriptor.safety {
            case .write:
                guard action.supportsGuardedMutation || action.supportsDirectWriteExecution else {
                    throw AutomationActionError.invalidArguments(
                        "Write action \(action.descriptor.id.rawValue) must support guarded or direct execution.",
                    )
                }
            case .read, .draft:
                guard !action.supportsGuardedMutation else {
                    throw AutomationActionError.invalidArguments(
                        "Read or draft action \(action.descriptor.id.rawValue) must not conform to GuardedAutomationAction.",
                    )
                }
            }
            actionsByID[action.descriptor.id] = action
        }
        self.actionsByID = actionsByID
        registeredActions = actions
    }

    private static func validate(
        _ descriptor: AutomationActionDescriptor,
    ) throws(AutomationActionError) {
        let actionID = descriptor.id.rawValue
        let validIDCharacters = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "_"))
        guard !actionID.isEmpty,
              actionID.unicodeScalars.allSatisfy(validIDCharacters.contains),
              !actionID.contains("__")
        else {
            throw .invalidArguments("Automation action IDs must use lowercase snake case: \(actionID).")
        }
        try validateObjectSchema(descriptor.inputSchema, named: "input", actionID: actionID)
        try validateObjectSchema(descriptor.outputSchema, named: "output", actionID: actionID)
    }

    private static func validateObjectSchema(
        _ schema: JSONValue,
        named name: String,
        actionID: String,
    ) throws(AutomationActionError) {
        guard let definition = schema.objectValue,
              definition["type"] == .string("object"),
              definition["properties"]?.objectValue != nil
        else {
            throw .invalidArguments("The \(name) schema for \(actionID) must be an object schema.")
        }
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
