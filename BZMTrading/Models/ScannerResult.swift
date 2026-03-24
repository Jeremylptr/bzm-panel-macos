import Foundation

struct ScannerResult {
    var opportunities: [Opportunity] = []
    var currencyStrength: [String: Double] = [:]
    var sessions: [String] = []
    var riskSentiment: String = "neutral"
    var updated: Date = Date()

    struct Opportunity: Identifiable {
        let id: String  // pair
        var pair: String
        var score: Double
        var direction: Direction
        var reasons: [String]
        var warning: Bool
        var newsCount: Int
        var baseStrength: Double
        var quoteStrength: Double

        enum Direction: String {
            case long, short, neutral
            var icon: String {
                switch self { case .long: return "▲ LONG"; case .short: return "▼ SHORT"; case .neutral: return "─" }
            }
        }
    }
}

let allForexPairs = [
    "EUR/USD", "GBP/USD", "USD/JPY", "USD/CHF",
    "AUD/USD", "USD/CAD", "NZD/USD",
    "EUR/GBP", "EUR/JPY", "GBP/JPY", "EUR/CHF",
    "AUD/JPY", "GBP/CHF", "EUR/AUD", "GBP/AUD",
    "XAU/USD",
]

let sessionPairsMap: [String: [String]] = [
    "london":   ["EUR/USD","GBP/USD","EUR/GBP","EUR/CHF","GBP/CHF","EUR/JPY","GBP/JPY"],
    "new_york": ["EUR/USD","GBP/USD","USD/JPY","USD/CAD","USD/CHF","XAU/USD"],
    "tokyo":    ["USD/JPY","EUR/JPY","GBP/JPY","AUD/JPY","AUD/USD","NZD/USD"],
    "sydney":   ["AUD/USD","NZD/USD","AUD/JPY"],
]
