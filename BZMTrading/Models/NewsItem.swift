import Foundation

struct NewsItem: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var source: String
    var url: String
    var published: Date
    var content: String
    var hash: String
    var score: Double
    var priority: Int
    var analysis: NewsAnalysis?

    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool { lhs.id == rhs.id }
}

struct NewsAnalysis: Codable, Equatable {
    var relevant: Bool = true
    var score: Double = 0
    var urgency: String = "hours"
    var headline: String = ""
    var analysis: String = ""
    var pairs: [String: String] = [:]         // "EUR/USD": "bullish"
    var category: String = ""
    var factors: [String] = []
    var summary: String = ""
    var macro: String = ""
    var risks: [String] = []
    var watchNext: String = ""

    // Detail fields
    var strategy: TradeStrategy?
    var pairDetails: [String: PairDetail] = [:]

    enum CodingKeys: String, CodingKey {
        case relevant, score, urgency, headline, analysis, pairs
        case category, factors, summary, macro, risks
        case watchNext = "watch_next"
        case strategy, pairDetails
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relevant   = (try? c.decode(Bool.self, forKey: .relevant)) ?? true
        score      = (try? c.decode(Double.self, forKey: .score)) ?? 0
        urgency    = (try? c.decode(String.self, forKey: .urgency)) ?? "hours"
        headline   = (try? c.decode(String.self, forKey: .headline)) ?? ""
        analysis   = (try? c.decode(String.self, forKey: .analysis)) ?? ""
        pairs      = (try? c.decode([String: String].self, forKey: .pairs)) ?? [:]
        category   = (try? c.decode(String.self, forKey: .category)) ?? ""
        factors    = (try? c.decode([String].self, forKey: .factors)) ?? []
        summary    = (try? c.decode(String.self, forKey: .summary)) ?? ""
        macro      = (try? c.decode(String.self, forKey: .macro)) ?? ""
        risks      = (try? c.decode([String].self, forKey: .risks)) ?? []
        watchNext  = (try? c.decode(String.self, forKey: .watchNext)) ?? ""
        strategy   = try? c.decode(TradeStrategy.self, forKey: .strategy)
        pairDetails = (try? c.decode([String: PairDetail].self, forKey: .pairDetails)) ?? [:]
    }

    init() {}
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(relevant, forKey: .relevant)
        try c.encode(score, forKey: .score)
        try c.encode(urgency, forKey: .urgency)
        try c.encode(headline, forKey: .headline)
        try c.encode(analysis, forKey: .analysis)
        try c.encode(pairs, forKey: .pairs)
        try c.encode(category, forKey: .category)
        try c.encode(factors, forKey: .factors)
        try c.encode(summary, forKey: .summary)
        try c.encode(macro, forKey: .macro)
        try c.encode(risks, forKey: .risks)
        try c.encode(watchNext, forKey: .watchNext)
        try? c.encode(strategy, forKey: .strategy)
        try? c.encode(pairDetails, forKey: .pairDetails)
    }
}

struct TradeStrategy: Codable, Equatable {
    var bias: String = ""
    var entry: String = ""
    var stop: String = ""
    var target: String = ""
}

struct PairDetail: Codable, Equatable {
    var direction: String = ""
    var reasoning: String = ""
    var movePips: String = ""
    var probability: Int = 0

    enum CodingKeys: String, CodingKey {
        case direction, reasoning, probability
        case movePips = "move_pips"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        direction   = (try? c.decode(String.self, forKey: .direction)) ?? ""
        reasoning   = (try? c.decode(String.self, forKey: .reasoning)) ?? ""
        movePips    = (try? c.decode(String.self, forKey: .movePips)) ?? ""
        probability = (try? c.decode(Int.self, forKey: .probability)) ?? 0
    }

    init() {}
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(direction, forKey: .direction)
        try c.encode(reasoning, forKey: .reasoning)
        try c.encode(movePips, forKey: .movePips)
        try c.encode(probability, forKey: .probability)
    }
}
