import AppDabServices

public struct AnyAutomationAction: Sendable {
    public let descriptor: AutomationActionDescriptor
    private let actionTypeID: ObjectIdentifier
    private let executeAction: @Sendable ([String: JSONValue], any AutomationDataProviding) async throws -> AutomationResponse
    private let prepareAction: (@Sendable ([String: JSONValue], any AutomationDataProviding) async throws -> AutomationMutationPreparation)?
    private let validateMutationAction: (@Sendable ([String: JSONValue], AutomationMutationPlan, any AutomationDataProviding) async throws -> Void)?
    private let commitAction: (@Sendable ([String: JSONValue], AutomationMutationPlan, any AutomationDataProviding) async throws -> CommittedResponse)?
    private let reconcileAction: (@Sendable ([String: JSONValue], AutomationMutationPlan, any AutomationDataProviding) async throws -> MutationReconciliation)?

    public init<Action: AutomationAction>(_ actionType: Action.Type) {
        self.init(
            actionType,
            prepareAction: nil,
            validateMutationAction: nil,
            commitAction: nil,
            reconcileAction: nil
        )
    }

    public static func guarded<Action: GuardedAutomationAction>(_ actionType: Action.Type) -> Self {
        .init(
            actionType,
            prepareAction: { arguments, dataProvider in
                let action = actionType.init()
                let input = try Self.input(Action.Input.self, arguments: arguments)
                return try await action.prepareMutation(input: input, dataProvider: dataProvider)
            },
            validateMutationAction: { arguments, plan, dataProvider in
                let action = actionType.init()
                let input = try Self.input(Action.Input.self, arguments: arguments)
                try await action.validateMutation(input: input, plan: plan, dataProvider: dataProvider)
            },
            commitAction: { arguments, plan, dataProvider in
                let action = actionType.init()
                let input = try Self.input(Action.Input.self, arguments: arguments)
                let output = try await action.commitMutation(
                    input: input,
                    plan: plan,
                    dataProvider: dataProvider
                )
                return try Self.committedResponse(action: action, output: output)
            },
            reconcileAction: { arguments, plan, dataProvider in
                let action = actionType.init()
                let input = try Self.input(Action.Input.self, arguments: arguments)
                switch try await action.reconcileMutation(
                    input: input,
                    plan: plan,
                    dataProvider: dataProvider
                ) {
                case .succeeded(let output):
                    return .succeeded(try Self.committedResponse(action: action, output: output))
                case .notApplied:
                    return .notApplied
                case .unresolved:
                    return .unresolved
                }
            }
        )
    }

    private init<Action: AutomationAction>(
        _ actionType: Action.Type,
        prepareAction: (@Sendable ([String: JSONValue], any AutomationDataProviding) async throws -> AutomationMutationPreparation)?,
        validateMutationAction: (@Sendable ([String: JSONValue], AutomationMutationPlan, any AutomationDataProviding) async throws -> Void)?,
        commitAction: (@Sendable ([String: JSONValue], AutomationMutationPlan, any AutomationDataProviding) async throws -> CommittedResponse)?,
        reconcileAction: (@Sendable ([String: JSONValue], AutomationMutationPlan, any AutomationDataProviding) async throws -> MutationReconciliation)?
    ) {
        descriptor = actionType.descriptor
        actionTypeID = ObjectIdentifier(actionType)
        executeAction = { arguments, dataProvider in
            let action = actionType.init()
            let input = try Self.input(Action.Input.self, arguments: arguments)
            let output = try await action.perform(input: input, dataProvider: dataProvider)
            return try Self.response(action: action, output: output)
        }
        self.prepareAction = prepareAction
        self.validateMutationAction = validateMutationAction
        self.commitAction = commitAction
        self.reconcileAction = reconcileAction
    }

    func execute(
        arguments: [String: JSONValue],
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationResponse {
        try await executeAction(arguments, dataProvider)
    }

    func prepareMutation(
        arguments: [String: JSONValue],
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationPreparation {
        guard let prepareAction else {
            throw AutomationExecutionError.unsupportedExecutionMode(
                action: descriptor.id.rawValue,
                mode: .preview
            )
        }
        return try await prepareAction(arguments, dataProvider)
    }

    func validateMutation(
        arguments: [String: JSONValue],
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws {
        guard let validateMutationAction else {
            throw AutomationExecutionError.unsupportedExecutionMode(
                action: descriptor.id.rawValue,
                mode: .commit
            )
        }
        try await validateMutationAction(arguments, plan, dataProvider)
    }

    func commitMutation(
        arguments: [String: JSONValue],
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> CommittedResponse {
        guard let commitAction else {
            throw AutomationExecutionError.unsupportedExecutionMode(
                action: descriptor.id.rawValue,
                mode: .commit
            )
        }
        return try await commitAction(arguments, plan, dataProvider)
    }

    func reconcileMutation(
        arguments: [String: JSONValue],
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> MutationReconciliation {
        guard let reconcileAction else {
            throw AutomationExecutionError.unsupportedExecutionMode(
                action: descriptor.id.rawValue,
                mode: .reconcile
            )
        }
        return try await reconcileAction(arguments, plan, dataProvider)
    }

    var supportsGuardedMutation: Bool {
        prepareAction != nil && validateMutationAction != nil && commitAction != nil && reconcileAction != nil
    }

    func isRegistered<Action: AutomationAction>(_ actionType: Action.Type) -> Bool {
        actionTypeID == ObjectIdentifier(actionType)
    }

    private static func input<Input: AutomationActionInput>(
        _ type: Input.Type,
        arguments: [String: JSONValue]
    ) throws(AutomationActionError) -> Input {
        let input = try Input(arguments: arguments)
        try input.validate()
        return input
    }

    private static func response<Action: AutomationAction>(
        action: Action,
        output: Action.Output
    ) throws -> AutomationResponse {
        .init(
            actionID: Action.descriptor.id,
            summary: action.summary(for: output),
            data: try action.data(for: output)
        )
    }

    private static func committedResponse<Action: GuardedAutomationAction>(
        action: Action,
        output: Action.Output
    ) throws -> CommittedResponse {
        .init(
            response: try response(action: action, output: output),
            redactedReplayData: try action.redactedReplayData(for: output)
        )
    }
}
