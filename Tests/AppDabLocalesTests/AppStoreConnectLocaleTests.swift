import AppDabLocales
import Testing

struct AppStoreConnectLocaleTests {
    @Test func supportedLocaleIdentifiersAreUnique() {
        let identifiers = AppStoreConnectLocale.supportedLocales.map { $0.id.lowercased() }
        #expect(Set(identifiers).count == identifiers.count)
        #expect(AppStoreConnectLocale.supportedLocales.allSatisfy { !$0.name.isEmpty && !$0.emoji.isEmpty })
    }

    @Test func lookupIgnoresIdentifierCase() {
        #expect(AppStoreConnectLocale.getStrict(fromId: "EN-us")?.id == "en-US")
    }

    @Test func unknownLocaleUsesExistingFallback() {
        #expect(AppStoreConnectLocale.getStrict(fromId: "xx-ZZ") == nil)
        #expect(AppStoreConnectLocale.get(fromId: "xx-ZZ").id == "?")
        #expect(AppStoreConnectLocale.get(fromId: "xx-ZZ").name == "Unknown")
    }
}
