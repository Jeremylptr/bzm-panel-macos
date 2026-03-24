import Foundation
import Security

private let wixBaseURL = "https://www.bluezonemarkets.com/_functions"

// ── Log-Helfer ────────────────────────────────────────────────────────────────

private func log(_ msg: String) {
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(ts)] [Auth] \(msg)")
}

// ── Ergebnis-Typen ────────────────────────────────────────────────────────────

enum AuthResult {
    case success(email: String, name: String)
    case failure(reason: String)
    case networkError
}

enum VerifyResult {
    case valid(email: String)
    case invalid(reason: String)
    case networkError
}

// ── AuthService ───────────────────────────────────────────────────────────────

@MainActor
final class AuthService: ObservableObject {

    @Published var isAuthenticated  = false
    @Published var isLoading        = false
    @Published var userEmail        = ""
    @Published var authError: String? = nil

    // Abo-Infos (werden bei Login + Verify befüllt)
    @Published var planName:         String = ""
    @Published var subscriptionExpiry: Date? = nil
    @Published var lastCheckedAt:    Date? = nil
    @Published var isCheckingInBackground = false

    static let shared = AuthService()
    private var backgroundTask: Task<Void, Never>? = nil
    private init() {}

    // MARK: - Hintergrund-Abo-Check (alle 60 Minuten)

    func startBackgroundChecks() {
        stopBackgroundChecks()
        backgroundTask = Task { [weak self] in
            // Erster Check nach 60 Minuten
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.backgroundVerify()
            }
        }
        log("→ Hintergrund-Abo-Check gestartet (alle 60 Min)")
    }

    func stopBackgroundChecks() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }

    /// Stiller Hintergrund-Check: prüft Token + Abo, sperrt App bei Fehler
    private func backgroundVerify() async {
        log("→ Hintergrund-Abo-Check läuft…")
        isCheckingInBackground = true
        defer { isCheckingInBackground = false }

        let result = await verifyOnStartup()
        switch result {
        case .valid:
            log("✓ Hintergrund-Check: Abo gültig")
        case .invalid(let reason):
            log("✗ Hintergrund-Check: Abo ungültig — \(reason)")
            // App sperren: zurück zum Login
        case .networkError:
            log("⚠ Hintergrund-Check: Netzwerkfehler — behalte aktuellen Status")
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async -> AuthResult {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let cleanEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
        log("→ Login-Anfrage für: \(cleanEmail)")
        log("  URL: \(wixBaseURL)/appLogin")

        guard let url = URL(string: "\(wixBaseURL)/appLogin") else {
            log("✗ Ungültige URL")
            return .networkError
        }

        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["email": cleanEmail, "password": password]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            log("✗ JSON-Serialisierung fehlgeschlagen")
            return .networkError
        }
        req.httpBody = bodyData
        log("  Request-Body: email=\(cleanEmail), password=\(String(repeating: "•", count: password.count))")

        do {
            log("  Sende Request…")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                log("✗ Kein HTTP-Response erhalten")
                return .networkError
            }

            log("  HTTP Status: \(http.statusCode)")

            let rawBody = String(data: data, encoding: .utf8) ?? "(kein Body)"
            log("  Response-Body: \(rawBody)")

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log("✗ JSON-Parsing fehlgeschlagen")
                return .networkError
            }

            if let success = json["success"] as? Bool, success,
               let token = json["token"] as? String {
                let resultEmail = json["email"] as? String ?? cleanEmail
                let name        = json["name"]  as? String ?? ""
                let plan        = json["planName"] as? String ?? "?"

                let expiry = (json["expiresAt"] as? String).flatMap { parseISO($0) }

                saveToken(token)
                saveEmail(resultEmail)
                savePlan(plan)
                self.isAuthenticated     = true
                self.userEmail           = resultEmail
                self.planName            = plan
                self.subscriptionExpiry  = expiry
                self.lastCheckedAt       = Date()

                log("✓ Login erfolgreich!")
                log("  Email: \(resultEmail), Name: \(name), Plan: \(plan)")
                log("  Token gespeichert: \(token.prefix(8))…")
                if let exp = expiry { log("  Läuft ab: \(exp)") }
                return .success(email: resultEmail, name: name)
            } else {
                let reason = json["reason"] as? String ?? "Unbekannter Fehler"
                authError = reason
                log("✗ Login abgelehnt: \(reason)")
                return .failure(reason: reason)
            }
        } catch {
            log("✗ Netzwerkfehler: \(error.localizedDescription)")
            return .networkError
        }
    }

    // MARK: - Verify

    func verifyOnStartup() async -> VerifyResult {
        log("→ App-Start: Token-Prüfung")

        guard let token = loadToken() else {
            log("  Kein Token im Keychain — zeige Login")
            isAuthenticated = false
            return .invalid(reason: "Nicht angemeldet")
        }

        log("  Token gefunden: \(token.prefix(8))…")
        log("  URL: \(wixBaseURL)/verifyToken")

        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(wixBaseURL)/verifyToken") else {
            log("✗ Ungültige URL — Offline-Modus")
            isAuthenticated = true
            userEmail = loadEmail() ?? ""
            planName  = loadPlan()  ?? ""
            return .networkError
        }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let bodyData = try? JSONSerialization.data(withJSONObject: ["token": token]) else {
            log("✗ JSON-Serialisierung fehlgeschlagen — Offline-Modus")
            isAuthenticated = true
            userEmail = loadEmail() ?? ""
            return .networkError
        }
        req.httpBody = bodyData

        do {
            log("  Sende Verify-Request…")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                log("✗ Kein HTTP-Response — Offline-Modus")
                isAuthenticated = true
                userEmail = loadEmail() ?? ""
                return .networkError
            }

            log("  HTTP Status: \(http.statusCode)")

            let rawBody = String(data: data, encoding: .utf8) ?? "(kein Body)"
            log("  Response-Body: \(rawBody)")

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log("✗ JSON-Parsing fehlgeschlagen — Offline-Modus")
                isAuthenticated = true
                userEmail = loadEmail() ?? ""
                return .networkError
            }

            if let valid = json["valid"] as? Bool, valid {
                let email  = json["email"]     as? String ?? loadEmail() ?? ""
                let plan   = json["planName"]  as? String ?? loadPlan() ?? ""
                let expiry = (json["expiresAt"] as? String).flatMap { parseISO($0) }
                isAuthenticated    = true
                userEmail          = email
                planName           = plan
                subscriptionExpiry = expiry
                lastCheckedAt      = Date()
                saveEmail(email)
                savePlan(plan)
                log("✓ Token gültig — App freigegeben")
                log("  Email: \(email), Plan: \(plan)")
                if let exp = expiry { log("  Läuft ab: \(exp)") }
                return .valid(email: email)
            } else {
                let reason = json["reason"] as? String ?? "Sitzung ungültig"
                deleteToken()
                isAuthenticated = false
                userEmail = ""
                log("✗ Token ungültig: \(reason)")
                return .invalid(reason: reason)
            }
        } catch {
            log("✗ Netzwerkfehler: \(error.localizedDescription) — Offline-Modus")
            isAuthenticated = true
            userEmail = loadEmail() ?? ""
            planName  = loadPlan()  ?? ""
            return .networkError
        }
    }

    // MARK: - Logout

    func logout() {
        log("→ Logout für: \(userEmail)")
        stopBackgroundChecks()
        deleteToken()
        deleteEmail()
        deletePlan()
        isAuthenticated     = false
        userEmail           = ""
        planName            = ""
        subscriptionExpiry  = nil
        lastCheckedAt       = nil
        log("✓ Logout abgeschlossen")
    }

    // MARK: - Keychain

    private let tokenKey = "bzm.appToken"
    private let emailKey = "bzm.userEmail"
    private let planKey  = "bzm.planName"

    private func saveToken(_ token: String) {
        save(key: tokenKey, value: token)
        log("  Keychain: Token gespeichert")
    }
    private func loadToken() -> String? {
        let t = load(key: tokenKey)
        log("  Keychain: Token \(t == nil ? "nicht gefunden" : "geladen")")
        return t
    }
    private func deleteToken() {
        delete(key: tokenKey)
        log("  Keychain: Token gelöscht")
    }
    private func saveEmail(_ email: String) { save(key: emailKey, value: email) }
    private func loadEmail() -> String? { load(key: emailKey) }
    private func deleteEmail() { delete(key: emailKey) }

    private func savePlan(_ plan: String) { save(key: planKey, value: plan) }
    private func loadPlan() -> String? { load(key: planKey) }
    private func deletePlan() { delete(key: planKey) }

    // MARK: - ISO 8601 Parser

    private func parseISO(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            log("⚠ Keychain save fehlgeschlagen für '\(key)': OSStatus \(status)")
        }
    }

    private func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
