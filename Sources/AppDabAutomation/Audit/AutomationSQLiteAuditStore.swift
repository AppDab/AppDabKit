import Foundation
import SQLite3

public actor AutomationSQLiteAuditStore: AutomationAuditStoring {
    private let databaseURL: URL
    private var connection: SQLiteConnection?

    public init(databaseURL: URL = AutomationSQLiteAuditStore.defaultDatabaseURL()) {
        self.databaseURL = databaseURL
    }

    public static func defaultDatabaseURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appendingPathComponent("AppDabKit", isDirectory: true)
            .appendingPathComponent("Automation", isDirectory: true)
            .appendingPathComponent("automation-audit.sqlite")
    }

    public func savePreview(_ plan: AutomationMutationPlan) async throws {
        let record = try encode(plan)
        try transaction {
            try pruneExpiredPreviews(
                now: plan.createdAt,
                excluding: plan.confirmationFingerprint
            )
            try execute(
                """
                INSERT INTO mutation_previews (fingerprint, record, expires_at)
                VALUES (?, ?, ?)
                ON CONFLICT(fingerprint) DO UPDATE SET
                    record = excluded.record,
                    expires_at = excluded.expires_at
                """,
                bindings: [
                    .text(plan.confirmationFingerprint),
                    .text(record),
                    .text(String(plan.expiresAt.timeIntervalSince1970)),
                ]
            )
        }
    }

    public func preview(
        confirmationFingerprint: String,
        now: Date
    ) async throws -> AutomationMutationPlan? {
        try transaction {
            try pruneExpiredPreviews(now: now, excluding: confirmationFingerprint)
            guard let record = try firstText(
                "SELECT record FROM mutation_previews WHERE fingerprint = ?",
                bindings: [.text(confirmationFingerprint)]
            ) else {
                return nil
            }
            return try decode(AutomationMutationPlan.self, from: record)
        }
    }

    public func removePreview(confirmationFingerprint: String) async throws {
        try deletePreview(confirmationFingerprint: confirmationFingerprint)
    }

    public func beginCommit(
        actionID: AutomationActionID,
        confirmationFingerprint: String,
        idempotencyKey: String,
        now: Date
    ) async throws -> AutomationCommitClaim {
        try transaction {
            try pruneExpiredPreviews(now: now, excluding: confirmationFingerprint)
            if let existing = try readAuditRecord(idempotencyKey: idempotencyKey) {
                guard existing.confirmationFingerprint == confirmationFingerprint else {
                    throw AutomationExecutionError.idempotencyCollision
                }
                switch existing.status {
                case .succeeded:
                    guard let receipt = existing.receipt else {
                        throw AutomationExecutionError.persistence(
                            "A successful audit record is missing its receipt."
                        )
                    }
                    return .replay(receipt)
                case .pending, .indeterminate:
                    throw AutomationExecutionError.commitBlocked(existing.status)
                }
            }

            try writeAuditRecord(.init(
                actionID: actionID,
                confirmationFingerprint: confirmationFingerprint,
                idempotencyKey: idempotencyKey,
                status: .pending
            ))
            let claimID = UUID().uuidString.lowercased()
            try writePendingClaim(idempotencyKey: idempotencyKey, claimedAt: now, claimID: claimID)
            return .execute(claimID: claimID)
        }
    }

    public func completeCommit(_ receipt: AutomationMutationReceipt, claimID: String) async throws {
        try transaction {
            try validatePendingClaim(
                idempotencyKey: receipt.idempotencyKey,
                confirmationFingerprint: receipt.confirmationFingerprint,
                claimID: claimID
            )
            try writeAuditRecord(.init(
                actionID: receipt.actionID,
                confirmationFingerprint: receipt.confirmationFingerprint,
                idempotencyKey: receipt.idempotencyKey,
                status: .succeeded,
                receipt: receipt
            ))
            try removePendingClaim(idempotencyKey: receipt.idempotencyKey)
            try removeReconciliationClaim(idempotencyKey: receipt.idempotencyKey)
            try deletePreview(confirmationFingerprint: receipt.confirmationFingerprint)
        }
    }

    public func markIndeterminate(
        actionID: AutomationActionID,
        confirmationFingerprint: String,
        idempotencyKey: String,
        claimID: String
    ) async throws {
        try transaction {
            try validatePendingClaim(
                idempotencyKey: idempotencyKey,
                confirmationFingerprint: confirmationFingerprint,
                claimID: claimID
            )
            try writeAuditRecord(.init(
                actionID: actionID,
                confirmationFingerprint: confirmationFingerprint,
                idempotencyKey: idempotencyKey,
                status: .indeterminate
            ))
            try removePendingClaim(idempotencyKey: idempotencyKey)
        }
    }

    public func beginReconciliation(
        confirmationFingerprint: String,
        idempotencyKey: String,
        now: Date,
        pendingLeaseDuration: TimeInterval
    ) async throws -> AutomationReconciliationClaim {
        try transaction {
            try pruneExpiredPreviews(now: now, excluding: confirmationFingerprint)
            guard let existing = try readAuditRecord(idempotencyKey: idempotencyKey) else {
                throw AutomationExecutionError.previewNotFound
            }
            guard existing.confirmationFingerprint == confirmationFingerprint else {
                throw AutomationExecutionError.idempotencyCollision
            }
            switch existing.status {
            case .succeeded:
                guard let receipt = existing.receipt else {
                    throw AutomationExecutionError.persistence(
                        "A successful audit record is missing its receipt."
                    )
                }
                return .replay(receipt)
            case .indeterminate:
                return try claimReconciliation(
                    idempotencyKey: idempotencyKey,
                    now: now,
                    leaseDuration: pendingLeaseDuration
                )
            case .pending:
                guard let claimedAt = try pendingClaimedAt(idempotencyKey: idempotencyKey) else {
                    throw AutomationExecutionError.persistence(
                        "A pending audit record is missing its claim timestamp."
                    )
                }
                guard claimedAt.addingTimeInterval(pendingLeaseDuration) <= now else {
                    throw AutomationExecutionError.commitBlocked(.pending)
                }
                try writeAuditRecord(.init(
                    actionID: existing.actionID,
                    confirmationFingerprint: existing.confirmationFingerprint,
                    idempotencyKey: existing.idempotencyKey,
                    status: .indeterminate
                ))
                try removePendingClaim(idempotencyKey: idempotencyKey)
                return try claimReconciliation(
                    idempotencyKey: idempotencyKey,
                    now: now,
                    leaseDuration: pendingLeaseDuration
                )
            }
        }
    }

    public func completeReconciliation(
        _ receipt: AutomationMutationReceipt,
        claimID: String
    ) async throws {
        try transaction {
            try validateReconciliationClaim(
                idempotencyKey: receipt.idempotencyKey,
                claimID: claimID
            )
            guard let existing = try readAuditRecord(idempotencyKey: receipt.idempotencyKey),
                  existing.confirmationFingerprint == receipt.confirmationFingerprint,
                  existing.status == .indeterminate else {
                throw AutomationExecutionError.commitBlocked(.indeterminate)
            }
            try writeAuditRecord(.init(
                actionID: receipt.actionID,
                confirmationFingerprint: receipt.confirmationFingerprint,
                idempotencyKey: receipt.idempotencyKey,
                status: .succeeded,
                receipt: receipt
            ))
            try removeReconciliationClaim(idempotencyKey: receipt.idempotencyKey)
            try deletePreview(confirmationFingerprint: receipt.confirmationFingerprint)
        }
    }

    public func auditRecord(idempotencyKey: String) async throws -> AutomationAuditRecord? {
        try readAuditRecord(idempotencyKey: idempotencyKey)
    }

    public func resolveNotApplied(
        confirmationFingerprint: String,
        idempotencyKey: String,
        claimID: String
    ) async throws {
        try transaction {
            try validateReconciliationClaim(idempotencyKey: idempotencyKey, claimID: claimID)
            guard let existing = try readAuditRecord(idempotencyKey: idempotencyKey) else {
                throw AutomationExecutionError.commitBlocked(.indeterminate)
            }
            guard existing.confirmationFingerprint == confirmationFingerprint else {
                throw AutomationExecutionError.idempotencyCollision
            }
            guard existing.status == .indeterminate else {
                throw AutomationExecutionError.commitBlocked(existing.status)
            }
            try execute(
                "DELETE FROM mutation_audits WHERE idempotency_key = ?",
                bindings: [.text(idempotencyKey)]
            )
            try removePendingClaim(idempotencyKey: idempotencyKey)
            try removeReconciliationClaim(idempotencyKey: idempotencyKey)
        }
    }

    public func releaseReconciliation(idempotencyKey: String, claimID: String) async throws {
        try transaction {
            guard try reconciliationClaim(idempotencyKey: idempotencyKey)?.claimID == claimID else {
                return
            }
            try removeReconciliationClaim(idempotencyKey: idempotencyKey)
        }
    }

    public func auditRecords() async throws -> [AutomationAuditRecord] {
        try allTexts("SELECT record FROM mutation_audits ORDER BY idempotency_key")
            .map { try decode(AutomationAuditRecord.self, from: $0) }
    }

    public func clear() async throws {
        try transaction {
            try execute("DELETE FROM mutation_previews")
            try execute("DELETE FROM mutation_audits")
            try execute("DELETE FROM mutation_pending_claims")
            try execute("DELETE FROM mutation_reconciliation_claims")
        }
    }

    private func writeAuditRecord(_ record: AutomationAuditRecord) throws {
        try execute(
            """
            INSERT INTO mutation_audits (idempotency_key, record)
            VALUES (?, ?)
            ON CONFLICT(idempotency_key) DO UPDATE SET record = excluded.record
            """,
            bindings: [.text(record.idempotencyKey), .text(try encode(record))]
        )
    }

    private func pruneExpiredPreviews(now: Date, excluding fingerprint: String? = nil) throws {
        var sql = "DELETE FROM mutation_previews WHERE CAST(expires_at AS REAL) <= CAST(? AS REAL)"
        var bindings: [SQLiteBinding] = [.text(String(now.timeIntervalSince1970))]
        if let fingerprint {
            sql += " AND fingerprint != ?"
            bindings.append(.text(fingerprint))
        }
        try execute(sql, bindings: bindings)
    }

    private func deletePreview(confirmationFingerprint: String) throws {
        try execute(
            "DELETE FROM mutation_previews WHERE fingerprint = ?",
            bindings: [.text(confirmationFingerprint)]
        )
    }

    private func readAuditRecord(idempotencyKey: String) throws -> AutomationAuditRecord? {
        guard let record = try firstText(
            "SELECT record FROM mutation_audits WHERE idempotency_key = ?",
            bindings: [.text(idempotencyKey)]
        ) else {
            return nil
        }
        return try decode(AutomationAuditRecord.self, from: record)
    }

    private func writePendingClaim(idempotencyKey: String, claimedAt: Date, claimID: String) throws {
        try execute(
            "INSERT INTO mutation_pending_claims (idempotency_key, claimed_at, claim_id) VALUES (?, ?, ?)",
            bindings: [.text(idempotencyKey), .text(String(claimedAt.timeIntervalSince1970)), .text(claimID)]
        )
    }

    private func validatePendingClaim(
        idempotencyKey: String,
        confirmationFingerprint: String,
        claimID: String
    ) throws {
        let storedClaimID = try firstText(
            "SELECT claim_id FROM mutation_pending_claims WHERE idempotency_key = ?",
            bindings: [.text(idempotencyKey)]
        )
        guard storedClaimID == claimID,
              let record = try readAuditRecord(idempotencyKey: idempotencyKey),
              record.status == .pending,
              record.confirmationFingerprint == confirmationFingerprint else {
            throw AutomationExecutionError.commitBlocked(.indeterminate)
        }
    }

    private func pendingClaimedAt(idempotencyKey: String) throws -> Date? {
        guard let value = try firstText(
            "SELECT claimed_at FROM mutation_pending_claims WHERE idempotency_key = ?",
            bindings: [.text(idempotencyKey)]
        ), let timestamp = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func removePendingClaim(idempotencyKey: String) throws {
        try execute(
            "DELETE FROM mutation_pending_claims WHERE idempotency_key = ?",
            bindings: [.text(idempotencyKey)]
        )
    }

    private func claimReconciliation(
        idempotencyKey: String,
        now: Date,
        leaseDuration: TimeInterval
    ) throws -> AutomationReconciliationClaim {
        if let existing = try reconciliationClaim(idempotencyKey: idempotencyKey),
           existing.claimedAt.addingTimeInterval(leaseDuration) > now {
            throw AutomationExecutionError.commitBlocked(.indeterminate)
        }
        let claimID = UUID().uuidString.lowercased()
        try execute(
            """
            INSERT INTO mutation_reconciliation_claims (idempotency_key, claim_id, claimed_at)
            VALUES (?, ?, ?)
            ON CONFLICT(idempotency_key) DO UPDATE SET
                claim_id = excluded.claim_id,
                claimed_at = excluded.claimed_at
            """,
            bindings: [
                .text(idempotencyKey),
                .text(claimID),
                .text(String(now.timeIntervalSince1970)),
            ]
        )
        return .reconcile(claimID: claimID)
    }

    private func reconciliationClaim(
        idempotencyKey: String
    ) throws -> (claimID: String, claimedAt: Date)? {
        guard let values = try firstTwoTexts(
            """
            SELECT claim_id, claimed_at
            FROM mutation_reconciliation_claims
            WHERE idempotency_key = ?
            """,
            bindings: [.text(idempotencyKey)]
        ), let timestamp = TimeInterval(values.1) else {
            return nil
        }
        return (values.0, Date(timeIntervalSince1970: timestamp))
    }

    private func validateReconciliationClaim(idempotencyKey: String, claimID: String) throws {
        guard try reconciliationClaim(idempotencyKey: idempotencyKey)?.claimID == claimID else {
            throw AutomationExecutionError.commitBlocked(.indeterminate)
        }
    }

    private func removeReconciliationClaim(idempotencyKey: String) throws {
        try execute(
            "DELETE FROM mutation_reconciliation_claims WHERE idempotency_key = ?",
            bindings: [.text(idempotencyKey)]
        )
    }

    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            let value = try body()
            try execute("COMMIT TRANSACTION")
            return value
        } catch {
            try? execute("ROLLBACK TRANSACTION")
            throw error
        }
    }

    private func execute(
        _ sql: String,
        bindings: [SQLiteBinding] = []
    ) throws {
        let database = try openDatabase()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw databaseError(database)
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, database: database)
        var stepResult = step(statement)
        while stepResult == SQLITE_ROW {
            stepResult = step(statement)
        }
        guard stepResult == SQLITE_DONE else {
            throw databaseError(database)
        }
    }

    private func firstText(
        _ sql: String,
        bindings: [SQLiteBinding] = []
    ) throws -> String? {
        let database = try openDatabase()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw databaseError(database)
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, database: database)
        switch step(statement) {
        case SQLITE_ROW:
            guard let text = sqlite3_column_text(statement, 0) else { return nil }
            return String(cString: text)
        case SQLITE_DONE:
            return nil
        default:
            throw databaseError(database)
        }
    }

    private func firstTwoTexts(
        _ sql: String,
        bindings: [SQLiteBinding] = []
    ) throws -> (String, String)? {
        let database = try openDatabase()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw databaseError(database)
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement, database: database)
        switch step(statement) {
        case SQLITE_ROW:
            guard let first = sqlite3_column_text(statement, 0),
                  let second = sqlite3_column_text(statement, 1) else {
                return nil
            }
            return (String(cString: first), String(cString: second))
        case SQLITE_DONE:
            return nil
        default:
            throw databaseError(database)
        }
    }

    private func allTexts(_ sql: String) throws -> [String] {
        let database = try openDatabase()
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw databaseError(database)
        }
        defer { sqlite3_finalize(statement) }

        var values = [String]()
        while true {
            switch step(statement) {
            case SQLITE_ROW:
                if let text = sqlite3_column_text(statement, 0) {
                    values.append(String(cString: text))
                }
            case SQLITE_DONE:
                return values
            default:
                throw databaseError(database)
            }
        }
    }

    private func bind(
        _ bindings: [SQLiteBinding],
        to statement: OpaquePointer,
        database: OpaquePointer
    ) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result = switch binding {
            case .text(let value):
                value.withCString {
                    sqlite3_bind_text(statement, index, $0, -1, transient)
                }
            }
            guard result == SQLITE_OK else {
                throw databaseError(database)
            }
        }
    }

    private func step(_ statement: OpaquePointer) -> Int32 {
        var result = sqlite3_step(statement)
        var retryCount = 0
        while (result == SQLITE_BUSY || result == SQLITE_LOCKED), retryCount < 100 {
            Thread.sleep(forTimeInterval: 0.005)
            retryCount += 1
            result = sqlite3_step(statement)
        }
        return result
    }

    private func openDatabase() throws -> OpaquePointer {
        if let connection {
            return connection.pointer
        }

        do {
            try FileManager.default.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw AutomationExecutionError.persistence(error.localizedDescription)
        }

        var database: OpaquePointer?
        let result = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let database else {
            if let database {
                sqlite3_close(database)
            }
            throw AutomationExecutionError.persistence("Could not open the SQLite database.")
        }
        connection = SQLiteConnection(pointer: database)

        do {
            sqlite3_busy_timeout(database, 5_000)
            try execute("PRAGMA journal_mode = WAL")
            try execute("PRAGMA synchronous = FULL")
            try execute(
                """
                CREATE TABLE IF NOT EXISTS mutation_previews (
                    fingerprint TEXT PRIMARY KEY NOT NULL,
                    record TEXT NOT NULL,
                    expires_at TEXT
                )
                """
            )
            try transaction {
                if try firstText("SELECT name FROM pragma_table_info('mutation_previews') WHERE name = 'expires_at'") == nil {
                    try execute("ALTER TABLE mutation_previews ADD COLUMN expires_at TEXT")
                }
                try execute(
                    "UPDATE mutation_previews SET expires_at = json_extract(record, '$.expiresAt') WHERE expires_at IS NULL"
                )
            }
            try execute(
                """
                CREATE TABLE IF NOT EXISTS mutation_audits (
                    idempotency_key TEXT PRIMARY KEY NOT NULL,
                    record TEXT NOT NULL
                )
                """
            )
            try execute(
                """
                CREATE TABLE IF NOT EXISTS mutation_pending_claims (
                    idempotency_key TEXT PRIMARY KEY NOT NULL,
                    claimed_at TEXT NOT NULL,
                    claim_id TEXT
                )
                """
            )
            // Migrate pending claims created before commit ownership tokens were introduced.
            try transaction {
                if try firstText("SELECT name FROM pragma_table_info('mutation_pending_claims') WHERE name = 'claim_id'") == nil {
                    try execute("ALTER TABLE mutation_pending_claims ADD COLUMN claim_id TEXT")
                }
            }
            try execute(
                """
                CREATE TABLE IF NOT EXISTS mutation_reconciliation_claims (
                    idempotency_key TEXT PRIMARY KEY NOT NULL,
                    claim_id TEXT NOT NULL,
                    claimed_at TEXT NOT NULL
                )
                """
            )
        } catch {
            connection = nil
            throw error
        }
        return database
    }

    private func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        do {
            return String(decoding: try encoder.encode(value), as: UTF8.self)
        } catch {
            throw AutomationExecutionError.persistence(error.localizedDescription)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from value: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        do {
            return try decoder.decode(type, from: Data(value.utf8))
        } catch {
            throw AutomationExecutionError.persistence(error.localizedDescription)
        }
    }

    private func databaseError(_ database: OpaquePointer) -> AutomationExecutionError {
        let message = sqlite3_errmsg(database).map(String.init(cString:)) ?? "Unknown SQLite error."
        return .persistence(message)
    }
}
