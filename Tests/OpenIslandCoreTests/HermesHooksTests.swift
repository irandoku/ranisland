import Foundation
import SQLite3
import Testing
@testable import OpenIslandCore

struct HermesHooksTests {
    @Test
    func bridgePayloadRoundTripsThroughTheWireCodec() throws {
        let payload = HermesHookPayload(
            eventName: "agent:start",
            sessionID: "hermes-1",
            sessionKey: "agent:main:telegram:chat-1",
            platform: "telegram",
            chatID: "chat-1",
            message: "Inspect the project"
        )

        let encoded = try BridgeCodec.encodeLine(.command(.processHermesHook(payload)))
        var buffer = encoded
        let decoded = try BridgeCodec.decodeLines(from: &buffer)

        #expect(decoded == [.command(.processHermesHook(payload))])
    }

    @Test
    func readerLoadsGatewaySessionsWithoutWritingTheDatabase() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        try HermesFixture.writeDatabase(at: home.appendingPathComponent("state.db"))
        try Data("{\"pid\": 2147483647}".utf8)
            .write(to: home.appendingPathComponent("gateway.pid"))
        try Data("{\"gateway_state\": \"running\"}".utf8)
            .write(to: home.appendingPathComponent("gateway_state.json"))

        let snapshot = HermesSessionReader(hermesHomePath: home.path).snapshot()
        #expect(snapshot.sessions.count == 2)
        #expect(snapshot.sessions.first?.id == "active")
        #expect(snapshot.sessions.first?.surfaceTitle == "Hermes · Telegram")
        #expect(snapshot.sessions.first?.workingDirectory == "/tmp/project")
        #expect(snapshot.sessions.first?.isActive == true)
        #expect(snapshot.sessions.last?.endReason == "session_reset")
        #expect(snapshot.gateway.state == "running")
        #expect(!snapshot.gateway.isRunning)
    }

    @Test
    func defaultHermesHomeHonorsEnvironmentOverride() {
        #expect(
            HermesSessionReader.defaultHermesHomePath(environment: ["HERMES_HOME": "/tmp/hermes-test"])
                == "/tmp/hermes-test"
        )
    }

    @Test
    func bridgeMapsHermesLifecycleToExistingAgentEvents() async throws {
        let socketURL = BridgeSocketLocation.uniqueTestURL()
        let server = BridgeServer(socketURL: socketURL)
        try server.start()
        defer { server.stop() }

        let observer = LocalBridgeClient(socketURL: socketURL)
        let stream = try observer.connect()
        defer { observer.disconnect() }
        try await observer.send(.registerClient(role: .observer))

        _ = try BridgeCommandClient(socketURL: socketURL).send(
            .processHermesHook(
                HermesHookPayload(
                    eventName: "session:start",
                    sessionID: "hermes-session",
                    sessionKey: "route-1",
                    platform: "telegram"
                )
            )
        )
        _ = try BridgeCommandClient(socketURL: socketURL).send(
            .processHermesHook(
                HermesHookPayload(
                    eventName: "agent:start",
                    sessionID: "hermes-session",
                    message: "Running the task"
                )
            )
        )
        _ = try BridgeCommandClient(socketURL: socketURL).send(
            .processHermesHook(
                HermesHookPayload(
                    eventName: "agent:end",
                    sessionID: "hermes-session",
                    response: "Done"
                )
            )
        )

        var iterator = stream.makeAsyncIterator()
        let started = try await nextHermesEvent(from: &iterator) { event in
            if case .sessionStarted = event { return true }
            return false
        }
        let running = try await nextHermesEvent(from: &iterator) { event in
            if case .activityUpdated = event { return true }
            return false
        }
        let completed = try await nextHermesEvent(from: &iterator) { event in
            if case .activityUpdated = event { return true }
            return false
        }

        guard case let .sessionStarted(startPayload) = started,
              case let .activityUpdated(runningPayload) = running,
              case let .activityUpdated(completedPayload) = completed else {
            Issue.record("Expected Hermes lifecycle events")
            return
        }

        #expect(startPayload.tool == .hermes)
        #expect(startPayload.isRemote)
        #expect(runningPayload.phase == .running)
        #expect(completedPayload.phase == .completed)
        #expect(completedPayload.summary == "Done")
    }
}

private func nextHermesEvent(
    from iterator: inout AsyncThrowingStream<AgentEvent, Error>.Iterator,
    matching predicate: (AgentEvent) -> Bool
) async throws -> AgentEvent {
    for _ in 0..<12 {
        guard let event = try await iterator.next() else {
            throw NSError(domain: "HermesHooksTests", code: 1)
        }
        if predicate(event) {
            return event
        }
    }
    throw NSError(domain: "HermesHooksTests", code: 2)
}

private enum HermesFixture {
    static func writeDatabase(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "HermesFixture", code: 1)
        }
        defer { sqlite3_close(database) }

        let statements = [
            """
            CREATE TABLE sessions (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL,
                session_key TEXT,
                chat_id TEXT,
                thread_id TEXT,
                display_name TEXT,
                title TEXT,
                started_at REAL NOT NULL,
                ended_at REAL,
                end_reason TEXT,
                cwd TEXT
            );
            """,
            """
            CREATE TABLE messages (
                session_id TEXT NOT NULL,
                timestamp REAL NOT NULL
            );
            """,
            """
            INSERT INTO sessions
                (id, source, session_key, chat_id, display_name, started_at, cwd)
            VALUES
                ('active', 'telegram', 'route-active', 'chat-1', NULL, 1000, '/tmp/project');
            """,
            """
            INSERT INTO sessions
                (id, source, session_key, chat_id, title, started_at, ended_at, end_reason)
            VALUES
                ('ended', 'telegram', 'route-ended', 'chat-2', 'Old task', 900, 950, 'session_reset');
            """,
            "INSERT INTO messages (session_id, timestamp) VALUES ('active', 1010);",
        ]

        for statement in statements {
            guard sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "HermesFixture", code: 2)
            }
        }
    }
}
