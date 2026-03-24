import SwiftUI

struct MainView: View {
    @EnvironmentObject var state: AppState
    @State private var showSessionDialog = false

    var body: some View {
        VStack(spacing: 0) {
            TopBarView(showSessionDialog: $showSessionDialog)
            Divider().background(Color.borderMain)

            HStack(spacing: 0) {
                // LINKS — Forex Preise (fix)
                PricePanelView()
                    .frame(width: 280)

                Divider().background(Color.borderMain)

                // MITTE — News-Liste oben, Detail unten (klappt auf)
                CenterColumnView()
                    .frame(maxWidth: .infinity)

                Divider().background(Color.borderMain)

                // RECHTS — Kalender volle Höhe
                RightColumnView()
                    .frame(width: 360)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView()
        }
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $state.showSettings) { SettingsView() }
        .sheet(isPresented: $showSessionDialog) { SessionInfoView() }
        .sheet(item: Binding(
            get: { state.liveBriefing },
            set: { if $0 == nil { state.liveBriefing = nil } }
        )) { briefing in LiveBriefingView(briefing: briefing).environmentObject(state) }
        .sheet(item: Binding(
            get: { state.marketOverview },
            set: { if $0 == nil { state.marketOverview = nil } }
        )) { overview in MarketOverviewView(overview: overview).environmentObject(state) }
    }
}

// MARK: - Center Column
struct CenterColumnView: View {
    @EnvironmentObject var state: AppState
    @State private var detailHeight: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // News-Liste (oben, flexibel)
                NewsPanelView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Detail-Panel unten — erscheint wenn News ausgewählt
                if state.selectedNews != nil {
                    Divider().background(Color.borderLt)

                    // Drag-Handle
                    DragHandleBar(height: $detailHeight, minHeight: 220, maxHeight: geo.size.height * 0.7)

                    // Detail-Inhalt
                    DetailPanelView()
                        .frame(height: detailHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.selectedNews?.id)
        }
    }
}

// MARK: - Drag Handle
struct DragHandleBar: View {
    @Binding var height: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        ZStack {
            Color.bgHeader
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.borderLt)
                .frame(width: 40, height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 12)
        .cursor(.resizeUpDown)
        .gesture(
            DragGesture()
                .onChanged { v in
                    let newH = height - v.translation.height
                    height = min(maxHeight, max(minHeight, newH))
                }
        )
    }
}

// MARK: - Right Column (Kalender + Scanner-Tab)
struct RightColumnView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header mit Tabs
            HStack(spacing: 0) {
                Text("WIRTSCHAFTSKALENDER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.bzCyan)
                    .tracking(1.5)
                    .padding(.leading, 12)

                Spacer()

                // Scanner-Tab als kleiner Button
                Button {
                    state.showScannerPanel.toggle()
                } label: {
                    Text(state.showScannerPanel ? "KALENDER" : "SCANNER")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(state.showScannerPanel ? .bzBlue : .textMuted)
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.bgItem)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
            }
            .frame(height: 30)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

            if state.showScannerPanel {
                ScannerPanelView()
            } else {
                CalendarPanelView()
            }
        }
        .background(Color.bgPanel)
    }
}

// MARK: - Top Bar
struct TopBarView: View {
    @EnvironmentObject var state: AppState
    @Binding var showSessionDialog: Bool
    @State private var clockStr = ""
    @State private var marketStatus = MarketHours.status()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var effectiveMarketIsOpen: Bool { marketStatus.isOpen }
    private var effectiveMarketLabel: String { marketStatus.label }

    var body: some View {
        HStack(spacing: 0) {
            // Logo
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.bzBlue)
                    .frame(width: 3, height: 22)
                Text("◈")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(.bzBlue)
                Text("BZM PANEL")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.textHead)
                    .tracking(1)
            }
            .padding(.leading, 14)

            Spacer()

            // Markt-Status Badge (Wochenende / Session)
            Button { showSessionDialog = true } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(effectiveMarketIsOpen ? Color.bzGreen : Color.bzOrange)
                        .frame(width: 6, height: 6)
                    Text(effectiveMarketLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(effectiveMarketIsOpen ? .bzGreen : .bzOrange)
                        .tracking(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.bgItem)
                .cornerRadius(3)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // Live Briefing Button
            Button {
                state.requestLiveBriefing()
            } label: {
                HStack(spacing: 4) {
                    if state.isLoadingBriefing {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text("Live Briefing")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.bzGreen)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Color(hex: "#1b2d1a"))
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bzGreen.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(state.isLoadingBriefing)
            .padding(.trailing, 4)

            // Marktübersicht Button
            Button {
                state.requestMarketOverview()
            } label: {
                HStack(spacing: 4) {
                    if state.isLoadingOverview {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text("Marktübersicht")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.bzBlue)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Color(hex: "#1a253a"))
                .cornerRadius(3)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.bzBlue.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(state.isLoadingOverview)
            .padding(.trailing, 10)

            // Uhrzeit (ohne Zeitzone)
            Text(clockStr)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.bzCyan)
                .frame(minWidth: 140, alignment: .trailing)
                .padding(.trailing, 12)
                .onReceive(timer) { _ in updateClock() }
                .onAppear { updateClock() }

            Divider().frame(height: 22).background(Color.borderLt)

            // Settings
            Button { state.showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.textDim)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
        }
        .frame(height: 48)
        .background(
            LinearGradient(
                colors: [Color(hex: "#0a1628"), Color(hex: "#0d1a35"), Color(hex: "#0a1628")],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    private func updateClock() {
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy  HH:mm:ss"
        clockStr = df.string(from: now)
        marketStatus = MarketHours.status(at: now)
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack {
            Circle()
                .fill(Color.bzGreen)
                .frame(width: 5, height: 5)
            Text(state.status)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textDim)
                .lineLimit(1)
            Spacer()
            Text("\(state.news.filter { $0.analysis != nil }.count)/\(state.news.count) News")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(Color.bgHeader)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .top)
    }
}

// MARK: - Session Info Dialog
struct SessionInfoView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    static let sessions: [(String, Int, Int, String, [String])] = [
        ("Sydney",   21, 6,  "Mittel",    ["AUD/USD","NZD/USD","AUD/JPY"]),
        ("Tokyo",    23, 8,  "Hoch",      ["USD/JPY","EUR/JPY","GBP/JPY","AUD/JPY"]),
        ("London",   7,  16, "Sehr Hoch", ["EUR/USD","GBP/USD","EUR/GBP","USD/CHF"]),
        ("New York", 13, 22, "Sehr Hoch", ["EUR/USD","USD/CAD","USD/CHF","XAU/USD"]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TRADING SESSIONS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.bzCyan)
                Spacer()
                Button("Schließen") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.textDim)
            }
            .padding(16)
            .background(Color.bgHeader)

            HStack {
                let active = state.sessions.map { $0.uppercased() }.joined(separator: ", ")
                Text("Aktiv: \(active.isEmpty ? "Keine" : active)")
                    .font(terminalFontSmall).foregroundColor(.textDim)
                if let overlap = state.sessionOverlap {
                    Text("|").foregroundColor(.borderLt)
                    Text("★ \(overlap)").font(terminalFontSmall).foregroundColor(.bzGreen)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color.bgItem)

            Divider().background(Color.borderMain)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Session")   .sessHdr().frame(width: 90,  alignment: .leading)
                    Text("Lokal")     .sessHdr().frame(width: 100, alignment: .leading)
                    Text("UTC")       .sessHdr().frame(width: 100, alignment: .leading)
                    Text("Volumen")   .sessHdr().frame(width: 90,  alignment: .leading)
                    Text("Top Paare") .sessHdr().frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Color.bgHeader)

                ForEach(Self.sessions, id: \.0) { name, utcS, utcE, imp, pairs in
                    let isActive = state.sessions.contains { $0.lowercased() == name.lowercased() }
                    HStack(spacing: 0) {
                        Text(name)
                            .font(.system(size: 12, weight: isActive ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isActive ? .bzYellow : .textMain)
                            .frame(width: 90, alignment: .leading)
                        Text(utcToLocal(utcS) + "–" + utcToLocal(utcE))
                            .font(terminalFontSmall).foregroundColor(.textDim)
                            .frame(width: 100, alignment: .leading)
                        Text(String(format: "%02d:00–%02d:00", utcS, utcE))
                            .font(terminalFontSmall).foregroundColor(.textMuted)
                            .frame(width: 100, alignment: .leading)
                        Text(imp)
                            .font(terminalFontSmall)
                            .foregroundColor(imp.contains("Sehr") ? .bzGreen : .bzYellow)
                            .frame(width: 90, alignment: .leading)
                        Text(pairs.joined(separator: "  "))
                            .font(terminalFontSmall).foregroundColor(.textDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(isActive ? Color.bgSelected.opacity(0.3) : Color.clear)
                    Divider().background(Color.borderDim)
                }
            }

            Text("Tip: London + New York Overlap ist meist die liquideste Phase (enger Spread, starke Bewegungen bei EUR/USD, GBP/USD, Gold).")
                .font(terminalFontSmall).foregroundColor(.textMuted)
                .padding(16).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 860, height: 420)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
    }

    private func utcToLocal(_ h: Int) -> String {
        var c = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        c.hour = h; c.minute = 0; c.second = 0
        c.timeZone = TimeZone(identifier: "UTC")
        guard let d = Calendar.current.date(from: c) else { return String(format: "%02d:00", h) }
        let df = DateFormatter(); df.dateFormat = "HH:mm"; return df.string(from: d)
    }
}

private extension Text {
    func sessHdr() -> some View {
        self.font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(.textMuted).tracking(1)
    }
}

// MARK: - Cursor helper
private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Live Briefing View
struct LiveBriefingView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    let briefing: LiveBriefing

    @StateObject private var player = AudioPlayerService()
    @State private var isDragging = false

    // Wortanzahl im Text
    private var wordCount: Int {
        briefing.text.split(separator: " ").count
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform").foregroundColor(.bzGreen)
                    Text("LIVE BRIEFING")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.bzGreen)
                }
                Spacer()
                Text("~\(wordCount) Wörter · ≈\(max(1, wordCount / 120)) min")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textMuted)
                    .padding(.trailing, 12)
                Button("Schließen") {
                    player.stop()
                    dismiss()
                }
                .buttonStyle(.plain).foregroundColor(.textDim)
            }
            .padding(16)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Titel
                    Text(briefing.title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.textHead)

                    // ── Audio Player ─────────────────────────────
                    VStack(spacing: 10) {
                        if briefing.audioData != nil {
                            // Fortschrittsbalken
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.bgItem)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.bzGreen)
                                        .frame(width: geo.size.width * player.progress, height: 6)
                                        .animation(.linear(duration: 0.25), value: player.progress)
                                }
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                                    player.seek(to: min(1, max(0, v.location.x / geo.size.width)))
                                })
                            }
                            .frame(height: 6)

                            // Zeit + Controls
                            HStack(spacing: 16) {
                                Text(player.currentTimeFormatted)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.textDim)
                                    .frame(width: 36)

                                Spacer()

                                // Play / Pause
                                Button {
                                    if player.isPlaying {
                                        player.togglePlay()
                                    } else if player.duration > 0 {
                                        player.togglePlay()
                                    } else if let data = briefing.audioData {
                                        player.loadAndPlay(data: data)
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.bzGreen)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Text(player.durationFormatted)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.textDim)
                                    .frame(width: 36)
                            }

                            if let err = player.errorMessage {
                                Text(err)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.bzRed)
                            }
                        } else {
                            // Kein Audio — Fehlerhinweis
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.slash").foregroundColor(.textMuted)
                                Text("Audio nicht verfügbar — OpenAI TTS fehlgeschlagen")
                                    .font(terminalFontSmall).foregroundColor(.textMuted)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.bgItem).cornerRadius(6)
                        }
                    }
                    .padding(14)
                    .background(Color(hex: "#0d1f10"))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.bzGreen.opacity(0.25), lineWidth: 1))

                    // ── Briefing-Text ────────────────────────────
                    Text(briefing.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.textMain)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                        .padding(14)
                        .background(Color.bgItem)
                        .cornerRadius(8)

                    // ── Key Points ───────────────────────────────
                    if !briefing.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("KERNPUNKTE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted).tracking(1.5)
                            ForEach(briefing.keyPoints, id: \.self) { pt in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("▸").foregroundColor(.bzBlue)
                                    Text(pt).font(.system(size: 11, design: .monospaced)).foregroundColor(.textMain)
                                }
                            }
                        }
                    }

                    // ── Watch Next ───────────────────────────────
                    if !briefing.watchNext.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BEOBACHTEN")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted).tracking(1.5)
                            ForEach(briefing.watchNext, id: \.self) { ev in
                                HStack(spacing: 8) {
                                    Text("⏱").font(.system(size: 11))
                                    Text(ev).font(.system(size: 11, design: .monospaced)).foregroundColor(.bzCyan)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.bgMain)
        }
        .frame(width: 640, height: 580)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
        .onAppear {
            // Audio sofort laden sobald Fenster öffnet
            if let data = briefing.audioData {
                player.loadAndPlay(data: data)
            }
        }
        .onDisappear { player.stop() }
    }
}

// MARK: - Market Overview View
struct MarketOverviewView: View {
    @Environment(\.dismiss) var dismiss
    let overview: MarketOverview

    var sentimentColor: Color {
        switch overview.sentiment {
        case "risk-on":  return .bzGreen
        case "risk-off": return .bzRed
        default:         return .bzYellow
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis").foregroundColor(.bzBlue)
                    Text("MARKTÜBERSICHT")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.bzBlue)
                }
                Spacer()
                Button("Schließen") { dismiss() }.buttonStyle(.plain).foregroundColor(.textDim)
            }
            .padding(16)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Sentiment Badge
                    HStack {
                        Text(overview.sentiment.uppercased())
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(sentimentColor)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(sentimentColor.opacity(0.15))
                            .cornerRadius(6)
                        Spacer()
                        Text("Top: \(overview.topPair)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzYellow)
                    }

                    // Overview Text
                    Text(overview.overview)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.textMain)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(14).background(Color.bgItem).cornerRadius(8)

                    // Currency Sentiment Grid
                    VStack(spacing: 0) {
                        Text("WÄHRUNGS-SENTIMENT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted).tracking(1.5)
                            .padding(.bottom, 8)

                        HStack(spacing: 10) {
                            ForEach([("USD", overview.usd), ("EUR", overview.eur),
                                     ("GBP", overview.gbp), ("JPY", overview.jpy)], id: \.0) { cur, dir in
                                VStack(spacing: 4) {
                                    Text(cur)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(.textHead)
                                    Text(dir.uppercased())
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(dir == "bullish" ? .bzGreen : dir == "bearish" ? .bzRed : .textDim)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.bgItem)
                                .cornerRadius(6)
                            }
                        }
                    }

                    // Themes
                    if !overview.themes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MARKT-THEMEN")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted).tracking(1.5)
                            ForEach(overview.themes, id: \.self) { theme in
                                HStack(spacing: 8) {
                                    Text("▸").foregroundColor(.bzPurple)
                                    Text(theme).font(.system(size: 11, design: .monospaced)).foregroundColor(.textMain)
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Color.bgMain)
        }
        .frame(width: 560, height: 480)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
    }
}
