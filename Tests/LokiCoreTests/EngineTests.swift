import XCTest
@testable import LokiCore

/// A prank with no side effects, used to exercise the engine's lifecycle.
private final class FakePrank: PrankModule {
    let id: String
    let name: String
    let category = PrankCategory.ui
    let intensity = Intensity.silly
    let requiredPermissions: [Permission] = []
    let isReversible: Bool

    private(set) var runCount = 0
    private(set) var undoCount = 0
    var runError: Error?

    init(id: String, reversible: Bool = true) {
        self.id = id
        self.name = id
        self.isReversible = reversible
    }

    func run(context: PrankContext) throws {
        if let runError { throw runError }
        runCount += 1
    }
    func undo(context: PrankContext) throws { undoCount += 1 }
}

/// An isolated UserDefaults so tests never touch the real config.
private func testDefaults() -> UserDefaults {
    UserDefaults(suiteName: "loki-test-\(UUID().uuidString)")!
}

final class CatalogTests: XCTestCase {
    func testCatalogHasUniqueIDs() {
        let pranks = LokiFactory.allPranks()
        let ids = pranks.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "Doppelte Prank-IDs gefunden")
    }

    func testCatalogSize() {
        XCTAssertEqual(LokiFactory.allPranks().count, 32)
    }

    func testModesReferenceValidPranks() {
        let ids = Set(LokiFactory.allPranks().map { $0.id })
        for mode in LokiFactory.allModes() {
            for step in mode.steps {
                XCTAssertTrue(ids.contains(step.prankID),
                              "Mode \(mode.id) referenziert unbekannten Prank \(step.prankID)")
            }
        }
    }

    func testModeSetupReferencesValidPranks() {
        let ids = Set(LokiFactory.allPranks().map { $0.id })
        for mode in LokiFactory.allModes() {
            for cfg in mode.setup {
                XCTAssertTrue(ids.contains(cfg.prankID),
                              "Mode \(mode.id) setup referenziert unbekannten Prank \(cfg.prankID)")
            }
        }
    }

    func testHauntModeIsNarrated() {
        guard let haunt = LokiFactory.allModes().first(where: { $0.tier == 3 }) else {
            return XCTFail("Kein Tier-3-Modus gefunden")
        }
        XCTAssertGreaterThan(haunt.narration.count, 5, "Heimsuchung sollte eine erzählte Story sein")
        // Narration beats should be ordered in time.
        let times = haunt.narration.map(\.at)
        XCTAssertEqual(times, times.sorted(), "Narration-Beats sind nicht chronologisch")
    }

    func testModesCoverTiersAndEndWithReveal() {
        let modes = LokiFactory.allModes()
        XCTAssertEqual(Set(modes.map { $0.tier }), [1, 2, 3])
        for mode in modes {
            XCTAssertTrue(mode.steps.contains { $0.prankID == "reveal" },
                          "Mode \(mode.id) endet nicht mit Auflösung")
        }
    }

    func testEverySettingHasUniqueKeyWithinPrank() {
        for prank in LokiFactory.allPranks() {
            let keys = prank.settings.map { $0.key }
            XCTAssertEqual(Set(keys).count, keys.count, "Doppelte Setting-Keys in \(prank.id)")
        }
    }
}

final class StateStoreTests: XCTestCase {
    private func tempStore() -> StateStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("loki-test-\(UUID().uuidString).json")
        return StateStore(url: url)
    }

    func testSaveDoesNotOverwriteOriginal() {
        let store = tempStore()
        store.saveOriginal("k", value: "original")
        store.saveOriginal("k", value: "pranked")
        XCTAssertEqual(store.original("k"), "original")
    }

    func testConsumeRemovesValue() {
        let store = tempStore()
        store.saveOriginal("k", value: "v")
        XCTAssertEqual(store.consumeOriginal("k"), "v")
        XCTAssertNil(store.original("k"))
    }

    func testPersistsAcrossInstances() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("loki-test-\(UUID().uuidString).json")
        let a = StateStore(url: url)
        a.saveOriginal("k", value: "v")
        let b = StateStore(url: url)
        XCTAssertEqual(b.original("k"), "v")
    }
}

final class PrankEngineTests: XCTestCase {
    private func makeEngine() -> PrankEngine {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("loki-test-\(UUID().uuidString).json")
        let ctx = PrankContext(runner: ScriptRunner(), store: StateStore(url: url),
                               config: ConfigStore(defaults: testDefaults()))
        return PrankEngine(context: ctx)
    }

    func testToggleTracksActiveForReversible() throws {
        let engine = makeEngine()
        let prank = FakePrank(id: "a")
        engine.register(prank)

        try engine.toggle(id: "a")
        XCTAssertTrue(engine.isActive("a"))
        XCTAssertEqual(prank.runCount, 1)

        try engine.toggle(id: "a")
        XCTAssertFalse(engine.isActive("a"))
        XCTAssertEqual(prank.undoCount, 1)
    }

    func testOneShotNotTrackedAsActive() throws {
        let engine = makeEngine()
        engine.register(FakePrank(id: "once", reversible: false))
        try engine.run(id: "once")
        XCTAssertFalse(engine.isActive("once"))
    }

    func testPanicUndoesAllActive() throws {
        let engine = makeEngine()
        let a = FakePrank(id: "a"); let b = FakePrank(id: "b")
        engine.register([a, b])
        try engine.run(id: "a")
        try engine.run(id: "b")
        XCTAssertEqual(engine.activePranks.count, 2)

        let errors = engine.panic()
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(a.undoCount, 1)
        XCTAssertEqual(b.undoCount, 1)
        XCTAssertTrue(engine.activePranks.isEmpty)
    }

    func testAutoRevealFiresAfterRunningAPrank() {
        let engine = makeEngine()
        engine.register(FakePrank(id: "a"))
        engine.autoRevealMinutes = 0.01 // 0.6s

        let expectation = XCTestExpectation(description: "auto-reveal fires")
        engine.onAutoReveal = { expectation.fulfill() }
        try? engine.run(id: "a")
        XCTAssertTrue(engine.autoRevealArmed)

        wait(for: [expectation], timeout: 3)
    }

    func testAutoRevealCancelledByPanic() {
        let engine = makeEngine()
        engine.register(FakePrank(id: "a"))
        engine.autoRevealMinutes = 5
        try? engine.run(id: "a")
        XCTAssertTrue(engine.autoRevealArmed)
        _ = engine.panic()
        XCTAssertFalse(engine.autoRevealArmed)
    }

    func testRegisterIsIdempotentOnID() {
        let engine = makeEngine()
        engine.register(FakePrank(id: "dup"))
        engine.register(FakePrank(id: "dup"))
        XCTAssertEqual(engine.all.filter { $0.id == "dup" }.count, 1)
    }
}
