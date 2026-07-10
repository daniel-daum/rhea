import Foundation
import Network

/// Minimal in-process HTTP/1.1 server that speaks just enough of the OpenAI
/// chat-completions response shape to stand in for LM Studio / oMLX in tests.
/// Binds to a loopback port chosen by the OS — no real network access, no
/// external service involved. One instance serves one canned response.
final class StubExtractionServer {
    enum StubError: Error { case timedOut, notStarted }

    private let listener: NWListener
    private let responseBytes: Data
    private let queue = DispatchQueue(label: "StubExtractionServer")
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    private(set) var port: UInt16 = 0

    /// - Parameter modelResponseContent: raw text the "model" emits as `choices[0].message.content`
    ///   (may include markdown fences / leading prose — exactly what a real model would return).
    init(modelResponseContent: String, statusCode: Int = 200) throws {
        let chatResponse: [String: Any] = [
            "choices": [
                ["message": ["content": modelResponseContent]]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: chatResponse)

        let statusLine = "HTTP/1.1 \(statusCode) \(StubExtractionServer.reason(for: statusCode))\r\n"
        var head = statusLine
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Connection: close\r\n"
        head += "\r\n"

        var bytes = Data(head.utf8)
        bytes.append(body)
        self.responseBytes = bytes

        self.listener = try NWListener(using: .tcp, on: .any)
    }

    /// Starts listening on loopback and blocks until a port is assigned.
    func start() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var startError: Error?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                startError = error
                semaphore.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)

        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            throw StubError.timedOut
        }
        if let startError { throw startError }
        guard let assignedPort = listener.port?.rawValue else { throw StubError.notStarted }
        port = assignedPort
    }

    func stop() {
        listener.cancel()
        queue.sync {
            connections.values.forEach { $0.cancel() }
            connections.removeAll()
        }
    }

    var endpoint: String {
        "http://127.0.0.1:\(port)/v1/chat/completions"
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.drop(connection) }
            if case .cancelled = state { self?.drop(connection) }
        }
        connection.start(queue: queue)
        readRequest(on: connection, buffer: Data())
    }

    private func drop(_ connection: NWConnection) {
        connections.removeValue(forKey: ObjectIdentifier(connection))
    }

    // Reads until the header terminator, then drains any declared body before responding.
    private func readRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            guard error == nil else { self.drop(connection); connection.cancel(); return }

            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer[..<headerEnd.lowerBound]
                let headerText = String(data: headerData, encoding: .utf8) ?? ""
                let contentLength = StubExtractionServer.contentLength(fromHeaders: headerText)
                let bodySoFar = buffer.distance(from: headerEnd.upperBound, to: buffer.endIndex)

                if bodySoFar >= contentLength {
                    self.respond(on: connection)
                } else {
                    self.readRequest(on: connection, buffer: buffer)
                }
                return
            }

            if isComplete {
                self.respond(on: connection)
                return
            }

            self.readRequest(on: connection, buffer: buffer)
        }
    }

    private func respond(on connection: NWConnection) {
        connection.send(content: responseBytes, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            self?.drop(connection)
        })
    }

    private static func contentLength(fromHeaders headerText: String) -> Int {
        for line in headerText.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].caseInsensitiveCompare("Content-Length") == .orderedSame else { continue }
            return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return 0
    }

    private static func reason(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 500: return "Internal Server Error"
        default:  return "Unknown"
        }
    }
}
