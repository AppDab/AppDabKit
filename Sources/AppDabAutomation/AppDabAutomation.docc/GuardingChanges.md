# Previewing and committing changes

Actions that make guarded changes use a preview followed by an explicit commit. The preview describes the proposed change and returns a confirmation fingerprint. Present the summary to the user before committing.

```swift
let input = CreateAppVersionInput(
    accountID: accountID,
    appID: appID,
    platform: .iOS,
    version: "2.0"
)

let plan = try await executor.preview(CreateAppVersionAction.self, input: input)
let version = try await executor.commit(
    CreateAppVersionAction.self,
    input: input,
    confirmationFingerprint: plan.confirmationFingerprint,
    idempotencyKey: UUID().uuidString
)
```

The executor verifies the preview, input, action, and remote preconditions at commit time. Plans expire after 10 minutes by default. Reuse the same idempotency key when retrying a commit. If the outcome is uncertain, use reconciliation to inspect remote state before attempting another mutation.

The JSON request API supports `.preview`, `.commit`, and `.reconcile` modes. Ordinary execution of a guarded write prepares a preview; direct writes are reserved for operations that explicitly support safe direct execution.
