import Foundation
import Network

final class SignalingServer {
    private let port: UInt16
    private let sessionManager: SessionManager
    private let onStatusChanged: (String) -> Void
    private var listener: NWListener?

    init(
        port: UInt16,
        sessionManager: SessionManager,
        onStatusChanged: @escaping (String) -> Void
    ) {
        self.port = port
        self.sessionManager = sessionManager
        self.onStatusChanged = onStatusChanged
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onStatusChanged("Listening on :\(self?.port ?? 0)")
            case .failed(let error):
                self?.onStatusChanged("Failed: \(error.localizedDescription)")
            default:
                break
            }
        }

        listener.start(queue: .main)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.send(.text(error.localizedDescription, statusCode: 500), on: connection)
                return
            }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if self.hasCompleteHTTPRequest(nextBuffer) || isComplete {
                Task {
                    let response = await self.response(for: nextBuffer)
                    self.send(response, on: connection)
                }
            } else {
                self.receive(on: connection, buffer: nextBuffer)
            }
        }
    }

    private func hasCompleteHTTPRequest(_ data: Data) -> Bool {
        guard
            let headerRange = data.range(of: Data("\r\n\r\n".utf8)),
            let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8)
        else {
            return false
        }

        let contentLength = headerText
            .split(separator: "\r\n")
            .compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, parts[0].lowercased() == "content-length" else {
                    return nil
                }
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
            .first ?? 0

        return data.count >= headerRange.upperBound + contentLength
    }

    private func response(for data: Data) async -> HTTPResponse {
        guard let request = HTTPRequest(data: data) else {
            return .text("Malformed HTTP request.", statusCode: 400)
        }

        if request.method == "OPTIONS" {
            return .empty()
        }

        do {
            return try await route(request)
        } catch let error as AgentError {
            return .error(error)
        } catch DecodingError.dataCorrupted,
                DecodingError.keyNotFound,
                DecodingError.typeMismatch,
                DecodingError.valueNotFound {
            return .error(.invalidJSON)
        } catch {
            return .text(error.localizedDescription, statusCode: 500)
        }
    }

    private func route(_ request: HTTPRequest) async throws -> HTTPResponse {
        let parts = request.path.split(separator: "/").map(String.init)

        if request.method == "GET", request.path == "/api/health" {
            return .json(
                HealthResponse(
                    version: protocolVersion,
                    status: sessionManager.healthStatus,
                    activeSession: sessionManager.hasActiveSession,
                    screenRecordingAllowed: ScreenRecordingPermission.isGranted,
                    accessibilityAllowed: AccessibilityPermission.isGranted,
                    sessionStatus: sessionManager.status,
                    serverStatus: "Listening on :\(port)",
                    lastError: sessionManager.lastError,
                    media: sessionManager.mediaDiagnostics,
                    control: sessionManager.controlDiagnostics
                )
            )
        }

        if request.method == "POST", request.path == "/api/sessions" {
            let payload = try JSONDecoder().decode(CreateSessionRequest.self, from: request.body)
            guard payload.version == protocolVersion else {
                throw AgentError.unsupportedProtocolVersion
            }
            let response = try await sessionManager.createSession(from: payload.offer)
            return .json(response)
        }

        if parts.count == 4, parts[0] == "api", parts[1] == "sessions", parts[3] == "ice" {
            let sessionId = parts[2]

            if request.method == "POST" {
                let payload = try JSONDecoder().decode(AddIceCandidateRequest.self, from: request.body)
                guard payload.version == protocolVersion else {
                    throw AgentError.unsupportedProtocolVersion
                }
                try sessionManager.addIceCandidate(payload.candidate, to: sessionId)
                return .empty()
            }

            if request.method == "GET" {
                let cursor = Int(request.query["since"] ?? "0") ?? 0
                return .json(try sessionManager.localCandidates(for: sessionId, since: cursor))
            }
        }

        if parts.count == 3, parts[0] == "api", parts[1] == "sessions", request.method == "DELETE" {
            await sessionManager.closeSession(id: parts[2])
            return .empty()
        }

        throw AgentError.notFound
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
