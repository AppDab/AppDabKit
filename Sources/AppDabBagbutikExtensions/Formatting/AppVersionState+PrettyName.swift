import BagbutikAppStoreModels

public extension AppVersionState {
    var prettyName: String {
        switch self {
        case .accepted: "Accepted"
        case .developerRejected: "Developer Rejected"
        case .inReview: "In Review"
        case .invalidBinary: "Invalid Binary"
        case .metadataRejected: "Metadata Rejected"
        case .pendingAppleRelease: "Pending Apple Release"
        case .pendingDeveloperRelease: "Pending Developer Release"
        case .prepareForSubmission: "Prepare for Submission"
        case .processingForDistribution: "Processing for Distribution"
        case .readyForDistribution: "Ready for Distribution"
        case .readyForReview: "Ready for Review"
        case .rejected: "Rejected"
        case .replacedWithNewVersion: "Replaced with New Version"
        case .waitingForExportCompliance: "Waiting for Export Compliance"
        case .waitingForReview: "Waiting for Review"
        @unknown default: fatalError()
        }
    }
}
