import AppDabAutomation

public struct CreateVersionHarness {
    let executor: Executor

    public init(executor: Executor) {
        self.executor = executor
    }

    public func preview() async throws -> AutomationResponse {
        try await execute(context: .init(mode: .preview))
    }

    public func commit(plan: AutomationMutationPlan, key: String) async throws -> AutomationResponse {
        try await execute(context: .init(
            mode: .commit,
            confirmationFingerprint: plan.confirmationFingerprint,
            idempotencyKey: key
        ))
    }

    public func reconcile(plan: AutomationMutationPlan, key: String) async throws -> AutomationResponse {
        try await execute(context: .init(
            mode: .reconcile,
            confirmationFingerprint: plan.confirmationFingerprint,
            idempotencyKey: key
        ))
    }

    private func execute(context: AutomationExecutionContext) async throws -> AutomationResponse {
        try await executor.execute(.init(
            actionID: .createAppVersion,
            arguments: [
                "account_id": .string("account-1"),
                "app_id": .string("app-1"),
                "platform": .string("IOS"),
                "version": .string("2.0"),
            ],
            surface: .cli,
            executionContext: context
        ))
    }
}
