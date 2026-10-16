# Choosing an App Store Connect locale

Use ``AppStoreConnectLocale/supportedLocales`` when presenting locale choices for fields that use App Store Connect localization identifiers. This list describes the locales supported by those schemas; it is not a list of every locale Foundation recognizes.

```swift
import AppDabLocales

let locale = AppStoreConnectLocale.get(fromId: "da")
print("\(locale.emoji) \(locale.name)")
```

Use ``AppStoreConnectLocale/getStrict(fromId:)`` when unsupported identifiers should return `nil`. Use ``AppStoreConnectLocale/get(fromId:)`` when an unknown identifier should display the `Unknown` placeholder.

Names returned by the module are localized in US English. Use the original identifier as the stable value for App Store Connect requests.
