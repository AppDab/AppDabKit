@testable import AppDabAutomation
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

struct BetaAppReviewDetailActionTests {
    @Test func readAndUpdateExposeDemoAccountPassword() async throws {
        for actionID in [AutomationActionID.getBetaAppReviewDetail, .updateBetaAppReviewDetail] {
            let reviewDetail = AutomationActionCatalog.descriptor(for: actionID)?.outputSchema.objectValue?["properties"]?.objectValue?["reviewDetail"]?.objectValue
            #expect(reviewDetail?["properties"]?.objectValue?["demoAccountPassword"]?.objectValue?["type"] == .string("string"))
            #expect(reviewDetail?["required"]?.arrayValue?.contains(.string("demoAccountPassword")) == true)
        }

        let provider = MockAutomationDataProvider()
        let read = try await GetBetaAppReviewDetailAction().perform(
            input: GetAppInput(accountID: "account-1", appID: "app-1"), dataProvider: provider,
        )
        #expect(read.objectValue?["reviewDetail"]?.objectValue?["demoAccountPassword"] == .string("current-password"))

        let changes = BetaAppReviewDetailChanges(
            contactFirstName: "", contactLastName: "", contactPhone: "", contactEmail: "",
            demoAccountRequired: true, demoAccountName: "demo", demoAccountPassword: "updated-password", notes: "",
        )
        let input = BetaAppTestingInput(accountID: "account-1", appID: "app-1", reviewDetailChanges: changes)
        let action = UpdateBetaAppReviewDetailAction()
        let preparation = try await action.prepareMutation(input: input, dataProvider: provider)
        let plan = AutomationMutationPlan(
            planID: "plan-1", actionID: .updateBetaAppReviewDetail, targetIdentifiers: preparation.targetIdentifiers,
            redactedSummary: preparation.redactedSummary, canonicalInputHash: "hash", confirmationFingerprint: "fingerprint",
            remotePreconditions: preparation.remotePreconditions, createdAt: .now, expiresAt: .now,
        )
        let updated = try await action.commitMutation(input: input, plan: plan, dataProvider: provider)
        #expect(updated.objectValue?["reviewDetail"]?.objectValue?["demoAccountPassword"] == .string("updated-password"))
    }
}
