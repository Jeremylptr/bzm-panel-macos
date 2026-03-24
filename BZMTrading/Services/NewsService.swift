import Foundation

typealias NewsCallback = (NewsItem) async -> Void
typealias NewsHealthCallback = (Date, Bool) async -> Void

actor NewsService {
    private let config: Config
    private let db: DatabaseService
    private var seenHashes = Set<String>()
    private var lastFetch: [String: Date] = [:]

    struct Feed {
        let name: String
        let url: String
        let priority: Int
    }

    static let feeds: [Feed] = [
        // Priorität 1 — Forex-spezifisch und zentrale Makro-Trigger
        Feed(name: "InvestingLive",     url: "https://investinglive.com/feed/news/",                             priority: 1),
        Feed(name: "InvestingLive CB",  url: "https://investinglive.com/feed/centralbank/",                      priority: 1),
        Feed(name: "FXStreet",          url: "https://www.fxstreet.com/news/feed",                               priority: 1),
        Feed(name: "DailyFX",           url: "https://www.dailyfx.com/feeds/forex-market-news",                  priority: 1),
        Feed(name: "ActionForex",       url: "https://www.actionforex.com/feed/",                                priority: 1),
        Feed(name: "Investing.com",     url: "https://www.investing.com/rss/news.rss",                           priority: 1),
        Feed(name: "Google Forex",      url: "https://news.google.com/rss/search?q=forex%20market&hl=en-US&gl=US&ceid=US:en", priority: 1),
        Feed(name: "Google Fed",        url: "https://news.google.com/rss/search?q=federal%20reserve%20rate%20decision&hl=en-US&gl=US&ceid=US:en", priority: 1),
        Feed(name: "Google ECB",        url: "https://news.google.com/rss/search?q=ecb%20interest%20rate&hl=en-US&gl=US&ceid=US:en", priority: 1),
        // Priorität 2 — Breite Finanz- und Makroquellen
        Feed(name: "CNBC Finance",      url: "https://www.cnbc.com/id/10000664/device/rss/rss.html",             priority: 2),
        Feed(name: "NYT Economy",       url: "https://rss.nytimes.com/services/xml/rss/nyt/Economy.xml",         priority: 2),
        Feed(name: "BBC Business",      url: "https://feeds.bbci.co.uk/news/business/rss.xml",                   priority: 2),
        Feed(name: "Guardian Business", url: "https://www.theguardian.com/business/rss",                         priority: 2),
        Feed(name: "MarketWatch",       url: "https://feeds.content.dowjones.io/public/rss/mw_topstories",       priority: 2),
        Feed(name: "WSJ Markets",       url: "https://feeds.a.dj.com/rss/RSSMarketsMain.xml",                    priority: 2),
        Feed(name: "Fed Monetary",      url: "https://www.federalreserve.gov/feeds/press_monetary.xml",          priority: 2),
        Feed(name: "Fed Speeches",      url: "https://www.federalreserve.gov/feeds/speeches_and_testimony.xml",  priority: 2),
        Feed(name: "BOJ Updates",       url: "https://www.boj.or.jp/rss/whatsnew.xml",                           priority: 2),
        // Priorität 3 — Zusätzliche Quellen
        Feed(name: "Seeking Alpha",     url: "https://seekingalpha.com/market_currents.xml",                     priority: 3),
        Feed(name: "ZeroHedge",         url: "https://feeds.feedburner.com/zerohedge/feed",                      priority: 3),
        Feed(name: "Nasdaq News",       url: "https://www.nasdaq.com/feed/rssoutbound?category=Markets",         priority: 3),
        Feed(name: "Google EURUSD",     url: "https://news.google.com/rss/search?q=EURUSD&hl=en-US&gl=US&ceid=US:en", priority: 3),
    ]

    static let refreshByPriority: [Int: Int] = [1: 10, 2: 10, 3: 10]

    static let forexKeywords = [
        "dollar","euro","pound","sterling","yen","franc","yuan",
        "usd","eur","gbp","jpy","chf","cad","aud","nzd",
        "federal reserve","fed","ecb","bank of england","boe","bank of japan","boj",
        "central bank","monetary policy","interest rate","rate hike","rate cut",
        "fomc","inflation","cpi","pce","gdp","nfp","payroll","employment",
        "forex","currency","exchange rate",
        "oil price","crude","gold price","treasury yield",
        "risk-off","risk-on","safe haven","breaking","recession",
    ]

    static let highImpact = [
        "federal reserve","fomc","rate decision","rate hike","rate cut",
        "bank of england","ecb","bank of japan","nonfarm payroll","nfp",
        "cpi data","inflation data","gdp","recession","crisis","emergency",
    ]

    static let criticalImpact = [
        "intervention", "surprise", "unscheduled", "emergency", "black swan",
        "war", "attack", "sanction", "default", "bank run", "liquidity crisis",
        "credit downgrade", "systemic risk", "debt crisis", "capital controls",
    ]

    static let mediumImpact = [
        "minutes", "speech", "forecast", "guidance", "outlook", "survey",
        "retail sales", "pmi", "consumer confidence", "jobless claims",
        "producer prices", "industrial production", "housing", "trade balance",
    ]

    init(config: Config, db: DatabaseService) {
        self.config = config
        self.db = db
    }

    func start(callback: @escaping NewsCallback, healthCallback: NewsHealthCallback? = nil) async {
        // Pre-load seen hashes
        let recent = await db.getRecent(limit: 500)
        for item in recent { seenHashes.insert(item.hash) }

        while true {
            await fetchDue(callback: callback, healthCallback: healthCallback)
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        }
    }

    private func fetchDue(callback: @escaping NewsCallback, healthCallback: NewsHealthCallback?) async {
        let now = Date()
        var due: [Feed] = []
        for feed in Self.feeds {
            let interval = TimeInterval(Self.refreshByPriority[feed.priority] ?? config.newsRefreshSeconds)
            if now.timeIntervalSince(lastFetch[feed.name] ?? .distantPast) >= interval {
                due.append(feed)
            }
        }
        var successCount = 0
        var failureCount = 0
        await withTaskGroup(of: Bool.self) { group in
            for feed in due {
                group.addTask { await self.fetchOne(feed: feed, callback: callback) }
            }
            for await ok in group {
                if ok {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            }
        }
        for feed in due { lastFetch[feed.name] = now }
        if !due.isEmpty {
            // Grün, sobald mindestens ein Feed erfolgreich war.
            // Rot nur, wenn im gesamten Zyklus kein Feed erfolgreich geladen wurde.
            let isHealthy = successCount > 0 || failureCount == 0
            await healthCallback?(now, isHealthy)
        }
    }

    private func fetchOne(feed: Feed, callback: @escaping NewsCallback) async -> Bool {
        guard let url = URL(string: feed.url) else { return false }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Mozilla/5.0 (compatible; BZMTrading/2.0)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return false }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return false
        }
        let entries = RSSParser.parse(data: data)
        if entries.isEmpty { return false }
        for entry in entries {
            await processEntry(entry, source: feed.name, priority: feed.priority, callback: callback)
        }
        return true
    }

    private func processEntry(_ entry: RSSEntry, source: String, priority: Int, callback: @escaping NewsCallback) async {
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        // Age filter
        if let pub = entry.published {
            if Date().timeIntervalSince(pub) > Double(config.newsMaxAgeHours * 3600) { return }
        }

        let hashInput = (title + entry.link).data(using: .utf8) ?? Data()
        let hash = hashInput.md5Hex

        if seenHashes.contains(hash) { return }
        if await db.isSeen(hash: hash) {
            seenHashes.insert(hash)
            return
        }
        seenHashes.insert(hash)
        if seenHashes.count > 5000 {
            seenHashes = Set(seenHashes.prefix(4000))
        }

        // Relevanz-Scoring ohne harte Ausfilterung:
        // Alle Feed-Einträge werden aufgenommen, sofern sie neu und innerhalb der Age-Grenze sind.
        let text = (title + " " + entry.description).lowercased()
        let score = impactScore(text: text, priority: priority)

        // Wenn das Veröffentlichungsdatum aus dem Feed nicht geparst werden konnte,
        // verwenden wir einen konservativen Fallback (2h zurück) statt Date(),
        // damit der Artikel nicht fälschlicherweise als "jetzt" erscheint.
        let publishedDate = entry.published ?? Date().addingTimeInterval(-7200)

        let item = NewsItem(
            id: UUID().uuidString,
            title: title,
            source: source,
            url: entry.link,
            published: publishedDate,
            content: String(entry.description.prefix(2000)),
            hash: hash,
            score: score,
            priority: priority,
            analysis: nil
        )
        await db.insert(news: item)
        await callback(item)
    }

    private func impactScore(text: String, priority: Int) -> Double {
        let forexHits = Self.forexKeywords.filter { text.contains($0) }.count
        let highHits = Self.highImpact.filter { text.contains($0) }.count
        let criticalHits = Self.criticalImpact.filter { text.contains($0) }.count
        let mediumHits = Self.mediumImpact.filter { text.contains($0) }.count

        var score = 1.0
        score += Double(priority == 1 ? 1.5 : priority == 2 ? 1.0 : 0.5)
        score += min(2.0, Double(forexHits) * 0.25)
        score += min(3.0, Double(highHits) * 1.1)
        score += min(3.0, Double(criticalHits) * 1.5)
        score += min(1.5, Double(mediumHits) * 0.35)

        if text.contains("breaking") { score += 0.6 }
        if text.contains("live") { score += 0.3 }

        return max(1.0, min(10.0, score.rounded()))
    }
}

// MARK: - Simple RSS XML Parser
struct RSSEntry {
    var title: String = ""
    var link: String = ""
    var description: String = ""
    var published: Date? = nil
}

class RSSParser: NSObject, XMLParserDelegate {
    private var entries: [RSSEntry] = []
    private var current: RSSEntry = RSSEntry()
    private var currentElement: String = ""
    private var currentText: String = ""
    private var inItem = false

    static func parse(data: Data) -> [RSSEntry] {
        let p = RSSParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        parser.parse()
        return p.entries
    }

    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName qn: String?, attributes: [String: String] = [:]) {
        currentElement = el.lowercased()
        currentText = ""
        if currentElement == "item" || currentElement == "entry" { inItem = true; current = RSSEntry() }
        if currentElement == "link", let href = attributes["href"] ?? attributes["rel"], !href.isEmpty {
            if inItem && current.link.isEmpty { current.link = href }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName qn: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if inItem {
            switch el.lowercased() {
            case "title":       if !text.isEmpty { current.title = stripHTML(text) }
            case "link":        if current.link.isEmpty { current.link = text }
            case "description", "summary", "content", "content:encoded":
                if current.description.isEmpty { current.description = stripHTML(text) }
            case "pubdate", "published", "dc:date", "updated":
                current.published = parseDate(text)
            case "item", "entry":
                if !current.title.isEmpty { entries.append(current) }
                inItem = false
            default: break
            }
        }
        currentText = ""
    }

    private func stripHTML(_ s: String) -> String {
        let stripped = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return stripped.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        // ISO 8601 – deckt "2026-03-17T14:30:00Z", "+00:00", fraktionale Sekunden ab
        let iso = ISO8601DateFormatter()
        for opt: ISO8601DateFormatter.Options in [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate, .withTime, .withColonSeparatorInTimeZone],
            [.withFullDate, .withTime, .withTimeZone],
        ] {
            iso.formatOptions = opt
            if let d = iso.date(from: s) { return d }
        }

        // RFC 2822 + Varianten (RSS Standard)
        let fmts = [
            "EEE, dd MMM yyyy HH:mm:ss Z",      // "+0000"  "Mon, 15 Jan 2024 14:30:00 +0000"
            "EEE, dd MMM yyyy HH:mm:ss z",       // "GMT"
            "EEE,  d MMM yyyy HH:mm:ss Z",       // einstelliger Tag (führendes Leerzeichen)
            "EEE,  d MMM yyyy HH:mm:ss z",
            "dd MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss z",
            "EEE, dd MMM yyyy HH:mm Z",          // ohne Sekunden
            "EEE, dd MMM yyyy HH:mm z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",        // "+00:00" mit Doppelpunkt
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd HH:mm:ss Z",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fmts {
            df.dateFormat = fmt
            if let d = df.date(from: s) { return d }
        }
        return nil
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
