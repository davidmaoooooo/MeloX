import Foundation

@MainActor
final class ThirdPartySourceStore {
    static let shared = ThirdPartySourceStore()

    private let defaults = UserDefaults.standard
    private let listKey = "melox.desktop.thirdPartySources"
    private let selectedKey = "melox.desktop.thirdPartySourceSelectedID"
    private let enabledKey = "melox.desktop.thirdPartySourceEnabled"

    private(set) var sources: [ThirdPartySource] = []

    private init() { reload() }

    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) && selected != nil }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    var selected: ThirdPartySource? {
        guard let id = defaults.string(forKey: selectedKey),
              let uuid = UUID(uuidString: id) else { return nil }
        return sources.first { $0.id == uuid && $0.enabled }
    }

    func reload() {
        guard let data = defaults.data(forKey: listKey),
              let decoded = try? JSONDecoder().decode([ThirdPartySource].self, from: data) else {
            sources = []
            return
        }
        sources = decoded
    }

    @discardableResult
    func importScript(data: Data, fileName: String, name: String? = nil) throws -> ThirdPartySource {
        let id = UUID()
        let safeName = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let localFileName = "\(id.uuidString).js"
        let directory = scriptsDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appending(path: localFileName), options: .atomic)
        let source = ThirdPartySource(id: id, name: safeName, scriptURL: nil,
                                      localFileName: localFileName, enabled: true, createdAt: Date())
        sources = sources.map { var value = $0; value.enabled = false; return value } + [source]
        defaults.set(id.uuidString, forKey: selectedKey)
        isEnabled = true
        persist()
        return source
    }

    @discardableResult
    func addRemote(url: URL, name: String? = nil) -> ThirdPartySource {
        let id = UUID()
        let source = ThirdPartySource(id: id, name: name?.isEmpty == false ? name! : (url.host ?? "远程音源"),
                                      scriptURL: url, localFileName: nil, enabled: true, createdAt: Date())
        sources = sources.map { var value = $0; value.enabled = false; return value } + [source]
        defaults.set(id.uuidString, forKey: selectedKey)
        isEnabled = true
        persist()
        return source
    }

    func setEnabled(_ source: ThirdPartySource) {
        sources = sources.map { var value = $0; value.enabled = value.id == source.id; return value }
        defaults.set(source.id.uuidString, forKey: selectedKey)
        isEnabled = true
        persist()
    }

    func remove(_ source: ThirdPartySource) {
        if let localFileName = source.localFileName {
            try? FileManager.default.removeItem(at: scriptsDirectory().appending(path: localFileName))
        }
        sources.removeAll { $0.id == source.id }
        if selected?.id == source.id || defaults.string(forKey: selectedKey) == source.id.uuidString {
            defaults.set(sources.first?.id.uuidString, forKey: selectedKey)
        }
        if sources.isEmpty { isEnabled = false }
        persist()
    }

    func scriptData(for source: ThirdPartySource) async throws -> Data {
        if let localFileName = source.localFileName {
            return try Data(contentsOf: scriptsDirectory().appending(path: localFileName))
        }
        guard let url = source.scriptURL else { throw CocoaError(.fileNoSuchFile) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.noPlayableSource
        }
        return data
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sources) { defaults.set(data, forKey: listKey) }
    }

    private func scriptsDirectory() -> URL {
        AppStorageLocations.applicationSupportRoot().appending(path: "ThirdPartySources", directoryHint: .isDirectory)
    }
}
