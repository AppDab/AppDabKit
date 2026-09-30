import Foundation

public struct AppLocale: Hashable, Identifiable, Sendable {
    public let id: String
    public let emoji: String
    public let name: String

    public static let supportedLocales: [AppLocale] = [
        (id: "ar-SA", emoji: "🇸🇦"),
        (id: "bn-BD", emoji: "🇧🇩"),
        (id: "ca", emoji: "🏴"),
        (id: "cs", emoji: "🇨🇿"),
        (id: "da", emoji: "🇩🇰"),
        (id: "de-DE", emoji: "🇩🇪"),
        (id: "el", emoji: "🇬🇷"),
        (id: "en-AU", emoji: "🇦🇺"),
        (id: "en-CA", emoji: "🇨🇦"),
        (id: "en-GB", emoji: "🇬🇧"),
        (id: "en-US", emoji: "🇺🇸"),
        (id: "es-ES", emoji: "🇪🇸"),
        (id: "es-MX", emoji: "🇲🇽"),
        (id: "fi", emoji: "🇫🇮"),
        (id: "fr-CA", emoji: "🇨🇦"),
        (id: "fr-FR", emoji: "🇫🇷"),
        (id: "gu-IN", emoji: "🇮🇳"),
        (id: "he", emoji: "🇮🇱"),
        (id: "hi", emoji: "🇮🇳"),
        (id: "hr", emoji: "🇭🇷"),
        (id: "hu", emoji: "🇭🇺"),
        (id: "id", emoji: "🇮🇩"),
        (id: "it", emoji: "🇮🇹"),
        (id: "ja", emoji: "🇯🇵"),
        (id: "kn-IN", emoji: "🇮🇳"),
        (id: "ko", emoji: "🇰🇷"),
        (id: "ml-IN", emoji: "🇮🇳"),
        (id: "mr-IN", emoji: "🇮🇳"),
        (id: "ms", emoji: "🇲🇾"),
        (id: "nl-NL", emoji: "🇳🇱"),
        (id: "no", emoji: "🇳🇴"),
        (id: "or-IN", emoji: "🇮🇳"),
        (id: "pa-IN", emoji: "🇮🇳"),
        (id: "pl", emoji: "🇵🇱"),
        (id: "pt-BR", emoji: "🇧🇷"),
        (id: "pt-PT", emoji: "🇵🇹"),
        (id: "ro", emoji: "🇷🇴"),
        (id: "ru", emoji: "🇷🇺"),
        (id: "sk", emoji: "🇸🇰"),
        (id: "sl-SI", emoji: "🇸🇮"),
        (id: "sv", emoji: "🇸🇪"),
        (id: "ta-IN", emoji: "🇮🇳"),
        (id: "te-IN", emoji: "🇮🇳"),
        (id: "th", emoji: "🇹🇭"),
        (id: "tr", emoji: "🇹🇷"),
        (id: "uk", emoji: "🇺🇦"),
        (id: "ur-PK", emoji: "🇵🇰"),
        (id: "vi", emoji: "🇻🇳"),
        (id: "zh-Hans", emoji: "🇨🇳"),
        (id: "zh-Hant", emoji: "🇨🇳"),
    ]
    .map { AppLocale(id: $0.id, emoji: $0.emoji, name: Self.getDisplayName(forLocale: $0.id)) }
    .sorted(by: { $0.name < $1.name })

    public static func getDisplayName(forLocale localeIdentifier: String) -> String {
        usLocale.localizedString(forIdentifier: localeIdentifier) ?? localeIdentifier
    }

    public static func getDisplayName(forLocale locale: Locale) -> String {
        getDisplayName(forLocale: locale.identifier)
    }

    public static func getDisplayName(forTimeZone timeZone: TimeZone) -> String? {
        timeZone.localizedName(for: .generic, locale: usLocale)
    }

    public static func getStrict(fromId localeId: String) -> AppLocale? {
        let localeId = localeId.lowercased()
        return supportedLocales.first(where: { $0.id.lowercased() == localeId })
    }

    public static func get(fromId localeId: String) -> AppLocale {
        getStrict(fromId: localeId) ?? AppLocale(id: "?", emoji: "🏳", name: "Unknown")
    }

    private static let usLocale = Locale(identifier: "en-US")
}
