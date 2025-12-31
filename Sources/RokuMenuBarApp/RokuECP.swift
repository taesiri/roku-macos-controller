import Combine
import Darwin
import Foundation

struct RokuApp: Identifiable {
    let id: String
    let name: String
}

@MainActor
final class RokuViewModel: ObservableObject {
    @Published var hostInput: String = ""
    @Published private(set) var host: String = ""
    @Published private(set) var apps: [RokuApp] = []
    @Published var status: String = "Idle"

    private let defaultsKey = "rokuHost"

    init() {
        let savedHost = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
        host = savedHost
        hostInput = savedHost
        if !savedHost.isEmpty {
            refreshApps()
        }
    }

    func applyHostInput() {
        let trimmed = hostInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = "Enter a Roku IP address."
            return
        }
        host = trimmed
        UserDefaults.standard.set(host, forKey: defaultsKey)
        status = "Using \(host)"
        refreshApps()
    }

    func discover() {
        status = "Discovering on local network..."
        Task {
            let hosts = await RokuSSDP.discoverAsync(timeout: 3)
            if let first = hosts.first {
                host = first
                hostInput = first
                UserDefaults.standard.set(first, forKey: defaultsKey)
                status = "Discovered \(first)"
                refreshApps()
            } else {
                status = "No Roku found."
            }
        }
    }

    func keypress(_ key: String) {
        guard ensureHost() else { return }
        let client = RokuClient(host: host)
        let path = "/keypress/\(encode(key))"
        Task {
            do {
                _ = try await client.post(path: path)
                status = "Sent \(path)"
            } catch {
                status = "Failed to send \(key)."
            }
        }
    }

    func launchApp(named name: String, fallbackId: String) {
        guard ensureHost() else { return }
        let appId = apps.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.id ?? fallbackId
        let client = RokuClient(host: host)
        let path = "/launch/\(encode(appId))"
        Task {
            do {
                _ = try await client.post(path: path)
                status = "Launched \(name)."
            } catch {
                status = "Failed to launch \(name)."
            }
        }
    }

    func refreshApps() {
        guard ensureHost() else { return }
        let client = RokuClient(host: host)
        Task {
            do {
                let data = try await client.get(path: "/query/apps")
                let parser = RokuAppsParser()
                if let list = parser.parse(data: data) {
                    apps = list
                    status = "Loaded \(list.count) apps."
                } else {
                    status = "Failed to parse apps list."
                }
            } catch {
                status = "Failed to load apps."
            }
        }
    }

    func typeText(_ text: String) {
        guard ensureHost() else { return }
        let characters = Array(text)
        guard !characters.isEmpty else { return }
        status = "Typing..."
        let client = RokuClient(host: host)
        Task {
            for ch in characters {
                let lit = "Lit_\(ch)"
                let path = "/keypress/\(encode(lit))"
                _ = try? await client.post(path: path)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            status = "Typed \(characters.count) chars."
        }
    }

    private func ensureHost() -> Bool {
        if host.isEmpty {
            status = "Set a Roku IP or run Auto-Discover."
            return false
        }
        return true
    }

    private func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }
}

enum RokuError: Error {
    case invalidURL
    case badResponse(Int)
}

struct RokuClient {
    let host: String

    func get(path: String) async throws -> Data {
        guard let url = makeURL(path: path) else { throw RokuError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else { throw RokuError.badResponse(statusCode) }
        return data
    }

    func post(path: String) async throws -> Int {
        guard let url = makeURL(path: path) else { throw RokuError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        let (_, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else { throw RokuError.badResponse(statusCode) }
        return statusCode
    }

    private func makeURL(path: String) -> URL? {
        let hostValue = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostValue.isEmpty else { return nil }
        return URL(string: "http://\(hostValue):8060\(path)")
    }
}

struct RokuSSDP {
    static func discoverAsync(timeout: TimeInterval) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let hosts = discover(timeout: timeout)
                continuation.resume(returning: hosts)
            }
        }
    }

    static func discover(timeout: TimeInterval) -> [String] {
        let message = (
            "M-SEARCH * HTTP/1.1\r\n" +
            "HOST: 239.255.255.250:1900\r\n" +
            "MAN: \"ssdp:discover\"\r\n" +
            "ST: roku:ecp\r\n" +
            "MX: 2\r\n" +
            "\r\n"
        )

        var hosts: [String] = []
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return hosts }
        defer { close(sock) }

        var timeoutValue = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeoutValue, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(1900).bigEndian
        addr.sin_addr = in_addr(s_addr: inet_addr("239.255.255.250"))

        let sent = message.withCString { ptr in
            var sockAddr = sockaddr()
            memcpy(&sockAddr, &addr, MemoryLayout<sockaddr_in>.size)
            return sendto(sock, ptr, strlen(ptr), 0, &sockAddr, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        guard sent >= 0 else { return hosts }

        let endTime = Date().addingTimeInterval(timeout)
        while Date() < endTime {
            var buffer = [UInt8](repeating: 0, count: 4096)
            var fromAddr = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &fromAddr) { ptr -> ssize_t in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    return recvfrom(sock, &buffer, buffer.count, 0, sockPtr, &fromLen)
                }
            }
            if count <= 0 {
                continue
            }
            let response = String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
            if let host = parseLocationHost(from: response) {
                if !hosts.contains(host) {
                    hosts.append(host)
                }
            }
        }
        return hosts
    }

    private static func parseLocationHost(from response: String) -> String? {
        for line in response.split(whereSeparator: \.isNewline) {
            let lower = line.lowercased()
            if lower.hasPrefix("location:") {
                let value = line.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)
                if let url = URL(string: value), let host = url.host {
                    return host
                }
            }
        }
        return nil
    }
}

final class RokuAppsParser: NSObject, XMLParserDelegate {
    private var apps: [RokuApp] = []
    private var currentId: String = ""
    private var currentName: String = ""
    private var inApp = false

    func parse(data: Data) -> [RokuApp]? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        let ok = parser.parse()
        return ok ? apps : nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "app" {
            inApp = true
            currentId = attributeDict["id"] ?? ""
            currentName = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inApp {
            currentName += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "app" {
            let name = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !currentId.isEmpty && !name.isEmpty {
                apps.append(RokuApp(id: currentId, name: name))
            }
            inApp = false
        }
    }
}
