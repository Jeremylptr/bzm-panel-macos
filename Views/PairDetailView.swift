import SwiftUI

// Forex-Paar Detail-Dialog — öffnet sich per Klick auf eine Preis-Zeile
struct PairDetailView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    let pair: String

    @State private var isAnalyzing = false
    @State private var analysis: InstrumentAnalysis? = nil
    @State private var showAnalysis = false

    private var data: PriceData? { state.prices[pair] }

    // News die das Paar betreffen
    private var relatedNews: [NewsItem] {
        let p = pair.replacingOccurrences(of: "/", with: "").lowercased()
        let currencies = [
            String(p.prefix(3)),
            String(p.suffix(3))
        ]
        return state.news
            .filter { item in
                let haystack = (item.title + " " + (item.analysis?.headline ?? "")).lowercased()
                return currencies.contains { haystack.contains($0) }
                    || (item.analysis?.pairs.keys.contains { $0.replacingOccurrences(of: "/", with: "").lowercased() == p } == true)
            }
            .prefix(8)
            .map { $0 }
    }

    // Währungsbeschreibungen
    private static let currencyInfo: [String: (flag: String, name: String, zone: String, desc: String)] = [
        "USD": ("🇺🇸", "US-Dollar",           "USA",         "Leitwährung der Welt. Reagiert stark auf Fed, NFP, CPI, BIP-Daten."),
        "EUR": ("🇪🇺", "Euro",                "Eurozone",    "Zweitwichtigste Reservewährung. EZB-Entscheidungen und Euro-Inflation im Fokus."),
        "GBP": ("🇬🇧", "Britisches Pfund",    "UK",          "Oft volatil — Brexit-Nachwirkungen, BoE-Politik und UK-Konjunkturdaten."),
        "JPY": ("🇯🇵", "Japanischer Yen",     "Japan",       "Safe-Haven-Währung. BoJ-YCC und Zinsdifferenz zu USA/EU bestimmen JPY."),
        "CHF": ("🇨🇭", "Schweizer Franken",   "Schweiz",     "Safe-Haven. SNB interveniert gelegentlich. Kaum Inflation, stabile Wirtschaft."),
        "CAD": ("🇨🇦", "Kanadischer Dollar",  "Kanada",      "Rohstoff-Währung. Ölpreis und BoC-Zinsentscheid beeinflussen CAD stark."),
        "AUD": ("🇦🇺", "Australischer Dollar","Australien",  "Rohstoff-Währung (Eisenerz, Gold). RBA-Politik und China-Konjunktur relevant."),
        "NZD": ("🇳🇿", "Neuseeland-Dollar",   "Neuseeland",  "Ähnlich AUD, reagiert auf Milch-/Rohstoffpreise und RBNZ-Entscheidungen."),
        "XAU": ("🥇", "Gold (XAU)",           "Global",      "Safe-Haven und Inflationsschutz. USD-Stärke und Realzinsen bestimmen den Preis."),
        "DXY": ("📊", "US-Dollar-Index",      "Global",      "Misst den USD gegen einen Korb aus 6 Währungen (EUR, JPY, GBP, CAD, SEK, CHF)."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("◈")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.bzBlue)
                        Text(pair)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.textHead)
                    }
                    Text(pairSubtitle)
                        .font(terminalFontSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                // Preis-Box
                if let d = data {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(d.direction == .up ? "▲" : d.direction == .down ? "▼" : "─")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(priceColor(d))
                            Text(d.formatted())
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(priceColor(d))
                        }
                        Text(d.changeFormatted())
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(priceColor(d))
                        Text("Aktualisiert: " + timeAgo(d.timestamp))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textMuted)
                    }
                } else {
                    ProgressView()
                }

                // KI-Analyse Button
                Button {
                    isAnalyzing = true
                    Task {
                        let result = await state.requestInstrumentAnalysis(pair: pair)
                        await MainActor.run {
                            isAnalyzing = false
                            if let r = result { analysis = r; showAnalysis = true }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isAnalyzing {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "brain").font(.system(size: 10, weight: .bold))
                        }
                        Text("KI ANALYSE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.bzPurple)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color(hex: "#1a1028"))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bzPurple.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)
                .padding(.trailing, 8)

                Button("Schließen") { dismiss() }
                    .buttonStyle(.plain)
                    .font(terminalFontSmall)
                    .foregroundColor(.textDim)
                    .padding(.leading, 4)
            }
            .padding(20)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

            // ── Inhalt ──────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Währungsinfo-Karten
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(pairCurrencies, id: \.self) { cur in
                            if let info = Self.currencyInfo[cur] {
                                CurrencyInfoCard(code: cur, info: info)
                            }
                        }
                    }

                    Divider().background(Color.borderDim)

                    // Statistik-Zeile
                    if let d = data {
                        HStack(spacing: 0) {
                            StatBox(label: "KURS",    value: d.formatted(),     color: priceColor(d))
                            StatBox(label: "Δ",       value: d.changeFormatted(), color: priceColor(d))
                            StatBox(label: "RICHTUNG", value: d.direction == .up ? "▲ Steigend" : d.direction == .down ? "▼ Fallend" : "─ Neutral", color: priceColor(d))
                            StatBox(label: "LAST UPD", value: timeAgo(d.timestamp), color: .textDim)
                        }
                        .background(Color.bgItem)
                        .cornerRadius(6)
                    }

                    // Verwandte News
                    if !relatedNews.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("VERWANDTE NEWS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .tracking(1.5)
                                .padding(.bottom, 8)

                            ForEach(relatedNews) { item in
                                NewsCompactRow(item: item)
                                Divider().background(Color.borderDim)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "newspaper")
                                .foregroundColor(.textMuted)
                            Text("Keine aktuellen News für \(pair) verfügbar")
                                .font(terminalFontSmall)
                                .foregroundColor(.textMuted)
                        }
                        .padding()
                        .background(Color.bgItem)
                        .cornerRadius(6)
                    }

                    // Hinweis
                    Text("Hinweis: Keine Anlageberatung — immer eigenes Risiko und Kontext (Trend, Korrelationen, andere Termine) beachten.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
            .background(Color.bgMain)
        }
        .frame(width: 700, height: 560)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAnalysis) {
            if let ana = analysis {
                InstrumentAnalysisView(pair: pair, analysis: ana)
            }
        }
    }

    // Hilfs-Berechnungen
    private var pairCurrencies: [String] {
        let cleaned = pair.replacingOccurrences(of: "/", with: "")
        guard cleaned.count >= 6 else { return [cleaned] }
        return [String(cleaned.prefix(3)), String(cleaned.suffix(3))]
    }

    private var pairSubtitle: String {
        let curs = pairCurrencies
        let names = curs.compactMap { Self.currencyInfo[$0]?.name }
        if names.count == 2 { return "\(names[0])  /  \(names[1])" }
        return pair
    }

    private func priceColor(_ d: PriceData) -> Color {
        if d.changePct > 0.001 { return .bzGreen }
        if d.changePct < -0.001 { return .bzRed }
        return .textDim
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "gerade eben" }
        if s < 3600 { return "vor \(s/60)m" }
        return "vor \(s/3600)h"
    }
}

// ── Sub-Views ─────────────────────────────────────────────────────

private struct CurrencyInfoCard: View {
    let code: String
    let info: (flag: String, name: String, zone: String, desc: String)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(info.flag).font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text(code)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.textHead)
                    Text(info.name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textDim)
                }
            }
            Text(info.zone)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1)
            Text(info.desc)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgItem)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderDim, lineWidth: 1))
    }
}

private struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Instrument Analysis View
struct InstrumentAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    let pair: String
    let analysis: InstrumentAnalysis

    var verdictColor: Color {
        switch analysis.verdict {
        case "bullish":  return .bzGreen
        case "bearish":  return .bzRed
        default:         return .bzYellow
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("◈  KI INSTRUMENT-ANALYSE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.bzPurple).tracking(1)
                    Text(pair)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.textHead)
                }
                Spacer()

                // Verdict Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(analysis.verdict.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(verdictColor)
                    Text("Confidence: \(analysis.confidence)%")
                        .font(terminalFontSmall)
                        .foregroundColor(.textDim)
                }
                .padding(.trailing, 12)

                Button("Schließen") { dismiss() }
                    .buttonStyle(.plain).foregroundColor(.textDim)
            }
            .padding(16)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary
                    Text(analysis.summary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.textMain)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12).background(Color.bgItem).cornerRadius(8)

                    // Trade Setup
                    if !analysis.entryZone.isEmpty {
                        VStack(spacing: 0) {
                            Text("TRADE SETUP")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted).tracking(1.5)
                                .padding(.bottom, 8)
                            HStack(spacing: 10) {
                                SetupBox(label: "ENTRY",       value: analysis.entryZone, color: .bzBlue)
                                SetupBox(label: "STOP",        value: analysis.stop,      color: .bzRed)
                                SetupBox(label: "TARGET 1",    value: analysis.target1,   color: .bzGreen)
                                SetupBox(label: "TARGET 2",    value: analysis.target2,   color: .bzGreen)
                                SetupBox(label: "R:R",         value: analysis.riskReward,color: .bzYellow)
                                SetupBox(label: "ZEITRAHMEN",  value: analysis.timeframe, color: .textDim)
                            }
                        }
                    }

                    // Szenarien
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SZENARIEN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted).tracking(1.5)
                        HStack(spacing: 10) {
                            ScenarioBox(label: "BULLISH",  prob: analysis.bullProb, trigger: analysis.bullTrigger, color: .bzGreen)
                            ScenarioBox(label: "BASIS",    prob: analysis.baseProb, trigger: analysis.baseTrigger, color: .bzYellow)
                            ScenarioBox(label: "BEARISH",  prob: analysis.bearProb, trigger: analysis.bearTrigger, color: .bzRed)
                        }
                    }

                    // Listen
                    if !analysis.macroDrivers.isEmpty {
                        BulletSection(title: "MAKRO-TREIBER",   items: analysis.macroDrivers, color: .bzCyan)
                    }
                    if !analysis.catalysts.isEmpty {
                        BulletSection(title: "KATALYSATOREN",   items: analysis.catalysts,    color: .bzBlue)
                    }
                    if !analysis.risks.isEmpty {
                        BulletSection(title: "RISIKEN",          items: analysis.risks,        color: .bzOrange)
                    }

                    // Flow & Positioning
                    if !analysis.flowAnalysis.isEmpty {
                        InfoRow(label: "ORDERFLOW",      value: analysis.flowAnalysis)
                    }
                    if !analysis.positioning.isEmpty {
                        InfoRow(label: "POSITIONIERUNG", value: analysis.positioning)
                    }
                    if !analysis.momentum.isEmpty {
                        InfoRow(label: "MOMENTUM",       value: analysis.momentum)
                    }
                }
                .padding(16)
            }
            .background(Color.bgMain)
        }
        .frame(width: 760, height: 600)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
    }
}

private struct SetupBox: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.textMuted).tracking(1)
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8).background(Color.bgItem).cornerRadius(6)
    }
}

private struct ScenarioBox: View {
    let label: String; let prob: Int; let trigger: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(color)
                Spacer()
                Text("\(prob)%").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(color)
            }
            Text(trigger).font(.system(size: 10, design: .monospaced)).foregroundColor(.textDim)
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06)).cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

private struct BulletSection: View {
    let title: String; let items: [String]; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.textMuted).tracking(1.5)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("▸").foregroundColor(color).font(terminalFontSmall)
                    Text(item).font(.system(size: 11, design: .monospaced)).foregroundColor(.textMain)
                }
            }
        }
    }
}

private struct InfoRow: View {
    let label: String; let value: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.textMuted)
                .tracking(1).frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundColor(.textDim)
        }
    }
}

private struct NewsCompactRow: View {
    let item: NewsItem
    var score: Double { max(1, item.analysis?.score ?? item.score) }
    var headline: String { item.analysis?.headline.isEmpty == false ? item.analysis!.headline : item.title }

    var body: some View {
        HStack(spacing: 8) {
            if score > 0 {
                Text("\(Int(score))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.scoreColor(score))
                    .frame(width: 18, height: 18)
                    .background(Color.scoreColor(score).opacity(0.15))
                    .cornerRadius(3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textMain)
                    .lineLimit(2)
                Text(item.source.uppercased() + "  ·  " + relativeTime(item.published))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textMuted)
            }
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private func relativeTime(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "jetzt" }
        if s < 3600 { return "vor \(s/60)m" }
        return "vor \(s/3600)h"
    }
}
