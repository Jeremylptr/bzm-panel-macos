// ═══════════════════════════════════════════════════════════════════
//  APIKeys.swift — Pre-coded API-Schlüssel
//  Nutzer müssen keine eigenen Keys eintragen.
// ═══════════════════════════════════════════════════════════════════

enum APIKeys {
    /// Anthropic Claude API Key
    static let claude  = "DEIN_CLAUDE_KEY"

    /// OpenAI API Key (für TTS-Sprachausgabe)
    static let openAI  = "DEIN_OPENAI_KEY"

    /// OpenAI TTS Voice: alloy | echo | fable | onyx | nova | shimmer
    static let ttsVoice = "alloy"

    /// OpenAI TTS Model
    static let ttsModel = "tts-1"
}
