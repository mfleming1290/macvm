import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    init?(data: Data) {
        guard
            let headerRange = data.range(of: Data("\r\n\r\n".utf8)),
            let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8)
        else {
            return nil
        }

        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            return nil
        }

        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else {
            return nil
        }

        method = String(requestParts[0])

        let rawPath = String(requestParts[1])
        if let components = URLComponents(string: rawPath) {
            path = components.path
            var parsedQuery: [String: String] = [:]
            for item in components.queryItems ?? [] {
                if let value = item.value {
                    parsedQuery[item.name] = value
                }
            }
            query = parsedQuery
        } else {
            path = rawPath
            query = [:]
        }

        var parsedHeaders: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else {
                continue
            }

            let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            parsedHeaders[name] = value
        }
        headers = parsedHeaders

        let bodyStart = headerRange.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyEnd = min(data.count, bodyStart + contentLength)
        body = data[bodyStart..<bodyEnd]
    }
}

struct HTTPResponse {
    let statusCode: Int
    let statusText: String
    let headers: [String: String]
    let body: Data

    static func json<T: Encodable>(_ value: T, statusCode: Int = 200) -> HTTPResponse {
        let body = (try? JSONEncoder().encode(value)) ?? Data()
        return HTTPResponse(
            statusCode: statusCode,
            statusText: statusText(for: statusCode),
            headers: ["Content-Type": "application/json"],
            body: body
        )
    }

    static func error(_ error: AgentError) -> HTTPResponse {
        json(
            ErrorResponse(
                version: protocolVersion,
                error: ResponseError(
                    code: error.code,
                    message: error.localizedDescription
                )
            ),
            statusCode: error.statusCode
        )
    }

    static func text(_ text: String, statusCode: Int) -> HTTPResponse {
        HTTPResponse(
            statusCode: statusCode,
            statusText: statusText(for: statusCode),
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: Data(text.utf8)
        )
    }

    static func empty(statusCode: Int = 204) -> HTTPResponse {
        HTTPResponse(
            statusCode: statusCode,
            statusText: statusText(for: statusCode),
            headers: [:],
            body: Data()
        )
    }

    func serialized() -> Data {
        var responseHeaders = headers
        responseHeaders["Access-Control-Allow-Origin"] = "*"
        responseHeaders["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
        responseHeaders["Access-Control-Allow-Headers"] = "Content-Type"
        responseHeaders["Access-Control-Max-Age"] = "600"
        responseHeaders["Vary"] = "Origin"
        responseHeaders["Content-Length"] = "\(body.count)"
        responseHeaders["Connection"] = "close"

        var head = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (name, value) in responseHeaders {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"

        var data = Data(head.utf8)
        data.append(body)
        return data
    }

    private static func statusText(for statusCode: Int) -> String {
        switch statusCode {
        case 200:
            "OK"
        case 204:
            "No Content"
        case 400:
            "Bad Request"
        case 403:
            "Forbidden"
        case 404:
            "Not Found"
        case 405:
            "Method Not Allowed"
        case 500:
            "Internal Server Error"
        default:
            "OK"
        }
    }
}
