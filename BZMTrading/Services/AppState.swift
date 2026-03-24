import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // ─── Config ──────────────────────────────────────────────────
    @Published var config: Config = Config()

    // ─── Data ────────────────────────────────────────────────────
    @Published var news: [NewsItem] = []
    @Published var prices: [String: PriceData] = [:]
    @Published var calendar: [CalendarEvent] = []
    @Published var calendarLoadedOnce: Bool = false
    @Published var scanner: ScannerResult = ScannerResult()

    // ─── UI State ────────────────────────────────────────────────
    @Published var status: String = "Starte…"
    @Published var selectedNews: NewsItem? = nil
    @Published var selectedTab: Tab = .calendar
    @Published var showSettings: Bool = false
    @Published var isAnalyzingDetail: Bool = false
    @Published var aiModel: String = ""
    @Published var showScannerPanel: Bool = false
    @Published var newsLastCheckedAt: Date? = nil
    @Published var newsFetchHealthy: Bool = false

    // ─── Dialoge ─────────────────────────────────────────────────
    @Published var selectedPair: String? = nil
    @Published var selectedCalendarEvent: CalendarEvent? = nil

    // ─── Online Market Status (via Yahoo Finance) ────────────────
    /// nil = noch nicht geprüft, dann lokale Berechnung als Fallback

    // ─── AI Extras ───────────────────────────────────────────────
    @Published var liveBriefing: LiveBriefing? = nil
    @Published var isLoadingBriefing: Bool = false
    @Published var marketOverview: MarketOverview? = nil
    @Published var isLoadingOverview: Bool = false

    // ─── Session ─────────────────────────────────────────────────
    @Published var sessions: [String] = []
    @Published var sessionOverlap: String? = nil

    enum Tab: String, CaseIterable {
        case news      = "News"
        case prices    = "Preise"
        case calendar  = "Kalender"
        case scanner   = "Scanner"
    }

    private var newsService: NewsService?
    private var priceService: PriceService?
    private var calendarService: CalendarService?
    private var claudeService: ClaudeService?
    private var scannerService: ScannerService?
    private var db: DatabaseService?

    private var tasks: [Task<Void, Never>] = []

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task {
            await _start()
        }
    }

    private func _start() async {
        do { config = try Config.load() } catch { }

        let dbPath: String
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bzmDir = appSupport.appendingPathComponent("BZM")
        try? FileManager.default.createDirectory(at: bzmDir, withIntermediateDirectories: true)
        dbPath = bzmDir.appendingPathComponent("bzm_trading.db").path

        let database = DatabaseService(path: dbPath)
        await database.setup()
        self.db = database

        self.claudeService  = ClaudeService()
        self.newsService    = NewsService(config: config, db: database)
        self.priceService   = PriceService(config: config)
        self.calendarService = CalendarService(config: config)
        self.scannerService = ScannerService()

        status = "Lade gespeicherte News…"
        let recent = await database.getRecent(limit: 60)
        if !recent.isEmpty {
            news = recent.sorted { $0.published > $1.published }
            status = "\(recent.count) News aus Datenbank geladen"
        }

        status = "Starte Dienste…"

        // Test Claude API key
        let model = await claudeService?.testModel() ?? ""
        if !model.isEmpty {
            aiModel = model
            let short = model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-2024", with: "")
            status = "✓ Claude bereit (\(short))"
        } else {
            status = "⚠ AI-Backend nicht erreichbar"
        }

        // Start all background loops
        let t1 = Task { await self.runNewsLoop() }
        let t2 = Task { await self.runPriceLoop() }
        let t3 = Task { await self.runCalendarLoop() }
        let t4 = Task { await self.runScannerLoop() }
        let t5 = Task { await self.runSessionLoop() }
        tasks = [t1, t2, t3, t4, t5]
    }

    private func runNewsLoop() async {
        guard let svc = newsService, let db = db else { return }
        await svc.start(
            callback: { [weak self] item in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.handleNewRawItem(item, db: db)
                }
            },
            healthCallback: { [weak self] checkedAt, healthy in
                await MainActor.run {
                    self?.newsLastCheckedAt = checkedAt
                    self?.newsFetchHealthy = healthy
                }
            }
        )
    }

    private func handleNewRawItem(_ item: NewsItem, db: DatabaseService) async {
        // Add to list immediately (unanalyzed)
        if !news.contains(where: { $0.id == item.id }) {
            let previousNewestPublished = news.first?.published ?? .distantPast
            news.append(item)
            news.sort { $0.published > $1.published }
            if news.count > 200 { news = Array(news.prefix(200)) }

            // Sound nur dann, wenn die neue Meldung wirklich die neueste in der Liste ist.
            let isNewestNow = news.first?.id == item.id
            let isNewerThanPreviousTop = item.published >= previousNewestPublished
            if isNewestNow && isNewerThanPreviousTop {
                AudioPlayerService.playNewsAlert(
                    impactScore: item.score,
                    normalSoundName: config.newsSoundNormal,
                    highImpactSoundName: config.newsSoundHighImpact
                )
            }
        }

        // Run Claude analysis if key configured
        guard !config.claudeApiKey.isEmpty, let claude = claudeService else { return }
        let analysis = await claude.analyzeFast(item: item)
        guard let ana = analysis, ana.relevant else {
            // Remove irrelevant items
            news.removeAll { $0.id == item.id }
            return
        }

        // Update item with analysis
        if let idx = news.firstIndex(where: { $0.id == item.id }) {
            var updated = news[idx]
            var normalized = ana
            normalized.score = max(1, min(10, normalized.score))
            updated.analysis = normalized
            updated.score = normalized.score
            news[idx] = updated

            // Save to DB
            await db.updateAnalysis(id: item.id, analysis: normalized, score: normalized.score)

            if normalized.score >= config.alertMinScore {
                let headline = normalized.headline.isEmpty ? String(item.title.prefix(70)) : String(normalized.headline.prefix(70))
                status = "⚡ [\(Int(normalized.score))/10] \(item.source): \(headline)"
            }
        }
    }

    private func runPriceLoop() async {
        guard let svc = priceService else { return }
        await svc.start { [weak self] updated in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for (pair, data) in updated {
                    self.prices[pair] = data
                }
            }
        }
    }

    private func runCalendarLoop() async {
        guard let svc = calendarService else { return }
        await svc.start { [weak self] events in
            Task { @MainActor [weak self] in
                self?.calendar = events
                self?.calendarLoadedOnce = true
            }
        }
    }

    private func runScannerLoop() async {
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s startup delay
        while !Task.isCancelled {
            await updateScanner()
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s
        }
    }

    private func updateScanner() async {
        guard let svc = scannerService else { return }
        let currentPrices = prices
        let currentNews = news
        let currentCalendar = calendar
        let result = await svc.run(prices: currentPrices, news: currentNews, calendar: currentCalendar)
        scanner = result
    }

    private func runSessionLoop() async {
        while !Task.isCancelled {
            await updateSession()
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }

    private func updateSession() async {
        let hour = Calendar.current.component(.hour, from: Date())
        // UTC approximation
        let utcHour = (hour + TimeZone.current.secondsFromGMT() / -3600 + 24) % 24
        var active: [String] = []
        if utcHour >= 22 || utcHour < 8  { active.append("sydney") }
        if utcHour >= 0  && utcHour < 9  { active.append("tokyo") }
        if utcHour >= 7  && utcHour < 17 { active.append("london") }
        if utcHour >= 12 && utcHour < 22 { active.append("new_york") }
        sessions = active

        if active.contains("london") && active.contains("new_york") {
            sessionOverlap = "LONDON / NEW YORK  ★ Höchstes Volumen"
        } else if active.contains("tokyo") && active.contains("london") {
            sessionOverlap = "TOKYO / LONDON Überlappung"
        } else if active.contains("sydney") && active.contains("tokyo") {
            sessionOverlap = "SYDNEY / TOKYO Überlappung"
        } else {
            sessionOverlap = nil
        }
    }

    func requestDetailAnalysis(item: NewsItem) {
        guard let claude = claudeService else { return }
        isAnalyzingDetail = true
        Task {
            let detail = await claude.analyzeDetail(item: item)
            await MainActor.run {
                self.isAnalyzingDetail = false
                guard let d = detail, let idx = self.news.firstIndex(where: { $0.id == item.id }) else { return }
                var updated = self.news[idx]
                if updated.analysis == nil { updated.analysis = NewsAnalysis() }
                updated.analysis?.summary     = d.summary
                updated.analysis?.strategy    = d.strategy
                updated.analysis?.macro       = d.macro
                updated.analysis?.risks       = d.risks
                updated.analysis?.watchNext   = d.watchNext
                updated.analysis?.pairDetails = d.pairDetails
                self.news[idx] = updated
                self.selectedNews = updated
                self.status = "✓ Detail-Analyse: \(String(item.title.prefix(50)))"
            }
        }
    }

    // ── Live Briefing ─────────────────────────────────────────────
    func requestLiveBriefing() {
        guard let claude = claudeService, !isLoadingBriefing else { return }
        isLoadingBriefing = true
        status = "Erstelle Live-Briefing (Claude)…"
        Task {
            guard var result = await claude.getLiveBriefing(news: news, calendar: calendar) else {
                await MainActor.run {
                    self.isLoadingBriefing = false
                    self.status = "⚠ Live-Briefing fehlgeschlagen"
                }
                return
            }

            await MainActor.run { self.status = "✓ Briefing-Text bereit — erzeuge Audio…" }

            // TTS: Text → MP3 via OpenAI
            if !result.text.isEmpty {
                let audio = await claude.synthesizeSpeech(text: result.text)
                result.audioData = audio
            }

            await MainActor.run {
                self.isLoadingBriefing = false
                self.liveBriefing = result
                self.status = result.audioData != nil
                    ? "✓ Live-Briefing bereit — drücke Play zum Abspielen"
                    : "✓ Live-Briefing bereit (kein Audio)"
            }
        }
    }

    // ── Market Overview ───────────────────────────────────────────
    func requestMarketOverview() {
        guard let claude = claudeService, !isLoadingOverview else { return }
        isLoadingOverview = true
        status = "Lade Marktübersicht (Claude)…"
        Task {
            let result = await claude.getOverview(news: news, pairs: config.marketPairs)
            await MainActor.run {
                self.isLoadingOverview = false
                if let r = result {
                    self.marketOverview = r
                    self.status = "✓ Marktübersicht geladen"
                } else {
                    self.status = "⚠ Marktübersicht fehlgeschlagen"
                }
            }
        }
    }

    // ── Instrument Deep Analysis ──────────────────────────────────
    func requestInstrumentAnalysis(pair: String) async -> InstrumentAnalysis? {
        guard let claude = claudeService else { return nil }
        let priceData = prices[pair]
        return await claude.analyzeInstrumentDeep(
            pair: pair,
            price: priceData?.price ?? 0,
            changePct: priceData?.changePct ?? 0,
            news: news,
            calendar: calendar
        )
    }

    /// Marktstatus basierend auf lokalem Zeitplan (Forex 24/5).
    var marketIsOpen: Bool {
        MarketHours.isOpen
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        isRunning = false
    }
}
