import SwiftUI

struct DetailPanelView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            Color.bgPanel
            if let item = state.selectedNews {
                VStack(spacing: 0) {
                    // Kompakte Header-Leiste mit Schließen
                    HStack {
                        Text("◈ DETAIL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzPurple)
                            .tracking(1.5)

                        Spacer()

                        if state.isAnalyzingDetail {
                            ProgressView().scaleEffect(0.65).padding(.trailing, 4)
                        } else {
                            Button {
                                state.requestDetailAnalysis(item: item)
                            } label: {
                                Text("TIEFENANALYSE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.bzBlue)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.bgItem)
                                    .cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            state.selectedNews = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.textMuted)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                        .padding(.trailing, 10)
                    }
                    .frame(height: 30)
                    .background(Color.bgHeader)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

                    DetailContentView(item: item)
                        .id(item.id)
                }
            } else {
                EmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "newspaper")
                .font(.system(size: 40))
                .foregroundColor(.textMuted)
            Text("News auswählen")
                .font(terminalFontSmall)
                .foregroundColor(.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DetailContentView: View {
    @EnvironmentObject var state: AppState
    let item: NewsItem

    var ana: NewsAnalysis? { item.analysis }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DETAIL")
                    .panelHeader()
                Spacer()
                if state.isAnalyzingDetail {
                    ProgressView().scaleEffect(0.7)
                        .padding(.trailing, 8)
                } else {
                    Button {
                        state.requestDetailAnalysis(item: item)
                    } label: {
                        Text("TIEFENANALYSE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzPurple)
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.bgItem)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Source + time
                    HStack {
                        Text(item.source.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .tracking(1)
                        Spacer()
                        Text(item.published, style: .relative)
                            .font(terminalFontSmall)
                            .foregroundColor(.textMuted)
                    }

                    // Title
                    Text(ana?.headline.isEmpty == false ? ana!.headline : item.title)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textHead)

                    // Score + urgency
                    if let ana {
                        HStack(spacing: 10) {
                            ScoreBadge(score: ana.score)
                            UrgencyBadge(urgency: ana.urgency)
                            if !ana.category.isEmpty {
                                CategoryBadge(category: ana.category)
                            }
                        }
                    }

                    Divider().background(Color.borderDim)

                    // AI Analysis
                    if let ana {
                        if !ana.analysis.isEmpty {
                            SectionBox(title: "KI-ANALYSE") {
                                Text(ana.analysis)
                                    .font(terminalFontSmall)
                                    .foregroundColor(.textMain)
                            }
                        }

                        if !ana.summary.isEmpty {
                            SectionBox(title: "ZUSAMMENFASSUNG") {
                                Text(ana.summary)
                                    .font(terminalFontSmall)
                                    .foregroundColor(.textMain)
                            }
                        }

                        // Pairs impact
                        if !ana.pairs.isEmpty {
                            SectionBox(title: "BETROFFENE PAARE") {
                                PairsGrid(pairs: ana.pairs)
                            }
                        }

                        // Strategy
                        if let strat = ana.strategy, !strat.bias.isEmpty {
                            SectionBox(title: "TRADE-SETUP") {
                                TradeSetupView(strategy: strat)
                            }
                        }

                        // Factors / risks
                        if !ana.factors.isEmpty {
                            SectionBox(title: "FAKTOREN") {
                                BulletList(items: ana.factors, color: .bzBlue)
                            }
                        }

                        if !ana.risks.isEmpty {
                            SectionBox(title: "RISIKEN") {
                                BulletList(items: ana.risks, color: .bzOrange)
                            }
                        }

                        if !ana.macro.isEmpty {
                            SectionBox(title: "MAKRO") {
                                Text(ana.macro)
                                    .font(terminalFontSmall)
                                    .foregroundColor(.textDim)
                            }
                        }

                        if !ana.watchNext.isEmpty {
                            SectionBox(title: "BEOBACHTEN") {
                                Text(ana.watchNext)
                                    .font(terminalFontSmall)
                                    .foregroundColor(.bzCyan)
                            }
                        }
                    }

                    Divider().background(Color.borderDim)

                    // Original content
                    if !item.content.isEmpty {
                        SectionBox(title: "ORIGINAL") {
                            Text(item.content)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.textDim)
                        }
                    }

                    // Link
                    if !item.url.isEmpty, let url = URL(string: item.url) {
                        Link(destination: url) {
                            Text("→ Quelle öffnen")
                                .font(terminalFontSmall)
                                .foregroundColor(.bzBlue)
                        }
                    }
                }
                .padding(14)
            }
        }
    }
}

// MARK: - Sub views
struct ScoreBadge: View {
    let score: Double
    var body: some View {
        HStack(spacing: 4) {
            Text("\(Int(score))/10")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color.scoreColor(score))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.scoreColor(score).opacity(0.15))
        .cornerRadius(4)
    }
}

struct UrgencyBadge: View {
    let urgency: String
    var icon: String {
        switch urgency {
        case "immediate": return "⚡ SOFORT"
        case "hours":     return "⏱ STUNDEN"
        case "days":      return "📅 TAGE"
        default:          return urgency.uppercased()
        }
    }
    var color: Color {
        switch urgency {
        case "immediate": return .bzYellow
        case "hours":     return .bzBlue
        default:          return .textDim
        }
    }
    var body: some View {
        Text(icon)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

struct CategoryBadge: View {
    let category: String
    var body: some View {
        Text(category.replacingOccurrences(of: "_", with: " ").uppercased())
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.bgItem)
            .cornerRadius(4)
    }
}

struct PairsGrid: View {
    let pairs: [String: String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
            ForEach(pairs.sorted(by: { $0.key < $1.key }), id: \.key) { pair, dir in
                HStack {
                    Text(pair)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.textMain)
                    Spacer()
                    Text(dir == "bullish" ? "▲" : dir == "bearish" ? "▼" : "─")
                        .foregroundColor(dir == "bullish" ? .bzGreen : dir == "bearish" ? .bzRed : .textDim)
                    Text(dir.uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(dir == "bullish" ? .bzGreen : dir == "bearish" ? .bzRed : .textDim)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.bgItem)
                .cornerRadius(4)
            }
        }
    }
}

struct TradeSetupView: View {
    let strategy: TradeStrategy
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !strategy.bias.isEmpty {
                HStack {
                    Text("Bias").font(terminalFontSmall).foregroundColor(.textMuted).frame(width: 60, alignment: .leading)
                    Text(strategy.bias).font(terminalFontSmall).foregroundColor(.bzYellow).fontWeight(.semibold)
                }
            }
            if !strategy.entry.isEmpty {
                HStack {
                    Text("Entry").font(terminalFontSmall).foregroundColor(.textMuted).frame(width: 60, alignment: .leading)
                    Text(strategy.entry).font(terminalFontSmall).foregroundColor(.textMain)
                }
            }
            if !strategy.stop.isEmpty {
                HStack {
                    Text("Stop").font(terminalFontSmall).foregroundColor(.textMuted).frame(width: 60, alignment: .leading)
                    Text(strategy.stop).font(terminalFontSmall).foregroundColor(.bzRed)
                }
            }
            if !strategy.target.isEmpty {
                HStack {
                    Text("Target").font(terminalFontSmall).foregroundColor(.textMuted).frame(width: 60, alignment: .leading)
                    Text(strategy.target).font(terminalFontSmall).foregroundColor(.bzGreen)
                }
            }
        }
        .padding(10)
        .background(Color.bgItem)
        .cornerRadius(6)
    }
}

struct BulletList: View {
    let items: [String]
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").foregroundColor(color).font(terminalFontSmall)
                    Text(item).font(terminalFontSmall).foregroundColor(.textMain)
                }
            }
        }
    }
}

struct SectionBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1.5)
            content()
        }
    }
}
