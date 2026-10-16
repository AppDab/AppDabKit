# Executing automation actions

Create a ``ServiceAutomationDataProvider`` from your services and account store, then pass it to an ``Executor``.

```swift
import AppDabAutomation
import AppDabServices

func makeExecutor(accountStore: any AutomationAccountStoring) -> Executor {
    let accountProvider = StoredAccountProvider(
        loadAPIKeys: { try await accountStore.loadAPIKeys() }
    )
    let services = LiveServices(accountProvider: accountProvider)
    let dataProvider = ServiceAutomationDataProvider(
        services: services,
        accountStore: accountStore
    )
    return Executor(dataProvider: dataProvider)
}
```

Use a typed action when calling from Swift:

```swift
let apps = try await executor.execute(
    ListAppsAction.self,
    input: ListAppsInput(accountID: accountID)
)
```

Use ``AutomationRequest`` when an adapter receives an action identifier and JSON arguments. ``AutomationRegistry/standard`` exposes registered action descriptors and their schemas.
