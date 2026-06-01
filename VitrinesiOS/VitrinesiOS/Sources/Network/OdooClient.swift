// OdooClient.swift
// Vitrines d'Alençon — iOS
// Couche réseau unique : l'app iOS ne parle qu'à Odoo.
// Odoo gère Adelya en coulisses.

import Foundation

// MARK: - Configuration

enum OdooConfig {
#if DEBUG
    // Build Debug (lancé depuis Xcode) → serveur de staging (Odoo.sh)
    // On vise l'URL Odoo.sh native (cert *.dev.odoo.com valide) et non
    // staging.vitrines-alencon.fr, dont le domaine custom n'a pas encore
    // de certificat provisionné → erreur TLS sinon.
    static let baseURL  = "https://subteno-it-vitrines-alencon-staging-32921774.dev.odoo.com"
    static let database = "subteno-it-vitrines-alencon-staging-32921774"
#else
    // Build Release / TestFlight / App Store → production
    static let baseURL  = "https://www.vitrines-alencon.fr"
    static let database = "subteno-it-vitrines-alencon-master-25376606"
#endif
    static let jsonRPCPath = "/web/dataset/call_kw"
    static let sessionPath = "/web/session/authenticate"
}

// MARK: - Erreurs

enum OdooError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case odooError(code: Int, message: String)
    case decodingError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "URL invalide"
        case .networkError(let e): return "Erreur réseau : \(e.localizedDescription)"
        case .invalidResponse:     return "Réponse serveur invalide"
        case .odooError(_, let m): return m
        case .decodingError(let e): return "Erreur de décodage : \(e.localizedDescription)"
        case .unauthorized:         return "Session expirée, veuillez vous reconnecter"
        }
    }
}

// MARK: - JSON-RPC types

struct JSONRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let method  = "call"
    let id      = 1
    let params:  JSONRPCParams
}

struct JSONRPCParams: Encodable {
    let model:  String
    let method: String
    let args:   [AnyCodable]
    let kwargs: [String: AnyCodable]
}

struct JSONRPCResponse<T: Decodable>: Decodable {
    let result: T?
    let error:  JSONRPCError?
}

struct JSONRPCError: Decodable {
    let code:    Int
    let message: String
    let data:    JSONRPCErrorData?
}

struct JSONRPCErrorData: Decodable {
    let message: String?
}

// MARK: - AnyCodable (wrapper générique)

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)   { value = v; return }
        if let v = try? container.decode(Int.self)    { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([String: AnyCodable].self) { value = v; return }
        if let v = try? container.decode([AnyCodable].self) { value = v.map { $0.value }; return }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:                     try container.encode(v)
        case let v as Int:                      try container.encode(v)
        case let v as Double:                   try container.encode(v)
        case let v as String:                   try container.encode(v)
        case let v as [String: AnyCodable]:     try container.encode(v)
        case let v as [Any]:
            let wrapped = v.map { AnyCodable($0) }
            try container.encode(wrapped)
        default:                                try container.encodeNil()
        }
    }
}

// MARK: - Session Odoo

actor OdooSession {
    static let shared = OdooSession()
    private var sessionId: String?
    private var uid: Int?
    private var userName: String?

    func set(sessionId: String?, uid: Int?, name: String? = nil) {
        self.sessionId = sessionId
        self.uid = uid
        self.userName = name
    }

    func getSessionId() -> String? { sessionId }
    func getUID() -> Int? { uid }
    func getUserName() -> String? { userName }
    func isAuthenticated() -> Bool { uid != nil }

    func clear() {
        sessionId = nil
        uid = nil
        userName = nil
    }
}

// MARK: - Client principal

final class OdooClient {
    static let shared = OdooClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    // ⚠️ Pas de .convertFromSnakeCase : tous les modèles déclarent des CodingKeys
    // explicites en snake_case ("company_brief", "ordered_reference_ids"…).
    // Combiner les deux casse le décodage (la stratégie convertit la clé JSON en
    // camelCase, qui ne matche plus la CodingKey snake_case → champ silencieusement nil).
    private let decoder = JSONDecoder()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private init() {}

    // MARK: - Authentification

    func authenticate(login: String, password: String) async throws -> Int {
        let url = URL(string: OdooConfig.baseURL + OdooConfig.sessionPath)!

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "call",
            "id": 1,
            "params": [
                "db": OdooConfig.database,
                "login": login,
                "password": password
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OdooError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let uid = result["uid"] as? Int, uid > 0 else {
            throw OdooError.unauthorized
        }

        let name = result["name"] as? String ?? result["username"] as? String

        // Récupérer le session_id depuis les cookies
        let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
        let sessionId = cookies.first(where: { $0.name == "session_id" })?.value

        await OdooSession.shared.set(sessionId: sessionId, uid: uid, name: name)
        return uid
    }

    /// Tente de restaurer une session existante depuis le cookie persistant
    /// (HTTPCookieStorage survit au redémarrage de l'app). À appeler au lancement.
    @discardableResult
    func restoreSession() async -> Bool {
        guard let url = URL(string: OdooConfig.baseURL + "/web/session/get_session_info") else {
            return false
        }

        let body: [String: Any] = ["jsonrpc": "2.0", "method": "call", "params": [:]]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let uid = result["uid"] as? Int, uid > 0 else {
            await OdooSession.shared.clear()
            return false
        }

        let name = result["name"] as? String ?? result["username"] as? String
        let sessionId = HTTPCookieStorage.shared.cookies(for: url)?
            .first(where: { $0.name == "session_id" })?.value

        await OdooSession.shared.set(sessionId: sessionId, uid: uid, name: name)
        return true
    }

    func logout() async {
        await OdooSession.shared.clear()
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }

    // MARK: - Appel JSON-RPC générique

    func call<T: Decodable>(
        model: String,
        method: String,
        args: [Any] = [],
        kwargs: [String: Any] = [:]
    ) async throws -> T {
        let url = URL(string: OdooConfig.baseURL + OdooConfig.jsonRPCPath)!

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "call",
            "id": 1,
            "params": [
                "model": model,
                "method": method,
                "args": args,
                "kwargs": kwargs
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OdooError.invalidResponse
        }

        if http.statusCode == 401 {
            await OdooSession.shared.clear()
            throw OdooError.unauthorized
        }

        guard http.statusCode == 200 else {
            throw OdooError.invalidResponse
        }

        // Vérifier les erreurs JSON-RPC
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let errorData = error["data"] as? [String: Any]
            let exceptionName = errorData?["name"] as? String ?? ""

            // Odoo renvoie une session expirée en HTTP 200 + code 100
            // (SessionExpiredException), pas en 401.
            if code == 100 || exceptionName == "odoo.http.SessionExpiredException" {
                await OdooSession.shared.clear()
                throw OdooError.unauthorized
            }

            let message = errorData?["message"] as? String
                       ?? error["message"] as? String
                       ?? "Erreur inconnue"
            throw OdooError.odooError(code: code, message: message)
        }

        do {
            let decoded = try decoder.decode(JSONRPCResponse<T>.self, from: data)
            if let result = decoded.result {
                return result
            }
            throw OdooError.invalidResponse
        } catch let e as OdooError {
            throw e
        } catch {
            throw OdooError.decodingError(error)
        }
    }

    // MARK: - Appel d'une route JSON-RPC custom (controllers type="jsonrpc")

    /// Appelle une route Odoo custom déclarée en `type="jsonrpc"` (ex:
    /// `/scanner-carte-cadeau/scan`). Le corps suit l'enveloppe JSON-RPC
    /// standard avec `params` = les arguments nommés du contrôleur.
    func callRoute<T: Decodable>(_ path: String, params: [String: Any] = [:]) async throws -> T {
        guard let url = URL(string: OdooConfig.baseURL + path) else {
            throw OdooError.invalidURL
        }

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "call",
            "id": 1,
            "params": params
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OdooError.invalidResponse
        }

        if http.statusCode == 401 {
            await OdooSession.shared.clear()
            throw OdooError.unauthorized
        }

        guard http.statusCode == 200 else {
            throw OdooError.invalidResponse
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let errorData = error["data"] as? [String: Any]
            let exceptionName = errorData?["name"] as? String ?? ""
            if code == 100 || exceptionName == "odoo.http.SessionExpiredException" {
                await OdooSession.shared.clear()
                throw OdooError.unauthorized
            }
            let message = errorData?["message"] as? String
                       ?? error["message"] as? String
                       ?? "Erreur inconnue"
            throw OdooError.odooError(code: code, message: message)
        }

        do {
            let decoded = try decoder.decode(JSONRPCResponse<T>.self, from: data)
            if let result = decoded.result {
                return result
            }
            throw OdooError.invalidResponse
        } catch let e as OdooError {
            throw e
        } catch {
            throw OdooError.decodingError(error)
        }
    }

    // MARK: - Requête HTTP simple (pour les endpoints web /merchants)

    func get(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(string: OdooConfig.baseURL + path)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw OdooError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OdooError.invalidResponse
        }

        return data
    }

    // MARK: - Formulaire website Odoo (/website/form)

    /// Récupère le jeton CSRF de la page website indiquée (session courante).
    func websiteCSRFToken(path: String = "/contact") async -> String? {
        guard let data = try? await get(path: path),
              let html = String(data: data, encoding: .utf8) else { return nil }

        let patterns = [
            #"name="csrf_token"\s+value="([^"]+)""#,
            #"value="([^"]+)"\s+name="csrf_token""#,
            #"csrf_token\s*[:=]\s*["']([^"']+)["']"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    /// Soumet le formulaire de contact website (modèle `mail.mail`).
    /// Renvoie true si Odoo a accepté l'envoi.
    func submitContactForm(fields: [String: String]) async throws -> Bool {
        guard let csrf = await websiteCSRFToken(path: "/contact") else {
            throw OdooError.invalidResponse
        }
        guard let url = URL(string: OdooConfig.baseURL + "/website/form/mail.mail") else {
            throw OdooError.invalidURL
        }

        var payload = fields
        payload["csrf_token"] = csrf
        payload["email_to"] = "contact@vitrines-alencon.fr"

        let boundary = "----VitrinesAlenconFormBoundary7MA4YWxkTrZu0gW"
        var body = Data()
        for (key, value) in payload {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OdooError.invalidResponse
        }

        // Odoo renvoie {"id": <int>} en cas de succès, {"error"...} sinon.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if json["id"] != nil { return true }
            if let error = json["error"] as? String { throw OdooError.odooError(code: -1, message: error) }
        }
        return false
    }

    // MARK: - Inscription & activation de compte

    private func formURLEncoded(_ params: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = params.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }
        return pairs.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    private func postForm(path: String, params: [String: String]) async throws -> (Int, String) {
        guard let url = URL(string: OdooConfig.baseURL + path) else { throw OdooError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded(params)
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let html = String(data: data, encoding: .utf8) ?? ""
        return (code, html)
    }

    /// Extrait le texte du premier encart d'alerte (succès ou erreur) d'une page HTML.
    private func firstAlertText(in html: String, kind: String) -> String? {
        guard let range = html.range(of: kind) else { return nil }
        let snippet = String(html[range.upperBound...].prefix(900))
        let stripped = snippet.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : String(stripped.prefix(220))
    }

    /// Demande d'activation d'un compte existant (`/activer-mon-compte`).
    /// Le serveur renvoie toujours un succès générique si l'email est inconnu (sécurité).
    func requestAccountActivation(email: String) async throws -> Bool {
        guard let csrf = await websiteCSRFToken(path: "/activer-mon-compte") else {
            throw OdooError.invalidResponse
        }
        let (code, html) = try await postForm(path: "/activer-mon-compte",
                                              params: ["email": email, "csrf_token": csrf])
        guard code == 200 else { throw OdooError.invalidResponse }
        if html.contains("alert-success") || html.contains("o_activate_message") { return true }
        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
        return true
    }

    /// Inscription (création de carte) via `/web/signup`. En cas de succès, Odoo
    /// connecte l'utilisateur (cookie de session) ; on restaure alors la session.
    func signup(fields: [String: String]) async throws {
        guard let csrf = await websiteCSRFToken(path: "/web/signup") else {
            throw OdooError.invalidResponse
        }
        var params = fields
        params["csrf_token"] = csrf
        params["redirect"] = "/mobile-menu"
        params["token"] = ""
        let (_, html) = try await postForm(path: "/web/signup", params: params)

        // Succès = session connectée (cookie posé par le POST).
        if await restoreSession() { return }

        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
        throw OdooError.odooError(code: -1, message: "La création du compte a échoué. Vérifiez vos informations et réessayez.")
    }

    // MARK: - URL image Odoo

    func imageURL(model: String, recordId: Int, field: String = "image_1920", size: String = "400x400") -> URL? {
        URL(string: "\(OdooConfig.baseURL)/web/image/\(model)/\(recordId)/\(field)?width=\(size.split(separator: "x").first ?? "400")")
    }
}
