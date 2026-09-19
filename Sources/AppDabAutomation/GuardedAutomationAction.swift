import AppDabServices

public protocol GuardedAutomationAction: AutomationAction {
    func prepareMutation(
        input: Input,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationPreparation
    func validateMutation(
        input: Input,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws
    func commitMutation(
        input: Input,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> Output
    func redactedReplayData(for output: Output) throws -> JSONValue
    func reconcileMutation(
        input: Input,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationReconciliation<Output>
}

public extension GuardedAutomationAction {
    func validateMutation(
        input: Input,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws {}

    func reconcileMutation(
        input: Input,
        plan: AutomationMutationPlan,
        dataProvider: any AutomationDataProviding
    ) async throws -> AutomationMutationReconciliation<Output> {
        .unresolved
    }
}
