# Adding an Automation Action

Every AppDab automation action starts here. This guide defines the typed AppDabKit action and service contract.

## Define the service contract

1. Add or extend the canonical model and service method in `AppDabServices`. Convert Bagbutik values at this boundary so automation and adapters use service models only.
2. Add a typed input under `Sources/AppDabAutomation/Actions/Inputs` and a typed action under `Sources/AppDabAutomation/Actions`. Give each input type and each concrete action its own matching Swift file. Shared action implementations may have a separate file.
3. Use a lowercase snake case `AutomationActionID` and camel case JSON argument keys such as `accountID` and `appID`.
4. Supply object input and output schemas, strict input decoding, validation, user facing output summary, and encoded response data. The input decoder must reject any key absent from its input schema.
5. Register the action in `AutomationRegistry.standard`. Registration validates IDs and object schemas.

## Choose write behavior

Reads conform to `AutomationAction`. A direct write sets `supportsDirectWriteExecution` only when repeating the operation is safe. A guarded write conforms to `GuardedAutomationAction` and implements preview, remote precondition validation, commit, redacted replay data, and reconciliation before it is registered.

## Update the contract and verify

Add focused action tests for input validation, service behavior, output shape, and write behavior. Update this document when the shared contract changes. Run:

```sh
swift test
```

## File transfers and replay

Screenshot and app preview actions use `VersionMediaServing`. Upload previews read a file fingerprint and Apple's placement requirements without writing remote data. Commit revalidates the file and placement snapshot. Durable upload checkpoints retain only the scope, fingerprint, asset ID, upload completion, and placement ID. They complement the final mutation receipt and let reconciliation resume a known upload without creating another asset. An unknown creation outcome requires manual investigation.

Actions that produce local files implement `validateReplayData` so both typed and JSON execution verify the file before replaying a successful receipt. Replay data must never contain signed media URLs or upload headers.
