import AppDabLocales
import Testing

struct AppLocaleTests {
    @Test func supportedLocaleIdentifiersAreUnique() {
        let identifiers = AppLocale.supportedLocales.map { $0.id.lowercased() }
        #expect(Set(identifiers).count == identifiers.count)
        #expect(AppLocale.supportedLocales.allSatisfy { !$0.name.isEmpty && !$0.emoji.isEmpty })
    }

    @Test func lookupIgnoresIdentifierCase() {
        #expect(AppLocale.getStrict(fromId: "EN-us")?.id == "en-US")
    }

    @Test func unknownLocaleUsesExistingFallback() {
        #expect(AppLocale.getStrict(fromId: "xx-ZZ") == nil)
        #expect(AppLocale.get(fromId: "xx-ZZ").id == "?")
        #expect(AppLocale.get(fromId: "xx-ZZ").name == "Unknown")
    }
}
