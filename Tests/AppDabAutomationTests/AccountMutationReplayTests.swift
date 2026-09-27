import AppDabAutomation
import AppDabServices
import Foundation
import Testing

struct AccountMutationReplayTests {
    @Test func accountReceiptsRestoreTheVisibleResult() throws {
        let account = AccountSummary(accountID: "KEY123", name: "Example Team")
        let addition = AccountAddition(
            account: account,
            issue: .init(
                message: "Accept the latest agreement.",
                resolutionURL: URL(string: "https://example.com/agreement")
            )
        )
        let addAction = AddAccountAction()
        let removeAction = RemoveAccountAction()

        let added = try addAction.output(fromReplayData: addAction.redactedReplayData(for: addition))
        let removed = try removeAction.output(fromReplayData: removeAction.redactedReplayData(for: account))

        #expect(added == addition)
        #expect(removed == account)
    }
}
