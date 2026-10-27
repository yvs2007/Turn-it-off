import Foundation

public enum StateStoreError: Error, CustomStringConvertible {
    case containerUnavailable(groupIdentifier: String)
    case readFailed(underlying: Error)
    case writeFailed(underlying: Error)
    case decodeFailed(underlying: Error)

    public var description: String {
        switch self {
        case .containerUnavailable(let groupIdentifier):
            return "App Group container \(groupIdentifier) is unavailable."
        case .readFailed(let underlying):
            return "Read failed: \(underlying)"
        case .writeFailed(let underlying):
            return "Write failed: \(underlying)"
        case .decodeFailed(let underlying):
            return "Decode failed: \(underlying)"
        }
    }

    /// One short sentence, safe to show in the UI.
    public var userFacingMessage: String { "Saved settings couldn't be read on this device." }
}

/// Shared persistence contract, implemented by the App Group file store in the app and by
/// an in-memory double in tests.
public protocol StateStore: AnyObject {
    func load() throws -> AntiDistractState
    func save(_ state: AntiDistractState) throws
}

public extension StateStore {
    /// Read–modify–write helper so the app and the extension never hand-roll the sequence.
    @discardableResult
    func update(_ mutate: (inout AntiDistractState) -> Void) throws -> AntiDistractState {
        var state = try load()
        mutate(&state)
        try save(state)
        return state
    }
}

/// JSON file store. Point it at an App Group container URL in the app, or at a temporary
/// directory in tests — the behaviour is identical.
public final class FileStateStore: StateStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Standard location inside an App Group container.
    public static func appGroupFileURL(
        groupIdentifier: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ) else {
            throw StateStoreError.containerUnavailable(groupIdentifier: groupIdentifier)
        }
        return containerURL.appendingPathComponent("anti-distract-state.json")
    }

    public func load() throws -> AntiDistractState {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: fileURL.path) else { return .initial }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw StateStoreError.readFailed(underlying: error)
        }

        guard !data.isEmpty else { return .initial }

        do {
            return try decoder.decode(AntiDistractState.self, from: data)
        } catch {
            throw StateStoreError.decodeFailed(underlying: error)
        }
    }

    public func save(_ state: AntiDistractState) throws {
        lock.lock()
        defer { lock.unlock() }

        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            let data = try encoder.encode(state)
            // Atomic so a crash mid-write can't leave the extension reading half a file.
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StateStoreError.writeFailed(underlying: error)
        }
    }
}

/// Test double; also handy for SwiftUI previews.
public final class InMemoryStateStore: StateStore {
    private var state: AntiDistractState
    private let lock = NSLock()

    public init(state: AntiDistractState = .initial) {
        self.state = state
    }

    public func load() throws -> AntiDistractState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func save(_ state: AntiDistractState) throws {
        lock.lock()
        defer { lock.unlock() }
        self.state = state
    }
}
