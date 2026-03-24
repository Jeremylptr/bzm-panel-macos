import SwiftUI

struct PricePanelView: View {
    @EnvironmentObject var state: AppState
    @State private var localMarketStatus = MarketHours.status()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var mainPairs: [String] { state.config.marketPairs }
    var extraPairs: [String] { state.config.marketExtras }

    private var marketsOpen: Bool { localMarketStatus.isOpen }
    private var closedDetail: String { localMarketStatus.detail }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("FOREX PREISE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.bzCyan)
                .tracking(2)
                .panelHeader()

            // Wochenend-Banner
            if !marketsOpen {
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.bzOrange)
                        Text("MÄRKTE GESCHLOSSEN")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzOrange)
                            .tracking(1)
                    }
                    Text(closedDetail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(hex: "#1f1200"))
                .overlay(Rectangle().frame(height: 1).foregroundColor(.bzOrange.opacity(0.3)), alignment: .bottom)
            }

            // Spalten-Kopf
            HStack(spacing: 0) {
                Text("PAAR")
                    .priceColHdr().frame(maxWidth: .infinity, alignment: .leading)
                Text("KURS")
                    .priceColHdr().frame(width: 90, alignment: .trailing)
                Text("Δ%")
                    .priceColHdr().frame(width: 58, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDim), alignment: .bottom)

            // Main pairs
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(mainPairs, id: \.self) { pair in
                        PriceRowView(pair: pair, data: state.prices[pair], dimmed: !marketsOpen)
                            .onTapGesture { state.selectedPair = pair }
                        Divider().background(Color.borderDim)
                    }

                    if !extraPairs.isEmpty {
                        Text("MARKT-EXTRAS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .tracking(1.5)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.bgHeader)

                        ForEach(extraPairs, id: \.self) { pair in
                            PriceRowView(pair: pair, data: state.prices[pair], dimmed: !marketsOpen)
                                .onTapGesture { state.selectedPair = pair }
                            Divider().background(Color.borderDim)
                        }
                    }
                }
            }
            .background(Color.bgMain)

            // Hinweis-Text
            Text(marketsOpen ? "Antippen für Details" : "Letzte bekannte Kurse")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.textMuted)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color.bgHeader)
        }
        .background(Color.bgPanel)
        .overlay(Rectangle().frame(width: 1).foregroundColor(.borderMain), alignment: .trailing)
        .onReceive(timer) { _ in localMarketStatus = MarketHours.status() }
        .sheet(item: Binding(
            get: { state.selectedPair.map { IdentifiableString($0) } },
            set: { state.selectedPair = $0?.value }
        )) { item in
            PairDetailView(pair: item.value)
                .environmentObject(state)
        }
    }
}

// Hilfs-Wrapper für String als Identifiable
private struct IdentifiableString: Identifiable {
    let id: String
    var value: String { id }
    init(_ v: String) { id = v }
}

struct PriceRowView: View {
    let pair: String
    let data: PriceData?
    var dimmed: Bool = false   // true am Wochenende

    var body: some View {
        HStack(spacing: 4) {
            // Arrow
            Text(arrowStr)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(dimmed ? .textMuted : priceColor)
                .frame(width: 10)

            Text(pair)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(dimmed ? .textDim : .textMain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            if let d = data {
                Text(d.formatted())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(dimmed ? .textDim : priceColor)
                    .frame(width: 86, alignment: .trailing)

                Text(dimmed ? "WE" : d.changeFormatted())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textMuted)
                    .frame(width: 54, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textMuted)
                    .frame(width: 86, alignment: .trailing)
                if dimmed {
                    Text("WE")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textMuted)
                        .frame(width: 54, alignment: .trailing)
                } else {
                    ProgressView().scaleEffect(0.45).frame(width: 54, height: 16)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.bgMain)
        .contentShape(Rectangle())
        .opacity(dimmed ? 0.6 : 1.0)
    }

    private var priceColor: Color {
        guard let d = data else { return .textMuted }
        if d.changePct > 0.001 { return .bzGreen }
        if d.changePct < -0.001 { return .bzRed }
        return .textDim
    }

    private var arrowStr: String {
        guard let d = data else { return "" }
        switch d.direction {
        case .up:   return "▲"
        case .down: return "▼"
        default:    return "─"
        }
    }
}

private extension Text {
    func priceColHdr() -> some View {
        self.font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.textMuted)
            .tracking(1)
    }
}
