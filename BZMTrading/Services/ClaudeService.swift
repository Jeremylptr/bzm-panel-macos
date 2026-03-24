import Foundation

// ── Ergebnis-Structs ─────────────────────────────────────────────────────────

struct LiveBriefing: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let keyPoints: [String]
    let watchNext: [String]
    var audioData: Data? = nil   // MP3 von OpenAI TTS
}

struct MarketOverview: Identifiable {
    let id = UUID()
    let sentiment: String      // risk-on / risk-off / neutral
    let usd: String
    let eur: String
    let gbp: String
    let jpy: String
    let topPair: String
    let themes: [String]
    let overview: String
}

struct InstrumentAnalysis {
    let verdict: String        // bullish / bearish / neutral
    let confidence: Int
    let summary: String
    let entryZone: String
    let stop: String
    let target1: String
    let target2: String
    let riskReward: String
    let timeframe: String
    let macroDrivers: [String]
    let catalysts: [String]
    let risks: [String]
    let flowAnalysis: String
    let positioning: String
    let momentum: String
    // Szenarien
    let bullProb: Int; let bullTrigger: String
    let baseProb: Int; let baseTrigger: String
    let bearProb: Int; let bearTrigger: String
}

// ── Haupt-Service ─────────────────────────────────────────────────────────────

actor ClaudeService {
    private let wixBaseURL = "https://www.bluezonemarkets.com/_functions"
    private var workingModel: String? = nil
    private var requestTimes: [Date] = []

    // Alle Modell-Kandidaten neueste zuerst
    static let modelCandidates = [
        "claude-sonnet-4-5",
        "claude-opus-4-5",
        "claude-3-5-haiku-20241022",
        "claude-3-5-sonnet-20241022",
        "claude-3-haiku-20240307",
    ]

    // ── Modell-Test ───────────────────────────────────────────────
    func testModel() async -> String {
        for m in Self.modelCandidates {
            if let _ = try? await callClaude(model: m, prompt: "ping", maxTokens: 10) {
                workingModel = m
                return m
            }
        }
        return ""
    }

    // ── 1. Schnell-Analyse (jede News) ───────────────────────────
    func analyzeFast(item: NewsItem) async -> NewsAnalysis? {
        guard let model = await getModel() else { return nil }
        let prompt = """
        Forex-Analyst. Bewerte diese News.
        Titel: \(item.title)
        Quelle: \(item.source)
        Inhalt: \(String(item.content.prefix(1000)))
        Nur JSON, kein Markdown:
        {"relevant":true,"score":7,"urgency":"hours","headline":"Max 55 Zeichen","analysis":"1-2 Sätze DE","pairs":{"EUR/USD":"bearish"},"category":"central_bank","factors":["Faktor1"]}
        score 1-10, urgency: immediate/hours/days, pairs: bullish/bearish/neutral
        Nicht Forex-relevant: {"relevant":false}
        """
        await rateLimit()
        guard let raw = try? await callClaude(model: model, prompt: prompt, maxTokens: 350) else { return nil }
        return parseAnalysis(raw)
    }

    // ── 2. Tiefen-Analyse (auf Knopfdruck) ───────────────────────
    func analyzeDetail(item: NewsItem) async -> NewsAnalysis? {
        let candidates = ["claude-opus-4-5", "claude-sonnet-4-5"] + Self.modelCandidates
        let deduped = NSOrderedSet(array: candidates).array as! [String]
        let prompt = """
        Senior Forex-Analyst. Tiefenanalyse dieser News.
        Titel: \(item.title)
        Quelle: \(item.source)
        Inhalt: \(String(item.content.prefix(800)))
        Nur JSON, kein Markdown:
        {"summary":"2-3 Sätze DE","score":8,"pairs":{"EUR/USD":{"direction":"bearish","reasoning":"1 Satz","move_pips":"30-50","probability":70}},"strategy":{"bias":"Short EUR/USD","entry":"1.0855","stop":"1.0890","target":"1.0780"},"macro":"1 Satz Makro DE","risks":["Risiko1","Risiko2"],"watch_next":"Folge-Events"}
        """
        await rateLimit()
        for m in deduped {
            if let raw = try? await callClaude(model: m, prompt: prompt, maxTokens: 700) {
                return parseAnalysis(raw)
            }
        }
        return nil
    }

    // ── 3. Marktübersicht (Market Overview) ──────────────────────
    func getOverview(news: [NewsItem], pairs: [String]) async -> MarketOverview? {
        guard let model = await getModel() else { return nil }
        let summary = news.prefix(10).map { n in
            "- [\(Int(n.score))/10] \(n.analysis?.headline ?? n.title) (\(n.source))"
        }.joined(separator: "\n")

        let prompt = """
        Erstelle eine kurze Marktübersicht (JSON):
        News der letzten 2h:
        \(summary)
        Paare: \(pairs.joined(separator: ", "))

        {"sentiment":"risk-on/risk-off/neutral","usd":"bullish/bearish/neutral","eur":"bullish/bearish/neutral","gbp":"bullish/bearish/neutral","jpy":"bullish/bearish/neutral","top_pair":"EUR/USD","themes":["Thema1","Thema2"],"overview":"2-3 Sätze auf Deutsch"}
        """
        await rateLimit()
        guard let raw = try? await callClaude(model: model, prompt: prompt, maxTokens: 500),
              let json = parseRawJSON(raw) else { return nil }

        return MarketOverview(
            sentiment:  json["sentiment"]  as? String ?? "neutral",
            usd:        json["usd"]        as? String ?? "neutral",
            eur:        json["eur"]        as? String ?? "neutral",
            gbp:        json["gbp"]        as? String ?? "neutral",
            jpy:        json["jpy"]        as? String ?? "neutral",
            topPair:    json["top_pair"]   as? String ?? "",
            themes:     json["themes"]     as? [String] ?? [],
            overview:   json["overview"]   as? String ?? ""
        )
    }

    // ── 4. Live-Briefing ─────────────────────────────────────────
    func getLiveBriefing(news: [NewsItem], calendar: [CalendarEvent]) async -> LiveBriefing? {
        guard let model = await getModel() else { return nil }

        let mktStatus = MarketHours.status()

        // Wochenend-Briefing: kein Live-Trading möglich
        if !mktStatus.isOpen {
            let eventLines = calendar.prefix(8).map { ev in
                "- \(ev.timeDisplay) \(ev.currency) \(ev.impact.rawValue) \(ev.event)"
            }.joined(separator: "\n")
            let newsLines = news.prefix(8).map { n in
                "- \(n.analysis?.headline ?? n.title) (\(n.source))"
            }.joined(separator: "\n")

            let prompt = """
            Du bist der Audio-Briefing-Analyst eines Forex-Traders.
            Erstelle einen gesprochenen Wochenend-Marktbericht auf Deutsch.

            WICHTIG: Die Forex-Märkte sind gerade GESCHLOSSEN (Wochenende). Weise explizit darauf hin.
            Länge: EXAKT 110-130 Wörter. Fließtext, keine Aufzählungszeichen.

            Liefere NUR JSON, kein Markdown:
            {"title":"Kurz-Titel max 6 Wörter","briefing_text":"Fließender Sprechtext 110-130 Wörter auf Deutsch","key_points":["P1","P2","P3"],"watch_next":["Event1","Event2"]}

            Letzte bekannte News:
            \(newsLines.isEmpty ? "- Keine News" : newsLines)

            Wichtige Events nächste Woche:
            \(eventLines.isEmpty ? "- Keine Events" : eventLines)

            Fokus:
            - Märkte sind geschlossen, kein aktives Trading möglich
            - Rückblick auf die vergangene Woche
            - Ausblick: Was erwartet uns kommende Woche?
            - Auf welche Events zu Wochenbeginn achten?
            """
            await rateLimit()
            guard let raw = try? await callClaude(model: model, prompt: prompt, maxTokens: 700),
                  let json = parseRawJSON(raw) else {
                return LiveBriefing(
                    title: "Wochenende — Märkte geschlossen",
                    text: "Die Forex-Märkte sind aktuell geschlossen. \(mktStatus.detail). Nutze das Wochenende zur Analyse und Vorbereitung auf die kommende Handelswoche.",
                    keyPoints: ["Märkte geschlossen", mktStatus.detail],
                    watchNext: []
                )
            }
            return LiveBriefing(
                title:     json["title"]        as? String ?? "Wochenend-Briefing",
                text:      json["briefing_text"] as? String ?? "",
                keyPoints: json["key_points"]   as? [String] ?? [],
                watchNext: json["watch_next"]   as? [String] ?? []
            )
        }

        // Normales Briefing (Märkte geöffnet)
        guard !news.isEmpty else {
            return LiveBriefing(
                title: "Keine neuen News",
                text: "Aktuell liegen keine neuen, relevanten Marktmeldungen vor. Beobachte die nächsten Kalenderereignisse für frische Impulse.",
                keyPoints: ["Keine neuen Headlines"],
                watchNext: []
            )
        }

        let newsLines = news.prefix(14).map { n in
            "- [\(Int(n.score))/10] \(n.analysis?.headline ?? n.title) (\(n.source))"
        }.joined(separator: "\n")

        let eventLines = calendar.prefix(10).map { ev in
            "- \(ev.timeDisplay) \(ev.currency) \(ev.impact.rawValue) \(ev.event)"
        }.joined(separator: "\n")

        let prompt = """
        Du bist der Audio-Briefing-Analyst eines Forex-Traders.
        Erstelle einen gesprochenen Marktbericht auf Deutsch.

        WICHTIG — Länge: EXAKT 110-130 Wörter (entspricht ~60 Sekunden Sprechzeit bei normalem Tempo).
        Schreibe fließend und natürlich, als ob du ihn vorliest. Keine Aufzählungszeichen, nur Fließtext.
        Aktuelle Markt-Session: \(mktStatus.label) — \(mktStatus.detail)

        Liefere NUR JSON, kein Markdown:
        {"title":"Kurz-Titel max 6 Wörter","briefing_text":"Fließender Sprechtext 110-130 Wörter auf Deutsch","key_points":["P1","P2","P3"],"watch_next":["Event1","Event2"]}

        Aktuelle News (neueste zuerst):
        \(newsLines.isEmpty ? "- Keine News" : newsLines)

        Nächste Makro-Events:
        \(eventLines.isEmpty ? "- Keine Events" : eventLines)

        Fokus des Berichts:
        - Was bewegt die Märkte gerade?
        - Welche Instrumente sind heute am wichtigsten?
        - Worauf in den nächsten Stunden achten?
        """
        await rateLimit()
        guard let raw = try? await callClaude(model: model, prompt: prompt, maxTokens: 700),
              let json = parseRawJSON(raw) else { return nil }

        return LiveBriefing(
            title:      json["title"]          as? String ?? "Live Briefing",
            text:       json["briefing_text"]   as? String ?? "",
            keyPoints:  json["key_points"]      as? [String] ?? [],
            watchNext:  json["watch_next"]      as? [String] ?? []
        )
    }

    // ── 5. Instrument-Tiefenanalyse (aus Preis-Detail-Fenster) ───
    func analyzeInstrumentDeep(
        pair: String,
        price: Double,
        changePct: Double,
        news: [NewsItem],
        calendar: [CalendarEvent]
    ) async -> InstrumentAnalysis? {
        let candidates = ["claude-opus-4-5", "claude-sonnet-4-5"] + Self.modelCandidates
        let deduped = NSOrderedSet(array: candidates).array as! [String]

        let newsStr = news.prefix(12).map { n in
            "- [\(Int(n.score))/10] \(n.analysis?.headline ?? n.title) (\(n.source))"
        }.joined(separator: "\n").isEmpty ? "Keine relevanten News"
        : news.prefix(12).map { "- [\(Int($0.score))/10] \($0.analysis?.headline ?? $0.title) (\($0.source))" }.joined(separator: "\n")

        let eventsStr = calendar.prefix(8).map { ev in
            "- \(ev.timeDisplay) \(ev.currency) \(ev.impact.rawValue) \(ev.event)"
        }.joined(separator: "\n").isEmpty ? "Keine bevorstehenden Events"
        : calendar.prefix(8).map { "- \($0.timeDisplay) \($0.currency) \($0.impact.rawValue) \($0.event)" }.joined(separator: "\n")

        let prompt = """
        Du bist Senior Quantitative Analyst eines Tier-1 Hedgefonds.
        Analysiere \(pair) für einen Trader der JETZT entscheiden muss.

        MARKTDATEN:
        Kurs: \(String(format: "%.5g", price)) | Tageschange: \(String(format: "%+.3f", changePct))%

        RELEVANTE NEWS:
        \(newsStr)

        KOMMENDE EVENTS:
        \(eventsStr)

        Liefere NUR valides JSON, kein Markdown:
        {"verdict":"bullish","confidence":72,"summary":"2-3 Sätze Kernthese Deutsch","entry_zone":"1.0850-1.0870","stop":"1.0820","target_1":"1.0950","target_2":"1.1020","risk_reward":"1:2.5","timeframe":"1-3 Tage","scenarios":{"bull":{"probability":55,"trigger":"Auslöser"},"base":{"probability":30,"trigger":"Auslöser"},"bear":{"probability":15,"trigger":"Auslöser"}},"macro_drivers":["Treiber1"],"catalysts":["Event1"],"risks":["Risiko1"],"flow_analysis":"1 Satz Orderflow","positioning":"1 Satz Positionierung","momentum":"bullish"}
        """
        await rateLimit()
        for m in deduped {
            guard let raw = try? await callClaude(model: m, prompt: prompt, maxTokens: 900),
                  let json = parseRawJSON(raw) else { continue }
            let sc = json["scenarios"] as? [String: Any] ?? [:]
            let bull = sc["bull"] as? [String: Any] ?? [:]
            let base = sc["base"] as? [String: Any] ?? [:]
            let bear = sc["bear"] as? [String: Any] ?? [:]
            return InstrumentAnalysis(
                verdict:       json["verdict"]       as? String ?? "neutral",
                confidence:    json["confidence"]    as? Int ?? 0,
                summary:       json["summary"]       as? String ?? "",
                entryZone:     json["entry_zone"]    as? String ?? "",
                stop:          json["stop"]          as? String ?? "",
                target1:       json["target_1"]      as? String ?? "",
                target2:       json["target_2"]      as? String ?? "",
                riskReward:    json["risk_reward"]   as? String ?? "",
                timeframe:     json["timeframe"]     as? String ?? "",
                macroDrivers:  json["macro_drivers"] as? [String] ?? [],
                catalysts:     json["catalysts"]     as? [String] ?? [],
                risks:         json["risks"]         as? [String] ?? [],
                flowAnalysis:  json["flow_analysis"] as? String ?? "",
                positioning:   json["positioning"]   as? String ?? "",
                momentum:      json["momentum"]      as? String ?? "",
                bullProb:      bull["probability"]   as? Int ?? 0,
                bullTrigger:   bull["trigger"]       as? String ?? "",
                baseProb:      base["probability"]   as? Int ?? 0,
                baseTrigger:   base["trigger"]       as? String ?? "",
                bearProb:      bear["probability"]   as? Int ?? 0,
                bearTrigger:   bear["trigger"]       as? String ?? ""
            )
        }
        return nil
    }

    // ── TTS via OpenAI ────────────────────────────────────────────
    func synthesizeSpeech(text: String) async -> Data? {
        guard let token = await appToken() else {
            print("[TTS] Kein App-Token verfügbar")
            return nil
        }
        guard let url = URL(string: "\(wixBaseURL)/aiTTS") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "token": token,
            "model": APIKeys.ttsModel,
            "voice": APIKeys.ttsVoice,
            "text": String(text.prefix(4096))
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            print("[TTS] JSON-Serialisierung fehlgeschlagen")
            return nil
        }
        req.httpBody = bodyData

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                print("[TTS] Kein HTTP-Response")
                return nil
            }
            guard http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let audioB64 = json["audioBase64"] as? String,
                  let audioData = Data(base64Encoded: audioB64) else {
                let errorBody = String(data: data, encoding: .utf8) ?? "(keine Details)"
                print("[TTS] Fehler HTTP \(http.statusCode): \(errorBody)")
                return nil
            }
            print("[TTS] Erfolg — \(audioData.count) Bytes MP3")
            return audioData
        } catch {
            print("[TTS] Netzwerkfehler: \(error.localizedDescription)")
            return nil
        }
    }

    // ── Interne Helfer ────────────────────────────────────────────

    private func getModel() async -> String? {
        if let m = workingModel { return m }
        let m = await testModel()
        return m.isEmpty ? nil : workingModel
    }

    private func callClaude(model: String, prompt: String, maxTokens: Int) async throws -> String {
        guard let token = await appToken(),
              let url = URL(string: "\(wixBaseURL)/aiClaude") else {
            throw URLError(.userAuthenticationRequired)
        }
        var req = URLRequest(url: url, timeoutInterval: 35)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "token": token,
            "model": model,
            "maxTokens": maxTokens,
            "prompt": prompt
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = json["ok"] as? Bool, ok,
              let text = json["text"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        return text
    }

    private func appToken() async -> String? {
        await MainActor.run {
            AuthService.shared.backendToken()
        }
    }

    private func parseRawJSON(_ raw: String) -> [String: Any]? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s*```\\s*$",      with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let d = t.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return j
    }

    private func parseAnalysis(_ raw: String) -> NewsAnalysis? {
        guard let json = parseRawJSON(raw) else { return nil }
        var ana = NewsAnalysis()
        ana.relevant  = json["relevant"]  as? Bool ?? true
        ana.score     = (json["score"]    as? Double) ?? Double(json["score"] as? Int ?? 0)
        ana.urgency   = json["urgency"]   as? String ?? "hours"
        ana.headline  = json["headline"]  as? String ?? ""
        ana.analysis  = json["analysis"]  as? String ?? ""
        ana.category  = json["category"]  as? String ?? ""
        ana.factors   = json["factors"]   as? [String] ?? []
        ana.summary   = json["summary"]   as? String ?? ""
        ana.macro     = json["macro"]     as? String ?? ""
        ana.risks     = json["risks"]     as? [String] ?? []
        ana.watchNext = json["watch_next"] as? String ?? ""

        if let pairsRaw = json["pairs"] as? [String: Any] {
            var pairs: [String: String] = [:]
            var details: [String: PairDetail] = [:]
            for (k, v) in pairsRaw {
                if let str = v as? String {
                    pairs[k] = str
                } else if let dict = v as? [String: Any] {
                    pairs[k] = dict["direction"] as? String ?? "neutral"
                    var pd = PairDetail()
                    pd.direction   = dict["direction"]  as? String ?? ""
                    pd.reasoning   = dict["reasoning"]  as? String ?? ""
                    pd.movePips    = dict["move_pips"]  as? String ?? ""
                    pd.probability = dict["probability"] as? Int ?? 0
                    details[k] = pd
                }
            }
            ana.pairs = pairs
            ana.pairDetails = details
        }

        if let strat = json["strategy"] as? [String: Any] {
            var s = TradeStrategy()
            s.bias   = strat["bias"]   as? String ?? ""
            s.entry  = strat["entry"]  as? String ?? ""
            s.stop   = strat["stop"]   as? String ?? ""
            s.target = strat["target"] as? String ?? ""
            ana.strategy = s
        }
        return ana
    }

    private func rateLimit(perMin: Int = 40) async {
        let now = Date()
        requestTimes = requestTimes.filter { now.timeIntervalSince($0) < 60 }
        if requestTimes.count >= perMin {
            let wait = 61 - now.timeIntervalSince(requestTimes.first!)
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        }
        requestTimes.append(Date())
    }
}
