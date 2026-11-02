import Foundation
import Network

/// A test-only HTTP/1.1 server on 127.0.0.1. Per path it answers a scripted status, headers and body, or accepts and
/// never answers; it records each request's line, headers and body. One request per connection, closed after the
/// answer.
final class LocalReleaseServer: @unchecked Sendable {
    enum Reply: Sendable {
        case respond(status: Int, headers: [String: String] = [:], body: Data = Data())
        case neverAnswer
    }

    struct Request: Sendable, Equatable {
        let line: String
        /// In the order received, names as sent.
        let headers: [(name: String, value: String)]
        let body: Data

        static func == (a: Request, b: Request) -> Bool {
            a.line == b.line && a.body == b.body && a.headers.elementsEqual(b.headers) { $0 == $1 }
        }

        func header(_ name: String) -> String? {
            headers.first { $0.name.lowercased() == name.lowercased() }?.value
        }

        var path: String { line.split(separator: " ").dropFirst().first.map(String.init) ?? "" }
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "LocalReleaseServer")
    private let lock = NSLock()
    private var scripts: [String: [Reply]] = [:]
    private var served: [String: Int] = [:]
    private var recorded: [Request] = []
    private var connections: [NWConnection] = []
    let port: UInt16

    /// Listens until `stop()` or deinit.
    init() async throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let queue = queue
        port = try await withCheckedThrowingContinuation { continuation in
            let once = Once()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if once.first(), let port = listener.port?.rawValue { continuation.resume(returning: port) }
                case .failed(let error):
                    if once.first() { continuation.resume(throwing: error) }
                default: break
                }
            }
            listener.newConnectionHandler = { $0.cancel() }
            listener.start(queue: queue)
        }
        self.listener = listener
        listener.newConnectionHandler = { [unowned self] connection in accept(connection) }
    }

    deinit { stop() }

    func stop() {
        listener.cancel()
        lock.lock()
        let open = connections
        connections = []
        lock.unlock()
        open.forEach { $0.cancel() }
    }

    func url(path: String) -> URL { URL(string: "http://127.0.0.1:\(port)\(path)")! }

    /// The replies for `path`, one per request in order; the last one repeats.
    func script(_ path: String, _ replies: Reply...) {
        lock.lock()
        scripts[path] = replies
        lock.unlock()
    }

    var requests: [Request] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private func accept(_ connection: NWConnection) {
        lock.lock()
        connections.append(connection)
        lock.unlock()
        connection.start(queue: queue)
        receive(connection, buffered: Data())
    }

    private func receive(_ connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [self] data, _, isComplete, error in
            var buffer = buffered
            if let data { buffer.append(data) }
            if let request = Self.parse(buffer) {
                handle(request, on: connection)
            } else if error == nil, !isComplete {
                receive(connection, buffered: buffer)
            } else {
                connection.cancel()
            }
        }
    }

    /// nil until the head and the declared body have fully arrived.
    private static func parse(_ data: Data) -> Request? {
        let separator = Data("\r\n\r\n".utf8)
        guard let end = data.range(of: separator) else { return nil }
        let head = String(decoding: data[..<end.lowerBound], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let line = lines.removeFirst()
        let headers: [(name: String, value: String)] = lines.compactMap { text in
            guard let colon = text.firstIndex(of: ":") else { return nil }
            return (String(text[..<colon]), text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces))
        }
        let length = headers.first { $0.name.lowercased() == "content-length" }.flatMap { Int($0.value) } ?? 0
        let body = data[end.upperBound...]
        guard body.count >= length else { return nil }
        return Request(line: line, headers: headers, body: Data(body.prefix(length)))
    }

    private func handle(_ request: Request, on connection: NWConnection) {
        let reply: Reply?
        lock.lock()
        recorded.append(request)
        let path = request.path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let count = served[path, default: 0]
        served[path] = count + 1
        reply = scripts[path].map { $0[min(count, $0.count - 1)] }
        lock.unlock()

        switch reply {
        case nil:
            send(status: 404, headers: [:], body: Data(), on: connection)
        case .neverAnswer:
            break
        case .respond(let status, let headers, let body)?:
            send(status: status, headers: headers, body: body, on: connection)
        }
    }

    private func send(status: Int, headers: [String: String], body: Data, on connection: NWConnection) {
        var head = "HTTP/1.1 \(status) \(HTTPURLResponse.localizedString(forStatusCode: status))\r\n"
        head += "Content-Length: \(body.count)\r\nConnection: close\r\n"
        for (name, value) in headers { head += "\(name): \(value)\r\n" }
        head += "\r\n"
        connection.send(
            content: Data(head.utf8) + body, contentContext: .finalMessage, isComplete: true,
            completion: .contentProcessed { _ in connection.cancel() })
    }
}

private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    func first() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        defer { fired = true }
        return !fired
    }
}
