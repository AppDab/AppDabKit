import BagbutikTestFlightModels
import Foundation

public struct BetaAppLocalizationSummary: Codable, Equatable, Sendable {
    public let localizationID: String
    public let locale: String
    public let description: String
    public let feedbackEmail: String
    public let marketingURL: String
    public let privacyPolicyURL: String
    public let tvOSPrivacyPolicy: String

    public init(localizationID: String, locale: String, description: String = "", feedbackEmail: String = "",
                marketingURL: String = "", privacyPolicyURL: String = "", tvOSPrivacyPolicy: String = "")
    {
        self.localizationID = localizationID
        self.locale = locale
        self.description = description
        self.feedbackEmail = feedbackEmail
        self.marketingURL = marketingURL
        self.privacyPolicyURL = privacyPolicyURL
        self.tvOSPrivacyPolicy = tvOSPrivacyPolicy
    }

    init(_ localization: BetaAppLocalization) {
        self.init(localizationID: localization.id, locale: localization.attributes?.locale ?? "",
                  description: localization.attributes?.description ?? "",
                  feedbackEmail: localization.attributes?.feedbackEmail ?? "",
                  marketingURL: localization.attributes?.marketingUrl ?? "",
                  privacyPolicyURL: localization.attributes?.privacyPolicyUrl ?? "",
                  tvOSPrivacyPolicy: localization.attributes?.tvOsPrivacyPolicy ?? "")
    }
}

public struct BetaAppLocalizationChanges: Codable, Equatable, Sendable {
    public let description: String
    public let feedbackEmail: String
    public let marketingURL: String
    public let privacyPolicyURL: String
    public let tvOSPrivacyPolicy: String

    public init(description: String, feedbackEmail: String, marketingURL: String, privacyPolicyURL: String, tvOSPrivacyPolicy: String) {
        self.description = description
        self.feedbackEmail = feedbackEmail
        self.marketingURL = marketingURL
        self.privacyPolicyURL = privacyPolicyURL
        self.tvOSPrivacyPolicy = tvOSPrivacyPolicy
    }

    public func isApplied(to localization: BetaAppLocalizationSummary) -> Bool {
        localization.description == description && localization.feedbackEmail == feedbackEmail &&
            localization.marketingURL == marketingURL && localization.privacyPolicyURL == privacyPolicyURL &&
            localization.tvOSPrivacyPolicy == tvOSPrivacyPolicy
    }
}

public struct BetaAppReviewDetailSummary: Codable, Equatable, Sendable {
    public let reviewDetailID: String
    public let contactFirstName: String
    public let contactLastName: String
    public let contactPhone: String
    public let contactEmail: String
    public let demoAccountRequired: Bool
    public let demoAccountName: String
    public let demoAccountPassword: String
    public let notes: String

    public init(reviewDetailID: String, contactFirstName: String = "", contactLastName: String = "", contactPhone: String = "",
                contactEmail: String = "", demoAccountRequired: Bool = false, demoAccountName: String = "",
                demoAccountPassword: String = "", notes: String = "")
    {
        self.reviewDetailID = reviewDetailID
        self.contactFirstName = contactFirstName
        self.contactLastName = contactLastName
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.demoAccountRequired = demoAccountRequired
        self.demoAccountName = demoAccountName
        self.demoAccountPassword = demoAccountPassword
        self.notes = notes
    }

    init(_ detail: BetaAppReviewDetail) {
        self.init(reviewDetailID: detail.id, contactFirstName: detail.attributes?.contactFirstName ?? "",
                  contactLastName: detail.attributes?.contactLastName ?? "", contactPhone: detail.attributes?.contactPhone ?? "",
                  contactEmail: detail.attributes?.contactEmail ?? "", demoAccountRequired: detail.attributes?.demoAccountRequired ?? false,
                  demoAccountName: detail.attributes?.demoAccountName ?? "", demoAccountPassword: detail.attributes?.demoAccountPassword ?? "",
                  notes: detail.attributes?.notes ?? "")
    }
}

public struct BetaAppReviewDetailChanges: Codable, Equatable, Sendable {
    public let contactFirstName: String
    public let contactLastName: String
    public let contactPhone: String
    public let contactEmail: String
    public let demoAccountRequired: Bool
    public let demoAccountName: String
    public let demoAccountPassword: String
    public let notes: String

    public init(contactFirstName: String, contactLastName: String, contactPhone: String, contactEmail: String,
                demoAccountRequired: Bool, demoAccountName: String, demoAccountPassword: String, notes: String)
    {
        self.contactFirstName = contactFirstName
        self.contactLastName = contactLastName
        self.contactPhone = contactPhone
        self.contactEmail = contactEmail
        self.demoAccountRequired = demoAccountRequired
        self.demoAccountName = demoAccountName
        self.demoAccountPassword = demoAccountPassword
        self.notes = notes
    }

    public func isApplied(to detail: BetaAppReviewDetailSummary) -> Bool {
        detail.contactFirstName == contactFirstName && detail.contactLastName == contactLastName && detail.contactPhone == contactPhone &&
            detail.contactEmail == contactEmail && detail.demoAccountRequired == demoAccountRequired && detail.demoAccountName == demoAccountName &&
            detail.demoAccountPassword == demoAccountPassword && detail.notes == notes
    }
}

public struct BetaLicenseAgreementSummary: Codable, Equatable, Sendable {
    public let agreementID: String
    public let agreementText: String

    public init(agreementID: String, agreementText: String) {
        self.agreementID = agreementID
        self.agreementText = agreementText
    }

    init(_ agreement: BetaLicenseAgreement) {
        self.init(agreementID: agreement.id, agreementText: agreement.attributes?.agreementText ?? "")
    }
}
