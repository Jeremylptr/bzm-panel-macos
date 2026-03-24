import Foundation

struct Config: Codable {
    var claudeApiKey: String = ""
    var claudeFastModel: String = "claude-3-5-haiku-20241022"
    var claudeDetailModel: String = "claude-3-5-sonnet-20241022"
    var openaiApiKey: String = ""
    var openaiTTSModel: String = "gpt-4o-mini-tts"
    var openaiTTSVoice: String = "shimmer"
    var newsRefreshSeconds: Int = 10
    var newsMaxAgeHours: Int = 24
    var marketPairs: [String] = ["EUR/USD", "GBP/USD", "USD/JPY"]
    var marketExtras: [String] = ["DXY", "XAU/USD"]
    var priceRefreshSeconds: Int = 15
    var alertMinScore: Double = 7.0
    var newsSoundNormal: String = "Ping"
    var newsSoundHighImpact: String = "Hero"

    enum CodingKeys: String, CodingKey {
        case claudeApiKey = "claude_api_key"
        case claudeFastModel = "claude_fast_model"
        case claudeDetailModel = "claude_detail_model"
        case openaiApiKey = "openai_api_key"
        case openaiTTSModel = "openai_tts_model"
        case openaiTTSVoice = "openai_tts_voice"
        case newsRefreshSeconds = "news_refresh_seconds"
        case newsMaxAgeHours = "news_max_age_hours"
        case marketPairs = "market_pairs"
        case marketExtras = "market_extras"
        case priceRefreshSeconds = "price_refresh_seconds"
        case alertMinScore = "alert_min_score"
        case newsSoundNormal = "news_sound_normal"
        case newsSoundHighImpact = "news_sound_high_impact"
    }

    static func load() throws -> Config {
        let candidates = configCandidates()
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(Config.self, from: data)
            }
        }
        // No config found — use defaults (user can configure in Settings)
        return Config()
    }

    static func configCandidates() -> [String] {
        var paths: [String] = []
        // ~/Library/Application Support/BZM/config.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let base = appSupport {
            paths.append(base.appendingPathComponent("BZM/config.json").path)
        }
        // Next to the executable
        paths.append((Bundle.main.bundlePath as NSString).appendingPathComponent("Contents/Resources/config.json"))
        // Current directory
        paths.append("./config.json")
        return paths
    }

    func save() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("BZM")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("config.json")
        let data = try JSONEncoder().encode(self)
        try data.write(to: url)
    }

    static func defaultConfigPath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("BZM/config.json").path
    }
}
