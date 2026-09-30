import Foundation

public protocol BetaAppTestingServing: Sendable {
    func listLocalizations(accountID: String, appID: String) async throws -> [BetaAppLocalizationSummary]
    func getLocalization(accountID: String, localizationID: String) async throws -> BetaAppLocalizationSummary
    func createLocalization(accountID: String, appID: String, locale: String) async throws -> BetaAppLocalizationSummary
    func updateLocalization(accountID: String, localizationID: String, changes: BetaAppLocalizationChanges) async throws -> BetaAppLocalizationSummary
    func deleteLocalization(accountID: String, localizationID: String) async throws
    func getReviewDetail(accountID: String, appID: String) async throws -> BetaAppReviewDetailSummary
    func updateReviewDetail(accountID: String, appID: String, changes: BetaAppReviewDetailChanges) async throws -> BetaAppReviewDetailSummary
    func getLicenseAgreement(accountID: String, appID: String) async throws -> BetaLicenseAgreementSummary
    func updateLicenseAgreement(accountID: String, agreementID: String, agreementText: String) async throws -> BetaLicenseAgreementSummary
}
