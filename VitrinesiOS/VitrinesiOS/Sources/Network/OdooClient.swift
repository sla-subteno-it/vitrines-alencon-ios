// OdooClient.swift
// Vitrines d'Alençon — iOS
// Couche réseau unique : l'app iOS ne parle qu'à Odoo.
// Odoo gère Adelya en coulisses.

import Foundation

// MARK: - Configuration

/// Environnement serveur (sélectionnable en DEBUG depuis l'écran de connexion).
enum OdooEnvironment: String, CaseIterable, Identifiable {
    case staging, prod
    var id: String { rawValue }
    var label: String { self == .staging ? "Staging" : "Production" }
    var baseURL: String {
        switch self {
        case .staging: return "https://staging.vitrines-alencon.fr"
        case .prod:    return "https://www.vitrines-alencon.fr"
        }
    }
}

enum OdooConfig {
#if DEBUG
    private static let envKey = "odoo_environment"
    /// Environnement courant (persisté). Par défaut : staging en debug.
    static var environment: OdooEnvironment {
        get { OdooEnvironment(rawValue: UserDefaults.standard.string(forKey: envKey) ?? "") ?? .staging }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: envKey) }
    }
    static var baseURL: String { environment.baseURL }
#else
    // Build Release / TestFlight / App Store → toujours la production.
    static let baseURL = "https://www.vitrines-alencon.fr"
#endif
    // La base est auto-détectée via /web/database/list (une seule base par
    // instance) — pas besoin de la coder en dur.
    static let jsonRPCPath = "/web/dataset/call_kw"
    static let sessionPath = "/web/session/authenticate"
    static let databaseListPath = "/web/database/list"
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

    /// Nom de la base mis en cache après première détection.
    private var cachedDatabase: String?

    // MARK: - Base de données (mono-base auto-détectée)

    /// Récupère le nom de la base via `/web/database/list` (une seule base par
    /// instance Odoo.sh). Mis en cache pour les appels suivants.
    func resolveDatabase() async throws -> String {
        if let cachedDatabase { return cachedDatabase }
        guard let url = URL(string: OdooConfig.baseURL + OdooConfig.databaseListPath) else {
            throw OdooError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["jsonrpc": "2.0", "method": "call", "params": [:]])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["result"] as? [String], let db = list.first else {
            throw OdooError.odooError(code: -1, message: "Base de données introuvable.")
        }
        cachedDatabase = db
        return db
    }

    // MARK: - Authentification

    func authenticate(login: String, password: String) async throws -> Int {
        let url = URL(string: OdooConfig.baseURL + OdooConfig.sessionPath)!
        let database = try await resolveDatabase()

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "call",
            "id": 1,
            "params": [
                "db": database,
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

    /// État de restauration de session au lancement.
    enum SessionState {
        case authenticated   // session valide côté serveur
        case expired         // serveur joignable mais session invalide → déconnexion
        case offline         // serveur injoignable (pas de réseau) → ne pas déconnecter
    }

    /// Tente de restaurer une session existante depuis le cookie persistant
    /// (HTTPCookieStorage survit au redémarrage de l'app). À appeler au lancement.
    /// Distingue le cas hors-ligne (réseau KO) du cas session réellement expirée.
    func restoreSession() async -> SessionState {
        guard let url = URL(string: OdooConfig.baseURL + "/web/session/get_session_info") else {
            return .offline
        }

        let body: [String: Any] = ["jsonrpc": "2.0", "method": "call", "params": [:]]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Erreur réseau (avion, pas de connexion) → on ne touche pas à la session.
            return .offline
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let uid = result["uid"] as? Int, uid > 0 else {
            // Serveur joignable mais pas de session valide → expirée.
            await OdooSession.shared.clear()
            return .expired
        }

        let name = result["name"] as? String ?? result["username"] as? String
        let sessionId = HTTPCookieStorage.shared.cookies(for: url)?
            .first(where: { $0.name == "session_id" })?.value

        await OdooSession.shared.set(sessionId: sessionId, uid: uid, name: name)
        return .authenticated
    }

    func logout() async {
        await OdooSession.shared.clear()
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
    }

    /// Réinitialise session, cookies et base mise en cache — à appeler lors d'un
    /// changement d'environnement (staging ↔ prod) en debug.
    func resetForEnvironmentSwitch() async {
        cachedDatabase = nil
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

    /// Demande de réinitialisation du mot de passe (`/web/reset_password`).
    /// Odoo envoie un email contenant le lien de réinitialisation. Reproduit le
    /// POST du formulaire web pour rester 100 % dans l'app (aucun navigateur).
    func requestPasswordReset(login: String) async throws {
        guard let csrf = await websiteCSRFToken(path: "/web/reset_password") else {
            throw OdooError.invalidResponse
        }
        let (code, html) = try await postForm(path: "/web/reset_password",
                                              params: ["login": login, "csrf_token": csrf])
        guard code == 200 else { throw OdooError.invalidResponse }
        // Succès Odoo : encart alert-success (« Un email a été envoyé… »).
        if html.contains("alert-success") { return }
        // Erreur explicite (ex. « Aucun compte trouvé pour cet identifiant »).
        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
        // Pas d'alerte détectable (ex. redirection /web/login) → demande prise en compte.
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
        if case .authenticated = await restoreSession() { return }

        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
        throw OdooError.odooError(code: -1, message: "La création du compte a échoué. Vérifiez vos informations et réessayez.")
    }

    // MARK: - Notifications push (OneSignal → Odoo)

    private func postJSON(path: String, body: [String: Any]) async {
        guard let url = URL(string: OdooConfig.baseURL + path) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }

    /// Enregistre l'abonnement push auprès d'Odoo (`/onesignal/subscribe`).
    /// La session courante permet de lier l'abonnement au partenaire connecté.
    func registerPushPlayer(playerId: String, deviceType: String = "ios") async {
        await postJSON(path: "/onesignal/subscribe",
                       body: ["player_id": playerId, "device_type": deviceType])
    }

    /// Désactive l'abonnement push côté Odoo (`/onesignal/unsubscribe`).
    func unregisterPushPlayer(playerId: String) async {
        await postJSON(path: "/onesignal/unsubscribe", body: ["player_id": playerId])
    }

    // MARK: - Compte portail (infos perso, sécurité)

    /// Enregistre les informations personnelles / adresse principale via le
    /// formulaire portail Odoo (`/my/address/submit`).
    func savePersonalInfo(partnerId: Int, fields: [String: String]) async throws {
        guard let csrf = await websiteCSRFToken(path: "/my/account") else {
            throw OdooError.invalidResponse
        }
        var params = fields
        params["csrf_token"] = csrf
        params["address_type"] = "billing"
        params["use_delivery_as_billing"] = "True"
        params["partner_id"] = String(partnerId)
        params["callback"] = "/my"
        params["required_fields"] = "name,email"

        let (code, html) = try await postForm(path: "/my/address/submit", params: params)
        guard code == 200 || code == 302 || code == 303 else { throw OdooError.invalidResponse }
        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
    }

    /// Change le mot de passe via le formulaire portail (`/my/security`).
    func changePassword(old: String, new: String) async throws {
        guard let csrf = await websiteCSRFToken(path: "/my/security") else {
            throw OdooError.invalidResponse
        }
        let (code, html) = try await postForm(path: "/my/security", params: [
            "op": "password", "old": old, "new1": new, "new2": new, "csrf_token": csrf
        ])
        guard code == 200 || code == 302 || code == 303 else { throw OdooError.invalidResponse }
        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
    }

    /// Enregistre les préférences de communication (opt-in email/SMS) via le
    /// formulaire portail `/ma-carte` (met aussi à jour Adelya côté serveur).
    func saveCommunicationPreferences(emailOptin: Bool, smsOptin: Bool) async throws {
        guard let csrf = await websiteCSRFToken(path: "/ma-carte") else {
            throw OdooError.invalidResponse
        }
        guard let url = URL(string: OdooConfig.baseURL + "/ma-carte") else {
            throw OdooError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded([
            "action": "update_communication_preferences",
            "email_optin": emailOptin ? "1" : "0",
            "sms_optin": smsOptin ? "1" : "0",
            "csrf_token": csrf
        ])

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OdooError.invalidResponse }
        let finalURL = response.url?.absoluteString ?? ""

        if finalURL.contains("success=1") { return }
        if finalURL.contains("error=") {
            let msg = URLComponents(string: finalURL)?
                .queryItems?.first(where: { $0.name == "error" })?.value?
                .removingPercentEncoding
            throw OdooError.odooError(code: -1, message: msg ?? "Échec de la mise à jour des préférences.")
        }
        guard http.statusCode == 200 else { throw OdooError.invalidResponse }
    }

    /// Supprime (désactive) le compte via le portail Odoo (`/my/deactivate_account`).
    /// `confirmation` doit correspondre à l'identifiant (email) de l'utilisateur.
    /// `blacklist` = retirer aussi les coordonnées des communications (RGPD).
    func deleteAccount(password: String, confirmation: String, blacklist: Bool) async throws {
        guard let csrf = await websiteCSRFToken(path: "/my/security") else {
            throw OdooError.invalidResponse
        }
        var params = [
            "password": password,
            "validation": confirmation,
            "csrf_token": csrf
        ]
        if blacklist { params["request_blacklist"] = "on" }

        let (code, html) = try await postForm(path: "/my/deactivate_account", params: params)
        guard code == 200 || code == 302 || code == 303 else { throw OdooError.invalidResponse }
        if let err = firstAlertText(in: html, kind: "alert-danger") {
            throw OdooError.odooError(code: -1, message: err)
        }
        // Succès : le compte est désactivé et la session invalidée côté serveur.
    }

    // MARK: - URL image Odoo

    func imageURL(model: String, recordId: Int, field: String = "image_1920", size: String = "400x400") -> URL? {
        URL(string: "\(OdooConfig.baseURL)/web/image/\(model)/\(recordId)/\(field)?width=\(size.split(separator: "x").first ?? "400")")
    }
}
