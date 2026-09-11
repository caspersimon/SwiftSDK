import Foundation
import Testing

@testable import TelemetryDeck

struct SignalMetadataTests {
    @MainActor
    private final class UIState {
        var generation = 1
    }

    private struct Enricher: SignalEnricher {
        func enrich(signalType: String, for clientUser: String?, floatValue: Double?) -> [String: String] {
            ["precedence": "enricher", "enricherOnly": "present"]
        }
    }

    private func manager(metadata: SignalMetadata) -> SignalManager {
        let config = TelemetryManagerConfiguration(appID: "metadata-test", salt: "test-salt", baseURL: URL(string: "http://127.0.0.1:1")!)
        config.defaultUser = "test-user"
        config.logHandler = nil
        config.transmitInterval = 3600
        config.testMode = true
        config.metadataEnrichers = [Enricher()]
        let cache = SignalCache<SignalPostBody>(
            logHandler: nil,
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        return SignalManager(configuration: config, metadata: metadata, signalCache: cache)
    }

    @Test @MainActor
    func backlogUsesWorkerAndRefreshesUIWithoutChangingSignalContract() async throws {
        let state = UIState()
        let manager = manager(
            metadata: SignalMetadata(
                uiParameters: {
                    ["uiOnMain": "\(Thread.isMainThread)", "generation": "\(state.generation)"]
                },
                backgroundParameters: {
                    ["metadataOnMain": "\(Thread.isMainThread)", "precedence": "default"]
                }
            )
        )
        for index in 0..<32 {
            manager.processSignal(
                "NotNow.backlog",
                parameters: ["index": "\(index)", "precedence": "event"],
                floatValue: 4.5,
                customUserID: nil,
                configuration: manager.configuration
            )
        }
        await manager.waitForPendingSignalsForTesting()
        let backlog = manager.signalCacheForTesting.pop()
        #expect(backlog.count == 32)
        #expect(Set(backlog.compactMap { $0.payload["index"] }) == Set((0..<32).map(String.init)))
        for signal in backlog {
            #expect(signal.payload["uiOnMain"] == "true")
            #expect(signal.payload["metadataOnMain"] == "false")
            #expect(signal.payload["generation"] == "1")
            #expect(signal.payload["precedence"] == "event")
            #expect(signal.payload["enricherOnly"] == "present")
            #expect(signal.clientUser == CryptoHashing.sha256(string: "test-user", salt: "test-salt"))
            #expect(signal.sessionID == manager.configuration.sessionID.uuidString)
            #expect(signal.floatValue == 4.5)
            #expect(signal.type == "NotNow.backlog")
            #expect(signal.isTestMode == "true")
        }
        state.generation = 2
        manager.processSignal("NotNow.later", parameters: [:], floatValue: nil, customUserID: "custom", configuration: manager.configuration)
        await manager.waitForPendingSignalsForTesting()
        let later = try #require(manager.signalCacheForTesting.pop().first)
        #expect(later.payload["generation"] == "2")
        #expect(later.payload["precedence"] == "enricher")
        #expect(later.clientUser == CryptoHashing.sha256(string: "custom", salt: "test-salt"))
    }

    @Test @MainActor
    func liveWorkerPayloadMatchesUnmodified2142Contract() async throws {
        // Capture both sides of processing so an actual calendar boundary is not a false failure.
        let before = DefaultSignalPayload.legacyParameters
        let manager = manager(metadata: .live)
        manager.processSignal("NotNow.parity", parameters: [:], floatValue: nil, customUserID: nil, configuration: manager.configuration)
        await manager.waitForPendingSignalsForTesting()
        let signal = try #require(manager.signalCacheForTesting.pop().first)
        let after = DefaultSignalPayload.legacyParameters
        let expectedKeys = Set(before.keys).union(["precedence", "enricherOnly"])
        #expect(Set(signal.payload.keys) == expectedKeys)
        for key in before.keys {
            #expect(signal.payload[key] == before[key] || signal.payload[key] == after[key], "Changed parameter: \(key)")
        }
        #expect(DefaultSignalPayload.parameters == after)
    }

    @Test
    func retentionCutoffPreservesHistoryAndRefreshesConcurrentReads() async throws {
        let suite = "SignalMetadataTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let sessions = SessionManager(defaults: defaults)
        sessions.waitForPendingWrites()
        defer {
            sessions.waitForPendingWrites()
            defaults.removePersistentDomain(forName: suite)
        }
        let instant = Date(timeIntervalSince1970: 1_783_080_000)  // 2026-07-03 12:00:00 UTC
        defaults.set(["2025-01-01", "2026-06-02", "2026-06-03", "2026-07-03"], forKey: "distinctDaysUsed")
        #expect(sessions.distinctDaysUsedLastMonthCount(at: instant) == 2)
        #expect(sessions.distinctDaysUsed.count == 4)
        defaults.set(["2025-01-01", "2026-06-03", "2026-07-02", "2026-07-03"], forKey: "distinctDaysUsed")
        let counts = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for _ in 0..<32 {
                group.addTask { sessions.distinctDaysUsedLastMonthCount(at: instant) }
            }
            var counts: [Int] = []
            for await count in group { counts.append(count) }
            return counts
        }
        #expect(counts.count == 32)
        #expect(counts.allSatisfy { $0 == 3 })
    }
}
