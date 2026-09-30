import BagbutikCore
import BagbutikTestFlight
import BagbutikTestFlightModels
import ConnectAccounts

public final class BetaAppTestingService: BetaAppTestingServing, @unchecked Sendable {
    private let accountProvider: any APIKeyProviding

    public init(accountProvider: any APIKeyProviding) {
        self.accountProvider = accountProvider
    }

    public func listLocalizations(accountID: String, appID: String) async throws -> [BetaAppLocalizationSummary] {
        guard !appID.isEmpty else { throw ServiceError.invalidArguments("Argument appID must be nonempty.") }
        let service = try await service(accountID: accountID)
        do {
            var results: [BetaAppLocalizationSummary] = []
            var cursor: String?
            var seen = Set<String>()
            repeat {
                let request: Request<BetaAppLocalizationsWithoutIncludesResponse, ErrorResponse> = .listBetaAppLocalizationsForAppV1(
                    id: appID, limit: PaginationRequest.maximumLimit,
                )
                let response = try await service.request(request.withPaginationCursor(cursor))
                results += response.data.map(BetaAppLocalizationSummary.init)
                cursor = try PaginationCursor.extract(from: response.links.next)
                if let cursor, !seen.insert(cursor).inserted {
                    throw ServiceError.upstream("App Store Connect returned a repeated beta localization cursor.")
                }
            } while cursor != nil
            return results
        } catch { throw try ServiceError.classify(error) }
    }

    public func getLocalization(accountID: String, localizationID: String) async throws -> BetaAppLocalizationSummary {
        let service = try await service(accountID: accountID)
        do { return try await .init(service.request(.getBetaAppLocalizationV1(id: localizationID)).data) }
        catch { throw try ServiceError.classify(error) }
    }

    public func createLocalization(accountID: String, appID: String, locale: String) async throws -> BetaAppLocalizationSummary {
        guard !appID.isEmpty, !locale.isEmpty else { throw ServiceError.invalidArguments("App and locale must be nonempty.") }
        let service = try await service(accountID: accountID)
        do {
            let response = try await service.request(.createBetaAppLocalizationV1(requestBody: .init(data: .init(
                attributes: .init(locale: locale), relationships: .init(app: .init(data: .init(id: appID))),
            ))))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func updateLocalization(accountID: String, localizationID: String, changes: BetaAppLocalizationChanges) async throws -> BetaAppLocalizationSummary {
        let service = try await service(accountID: accountID)
        do {
            let response = try await service.request(.updateBetaAppLocalizationV1(
                id: localizationID,
                requestBody: .init(data: .init(id: localizationID, attributes: .init(
                    description: changes.description, feedbackEmail: changes.feedbackEmail,
                    marketingUrl: changes.marketingURL, privacyPolicyUrl: changes.privacyPolicyURL,
                    tvOsPrivacyPolicy: changes.tvOSPrivacyPolicy,
                ))),
            ))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func deleteLocalization(accountID: String, localizationID: String) async throws {
        let service = try await service(accountID: accountID)
        do { try await service.request(.deleteBetaAppLocalizationV1(id: localizationID)) }
        catch { throw try ServiceError.classify(error) }
    }

    public func getReviewDetail(accountID: String, appID: String) async throws -> BetaAppReviewDetailSummary {
        let service = try await service(accountID: accountID)
        do { return try await .init(service.request(.getBetaAppReviewDetailForAppV1(id: appID)).data) }
        catch { throw try ServiceError.classify(error) }
    }

    public func updateReviewDetail(accountID: String, appID: String, changes: BetaAppReviewDetailChanges) async throws -> BetaAppReviewDetailSummary {
        let service = try await service(accountID: accountID)
        do {
            let current = try await service.request(.getBetaAppReviewDetailForAppV1(id: appID))
            let detailID = current.data.id
            let response = try await service.request(.updateBetaAppReviewDetailV1(
                id: detailID,
                requestBody: .init(data: .init(id: detailID, attributes: .init(
                    contactEmail: changes.contactEmail, contactFirstName: changes.contactFirstName,
                    contactLastName: changes.contactLastName, contactPhone: changes.contactPhone,
                    demoAccountName: changes.demoAccountName, demoAccountPassword: changes.demoAccountPassword,
                    demoAccountRequired: changes.demoAccountRequired, notes: changes.notes,
                ))),
            ))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    public func getLicenseAgreement(accountID: String, appID: String) async throws -> BetaLicenseAgreementSummary {
        let service = try await service(accountID: accountID)
        do { return try await .init(service.request(.getBetaLicenseAgreementForAppV1(id: appID)).data) }
        catch { throw try ServiceError.classify(error) }
    }

    public func updateLicenseAgreement(accountID: String, agreementID: String, agreementText: String) async throws -> BetaLicenseAgreementSummary {
        let service = try await service(accountID: accountID)
        do {
            let response = try await service.request(.updateBetaLicenseAgreementV1(
                id: agreementID,
                requestBody: .init(data: .init(id: agreementID, attributes: .init(agreementText: agreementText))),
            ))
            return .init(response.data)
        } catch { throw try ServiceError.classify(error) }
    }

    private func service(accountID: String) async throws -> BagbutikService {
        let key = try await accountProvider.apiKey(forAccountID: accountID)
        return BagbutikService(jwt: key.jwt)
    }
}
