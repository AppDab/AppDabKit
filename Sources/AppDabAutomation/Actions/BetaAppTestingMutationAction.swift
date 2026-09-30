import AppDabServices
import Foundation

public enum BetaAppTestingMutationKind: Sendable {
    case createLocalization
    case updateLocalization
    case deleteLocalization
    case updateReviewDetail
    case updateLicenseAgreement
}

public protocol BetaAppTestingMutationSpec: Sendable {
    static var id: AutomationActionID { get }
    static var title: String { get }
    static var kind: BetaAppTestingMutationKind { get }
}

public struct BetaAppTestingMutationAction<Spec: BetaAppTestingMutationSpec>: ReplayableGuardedAutomationAction {
    public static var descriptor: AutomationActionDescriptor {
        .init(id: Spec.id, title: Spec.title, description: Spec.title + " for TestFlight beta testing.",
              inputSchema: inputSchema, outputSchema: outputSchema, outputType: "betaAppTesting", safety: .write)
    }

    private static var inputSchema: JSONValue {
        var properties: [String: JSONValue] = ["accountID": Schema.string(description: "The AppDab account identifier.")]
        var required = ["accountID"]
        switch Spec.kind {
        case .createLocalization:
            properties["appID"] = Schema.string(description: "The App Store Connect app identifier.")
            properties["locale"] = Schema.string(description: "The locale identifier, such as en-US.")
            required += ["appID", "locale"]
        case .updateLocalization:
            properties.merge(localizationProperties) { _, new in new }
            required += ["appID", "localizationID", "description", "feedbackEmail", "marketingURL", "privacyPolicyURL", "tvOSPrivacyPolicy"]
        case .deleteLocalization:
            properties["appID"] = Schema.string(description: "The App Store Connect app identifier.")
            properties["localizationID"] = Schema.string(description: "The beta app localization identifier.")
            required += ["appID", "localizationID"]
        case .updateReviewDetail:
            properties.merge(reviewProperties) { _, new in new }
            required += ["appID", "contactFirstName", "contactLastName", "contactPhone", "contactEmail", "demoAccountRequired", "demoAccountName", "demoAccountPassword", "notes"]
        case .updateLicenseAgreement:
            properties["appID"] = Schema.string(description: "The App Store Connect app identifier.")
            properties["agreementText"] = Schema.string(description: "The beta license agreement text.")
            required += ["appID", "agreementText"]
        }
        return Schema.object(properties: properties, required: required)
    }

    private static var outputSchema: JSONValue {
        let field: String
        let model: JSONValue
        switch Spec.kind {
        case .createLocalization, .updateLocalization, .deleteLocalization:
            field = "localization"
            model = Schema.betaAppLocalizationOutput
        case .updateReviewDetail:
            field = "reviewDetail"
            model = Schema.betaAppReviewDetailOutput
        case .updateLicenseAgreement:
            field = "licenseAgreement"
            model = Schema.betaLicenseAgreementOutput
        }
        return Schema.object(properties: [field: model], required: [field])
    }

    private static var localizationProperties: [String: JSONValue] {
        [
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "localizationID": Schema.string(description: "The beta app localization identifier."),
            "description": Schema.string(description: "The beta testing description, up to 4000 characters."),
            "feedbackEmail": Schema.string(description: "The email address for tester feedback."),
            "marketingURL": Schema.string(description: "The marketing URL."),
            "privacyPolicyURL": Schema.string(description: "The privacy policy URL."),
            "tvOSPrivacyPolicy": Schema.string(description: "The Apple TV privacy policy text, up to 6000 characters."),
        ]
    }

    private static var reviewProperties: [String: JSONValue] {
        [
            "appID": Schema.string(description: "The App Store Connect app identifier."),
            "contactFirstName": Schema.string(description: "The beta review contact first name."),
            "contactLastName": Schema.string(description: "The beta review contact last name."),
            "contactPhone": Schema.string(description: "The beta review contact phone number."),
            "contactEmail": Schema.string(description: "The beta review contact email."),
            "demoAccountRequired": Schema.outputBoolean,
            "demoAccountName": Schema.string(description: "The demo account name."),
            "demoAccountPassword": Schema.string(description: "The demo account password."),
            "notes": Schema.string(description: "Notes for beta app review."),
        ]
    }

    public init() {}

    public func perform(input _: BetaAppTestingInput, dataProvider _: any AutomationDataProviding) async throws -> JSONValue {
        throw AutomationExecutionError.unsupportedExecutionMode(action: Spec.id.rawValue, mode: .execute)
    }

    public func prepareMutation(input: BetaAppTestingInput, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationPreparation {
        try validate(input)
        let preconditions = try await preconditions(for: input, dataProvider: dataProvider)
        let target = input.localizationID ?? input.appID ?? ""
        return .init(targetIdentifiers: [input.accountID, target], redactedSummary: summary,
                     remotePreconditions: preconditions)
    }

    public func validateMutation(input: BetaAppTestingInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws {
        try validate(input)
        let current = try await preconditions(for: input, dataProvider: dataProvider)
        guard current == plan.remotePreconditions else {
            throw AutomationExecutionError.preconditionFailed("Beta testing information changed after preview.")
        }
    }

    public func commitMutation(input: BetaAppTestingInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> JSONValue {
        switch Spec.kind {
        case .createLocalization:
            let localization = try await dataProvider.createBetaAppLocalization(accountID: input.accountID, appID: input.appID!, locale: input.locale!)
            return try localizationData(localization)
        case .updateLocalization:
            let localization = try await dataProvider.updateBetaAppLocalization(accountID: input.accountID, localizationID: input.localizationID!, changes: input.localizationChanges!)
            return try localizationData(localization)
        case .deleteLocalization:
            let current = try decodeLocalization(plan)
            try await dataProvider.deleteBetaAppLocalization(accountID: input.accountID, localizationID: input.localizationID!)
            return try localizationData(current)
        case .updateReviewDetail:
            let detail = try await dataProvider.updateBetaAppReviewDetail(accountID: input.accountID, appID: input.appID!, changes: input.reviewDetailChanges!)
            return try reviewDetailData(detail)
        case .updateLicenseAgreement:
            let before = try decodeLicenseAgreement(plan)
            let agreement = try await dataProvider.updateBetaLicenseAgreement(accountID: input.accountID, agreementID: before.agreementID, agreementText: input.agreementText!)
            return try licenseAgreementData(agreement)
        }
    }

    public func reconcileMutation(input: BetaAppTestingInput, plan: AutomationMutationPlan, dataProvider: any AutomationDataProviding) async throws -> AutomationMutationReconciliation<JSONValue> {
        switch Spec.kind {
        case .createLocalization:
            let matches = try await dataProvider.listBetaAppLocalizations(accountID: input.accountID, appID: input.appID!).filter { $0.locale == input.locale }
            if matches.count == 1 {
                return try .succeeded(localizationData(matches[0]))
            }
            return matches.isEmpty ? .notApplied : .unresolved
        case .updateLocalization:
            let current = try await dataProvider.getBetaAppLocalization(accountID: input.accountID, localizationID: input.localizationID!)
            if input.localizationChanges!.isApplied(to: current) {
                return try .succeeded(localizationData(current))
            }
            return try JSONValue.fromEncodable(current) == plan.remotePreconditions["localization"] ? .notApplied : .unresolved
        case .deleteLocalization:
            let matches = try await dataProvider.listBetaAppLocalizations(accountID: input.accountID, appID: input.appID!)
            if !matches.contains(where: { $0.localizationID == input.localizationID }) {
                return try .succeeded(localizationData(decodeLocalization(plan)))
            }
            let current = matches.first(where: { $0.localizationID == input.localizationID })!
            return try JSONValue.fromEncodable(current) == plan.remotePreconditions["localization"] ? .notApplied : .unresolved
        case .updateReviewDetail:
            let current = try await dataProvider.getBetaAppReviewDetail(accountID: input.accountID, appID: input.appID!)
            if input.reviewDetailChanges!.isApplied(to: current) {
                return try .succeeded(reviewDetailData(current))
            }
            return try await preconditions(for: input, dataProvider: dataProvider) == plan.remotePreconditions ? .notApplied : .unresolved
        case .updateLicenseAgreement:
            let current = try await dataProvider.getBetaLicenseAgreement(accountID: input.accountID, appID: input.appID!)
            if current.agreementText == input.agreementText {
                return try .succeeded(licenseAgreementData(current))
            }
            return try await preconditions(for: input, dataProvider: dataProvider) == plan.remotePreconditions ? .notApplied : .unresolved
        }
    }

    public func summary(for _: JSONValue) -> String {
        summary
    }

    public func data(for output: JSONValue) throws -> JSONValue {
        output
    }

    public func redactedReplayData(for output: JSONValue) throws -> JSONValue {
        output
    }

    public func output(fromReplayData data: JSONValue) throws -> JSONValue {
        data
    }

    private var summary: String {
        switch Spec.kind {
        case .createLocalization: "Create beta app localization."
        case .updateLocalization: "Update beta app localization."
        case .deleteLocalization: "Delete beta app localization."
        case .updateReviewDetail: "Update beta app review details."
        case .updateLicenseAgreement: "Update beta license agreement."
        }
    }

    private func validate(_ input: BetaAppTestingInput) throws {
        guard !input.accountID.isEmpty else { throw AutomationActionError.invalidArguments("Argument accountID must be nonempty.") }
        switch Spec.kind {
        case .createLocalization:
            guard let appID = input.appID, !appID.isEmpty, let locale = input.locale, !locale.isEmpty else { throw AutomationActionError.invalidArguments("App and locale are required.") }
        case .updateLocalization:
            guard let appID = input.appID, !appID.isEmpty, let id = input.localizationID, !id.isEmpty, let changes = input.localizationChanges else { throw AutomationActionError.invalidArguments("App, localization, and all localization fields are required.") }
            guard changes.description.count <= 4000, changes.tvOSPrivacyPolicy.count <= 6000 else { throw AutomationActionError.invalidArguments("Beta localization text exceeds its character limit.") }
        case .deleteLocalization:
            guard let appID = input.appID, !appID.isEmpty, let id = input.localizationID, !id.isEmpty else { throw AutomationActionError.invalidArguments("App and localization identifiers are required.") }
        case .updateReviewDetail:
            guard let appID = input.appID, !appID.isEmpty, input.reviewDetailChanges != nil else { throw AutomationActionError.invalidArguments("App and review details are required.") }
        case .updateLicenseAgreement:
            guard let appID = input.appID, !appID.isEmpty, input.agreementText != nil else { throw AutomationActionError.invalidArguments("App and agreementText are required.") }
        }
    }

    private func preconditions(for input: BetaAppTestingInput, dataProvider: any AutomationDataProviding) async throws -> [String: JSONValue] {
        switch Spec.kind {
        case .createLocalization:
            let localizations = try await dataProvider.listBetaAppLocalizations(accountID: input.accountID, appID: input.appID!)
            guard !localizations.contains(where: { $0.locale.caseInsensitiveCompare(input.locale!) == .orderedSame }) else {
                throw AutomationActionError.invalidArguments("A beta app localization already exists for \(input.locale!).")
            }
            return ["localeAbsent": .bool(true)]
        case .updateLocalization, .deleteLocalization:
            let localizations = try await dataProvider.listBetaAppLocalizations(accountID: input.accountID, appID: input.appID!)
            guard let localization = localizations.first(where: { $0.localizationID == input.localizationID }) else {
                throw AutomationActionError.invalidArguments("The beta app localization does not belong to the selected app.")
            }
            if case .deleteLocalization = Spec.kind, localizations.count <= 1 {
                throw AutomationActionError.invalidArguments("An app must keep at least one beta app localization.")
            }
            return try ["localization": .fromEncodable(localization)]
        case .updateReviewDetail:
            let detail = try await dataProvider.getBetaAppReviewDetail(accountID: input.accountID, appID: input.appID!)
            return try ["reviewDetail": .fromEncodable(ReviewDetailPrecondition(detail))]
        case .updateLicenseAgreement:
            let agreement = try await dataProvider.getBetaLicenseAgreement(accountID: input.accountID, appID: input.appID!)
            return try ["licenseAgreement": .fromEncodable(agreement)]
        }
    }

    private struct ReviewDetailPrecondition: Codable, Equatable {
        let detail: BetaAppReviewDetailSummary

        init(_ detail: BetaAppReviewDetailSummary) {
            self.detail = .init(reviewDetailID: detail.reviewDetailID, contactFirstName: detail.contactFirstName,
                                contactLastName: detail.contactLastName, contactPhone: detail.contactPhone,
                                contactEmail: detail.contactEmail, demoAccountRequired: detail.demoAccountRequired,
                                demoAccountName: detail.demoAccountName, demoAccountPassword: "", notes: detail.notes)
        }
    }

    private func localizationData(_ localization: BetaAppLocalizationSummary) throws -> JSONValue {
        try .object(["localization": .fromEncodable(localization)])
    }

    private func reviewDetailData(_ detail: BetaAppReviewDetailSummary) throws -> JSONValue {
        try .object(["reviewDetail": .fromEncodable(detail)])
    }

    private func licenseAgreementData(_ agreement: BetaLicenseAgreementSummary) throws -> JSONValue {
        try .object(["licenseAgreement": .fromEncodable(agreement)])
    }

    private func decodeLocalization(_ plan: AutomationMutationPlan) throws -> BetaAppLocalizationSummary {
        guard let raw = plan.remotePreconditions["localization"] else { throw AutomationExecutionError.preconditionFailed("Localization preview data is missing.") }
        return try JSONDecoder().decode(BetaAppLocalizationSummary.self, from: JSONEncoder().encode(raw))
    }

    private func decodeLicenseAgreement(_ plan: AutomationMutationPlan) throws -> BetaLicenseAgreementSummary {
        guard let raw = plan.remotePreconditions["licenseAgreement"] else { throw AutomationExecutionError.preconditionFailed("License agreement preview data is missing.") }
        return try JSONDecoder().decode(BetaLicenseAgreementSummary.self, from: JSONEncoder().encode(raw))
    }
}

public enum CreateBetaAppLocalizationSpec: BetaAppTestingMutationSpec {
    public static let id: AutomationActionID = .createBetaAppLocalization
    public static let title = "Create Beta App Localization"
    public static let kind = BetaAppTestingMutationKind.createLocalization
}

public enum UpdateBetaAppLocalizationSpec: BetaAppTestingMutationSpec {
    public static let id: AutomationActionID = .updateBetaAppLocalization
    public static let title = "Update Beta App Localization"
    public static let kind = BetaAppTestingMutationKind.updateLocalization
}

public enum DeleteBetaAppLocalizationSpec: BetaAppTestingMutationSpec {
    public static let id: AutomationActionID = .deleteBetaAppLocalization
    public static let title = "Delete Beta App Localization"
    public static let kind = BetaAppTestingMutationKind.deleteLocalization
}

public enum UpdateBetaAppReviewDetailSpec: BetaAppTestingMutationSpec {
    public static let id: AutomationActionID = .updateBetaAppReviewDetail
    public static let title = "Update Beta App Review Detail"
    public static let kind = BetaAppTestingMutationKind.updateReviewDetail
}

public enum UpdateBetaLicenseAgreementSpec: BetaAppTestingMutationSpec {
    public static let id: AutomationActionID = .updateBetaLicenseAgreement
    public static let title = "Update Beta License Agreement"
    public static let kind = BetaAppTestingMutationKind.updateLicenseAgreement
}

public typealias CreateBetaAppLocalizationAction = BetaAppTestingMutationAction<CreateBetaAppLocalizationSpec>
public typealias UpdateBetaAppLocalizationAction = BetaAppTestingMutationAction<UpdateBetaAppLocalizationSpec>
public typealias DeleteBetaAppLocalizationAction = BetaAppTestingMutationAction<DeleteBetaAppLocalizationSpec>
public typealias UpdateBetaAppReviewDetailAction = BetaAppTestingMutationAction<UpdateBetaAppReviewDetailSpec>
public typealias UpdateBetaLicenseAgreementAction = BetaAppTestingMutationAction<UpdateBetaLicenseAgreementSpec>
