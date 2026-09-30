public struct BuildTestFlightSnapshot: Codable, Equatable, Sendable {
    public let build: BuildSummary
    public let individualTesterIDs: [String]
    public let betaGroupIDs: [String]
    public let betaReviewSubmissionID: String?
    public let externalBetaState: String?
    public let autoNotifyEnabled: Bool?

    public init(
        build: BuildSummary,
        individualTesterIDs: [String],
        betaGroupIDs: [String],
        betaReviewSubmissionID: String?,
        externalBetaState: String?,
        autoNotifyEnabled: Bool?,
    ) {
        self.build = build
        self.individualTesterIDs = individualTesterIDs.sorted()
        self.betaGroupIDs = betaGroupIDs.sorted()
        self.betaReviewSubmissionID = betaReviewSubmissionID
        self.externalBetaState = externalBetaState
        self.autoNotifyEnabled = autoNotifyEnabled
    }
}
