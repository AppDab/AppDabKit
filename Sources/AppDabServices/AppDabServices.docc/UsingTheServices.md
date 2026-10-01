# Using the services

Create ``StoredAccountProvider`` with a closure that loads the API keys from storage owned by your app, then pass it to ``LiveServices``.

```swift
import AppDabServices
import ConnectAccounts

func listApps(apiKeys: [APIKey], accountID: String) async throws -> AppList {
    let accountProvider = StoredAccountProvider(loadAPIKeys: { apiKeys })
    let services = LiveServices(accountProvider: accountProvider)

    return try await services.appCatalogService.listApps(
        accountID: accountID,
        pagination: PaginationRequest(limit: 50)
    )
}
```

The `accountID` is the stored API key's `id`. Call `accountProvider.listAccounts()` to discover the available account identifiers.

List methods return a page and its ``PaginationMetadata``. Pass its `nextCursor` and the same page limit in a new ``PaginationRequest`` to continue. The default page limit is 50, the maximum is 200, and a cursor requires an explicit limit.

The ``ServiceProviding`` and service protocols let you inject test or alternate implementations without changing code that consumes the services.
