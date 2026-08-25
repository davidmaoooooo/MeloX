import CommonCrypto
import Foundation
import JavaScriptCore
import Security

@MainActor
final class ThirdPartySourceRuntime {
    static let shared = ThirdPartySourceRuntime()
    private var engine: ThirdPartySourceEngine?

    func clear() { engine = nil }

    func fetchMusicURL(_ info: ThirdPartyMusicInfo) async throws -> URL {
        let store = ThirdPartySourceStore.shared
        guard store.isEnabled, let source = store.selected else { throw APIError.noPlayableSource }
        if engine?.source.id != source.id { engine = nil }
        if engine == nil { engine = try await ThirdPartySourceEngine(source: source) }
        guard let value = try await engine?.request(info), let url = URL(string: value),
              ["http", "https"].contains(url.scheme?.lowercased()) else { throw APIError.noPlayableSource }
        return url
    }
}

@MainActor
private final class ThirdPartySourceEngine {
    let source: ThirdPartySource
    private let context = JSContext()!
    private let key = UUID().uuidString
    private var sourceKey = "wy"
    private var continuations: [String: CheckedContinuation<String, Error>] = [:]

    init(source: ThirdPartySource) async throws {
        self.source = source
        context.exceptionHandler = { _, exception in
            NSLog("Third-party source JavaScript error: %@", exception?.toString() ?? "unknown")
        }
        installNativeBridge()
        // Depending on Xcode's resource synchronization, the folder may be
        // preserved in the bundle or its files may be flattened at the root.
        let preloadURL = Bundle.main.url(
            forResource: "user-api-preload",
            withExtension: "js",
            subdirectory: "ThirdPartySource"
        ) ?? Bundle.main.url(forResource: "user-api-preload", withExtension: "js")
        guard let preloadURL, let preload = try? String(contentsOf: preloadURL, encoding: .utf8) else {
            NSLog("Third-party source preload script is missing from the app bundle")
            throw APIError.noPlayableSource
        }
        let scriptData = try await ThirdPartySourceStore.shared.scriptData(for: source)
        guard let script = String(data: scriptData, encoding: .utf8) else { throw APIError.noPlayableSource }
        context.evaluateScript(preload)
        context.objectForKeyedSubscript("lx_setup")?.call(withArguments: [key, source.id.uuidString, source.name, "", "", "", "", script])
        if let exception = context.exception {
            NSLog("Third-party source preload failed: %@", exception.toString() ?? "unknown")
            throw APIError.noPlayableSource
        }
        context.evaluateScript(script)
        if let exception = context.exception {
            NSLog("Third-party source script failed: %@", exception.toString() ?? "unknown")
            throw APIError.noPlayableSource
        }
    }

    func request(_ info: ThirdPartyMusicInfo) async throws -> String {
        let musicInfo: [String: Any] = ["name": info.name, "singer": info.singer, "albumName": info.albumName,
            "interval": max(0, info.intervalMS / 1000), "source": sourceKey, "songmid": String(info.id),
            "id": info.id, "hash": String(info.id)]
        let payload: [String: Any] = ["source": sourceKey, "action": "musicUrl",
            "info": ["type": "320k", "musicInfo": musicInfo]]
        let requestKey = UUID().uuidString
        let data = try JSONSerialization.data(withJSONObject: ["requestKey": requestKey, "data": payload])
        guard let json = String(data: data, encoding: .utf8) else { throw APIError.noPlayableSource }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                continuations[requestKey] = continuation
                context.objectForKeyedSubscript("__lx_native__")?.call(withArguments: [key, "request", json])
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(30))
                    guard let self, let pending = self.continuations.removeValue(forKey: requestKey) else { return }
                    pending.resume(throwing: APIError.noPlayableSource)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, let pending = self.continuations.removeValue(forKey: requestKey) else { return }
                pending.resume(throwing: CancellationError())
            }
        }
    }

    private func installNativeBridge() {
        context.setObject({ [weak self] (args: [Any]) -> Any? in
            guard let self, args.count >= 3, String(describing: args[0]) == self.key else { return nil }
            self.handle(action: String(describing: args[1]), data: String(describing: args[2])); return nil
        }, forKeyedSubscript: "__lx_native_call__" as NSString)
        context.setObject({ (args: [Any]) -> String in Data(String(describing: args.first ?? "").utf8).base64EncodedString() }, forKeyedSubscript: "__lx_native_call__utils_str2b64" as NSString)
        context.setObject({ (args: [Any]) -> String in
            let decoded = Data(base64Encoded: String(describing: args.first ?? "")) ?? Data()
            return "[" + decoded.map(String.init).joined(separator: ",") + "]"
        }, forKeyedSubscript: "__lx_native_call__utils_b642buf" as NSString)
        context.setObject({ (args: [Any]) -> String in
            let value = String(describing: args.first ?? "").removingPercentEncoding ?? ""
            return InsecureMD5.hex(Data(value.utf8))
        }, forKeyedSubscript: "__lx_native_call__utils_str2md5" as NSString)
        context.setObject({ (args: [Any]) -> String in
            guard args.count >= 4 else { return "" }
            return Self.aes(dataBase64: String(describing: args[0]), keyBase64: String(describing: args[1]), ivBase64: String(describing: args[2]), mode: String(describing: args[3]))
        }, forKeyedSubscript: "__lx_native_call__utils_aes_encrypt" as NSString)
        context.setObject({ (args: [Any]) -> String in
            guard args.count >= 2 else { return "" }
            return Self.rsa(dataBase64: String(describing: args[0]), publicKeyBase64: String(describing: args[1]))
        }, forKeyedSubscript: "__lx_native_call__utils_rsa_encrypt" as NSString)
        context.setObject({ [weak self] (args: [Any]) -> NSNull in
            let id = String(describing: args.first ?? "")
            let delay = Int(String(describing: args.dropFirst().first ?? "0")) ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(0, delay))) {
                guard let self else { return }
                self.context.objectForKeyedSubscript("__lx_native__")?.call(withArguments: [self.key, "__set_timeout__", id])
            }; return NSNull()
        }, forKeyedSubscript: "__lx_native_call__set_timeout" as NSString)
    }

    private func handle(action: String, data: String) {
        switch action {
        case "init":
            guard let object = jsonObject(data), let info = object["info"] as? [String: Any], let sources = info["sources"] as? [String: Any] else { return }
            sourceKey = sources["wy"] != nil ? "wy" : (sources.keys.first ?? "wy")
        case "request": handleRequest(data)
        case "response": handleResponse(data)
        default: break
        }
    }

    private func handleRequest(_ data: String) {
        guard let object = jsonObject(data), let requestKey = object["requestKey"] as? String,
              let urlString = object["url"] as? String, let url = URL(string: urlString) else { return }
        let options = object["options"] as? [String: Any] ?? [:]
        var request = URLRequest(url: url)
        request.httpMethod = (options["method"] as? String ?? "GET").uppercased(); request.timeoutInterval = 30
        if let headers = options["headers"] as? [String: Any] { for (name, value) in headers { request.setValue(String(describing: value), forHTTPHeaderField: name) } }
        if let body = options["body"] { request.httpBody = bodyData(body) }
        else if let form = options["form"] ?? options["formData"] {
            request.httpBody = formData(form)
            if request.value(forHTTPHeaderField: "Content-Type") == nil { request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let http = response as? HTTPURLResponse
                let body: Any = (try? JSONSerialization.jsonObject(with: data)) ?? String(data: data, encoding: .utf8) ?? ""
                let headers = http?.allHeaderFields.reduce(into: [String: String]()) { $0[String(describing: $1.key).lowercased()] = String(describing: $1.value) } ?? [:]
                sendResponse(["requestKey": requestKey, "response": ["statusCode": http?.statusCode ?? 0, "statusMessage": HTTPURLResponse.localizedString(forStatusCode: http?.statusCode ?? 0), "headers": headers, "body": body]])
            } catch { sendResponse(["requestKey": requestKey, "error": error.localizedDescription]) }
        }
    }

    private func handleResponse(_ data: String) {
        guard let object = jsonObject(data), let requestKey = object["requestKey"] as? String, let continuation = continuations.removeValue(forKey: requestKey) else { return }
        guard object["status"] as? Bool == true,
              let result = object["result"] as? [String: Any],
              let value = result["data"] as? [String: Any],
              let url = value["url"] as? String else {
            NSLog("Third-party source returned no playable URL: %@", data)
            continuation.resume(throwing: APIError.noPlayableSource)
            return
        }
        continuation.resume(returning: url)
    }

    private func sendResponse(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let string = String(data: data, encoding: .utf8) else { return }
        context.objectForKeyedSubscript("__lx_native__")?.call(withArguments: [key, "response", string])
    }

    private func jsonObject(_ string: String) -> [String: Any]? { (try? JSONSerialization.jsonObject(with: Data(string.utf8))) as? [String: Any] }
    private func bodyData(_ body: Any) -> Data? { if let string = body as? String { return Data(string.utf8) }; return try? JSONSerialization.data(withJSONObject: body) }
    private func formData(_ form: Any) -> Data? {
        guard let values = form as? [String: Any] else { return nil }
        return Data(values.keys.sorted().map { "\(Self.urlEncode($0))=\(Self.urlEncode(String(describing: values[$0] ?? "")))" }.joined(separator: "&").utf8)
    }
    private static func urlEncode(_ string: String) -> String { string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string }

    private static func aes(dataBase64: String, keyBase64: String, ivBase64: String, mode: String) -> String {
        guard let input = Data(base64Encoded: dataBase64), let key = Data(base64Encoded: keyBase64) else { return "" }
        let iv = Data(base64Encoded: ivBase64) ?? Data(); let options: CCOptions = mode == "AES" ? CCOptions(kCCOptionECBMode) : CCOptions(kCCOptionPKCS7Padding)
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128); var length = 0
        let status = input.withUnsafeBytes { inputBytes in key.withUnsafeBytes { keyBytes in iv.withUnsafeBytes { ivBytes in
            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), options, keyBytes.baseAddress, key.count, mode == "AES" ? nil : ivBytes.baseAddress, inputBytes.baseAddress, input.count, &output, output.count, &length)
        } } }
        return status == kCCSuccess ? Data(output.prefix(length)).base64EncodedString() : ""
    }

    private static func rsa(dataBase64: String, publicKeyBase64: String) -> String {
        guard let data = Data(base64Encoded: dataBase64), let keyData = Data(base64Encoded: publicKeyBase64) else { return "" }
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic]
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil), SecKeyIsAlgorithmSupported(key, .encrypt, .rsaEncryptionRaw), let encrypted = SecKeyCreateEncryptedData(key, .rsaEncryptionRaw, data as CFData, nil) else { return "" }
        return (encrypted as Data).base64EncodedString()
    }
}

private enum InsecureMD5 {
    static func hex(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH)); data.withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
