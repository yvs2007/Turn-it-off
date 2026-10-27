import XCTest
@testable import AntiDistractDomain

final class PersistenceTests: XCTestCase {
    private var temporaryDirectoryURL = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("anti-distract-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        try super.tearDownWithError()
    }

    private func makeStore() -> FileStateStore {
        FileStateStore(fileURL: temporaryDirectoryURL.appendingPathComponent("state.json"))
    }

    // MARK: - Codable

    func testStateRoundTripsThroughJSON() throws {
        var state = AntiDistractState.onboarded(
            treeType: .redwood,
            schedule: BlockSchedule(
                start: TimeOfDay(hour: 21, minute: 30),
                end: TimeOfDay(hour: 7, minute: 15),
                weekdays: [.monday, .wednesday, .friday]
            ),
            selectedItemCount: 7
        )
        state.ledger.credit(
            activityName: "antidistract.window.2",
            start: Date(timeIntervalSince1970: 1_772_000_000),
            end: Date(timeIntervalSince1970: 1_772_000_000 + 7200),
            wasAuthorized: true
        )
        state.lastSeenProtectedHours = 1.25

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AntiDistractState.self, from: try encoder.encode(state))
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.treeType, .redwood)
        XCTAssertEqual(decoded.schedule.weekdays, [.monday, .wednesday, .friday])
        XCTAssertEqual(decoded.ledger.totalProtectedHours, 2, accuracy: 0.0001)
    }

    func testDecodingToleratesMissingKeys() throws {
        let json = Data(#"{"hasCompletedOnboarding":true}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AntiDistractState.self, from: json)
        XCTAssertTrue(decoded.hasCompletedOnboarding)
        XCTAssertEqual(decoded.treeType, .oak)
        XCTAssertEqual(decoded.schedule, .default)
        XCTAssertEqual(decoded.authorizationState, .notDetermined)
        XCTAssertEqual(decoded.ledger.totalProtectedHours, 0)
        XCTAssertNil(decoded.encodedActivitySelection)
    }

    func testDecodingUnknownTreeTypeFails() {
        let json = Data(#"{"treeType":"banana"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AntiDistractState.self, from: json))
    }

    // MARK: - FileStateStore

    func testMissingFileLoadsInitialState() throws {
        let store = makeStore()
        XCTAssertEqual(try store.load(), .initial)
    }

    func testEmptyFileLoadsInitialState() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("state.json")
        try Data().write(to: fileURL)
        XCTAssertEqual(try FileStateStore(fileURL: fileURL).load(), .initial)
    }

    func testSaveThenLoadPreservesState() throws {
        let store = makeStore()
        let state = AntiDistractState.onboarded(treeType: .spruce, totalProtectedHours: 12)
        try store.save(state)
        XCTAssertEqual(try store.load(), state)
    }

    func testSaveCreatesMissingDirectory() throws {
        let nestedURL = temporaryDirectoryURL
            .appendingPathComponent("nested/deeper/state.json")
        let store = FileStateStore(fileURL: nestedURL)
        try store.save(AntiDistractState.onboarded())
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedURL.path))
    }

    func testSeparateStoreInstancesShareTheFile() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("state.json")
        // Stands in for the app and the extension reading the same App Group container.
        let appStore = FileStateStore(fileURL: fileURL)
        let extensionStore = FileStateStore(fileURL: fileURL)

        try appStore.save(AntiDistractState.onboarded(treeType: .redwood))
        try extensionStore.update { state in
            ProtectedTimeRecorder.beginInterval(
                in: &state,
                activityName: "antidistract.window.2",
                at: Date(timeIntervalSince1970: 1_772_000_000)
            )
        }

        let reloaded = try appStore.load()
        XCTAssertTrue(reloaded.monitorReportsActiveWindow)
        XCTAssertEqual(reloaded.treeType, .redwood)
    }

    func testCorruptFileThrowsDecodeFailure() throws {
        let fileURL = temporaryDirectoryURL.appendingPathComponent("state.json")
        try Data("not json at all".utf8).write(to: fileURL)

        XCTAssertThrowsError(try FileStateStore(fileURL: fileURL).load()) { error in
            guard case StateStoreError.decodeFailed = error else {
                return XCTFail("Expected decodeFailed, got \(error)")
            }
        }
    }

    func testUpdateHelperReturnsMutatedState() throws {
        let store = makeStore()
        try store.save(AntiDistractState.onboarded())
        let updated = try store.update { $0.treeType = .spruce }
        XCTAssertEqual(updated.treeType, .spruce)
        XCTAssertEqual(try store.load().treeType, .spruce)
    }

    func testInMemoryStoreBehavesLikeFileStore() throws {
        let store = InMemoryStateStore()
        XCTAssertEqual(try store.load(), .initial)
        try store.update { $0.hasCompletedOnboarding = true }
        XCTAssertTrue(try store.load().hasCompletedOnboarding)
    }

    func testAppGroupURLFailsForUnknownGroup() {
        XCTAssertThrowsError(
            try FileStateStore.appGroupFileURL(groupIdentifier: "group.does.not.exist.anti.distract")
        ) { error in
            guard case StateStoreError.containerUnavailable = error else {
                return XCTFail("Expected containerUnavailable, got \(error)")
            }
        }
    }
}
