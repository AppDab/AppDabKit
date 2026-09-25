import BagbutikCore
import Foundation

private let missingAgreementErrorCode = "FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED"
private let missingAgreementIssueMessage = "The API key was added, but this App Store Connect account has missing or expired agreements. Some data will not load until the agreements are reviewed in App Store Connect."
let invalidAPIKeyMessage = "The entered keys are invalid. Check that they match the keys on App Store Connect."

enum APIKeyVerificationErrorResolution { case agreementIssue(AccountVerificationIssue); case invalidCredentials; case other(ServiceError) }

func mapAPIKeyVerificationError(_ error: Error) throws -> APIKeyVerificationErrorResolution {
    if let issue = agreementIssue(from: error) { return .agreementIssue(issue) }
    if isUnauthorized(error) || appStoreConnectErrors(in: error).contains(where: { $0.code == "NOT_AUTHORIZED" }) { return .invalidCredentials }
    return .other(try ServiceError.classify(error))
}

private func agreementIssue(from error: Error) -> AccountVerificationIssue? {
    guard let serviceError = error as? BagbutikCore.ServiceError, let agreementError = serviceError.errorResponse?.errors?.first(where: { $0.code == missingAgreementErrorCode }) else { return nil }
    return .init(message: missingAgreementIssueMessage, resolutionURL: agreementError.links?.see.flatMap(resolveAppStoreConnectURL))
}

private func resolveAppStoreConnectURL(_ pathOrURL: String) -> URL? {
    if let url = URL(string: pathOrURL), url.scheme != nil { return url }
    return URL(string: pathOrURL, relativeTo: URL(string: "https://appstoreconnect.apple.com")!)?.absoluteURL
}

private func appStoreConnectErrors(in error: Error) -> [ErrorResponse.Errors] { (error as? BagbutikCore.ServiceError)?.errorResponse?.errors ?? [] }

private func isUnauthorized(_ error: Error) -> Bool {
    guard let serviceError = error as? BagbutikCore.ServiceError else { return false }
    if case .unauthorized = serviceError { return true }
    return false
}
