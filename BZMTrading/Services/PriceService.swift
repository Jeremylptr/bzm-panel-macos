import Foundation

typealias PriceUpdateCallback = ([String: PriceData]) async -> Void

/// Forex-Preise über drei Quellen (in Priorität):
///   1. Yahoo Finance Chart-API v8   — keine Authentifizierung nötig, ~live
///   2. jsDelivr CDN (currency-api)  — zuverlässiger CDN, täglich aktualisiert
///   3. Frankfurter.app (ECB)        — sehr zuverlässig, täglich
actor PriceService {
    private let config: Config
    private var previousPrices: [String: Double] = [:]

    private let cdnURLs = [
        "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json",
        "https://currency-api.pages.dev/v1/currencies/usd.json"
    ]

    init(config: Config) { self.config = config }

    func start(callback: @escaping PriceUpdateCallback) async {
        await fetch(callback: callback)
        while true {
            if MarketHours.isOpen {
                try? await Task.sleep(nanoseconds: UInt64(config.priceRefreshSeconds) * 1_000_000_000)
            } else {
                try? await Task.sleep(nanoseconds: 300_000_000_000)
            }
            await fetch(callback: callback)
        }
    }

    // MARK: - Haupt-Fetch

    private func fetch(callback: @escaping PriceUpdateCallback) async {
        let allPairs = config.marketPairs + config.marketExtras
        guard !allPairs.isEmpty else { return }

        var result: [String: PriceData] = [:]

        // ── Strategie 1: Yahoo Finance Chart-API v8 (live, kein Crumb nötig) ──
        let yahooResult = await fetchViaYahooChart(pairs: allPairs)
        for (pair, price) in yahooResult {
            result[pair] = makePrice(pair: pair, price: price)
        }

        // ── Strategie 2: jsDelivr CDN — für alle noch fehlenden Paare ──
        let missing2 = allPairs.filter { result[$0] == nil }
        if !missing2.isEmpty, let rates = await fetchCDNRates() {
            for pair in missing2 {
                if let price = rateFromUSD(pair, rates: rates) {
                    result[pair] = makePrice(pair: pair, price: price)
                }
            }
        }

        // ── Strategie 3: Frankfurter.app — letzter Fallback ──
        let missing3 = allPairs.filter { result[$0] == nil }
        if !missing3.isEmpty, let rates = await fetchFrankfurterRates() {
            for pair in missing3 {
                if let price = rateFromUSD(pair, rates: rates) {
                    result[pair] = makePrice(pair: pair, price: price)
                }
            }
        }

        if !result.isEmpty { await callback(result) }
    }

    // MARK: - Strategie 1: Yahoo Finance Chart-API v8

    private func fetchViaYahooChart(pairs: [String]) async -> [String: Double] {
        var result: [String: Double] = [:]
        await withTaskGroup(of: (String, Double?).self) { group in
            for pair in pairs {
                guard let ticker = resolveYahooTicker(pair) else { continue }
                group.addTask { (pair, await self.chartPrice(ticker: ticker)) }
            }
            for await (pair, price) in group {
                if let p = price { result[pair] = p }
            }
        }
        return result
    }

    private func chartPrice(ticker: String) async -> Double? {
        let encoded = ticker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ticker
        let urlStr  = "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1m&range=1d"
        guard let url = URL(string: urlStr) else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first   = results.first,
              let meta    = first["meta"] as? [String: Any] else { return nil }

        // regularMarketPrice ist der aktuellste Kurs
        if let price = meta["regularMarketPrice"] as? Double, price > 0 { return price }
        return meta["previousClose"] as? Double
    }

    // MARK: - Strategie 2: jsDelivr CDN

    private func fetchCDNRates() async -> [String: Double]? {
        for urlStr in cdnURLs {
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let inner = json["usd"] as? [String: Any] else { continue }
            var rates: [String: Double] = [:]
            for (k, v) in inner { if let d = v as? Double { rates[k.uppercased()] = d } }
            if !rates.isEmpty { return rates }
        }
        return nil
    }

    // MARK: - Strategie 3: Frankfurter.app (USD-Basis)

    private func fetchFrankfurterRates() async -> [String: Double]? {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 12)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = json["rates"] as? [String: Double] else { return nil }
        return rates
    }

    // MARK: - Kursberechnung aus USD-Basis

    private func rateFromUSD(_ pair: String, rates: [String: Double]) -> Double? {
        switch pair {
        case "USD/JPY": return rates["JPY"]
        case "USD/CHF": return rates["CHF"]
        case "USD/CAD": return rates["CAD"]
        case "USD/MXN": return rates["MXN"]
        case "USD/CNH": return rates["CNY"]
        case "EUR/USD": return inv(rates["EUR"])
        case "GBP/USD": return inv(rates["GBP"])
        case "AUD/USD": return inv(rates["AUD"])
        case "NZD/USD": return inv(rates["NZD"])
        case "EUR/JPY": return cross(inv(rates["EUR"]), rates["JPY"])
        case "EUR/GBP": return cross(rates["GBP"],     inv(rates["EUR"]))
        case "EUR/CHF": return cross(inv(rates["EUR"]), rates["CHF"])
        case "EUR/AUD": return cross(rates["AUD"],     inv(rates["EUR"]))
        case "GBP/JPY": return cross(inv(rates["GBP"]), rates["JPY"])
        case "GBP/CHF": return cross(inv(rates["GBP"]), rates["CHF"])
        case "GBP/AUD": return cross(rates["AUD"],     inv(rates["GBP"]))
        case "AUD/JPY": return cross(inv(rates["AUD"]), rates["JPY"])
        case "XAU/USD": return inv(rates["XAU"])
        case "DXY", "CRUDE", "US10Y": return nil
        default:
            let p = pair.split(separator: "/")
            guard p.count == 2 else { return nil }
            let b = String(p[0]), q = String(p[1])
            if q == "USD" { return inv(rates[b]) }
            if b == "USD" { return rates[q] }
            guard let bv = rates[b], let qv = rates[q], bv > 0 else { return nil }
            return qv / bv
        }
    }

    // MARK: - PriceData erzeugen

    private func makePrice(pair: String, price: Double) -> PriceData {
        let prev   = previousPrices[pair] ?? price
        let change = price - prev
        let pct    = prev > 0 ? (change / prev * 100) : 0
        previousPrices[pair] = price
        return PriceData(
            id: pair, pair: pair,
            price: price, change: change, changePct: pct,
            direction: change > 0.000001 ? .up : change < -0.000001 ? .down : .flat,
            timestamp: Date()
        )
    }

    // MARK: - Helfer

    private func inv(_ v: Double?) -> Double? {
        guard let v, v > 0 else { return nil }
        return 1.0 / v
    }
    private func cross(_ a: Double?, _ b: Double?) -> Double? {
        guard let a, let b, a > 0, b > 0 else { return nil }
        return a * b
    }
}
