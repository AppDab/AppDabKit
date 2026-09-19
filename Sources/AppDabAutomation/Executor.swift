import AppDabServices
import CryptoKit
import Foundation

public final class Executor: Sendable {
    private let dataProvider: any AutomationDataProviding
    private let registry: AutomationRegistry
    private let auditStore: any AutomationAuditStoring
    private let now: @Sendable () -> Date
    private let makePlanID: @Sendable () -> String
    private let previewLifetime: TimeInterval
    private let pendingLeaseDuration: TimeInterval

    public init(
        dataProvider: any AutomationDataProviding,
        registry: AutomationRegistry = .standard,
        auditStore: any AutomationAuditStoring = AutomationSQLiteAuditStore(),
        previewLifetime: TimeInterval = 10 * 60,
        pendingLeaseDuration: TimeInterval = 10 * 60,
        now: @escaping @Sendable () -> Date = Date.init,
        makePlanID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.dataProvider = dataProvider
        self.registry = registry
        self.auditStore = auditStore
        self.previewLifetime = previewLifetime
        self.pendingLeaseDuration = pendingLeaseDuration
        self.now = now
        self.makePlanID = makePlanID
    }

    public func execute(_ request: AutomationRequest) async throws -> AutomationResponse {
        do {
            let action = try registry.action(for: request.actionID, surface: request.surface)
            switch action.descriptor.safety {
            case .read, .draft:
                guard request.executionContext.mode == .execute else {
                    throw AutomationExecutionError.unsupportedExecutionMode(
                        action: request.actionID.rawValue,
                        mode: request.executionContext.mode
                    )
                }
                return try await action.execute(
                    arguments: request.arguments,
                    dataProvider: dataProvider
                )
            case .write:
                switch request.executionContext.mode {
                case .execute, .preview:
                    return try await preview(action: action, request: request)
                case .commit:
                    return try await commit(action: action, request: request)
                case .reconcile:
                    return try await reconcile(action: action, request: request)
                }
            }
        } catch {
            throw normalizedError(error)
        }
    }

    public func execute<Action: AutomationAction>(
        _ actionType: Action.Type,
        input: Action.Input,
        surface: AutomationSurface
    ) async throws -> Action.Output {
        do {
            let registeredAction = try registry.action(for: actionType.descriptor.id, surface: surface)
            guard registeredAction.isRegistered(actionType) else {
                throw AutomationActionError.invalidArguments(
                    "The registered action for \(actionType.descriptor.id.rawValue) does not match the requested implementation."
                )
            }
            guard actionType.descriptor.safety != .write else {
                throw AutomationExecutionError.unsupportedExecutionMode(
                    action: actionType.descriptor.id.rawValue,
                    mode: .execute
                )
            }
            try input.validate()
            return try await actionType.init().perform(input: input, dataProvider: dataProvider)
        } catch {
            throw normalizedError(error)
        }
    }

    public func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        do {
            return try await dataProvider.getCustomerReview(accountID: accountID, reviewID: reviewID)
        } catch {
            throw normalizedError(error)
        }
    }

    private func normalizedError(_ error: Error) -> any Error {
        if let automationError = error as? AutomationActionError {
            return automationError
        }
        if let executionError = error as? AutomationExecutionError {
            return executionError
        }
        if let serviceError = error as? ServiceError {
            return AutomationActionError.from(serviceError: serviceError)
        }
        return AutomationActionError.upstream(error.localizedDescription)
    }

    private func preview(
        action: AnyAutomationAction,
        request: AutomationRequest
    ) async throws -> AutomationResponse {
        let preparation = try await action.prepareMutation(
            arguments: request.arguments,
            dataProvider: dataProvider
        )
        let createdAt = now()
        let inputHash = try hash(.object(request.arguments))
        let planID = makePlanID()
        let expiresAt = createdAt.addingTimeInterval(previewLifetime)
        let fingerprint = try fingerprint(
            planID: planID,
            actionID: request.actionID,
            preparation: preparation,
            inputHash: inputHash,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
        let plan = AutomationMutationPlan(
            planID: planID,
            actionID: request.actionID,
            targetIdentifiers: preparation.targetIdentifiers,
            redactedSummary: preparation.redactedSummary,
            canonicalInputHash: inputHash,
            confirmationFingerprint: fingerprint,
            remotePreconditions: preparation.remotePreconditions,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
        try await auditStore.savePreview(plan)
        return .init(
            actionID: request.actionID,
            summary: preparation.redactedSummary,
            data: .object([:]),
            plan: plan
        )
    }

    private func commit(
        action: AnyAutomationAction,
        request: AutomationRequest
    ) async throws -> AutomationResponse {
        let confirmation = try confirmation(from: request.executionContext)

        if let existing = try await auditStore.auditRecord(idempotencyKey: confirmation.key) {
            guard existing.confirmationFingerprint == confirmation.fingerprint else {
                throw AutomationExecutionError.idempotencyCollision
            }
            switch existing.status {
            case .succeeded:
                guard let receipt = existing.receipt else {
                    throw AutomationExecutionError.persistence(
                        "A successful audit record is missing its receipt."
                    )
                }
                return try replayResponse(receipt, request: request)
            case .pending, .indeterminate:
                throw AutomationExecutionError.commitBlocked(existing.status)
            }
        }

        let plan = try await validatedPlan(
            actionID: request.actionID,
            arguments: request.arguments,
            confirmationFingerprint: confirmation.fingerprint,
            requireUnexpired: true
        )
        try await action.validateMutation(
            arguments: request.arguments,
            plan: plan,
            dataProvider: dataProvider
        )

        let claimID: String
        switch try await auditStore.beginCommit(
            actionID: request.actionID,
            confirmationFingerprint: confirmation.fingerprint,
            idempotencyKey: confirmation.key,
            now: now()
        ) {
        case .replay(let receipt):
            return try replayResponse(receipt, request: request)
        case .execute(let commitClaimID):
            claimID = commitClaimID
        }

        do {
            let committed = try await action.commitMutation(
                arguments: request.arguments,
                plan: plan,
                dataProvider: dataProvider
            )
            let receipt = AutomationMutationReceipt(
                actionID: committed.response.actionID,
                confirmationFingerprint: confirmation.fingerprint,
                idempotencyKey: confirmation.key,
                canonicalInputHash: plan.canonicalInputHash,
                redactedSummary: committed.response.summary,
                redactedReplayData: committed.redactedReplayData,
                committedAt: now()
            )
            try await auditStore.completeCommit(receipt, claimID: claimID)
            return .init(
                actionID: committed.response.actionID,
                summary: committed.response.summary,
                data: committed.response.data,
                receipt: receipt
            )
        } catch {
            try? await auditStore.markIndeterminate(
                actionID: request.actionID,
                confirmationFingerprint: confirmation.fingerprint,
                idempotencyKey: confirmation.key,
                claimID: claimID
            )
            throw AutomationExecutionError.indeterminate
        }
    }

    private func reconcile(
        action: AnyAutomationAction,
        request: AutomationRequest
    ) async throws -> AutomationResponse {
        let confirmation = try confirmation(from: request.executionContext)
        let claimID: String
        switch try await auditStore.beginReconciliation(
            confirmationFingerprint: confirmation.fingerprint,
            idempotencyKey: confirmation.key,
            now: now(),
            pendingLeaseDuration: pendingLeaseDuration
        ) {
        case .replay(let receipt):
            return try replayResponse(receipt, request: request)
        case .reconcile(let reconciliationClaimID):
            claimID = reconciliationClaimID
        }

        do {
            let plan = try await validatedPlan(
                actionID: request.actionID,
                arguments: request.arguments,
                confirmationFingerprint: confirmation.fingerprint,
                requireUnexpired: false
            )
            switch try await action.reconcileMutation(
                arguments: request.arguments,
                plan: plan,
                dataProvider: dataProvider
            ) {
            case .succeeded(let committed):
                let receipt = AutomationMutationReceipt(
                    actionID: committed.response.actionID,
                    confirmationFingerprint: confirmation.fingerprint,
                    idempotencyKey: confirmation.key,
                    canonicalInputHash: plan.canonicalInputHash,
                    redactedSummary: committed.response.summary,
                    redactedReplayData: committed.redactedReplayData,
                    committedAt: now()
                )
                try await auditStore.completeReconciliation(receipt, claimID: claimID)
                return .init(
                    actionID: committed.response.actionID,
                    summary: committed.response.summary,
                    data: committed.response.data,
                    receipt: receipt
                )
            case .notApplied:
                try await auditStore.resolveNotApplied(
                    confirmationFingerprint: confirmation.fingerprint,
                    idempotencyKey: confirmation.key,
                    claimID: claimID
                )
                return .init(
                    actionID: request.actionID,
                    summary: "Reconciliation confirmed that no mutation was applied.",
                    data: .object([:])
                )
            case .unresolved:
                throw AutomationExecutionError.reconciliationUnresolved
            }
        } catch {
            try? await auditStore.releaseReconciliation(
                idempotencyKey: confirmation.key,
                claimID: claimID
            )
            throw error
        }
    }

    private func validatedPlan(
        actionID: AutomationActionID,
        arguments: [String: JSONValue],
        confirmationFingerprint: String,
        requireUnexpired: Bool
    ) async throws -> AutomationMutationPlan {
        let validationTime = now()
        guard let plan = try await auditStore.preview(
            confirmationFingerprint: confirmationFingerprint,
            now: validationTime
        ) else {
            throw AutomationExecutionError.previewNotFound
        }
        guard plan.actionID == actionID else {
            throw AutomationExecutionError.actionChanged
        }
        guard plan.canonicalInputHash == (try hash(.object(arguments))) else {
            throw AutomationExecutionError.inputChanged
        }
        if requireUnexpired, plan.expiresAt <= validationTime {
            try await auditStore.removePreview(confirmationFingerprint: confirmationFingerprint)
            throw AutomationExecutionError.previewExpired
        }
        return plan
    }

    private func confirmation(
        from context: AutomationExecutionContext
    ) throws -> (fingerprint: String, key: String) {
        guard let fingerprint = context.confirmationFingerprint,
              !fingerprint.isEmpty,
              let key = context.idempotencyKey,
              !key.isEmpty else {
            throw AutomationExecutionError.confirmationRequired
        }
        return (fingerprint, key)
    }

    private func replayResponse(
        _ receipt: AutomationMutationReceipt,
        request: AutomationRequest
    ) throws -> AutomationResponse {
        guard receipt.actionID == request.actionID else {
            throw AutomationExecutionError.actionChanged
        }
        guard receipt.canonicalInputHash == (try hash(.object(request.arguments))) else {
            throw AutomationExecutionError.inputChanged
        }
        return .init(
            actionID: receipt.actionID,
            summary: receipt.redactedSummary,
            data: receipt.redactedReplayData,
            receipt: receipt
        )
    }

    private func fingerprint(
        planID: String,
        actionID: AutomationActionID,
        preparation: AutomationMutationPreparation,
        inputHash: String,
        createdAt: Date,
        expiresAt: Date
    ) throws -> String {
        try hash(.object([
            "plan_id": .string(planID),
            "action": .string(actionID.rawValue),
            "targets": .array(preparation.targetIdentifiers.map(JSONValue.string)),
            "summary": .string(preparation.redactedSummary),
            "input_hash": .string(inputHash),
            "preconditions": .object(preparation.remotePreconditions),
            "created_at": .double(createdAt.timeIntervalSince1970),
            "expires_at": .double(expiresAt.timeIntervalSince1970),
        ]))
    }

    private func hash(_ value: JSONValue) throws -> String {
        let canonical = try JSONValueEncoding.string(from: value, prettyPrinted: false)
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
