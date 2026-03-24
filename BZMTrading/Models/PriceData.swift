import Foundation

struct PriceData: Identifiable, Equatable {
    let id: String         // pair name
    let pair: String
    let price: Double
    let change: Double
    let changePct: Double
    let direction: Direction
    let timestamp: Date

    enum Direction: String { case up, down, flat }

    static func == (lhs: PriceData, rhs: PriceData) -> Bool {
        lhs.pair == rhs.pair && lhs.price == rhs.price
    }

    func formatted() -> String {
        formatPrice(pair: pair, price: price)
    }

    func changeFormatted() -> String {
        let pct = String(format: "%+.3f%%", changePct)
        return pct
    }
}

func formatPrice(pair: String, price: Double) -> String {
    switch pair {
    case "XAU/USD", "CRUDE": return String(format: "%.2f", price)
    case "USD/JPY", "EUR/JPY", "GBP/JPY", "AUD/JPY": return String(format: "%.3f", price)
    case "US10Y": return String(format: "%.3f%%", price)
    case "DXY": return String(format: "%.3f", price)
    default: return String(format: "%.5f", price)
    }
}

// Ticker mapping: display name -> Yahoo Finance symbol
let yahooTickerMap: [String: String] = [
    "EUR/USD": "EURUSD=X",
    "GBP/USD": "GBPUSD=X",
    "USD/JPY": "USDJPY=X",
    "USD/CHF": "USDCHF=X",
    "AUD/USD": "AUDUSD=X",
    "NZD/USD": "NZDUSD=X",
    "USD/CAD": "USDCAD=X",
    "EUR/GBP": "EURGBP=X",
    "EUR/JPY": "EURJPY=X",
    "GBP/JPY": "GBPJPY=X",
    "USD/MXN": "USDMXN=X",
    "USD/CNH": "USDCNH=X",
    "AUD/JPY": "AUDJPY=X",
    "EUR/CHF": "EURCHF=X",
    "GBP/CHF": "GBPCHF=X",
    "EUR/AUD": "EURAUD=X",
    "GBP/AUD": "GBPAUD=X",
    "DXY":     "DX-Y.NYB",
    "XAU/USD": "GC=F",
    "CRUDE":   "CL=F",
    "US10Y":   "^TNX",
]

func resolveYahooTicker(_ symbol: String) -> String? {
    if let t = yahooTickerMap[symbol] { return t }
    if symbol.contains("=") || symbol.contains("^") || symbol.contains("-") { return symbol }
    if symbol.contains("/") {
        let p = symbol.split(separator: "/")
        if p.count == 2 { return "\(p[0])\(p[1])=X" }
    }
    return nil
}
