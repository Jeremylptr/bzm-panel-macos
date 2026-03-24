import Foundation
import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

// ── Ergebnis-Typen ────────────────────────────────────────────────────────────

struct AppVersionInfo: Identifiable {
    let id = UUID()
    let version:      String
    let downloadUrl:  String
    let releaseNotes: String
}

enum UpdateCheckResult {
    case upToDate
    case updateAvailable(AppVersionInfo)
    case error(String)
}

// ── UpdateService ─────────────────────────────────────────────────────────────

@MainActor
final class UpdateService: ObservableObject {

    static let shared = UpdateService()
    private init() {}

    @Published var updateAvailable: AppVersionInfo? = nil
    @Published var lastCheckedAt: Date? = nil
    @Published var lastCheckMessage: String = "Noch nicht geprüft"

#if canImport(Sparkle)
    private let sparkleBridge = SparkleBridge()
#endif

    private let updateEndpoints: [String] = [
        "https://www.bluezonemarkets.com/_functions/appVersion",
        "https://bluezonemarkets.com/_functions/appVersion",
        "https://www.bluezonemarkets.com/_functions-dev/appVersion",
    ]

    // MARK: - Öffentliche API

    /// Prüft beim App-Start ob eine neue Version verfügbar ist.
    func checkForUpdates() async {
#if canImport(Sparkle)
        print("[Update] Sparkle aktiv — starte Hintergrund-Check...")
        lastCheckedAt = Date()
        lastCheckMessage = "Pruefe Updates (Sparkle)..."
        sparkleBridge.checkInBackground()
        return
#else
        print("[Update] Starte Update-Check...")
        let result = await fetchLatestVersion()
        lastCheckedAt = Date()
        switch result {
        case .upToDate:
            print("[Update] App ist aktuell (\(currentVersion()))")
            lastCheckMessage = "App ist aktuell"
        case .updateAvailable(let info):
            print("[Update] Neue Version verfügbar: \(info.version) (aktuell: \(currentVersion()))")
            updateAvailable = info
            lastCheckMessage = "Update verfügbar: v\(info.version)"
        case .error(let msg):
            print("[Update] Prüfung fehlgeschlagen: \(msg)")
            lastCheckMessage = "Update-Check fehlgeschlagen: \(msg)"
        }
#endif
    }

    /// User-klickbarer Update-Trigger.
    /// Mit Sparkle: direkt integrierter Update-Flow.
    /// Ohne Sparkle: Download-Seite öffnen.
    func performUserInitiatedUpdate() {
#if canImport(Sparkle)
        print("[Update] User hat Update gestartet (Sparkle UI)")
        sparkleBridge.checkInteractively()
#else
        openDownloadPage()
#endif
    }

    /// Öffnet die Download-URL im Standard-Browser (Fallback ohne Sparkle).
    func openDownloadPage() {
        guard let info = updateAvailable,
              let url  = URL(string: info.downloadUrl),
              !info.downloadUrl.isEmpty else { return }
        NSWorkspace.shared.open(url)
    }

    /// Blendet den Update-Hinweis aus (bis zum nächsten Start).
    func dismissUpdate() {
        updateAvailable = nil
    }

    // MARK: - Private

    private func fetchLatestVersion() async -> UpdateCheckResult {
        var lastError = "Unbekannter Fehler"
        for endpoint in updateEndpoints {
            guard let url = URL(string: endpoint) else { continue }
            print("[Update] Prüfe Endpoint: \(endpoint)")
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            req.setValue("BZM Panel/\(currentVersion())", forHTTPHeaderField: "User-Agent")

            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse {
                    print("[Update] HTTP \(http.statusCode) von \(endpoint)")
                } else {
                    print("[Update] Antwort ohne HTTP-Status von \(endpoint)")
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let serverVersionRaw = json["version"] as? String else {
                    if let http = resp as? HTTPURLResponse {
                        lastError = "Ungültige Antwort (\(http.statusCode)) von \(endpoint)"
                    } else {
                        lastError = "Ungültige Antwort von \(endpoint)"
                    }
                    print("[Update] \(lastError)")
                    continue
                }

                let serverVersion = serverVersionRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                let downloadUrl = (json["downloadUrl"] as? String
                    ?? json["download_url"] as? String
                    ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let releaseNotes = (json["releaseNotes"] as? String
                    ?? json["release_notes"] as? String
                    ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                // Auch bei HTTP!=200 nutzen wir eine parsebare JSON-Antwort als Fallback.
                let info = AppVersionInfo(
                    version: serverVersion.isEmpty ? "1.0.0" : serverVersion,
                    downloadUrl: downloadUrl,
                    releaseNotes: releaseNotes
                )

                print("[Update] Server-Version: \(info.version)")
                print("[Update] Download-URL vorhanden: \(!info.downloadUrl.isEmpty)")

                if isNewerVersion(info.version, than: currentVersion()) {
                    print("[Update] Ergebnis: Update verfügbar")
                    return .updateAvailable(info)
                }
                print("[Update] Ergebnis: App aktuell")
                return .upToDate
            } catch {
                lastError = "\(endpoint): \(error.localizedDescription)"
                print("[Update] Endpoint fehlgeschlagen: \(lastError)")
            }
        }
        print("[Update] Kein Endpoint erfolgreich: \(lastError)")
        return .error(lastError)
    }

    /// Gibt die aktuelle Version aus dem App-Bundle zurück (z.B. "1.0.0").
    func currentVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// Vergleicht zwei Versions-Strings nach dem Schema Major.Minor.Patch.
    private func isNewerVersion(_ serverVersion: String, than localVersion: String) -> Bool {
        let serverParts = normalizedVersionParts(serverVersion)
        let localParts  = normalizedVersionParts(localVersion)

        let maxLen = max(serverParts.count, localParts.count)
        for i in 0..<maxLen {
            let s = i < serverParts.count ? serverParts[i] : 0
            let l = i < localParts.count  ? localParts[i]  : 0
            if s > l { return true }
            if s < l { return false }
        }
        return false
    }

    private func normalizedVersionParts(_ raw: String) -> [Int] {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "v", with: "")
            .split(separator: ".")
            .map { part in
                String(part.filter { $0.isNumber })
            }
        return cleaned.compactMap { Int($0) }
    }
}

#if canImport(Sparkle)
@MainActor
private final class SparkleBridge: NSObject {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func checkInBackground() {
        controller.updater.checkForUpdatesInBackground()
    }

    func checkInteractively() {
        controller.checkForUpdates(nil)
    }
}
#endif
