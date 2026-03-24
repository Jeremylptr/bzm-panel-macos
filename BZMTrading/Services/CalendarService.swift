import Foundation

typealias CalendarCallback = ([CalendarEvent]) async -> Void

actor CalendarService {
    private let config: Config
    private var events: [CalendarEvent] = []

    static let urls = [
        "https://nfs.faireconomy.media/ff_calendar_thisweek.json",
        "https://nfs.faireconomy.media/ff_calendar_nextweek.json",
    ]

    static let countryCurrency: [String: String] = [
        "USD":"USD","EUR":"EUR","GBP":"GBP","JPY":"JPY","CHF":"CHF",
        "CAD":"CAD","AUD":"AUD","NZD":"NZD","CNY":"CNY",
        "US":"USD","EU":"EUR","GB":"GBP","UK":"GBP","JP":"JPY",
        "CH":"CHF","CA":"CAD","AU":"AUD","NZ":"NZD","CN":"CNY",
        "DE":"EUR","FR":"EUR","IT":"EUR","ES":"EUR",
    ]

    init(config: Config) {
        self.config = config
    }

    func start(callback: @escaping CalendarCallback) async {
        await fetch(callback: callback)
        while true {
            try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            await fetch(callback: callback)
        }
    }

    private func fetch(callback: @escaping CalendarCallback) async {
        var allRaw: [[String: Any]] = []
        for urlStr in Self.urls {
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 15)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { continue }
            allRaw.append(contentsOf: json)
        }

        var processed: [CalendarEvent] = []
        for raw in allRaw {
            if let ev = process(raw: raw) { processed.append(ev) }
        }
        processed.sort { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        events = processed

        let upcoming = getUpcoming(hours: 48)
        await callback(upcoming)
    }

    private func process(raw: [String: Any]) -> CalendarEvent? {
        guard let title = raw["title"] as? String, !title.isEmpty else { return nil }
        let country = (raw["country"] as? String ?? "").uppercased()
        let impactStr = raw["impact"] as? String ?? "Low"
        let impact: CalendarEvent.Impact
        switch impactStr {
        case "High":    impact = .high
        case "Medium":  impact = .medium
        case "Low":     impact = .low
        case "Holiday": impact = .holiday
        default:        impact = .low
        }
        let dateStr = raw["date"] as? String ?? ""
        let rawTime = raw["time"] as? String ?? ""
        let eventDate = parseEventDate(dateRaw: dateStr, timeRaw: rawTime)
        let eventTime = toIsoString(eventDate) ?? dateStr
        let timeDisplay = makeTimeDisplay(date: eventDate, rawTime: rawTime)

        var hashData = "\(title)\(country)\(eventTime)".data(using: .utf8) ?? Data()
        let eid = hashData.md5Hex.prefix(16).description
        let currency = Self.countryCurrency[country] ?? String(country.prefix(3))

        return CalendarEvent(
            id: eid,
            time: eventTime,
            timeDisplay: timeDisplay,
            currency: currency,
            country: country,
            event: title,
            impact: impact,
            forecast: raw["forecast"] as? String ?? "",
            previous: raw["previous"] as? String ?? "",
            actual: raw["actual"] as? String ?? ""
        )
    }

    private func parseEventDate(dateRaw: String, timeRaw: String) -> Date? {
        let trimmedDate = dateRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTime = timeRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        let iso = ISO8601DateFormatter()
        for opt: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate]
        ] {
            iso.formatOptions = opt
            if let d = iso.date(from: trimmedDate) { return d }
        }

        let combined = "\(trimmedDate) \(trimmedTime)".trimmingCharacters(in: .whitespaces)
        let fmts = [
            "MM-dd-yyyy hh:mma",
            "MM-dd-yyyy hh:mm a",
            "MM-dd-yyyy HH:mm",
            "yyyy-MM-dd HH:mm",
            "MM-dd-yyyy",
            "yyyy-MM-dd",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            df.dateFormat = fmt
            if let d = df.date(from: combined) { return d }
            if let d = df.date(from: trimmedDate) { return d }
        }
        return nil
    }

    private func toIsoString(_ date: Date?) -> String? {
        guard let date else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return iso.string(from: date)
    }

    private func makeTimeDisplay(date: Date?, rawTime: String) -> String {
        let t = rawTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let allDayTokens = ["", "all day", "tentative", "day", "na", "n/a"]
        if allDayTokens.contains(t.lowercased()) {
            // Der Feed liefert oft trotzdem eine genaue Zeit im ISO-Date-Feld.
            if let date {
                let df = DateFormatter()
                df.dateFormat = "HH:mm"
                return df.string(from: date)
            }
            return "Ganztägig"
        }
        if let date {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df.string(from: date)
        }
        return t
    }

    private func getUpcoming(hours: Int) -> [CalendarEvent] {
        let now = Date()
        let until = now.addingTimeInterval(TimeInterval(hours * 3600))
        return events.filter { ev in
            guard let d = ev.date else { return false }
            return d >= now && d <= until
        }
    }
}

private extension Data {
    var md5Hex: String {
        var digest = [UInt8](repeating: 0, count: 16)
        self.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                CC_MD5(base, CC_LONG(self.count), &digest)
            }
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
import CommonCrypto
