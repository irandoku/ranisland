import Darwin
import Foundation
import SQLite3

public struct HermesHookPayload: Equatable, Codable, Sendable {
    public var eventName: String
    public var sessionID: String?
    public var sessionKey: String?
    public var platform: String?
    public var userID: String?
    public var chatID: String?
    public var threadID: String?
    public var message: String?
    public var response: String?

    public init(
        eventName: String,
        sessionID: String? = nil,
        sessionKey: String? = nil,
        platform: String? = nil,
        userID: String? = nil,
        chatID: String? = nil,
        threadID: String? = nil,
        message: String? = nil,
        response: String? = nil
    ) {
        self.eventName = eventName
        self.sessionID = sessionID
        self.sessionKey = sessionKey
        self.platform = platform
        self.userID = userID
        self.chatID = chatID
        self.threadID = threadID
        self.message = message
        self.response = response
    }
}

public struct HermesSessionRecord: Equatable, Sendable {
    public var id: String
    public var source: String
    public var sessionKey: String?
    public var chatID: String?
    public var threadID: String?
    public var displayName: String?
    public var title: String?
    public var startedAt: Date
    public var endedAt: Date?
    public var endReason: String?
    public var workingDirectory: String?
    public var lastActiveAt: Date

    public var isActive: Bool { endedAt == nil }

    public init(
        id: String,
        source: String,
        sessionKey: String? = nil,
        chatID: String? = nil,
        threadID: String? = nil,
        displayName: String? = nil,
        title: String? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        endReason: String? = nil,
        workingDirectory: String? = nil,
        lastActiveAt: Date
    ) {
        self.id = id
        self.source = source
        self.sessionKey = sessionKey
        self.chatID = chatID
        self.threadID = threadID
        self.displayName = displayName
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.workingDirectory = workingDirectory
        self.lastActiveAt = lastActiveAt
    }

    public var surfaceTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }
        return source.isEmpty ? "Hermes" : "Hermes · \(source.capitalized)"
    }
}

public struct HermesGatewayStatus: Equatable, Sendable {
    public var isRunning: Bool
    public var state: String?

    public init(isRunning: Bool, state: String? = nil) {
        self.isRunning = isRunning
        self.state = state
    }
}

public struct HermesRuntimeSnapshot: Equatable, Sendable {
    public var sessions: [HermesSessionRecord]
    public var gateway: HermesGatewayStatus

    public init(sessions: [HermesSessionRecord], gateway: HermesGatewayStatus) {
        self.sessions = sessions
        self.gateway = gateway
    }
}

/// Read-only view of Hermes gateway state. Missing files, schema drift, and
/// busy WAL reads degrade to an empty snapshot so Hermes never blocks the app.
public struct HermesSessionReader: Sendable {
    public let hermesHomePath: String

    public init(hermesHomePath: String = HermesSessionReader.defaultHermesHomePath()) {
        self.hermesHomePath = hermesHomePath
    }

    public static func defaultHermesHomePath(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        if let path = environment["HERMES_HOME"], !path.isEmpty {
            return path
        }
        return NSHomeDirectory() + "/.hermes"
    }

    public func snapshot() -> HermesRuntimeSnapshot {
        HermesRuntimeSnapshot(
            sessions: readSessions(),
            gateway: readGatewayStatus()
        )
    }

    private func readSessions() -> [HermesSessionRecord] {
        let databasePath = hermesHomePath + "/state.db"
        guard FileManager.default.fileExists(atPath: databasePath),
              let db = openReadOnlyDatabase(atPath: databasePath) else {
            return []
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT s.id, s.source, s.session_key, s.chat_id, s.thread_id,
               s.display_name, s.title, s.started_at, s.ended_at,
               s.end_reason, s.cwd,
               COALESCE(
                   (SELECT MAX(m.timestamp) FROM messages m WHERE m.session_id = s.id),
                   s.started_at
               ) AS last_active
        FROM sessions s
        WHERE s.session_key IS NOT NULL
        ORDER BY last_active DESC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var records: [HermesSessionRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = text(statement, column: 0),
                  let source = text(statement, column: 1),
                  let startedAt = date(statement, column: 7),
                  let lastActiveAt = date(statement, column: 11) else {
                continue
            }

            records.append(
                HermesSessionRecord(
                    id: id,
                    source: source,
                    sessionKey: text(statement, column: 2),
                    chatID: text(statement, column: 3),
                    threadID: text(statement, column: 4),
                    displayName: text(statement, column: 5),
                    title: text(statement, column: 6),
                    startedAt: startedAt,
                    endedAt: date(statement, column: 8),
                    endReason: text(statement, column: 9),
                    workingDirectory: text(statement, column: 10),
                    lastActiveAt: lastActiveAt
                )
            )
        }
        return records
    }

    private func readGatewayStatus() -> HermesGatewayStatus {
        let pidURL = URL(fileURLWithPath: hermesHomePath).appendingPathComponent("gateway.pid")
        let stateURL = URL(fileURLWithPath: hermesHomePath).appendingPathComponent("gateway_state.json")
        let state = readGatewayState(at: stateURL)
        guard let pid = readGatewayPID(at: pidURL) else {
            return HermesGatewayStatus(isRunning: false, state: state)
        }

        return HermesGatewayStatus(isRunning: processExists(pid), state: state)
    }

    private func readGatewayPID(at url: URL) -> Int32? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let pid = Int32(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) {
            return pid
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let number = object["pid"] as? NSNumber else {
            return nil
        }
        return number.int32Value
    }

    private func readGatewayState(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["gateway_state"] as? String ?? object["state"] as? String
    }

    private func openReadOnlyDatabase(atPath path: String) -> OpaquePointer? {
        var db: OpaquePointer?
        let flags: Int32 = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        sqlite3_busy_timeout(db, 60)
        return db
    }

    private func processExists(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private func text(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(cString: value)
    }

    private func date(_ statement: OpaquePointer?, column: Int32) -> Date? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
    }
}
