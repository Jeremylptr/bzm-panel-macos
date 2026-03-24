import Foundation

actor ScannerService {
    func run(prices: [String: PriceData], news: [NewsItem], calendar: [CalendarEvent]) async -> ScannerResult {
        let strength = currencyStrength(prices: prices, news: news)
        var opps: [ScannerResult.Opportunity] = []

        for pair in allForexPairs {
            let opp = opportunityScore(pair: pair, prices: prices, news: news,
                                       strength: strength, calendar: calendar)
            opps.append(opp)
        }

        opps.sort {
            if $0.direction == .neutral && $1.direction != .neutral { return false }
            if $0.direction != .neutral && $1.direction == .neutral { return true }
            return $0.score > $1.score
        }

        return ScannerResult(
            opportunities: opps,
            currencyStrength: strength,
            sessions: currentSessions(),
            riskSentiment: riskSentiment(news: news),
            updated: Date()
        )
    }

    private func currencyStrength(prices: [String: PriceData], news: [NewsItem]) -> [String: Double] {
        let currencies = ["USD","EUR","GBP","JPY","AUD","CHF","CAD","NZD"]
        var strength = Dictionary(uniqueKeysWithValues: currencies.map { ($0, 0.0) })
        var counts   = Dictionary(uniqueKeysWithValues: currencies.map { ($0, 0) })

        for (pair, data) in prices {
            let chg = data.changePct
            let (base, quote) = pairCurrencies(pair)
            if strength[base] != nil && strength[quote] != nil {
                strength[base]!  += chg
                strength[quote]! -= chg
                counts[base]!  += 1
                counts[quote]! += 1
            }
        }

        let cutoff = Date().addingTimeInterval(-6 * 3600)
        for item in news {
            guard item.score >= 2, item.published >= cutoff else { continue }
            let weight = max(0.3, item.score / 10.0)

            // 1) AI-annotierte Paare (wenn vorhanden)
            if let ana = item.analysis {
                for (pair, dir) in ana.pairs {
                    let (base, quote) = pairCurrencies(pair)
                    if strength[base] != nil && strength[quote] != nil {
                        if dir == "bullish" {
                            strength[base]!  += weight
                            strength[quote]! -= weight * 0.5
                        } else if dir == "bearish" {
                            strength[base]!  -= weight
                            strength[quote]! += weight * 0.5
                        }
                    }
                }
            }

            // 2) Fallback ohne AI: erwähnte Währungen + Tonalität
            let bias = inferredDirectionalBias(item: item)
            if bias != 0 {
                let mentioned = mentionedCurrencies(in: (item.title + " " + item.content).lowercased())
                for cur in mentioned where strength[cur] != nil {
                    strength[cur]! += Double(bias) * weight * 0.6
                    counts[cur]! += 1
                }
            }
        }

        for c in currencies {
            if (counts[c] ?? 0) > 0 {
                strength[c] = strength[c]! / Double(max(counts[c]!, 1))
            }
            strength[c] = max(-10, min(10, strength[c] ?? 0))
        }
        return strength
    }

    private func opportunityScore(pair: String, prices: [String: PriceData], news: [NewsItem],
                                   strength: [String: Double], calendar: [CalendarEvent]) -> ScannerResult.Opportunity {
        var score = 0.0
        var reasons: [String] = []
        var bullPts = 0.0
        var bearPts = 0.0
        let (base, quote) = pairCurrencies(pair)

        // 1. Currency strength
        let baseStr  = strength[base] ?? 0
        let quoteStr = strength[quote] ?? 0
        let diff = baseStr - quoteStr
        if abs(diff) > 0.3 {
            let pts = min(2.0, abs(diff) * 0.8)
            score += pts
            if diff > 0 { bullPts += pts; reasons.append("\(base) stark (+\(String(format: "%.1f", baseStr)))") }
            else        { bearPts += pts; reasons.append("\(quote) stark (+\(String(format: "%.1f", quoteStr)))") }
        }

        // 2. Price momentum
        if let pdata = prices[pair] {
            let chg = pdata.changePct
            if abs(chg) > 0.05 {
                let pts = min(2.0, abs(chg) * 4)
                score += pts
                if chg > 0 { bullPts += pts; reasons.append("Momentum ▲\(String(format: "%+.2f", chg))%") }
                else       { bearPts += pts; reasons.append("Momentum ▼\(String(format: "%+.2f", chg))%") }
            }
        }

        // 3. News sentiment (last 4h)
        let relevant = news.filter { item in
            guard item.score >= 2 else { return false }
            return isRelevantToPair(item: item, pair: pair)
        }
        var newsBull = 0.0, newsBear = 0.0
        for item in relevant.suffix(8) {
            let w = max(0.3, item.score / 10.0)
            if let ana = item.analysis, let dir = ana.pairs[pair] {
                if dir == "bullish" { newsBull += w } else if dir == "bearish" { newsBear += w }
            } else {
                let inferred = inferredPairBias(item: item, pair: pair)
                if inferred > 0 { newsBull += w }
                if inferred < 0 { newsBear += w }
            }
        }
        let newsDiff = newsBull - newsBear
        if abs(newsDiff) > 0.2 {
            let pts = min(3.0, abs(newsDiff) * 1.5)
            score += pts
            if newsDiff > 0 { bullPts += pts; reasons.append("News: \(Int(newsBull))x bullish") }
            else            { bearPts += pts; reasons.append("News: \(Int(newsBear))x bearish") }
        }

        // 4. Session bonus
        let active = currentSessions()
        for sess in active {
            if sessionPairsMap[sess]?.contains(pair) == true {
                score += 1.0
                reasons.append("\(sess.capitalized) Session aktiv")
                break
            }
        }

        // 5. Warning: high-impact event soon
        var warning = false
        for ev in calendar {
            guard ev.impact == .high, pair.contains(ev.currency) else { continue }
            if let mins = ev.minutesUntil, mins >= 0 && mins <= 30 {
                warning = true
                reasons.append("⚠ High-Impact in \(Int(mins)) min")
            }
        }

        let direction: ScannerResult.Opportunity.Direction
        if bullPts > bearPts + 0.4       { direction = .long }
        else if bearPts > bullPts + 0.4  { direction = .short }
        else if diff > 0.25              { direction = .long }
        else if diff < -0.25             { direction = .short }
        else { direction = .neutral; score *= 0.7 }

        return ScannerResult.Opportunity(
            id: pair, pair: pair,
            score: min(10, round(score * 10) / 10),
            direction: direction,
            reasons: Array(reasons.prefix(4)),
            warning: warning,
            newsCount: relevant.count,
            baseStrength: round(baseStr * 100) / 100,
            quoteStrength: round(quoteStr * 100) / 100
        )
    }

    private func currentSessions() -> [String] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let hour = cal.component(.hour, from: Date())
        var sessions: [String] = []
        if hour >= 22 || hour < 8  { sessions.append("sydney") }
        if hour >= 0  && hour < 9  { sessions.append("tokyo") }
        if hour >= 7  && hour < 17 { sessions.append("london") }
        if hour >= 12 && hour < 22 { sessions.append("new_york") }
        return sessions.isEmpty ? ["off"] : sessions
    }

    private func riskSentiment(news: [NewsItem]) -> String {
        let riskOn  = ["growth","optimism","rally","stimulus","jobs","employment","expansion","deal"]
        let riskOff = ["recession","crisis","conflict","war","default","inflation","tightening","collapse"]
        var on = 0.0, off = 0.0
        for item in news {
            guard item.score >= 3 else { continue }
            let text = (item.title + " " + item.content.prefix(300)).lowercased()
            let w = item.score / 10.0
            on  += riskOn.filter  { text.contains($0) }.count.toDouble * w
            off += riskOff.filter { text.contains($0) }.count.toDouble * w
        }
        if on > off * 1.5  { return "risk-on" }
        if off > on * 1.5  { return "risk-off" }
        return "neutral"
    }

    private func pairCurrencies(_ pair: String) -> (String, String) {
        let p = pair.replacingOccurrences(of: "/", with: "")
        if pair == "XAU/USD" { return ("XAU", "USD") }
        if p.count >= 6 { return (String(p.prefix(3)), String(p.dropFirst(3).prefix(3))) }
        return ("", "")
    }

    private func isRelevantToPair(item: NewsItem, pair: String) -> Bool {
        if let ana = item.analysis, ana.pairs[pair] != nil { return true }
        let (base, quote) = pairCurrencies(pair)
        let text = (item.title + " " + item.content).lowercased()
        return text.contains(base.lowercased()) || text.contains(quote.lowercased()) || text.contains(pair.lowercased())
    }

    private func inferredPairBias(item: NewsItem, pair: String) -> Int {
        let (base, quote) = pairCurrencies(pair)
        let text = (item.title + " " + item.content).lowercased()
        let baseMentioned = text.contains(base.lowercased())
        let quoteMentioned = text.contains(quote.lowercased())
        guard baseMentioned || quoteMentioned else { return 0 }

        let directional = inferredDirectionalBias(item: item)
        if directional == 0 { return 0 }
        if baseMentioned && !quoteMentioned { return directional }
        if quoteMentioned && !baseMentioned { return -directional }
        return directional
    }

    private func inferredDirectionalBias(item: NewsItem) -> Int {
        let text = (item.title + " " + item.content).lowercased()
        let bullish = [
            "rate hike", "hawkish", "strong", "beat", "above forecast", "higher than expected",
            "inflation up", "tightening", "surge", "rally"
        ]
        let bearish = [
            "rate cut", "dovish", "weak", "miss", "below forecast", "lower than expected",
            "recession", "slowdown", "drop", "selloff"
        ]
        let b = bullish.filter { text.contains($0) }.count
        let s = bearish.filter { text.contains($0) }.count
        if b > s { return 1 }
        if s > b { return -1 }
        return 0
    }

    private func mentionedCurrencies(in text: String) -> Set<String> {
        let map: [String: [String]] = [
            "USD": [" usd", "dollar", "federal reserve", "fed"],
            "EUR": [" eur", "euro", "ecb", "european central bank"],
            "GBP": [" gbp", "pound", "sterling", "bank of england", "boe"],
            "JPY": [" jpy", "yen", "bank of japan", "boj"],
            "AUD": [" aud", "aussie", "reserve bank of australia", "rba"],
            "CHF": [" chf", "franc", "snb", "swiss national bank"],
            "CAD": [" cad", "loonie", "bank of canada", "boc"],
            "NZD": [" nzd", "kiwi", "rbnz"]
        ]
        var out = Set<String>()
        for (cur, keys) in map where keys.contains(where: { text.contains($0) }) {
            out.insert(cur)
        }
        return out
    }
}

private extension Int {
    var toDouble: Double { Double(self) }
}
