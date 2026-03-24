import Foundation

struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: String
    var time: String           // ISO8601 string
    var timeDisplay: String
    var currency: String
    var country: String
    var event: String
    var impact: Impact
    var forecast: String
    var previous: String
    var actual: String

    enum Impact: String, Codable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case holiday = "Holiday"
        case unknown

        var color: String {
            switch self {
            case .high: return "#f87171"
            case .medium: return "#fbbf24"
            case .low: return "#60a5fa"
            default: return "#8ab0d0"
            }
        }

        var sort: Int {
            switch self { case .high: return 0; case .medium: return 1; default: return 2 }
        }
    }

    var date: Date? {
        let s = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        for opt: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate]
        ] {
            iso.formatOptions = opt
            if let d = iso.date(from: s) { return d }
        }

        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    var minutesUntil: Double? {
        guard let d = date else { return nil }
        return d.timeIntervalSinceNow / 60
    }

    var isAllDay: Bool {
        let t = timeDisplay.lowercased()
        return t.contains("all day") || t.contains("ganzt")
    }

    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool { lhs.id == rhs.id }

    enum CodingKeys: String, CodingKey {
        case id, time, currency, country, event, impact, forecast, previous, actual
        case timeDisplay = "time_display"
    }
}
