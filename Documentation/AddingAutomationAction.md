# Adding an Automation Action

Every AppDab automation action starts here. This guide defines the typed AppDabKit action and service contract.

## Define the service contract

1. Add or extend the canonical model and service method in `AppDabServices`. Convert Bagbutik values at this boundary so automation and adapters use service models only.
2. Add a typed input under `Sources/AppDabAutomation/Actions/Inputs` and a typed action under `Sources/AppDabAutomation/Actions`.
3. Use a lowercase snake case `AutomationActionID` and camel case JSON argument keys such as `accountID` and `appID`. CLI flags translate to dashed names such as `--account-id`.
4. Supply object input and output schemas, strict input decoding, validation, user facing output summary, and encoded response data. The input decoder must reject any key absent from its input schema.
5. Register the action in `AutomationRegistry.standard`. Registration validates IDs and object schemas.

## Choose write behavior

Reads conform to `AutomationAction`. A direct write sets `supportsDirectWriteExecution` only when repeating the operation is safe. A guarded write conforms to `GuardedAutomationAction` and implements preview, remote precondition validation, commit, redacted replay data, and reconciliation before it is registered.

## Complete the CLI command

Follow [Adding a Typed CLI Command](https://github.com/AppDab/AppDabCLI/blob/main/Documentation/AddingCLICommand.md). A typed named command is required for every registered action.

## Update the contract and verify

Add focused action tests for input validation, service behavior, output shape, and write behavior. Update this document when the shared contract changes. Run:

```sh
swift test
```

The AppDabCLI repository verifies that every registered action has a typed command.
