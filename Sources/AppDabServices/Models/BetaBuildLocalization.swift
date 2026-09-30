import BagbutikTestFlightModels
import Foundation

public struct BetaBuildLocalizationSummary: Codable, Equatable, Sendable {
    public let localizationID: String
    public let locale: String
    public let whatsNew: String

    public init(localizationID: String, locale: String, whatsNew: String) {
        self.localizationID = localizationID
        self.locale = locale
        self.whatsNew = whatsNew
    }

    init(_ localization: BetaBuildLocalization) {
        self.init(localizationID: localization.id, locale: localization.attributes?.locale ?? "",
                  whatsNew: localization.attributes?.whatsNew ?? "")
    }
}
