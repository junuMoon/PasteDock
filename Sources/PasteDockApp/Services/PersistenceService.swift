import Foundation

struct PersistedState: Codable {
    var settings: AppSettings
    var items: [ClipboardItem]
}

final class PersistenceService {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func loadState() -> PersistedState {
        let url = stateURL()

        guard let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(PersistedState.self, from: data) else {
            return PersistedState(settings: AppSettings(), items: [])
        }

        return state
    }

    func saveState(items: [ClipboardItem], settings: AppSettings) throws {
        let directoryURL = try applicationSupportDirectory()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let state = PersistedState(settings: settings, items: items)
        let data = try encoder.encode(state)
        try data.write(to: stateURL(), options: .atomic)
    }

    private func stateURL() -> URL {
        (try? applicationSupportDirectory())?.appendingPathComponent("state.json")
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pastedock-state.json")
    }

    private func applicationSupportDirectory() throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return baseURL.appendingPathComponent("PasteDock", isDirectory: true)
    }
}
