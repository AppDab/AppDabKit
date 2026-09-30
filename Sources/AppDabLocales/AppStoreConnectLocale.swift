import Foundation

/// A locale supported by the localized fields in App Store Connect schemas.
///
/// `supportedLocales` lists the locale identifiers accepted for those fields.
/// This is a curated App Store Connect list, not the full set of locales known
/// to Foundation. Display names are localized in US English.
public struct AppStoreConnectLocale: Hashable, Identifiable, Sendable {
    /// The locale identifier used by App Store Connect, such as `en-US`.
    public let id: String

    /// A flag associated with the locale for compact display.
    public let emoji: String

    /// The locale name displayed in US English.
    public let name: String

    /// The locale identifiers supported by localized App Store Connect schema fields.
    public static let supportedLocales: [AppStoreConnectLocale] = [
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
    .map { AppStoreConnectLocale(id: $0.id, emoji: $0.emoji, name: Self.getDisplayName(forLocale: $0.id)) }
    .sorted(by: { $0.name < $1.name })

    /// Returns the locale's display name in US English, or the identifier if it is unknown to Foundation.
    public static func getDisplayName(forLocale localeIdentifier: String) -> String {
        usLocale.localizedString(forIdentifier: localeIdentifier) ?? localeIdentifier
    }

    /// Returns the given locale's display name in US English.
    public static func getDisplayName(forLocale locale: Locale) -> String {
        getDisplayName(forLocale: locale.identifier)
    }

    /// Returns the time zone's generic display name in US English, when available.
    public static func getDisplayName(forTimeZone timeZone: TimeZone) -> String? {
        timeZone.localizedName(for: .generic, locale: usLocale)
    }

    /// Finds a supported locale by identifier, ignoring identifier letter case.
    public static func getStrict(fromId localeId: String) -> AppStoreConnectLocale? {
        let localeId = localeId.lowercased()
        return supportedLocales.first(where: { $0.id.lowercased() == localeId })
    }

    /// Finds a supported locale, returning an `Unknown` placeholder when the identifier is unsupported.
    public static func get(fromId localeId: String) -> AppStoreConnectLocale {
        getStrict(fromId: localeId) ?? AppStoreConnectLocale(id: "?", emoji: "🏳", name: "Unknown")
    }

    private static let usLocale = Locale(identifier: "en-US")
}
