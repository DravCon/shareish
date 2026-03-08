//
//  APIClient.swift
//  Shareish
//

import Foundation

/// Posted when the server returns 401 and the client clears the stored session.
extension Notification.Name {
    static let shareishSessionExpired = Notification.Name("ShareishSessionExpired")
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, detail: String? = nil)
    case unauthorized(String?)
    case decoding(Error)
    case encoding(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpStatus(let code, let detail):
            if let detail = detail, !detail.isEmpty { return "\(detail)" }
            return "Server error (HTTP \(code))"
        case .unauthorized(let detail): return detail ?? "Session expired. Please sign in again."
        case .decoding(let e): return "Decoding error: \(e.localizedDescription)"
        case .encoding(let e): return "Encoding error: \(e.localizedDescription)"
        case .noData: return "No data received"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    /// Base URL with no trailing slash (e.g. http://localhost:8000/api/v1)
    private var baseURL: String {
        let url = ServerConfig.baseURL
        return url.hasSuffix("/") ? String(url.dropLast()) : url
    }
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var authToken: String?

    init() {
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let isoWithFrac = ISO8601DateFormatter()
            isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoWithFrac.date(from: str) { return d }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: str) { return d }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = fmt.date(from: str) { return d }
            fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let d = fmt.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    /// Clear stored token and notify so the app can show login again (e.g. after 401).
    private func clearSessionAndNotify() {
        authToken = nil
        KeychainHelper.deleteToken()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .shareishSessionExpired, object: nil)
        }
    }

    private func url(for path: String, query: [String: String]? = nil) throws -> URL {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        let full = baseURL + normalizedPath
        var components = URLComponents(string: full)
        components?.queryItems = query?.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw APIError.invalidURL }
        return url
    }

    private func request(url: URL, method: String, body: Data? = nil, isMultipart: Bool = false, multipartBoundary: String? = nil) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if isMultipart, let boundary = multipartBoundary {
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        } else if body != nil && !isMultipart {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if let token = await authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 {
            await clearSessionAndNotify()
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw APIError.unauthorized(detail)
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw APIError.httpStatus(http.statusCode, detail: detail)
        }
        return (data, http)
    }

    func get<T: Decodable>(_ path: String, query: [String: String]? = nil) async throws -> T {
        let requestURL = try url(for: path, query: query)
        let (data, _) = try await request(url: requestURL, method: "GET")
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data: Data
        do {
            data = try encoder.encode(AnyEncodable(body))
        } catch {
            throw APIError.encoding(error)
        }
        let requestURL = try url(for: path)
        let (responseData, httpResponse) = try await request(url: requestURL, method: "POST", body: data)
        guard !responseData.isEmpty else {
            throw APIError.decoding(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response from server (status \(httpResponse.statusCode))"]))
        }
        do {
            return try decoder.decode(T.self, from: responseData)
        } catch {
            let bodyPreview = String(data: responseData, encoding: .utf8) ?? "<non-UTF8>"
            throw APIError.decoding(NSError(domain: "APIClient", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Decoding failed: \(error.localizedDescription). Response: \(bodyPreview.prefix(200))"
            ]))
        }
    }

    func post(_ path: String, body: some Encodable) async throws {
        let data: Data
        do {
            data = try encoder.encode(AnyEncodable(body))
        } catch {
            throw APIError.encoding(error)
        }
        let requestURL = try url(for: path)
        _ = try await request(url: requestURL, method: "POST", body: data)
    }

    func patch<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data: Data
        do {
            data = try encoder.encode(AnyEncodable(body))
        } catch {
            throw APIError.encoding(error)
        }
        let requestURL = try url(for: path)
        let (responseData, _) = try await request(url: requestURL, method: "PATCH", body: data)
        do {
            return try decoder.decode(T.self, from: responseData)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Upload image for AI identification. Multipart form with field "photo".
    func uploadImage(_ path: String, imageData: Data, filename: String = "photo.jpg") async throws -> AIIdentification {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let url = try url(for: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if let token = await authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 401 {
            await clearSessionAndNotify()
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw APIError.unauthorized(detail)
        }
        guard (200...299).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
            throw APIError.httpStatus(http.statusCode, detail: detail)
        }
        do {
            return try decoder.decode(AIIdentification.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

/// Type-erased Encodable for generic post/patch body.
private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
