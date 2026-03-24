import Foundation

/// Zentrales Wissen über Forex-Marktzeiten.
/// Forex läuft 24/5: Montag 00:00 Sydney bis Freitag ~22:00 UTC.
/// Samstag + Sonntag (bis ~22:00 UTC) = komplett geschlossen.
enum MarketHours {

    // MARK: - Haupt-API

    /// Sind Forex-Märkte jetzt geöffnet?
    static var isOpen: Bool { status(at: Date()).isOpen }

    /// Aktueller Marktstatus mit Beschreibung
    static func status(at date: Date = Date()) -> MarketStatus {
        let utc = Calendar.utc
        let weekday = utc.component(.weekday, from: date) // 1=So, 2=Mo … 7=Sa
        let hour    = utc.component(.hour,    from: date)
        let minute  = utc.component(.minute,  from: date)
        let minOfDay = hour * 60 + minute

        switch weekday {
        case 7: // Samstag — komplett geschlossen
            return MarketStatus(isOpen: false, label: "WOCHENENDE", detail: "Märkte öffnen Sonntag ~22:00 UTC", color: .weekend)

        case 1: // Sonntag — öffnet 22:00 UTC
            if minOfDay >= 22 * 60 {
                return MarketStatus(isOpen: true, label: "ASIA OPEN", detail: "Sydney-Session läuft", color: .open)
            } else {
                let minsLeft = 22 * 60 - minOfDay
                let h = minsLeft / 60; let m = minsLeft % 60
                return MarketStatus(
                    isOpen: false, label: "WOCHENENDE",
                    detail: String(format: "Öffnet in %dh %02dm (So 22:00 UTC)", h, m),
                    color: .weekend
                )
            }

        case 6: // Freitag — schließt 22:00 UTC
            if minOfDay < 22 * 60 {
                let minsLeft = 22 * 60 - minOfDay
                let h = minsLeft / 60; let m = minsLeft % 60
                let session = activeSession(utcHour: hour)
                return MarketStatus(
                    isOpen: true, label: session.label,
                    detail: String(format: "Schließt in %dh %02dm", h, m),
                    color: .open
                )
            } else {
                return MarketStatus(isOpen: false, label: "GESCHLOSSEN", detail: "Wochenende — öffnet So 22:00 UTC", color: .weekend)
            }

        default: // Montag–Donnerstag — 24h geöffnet
            let session = activeSession(utcHour: hour)
            return MarketStatus(isOpen: true, label: session.label, detail: session.detail, color: .open)
        }
    }

    /// Nächste Session die beginnt (für Countdown-Anzeige)
    static func nextSessionLabel(at date: Date = Date()) -> String? {
        let st = status(at: date)
        guard !st.isOpen else { return nil }
        return "Nächste: Sydney/Asia (So 22:00 UTC)"
    }

    // MARK: - Session-Erkennung (UTC-Stunden)

    struct SessionInfo {
        let label: String
        let detail: String
    }

    static func activeSession(utcHour h: Int) -> SessionInfo {
        switch h {
        case 22...23, 0...6:   return SessionInfo(label: "ASIA SESSION",   detail: "Sydney / Tokyo aktiv")
        case 7...8:             return SessionInfo(label: "ASIA/EU OVERLAP", detail: "Tokyo / Frankfurt überlappend")
        case 8...11:            return SessionInfo(label: "EU SESSION",     detail: "Frankfurt / London aktiv")
        case 12...16:           return SessionInfo(label: "EU/US OVERLAP",  detail: "London / New York — höchstes Volumen")
        case 17...21:           return SessionInfo(label: "US SESSION",     detail: "New York aktiv")
        default:                return SessionInfo(label: "LOW LIQUIDITY",  detail: "Zwischen den Sessions")
        }
    }
}

// MARK: - MarketStatus

struct MarketStatus {
    let isOpen:  Bool
    let label:   String
    let detail:  String
    let color:   StatusColor

    enum StatusColor { case open, weekend, low }
}

// MARK: - Calendar Helper

private extension Calendar {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
}
