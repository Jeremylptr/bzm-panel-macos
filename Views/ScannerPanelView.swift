import SwiftUI

struct ScannerPanelView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header info
                ScannerHeaderView()

                // Currency strength
                if !state.scanner.currencyStrength.isEmpty {
                    CurrencyStrengthView(strength: state.scanner.currencyStrength)
                }

                Divider().background(Color.borderDim)

                // Opportunities
                let visible = state.scanner.opportunities.filter { $0.score > 0.4 }
                if visible.isEmpty {
                    HStack {
                        Text("Keine klaren Setups — warte auf mehr Preis- oder News-Impuls.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textMuted)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                } else {
                    ForEach(visible, id: \.id) { opp in
                        OpportunityRowView(opp: opp)
                        Divider().background(Color.borderDim)
                    }
                }
            }
        }
        .background(Color.bgMain)
    }
}

struct ScannerHeaderView: View {
    @EnvironmentObject var state: AppState

    var sentimentColor: Color {
        switch state.scanner.riskSentiment {
        case "risk-on":  return .bzGreen
        case "risk-off": return .bzRed
        default:         return .bzYellow
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("INTELLIGENCE SCANNER")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.textMuted)
                    .tracking(1.5)
                Text(state.scanner.riskSentiment.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(sentimentColor)
            }
            Spacer()
            if !state.scanner.sessions.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(state.scanner.sessions, id: \.self) { s in
                        Text(s.uppercased())
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.bzBlue)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.bgHeader)
    }
}

struct CurrencyStrengthView: View {
    let strength: [String: Double]

    var sorted: [(String, Double)] {
        strength.sorted { $0.value > $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WÄHRUNGSSTÄRKE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1.5)

            HStack(spacing: 6) {
                ForEach(sorted, id: \.0) { cur, val in
                    VStack(spacing: 2) {
                        Text(cur)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.textDim)
                        Text(String(format: "%+.1f", val))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(val > 0 ? .bzGreen : val < 0 ? .bzRed : .textDim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.bgItem)
    }
}

struct OpportunityRowView: View {
    let opp: ScannerResult.Opportunity

    var dirColor: Color {
        switch opp.direction {
        case .long:    return .bzGreen
        case .short:   return .bzRed
        case .neutral: return .textDim
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color.borderDim, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(opp.score / 10))
                    .stroke(Color.scoreColor(opp.score), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(opp.score))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.scoreColor(opp.score))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(opp.pair)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.textHead)
                    Text(opp.direction.icon)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(dirColor)
                    if opp.warning {
                        Text("⚠")
                            .font(.system(size: 10))
                            .foregroundColor(.bzYellow)
                    }
                    Spacer()
                    Text("\(opp.newsCount)N")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textMuted)
                }

                ForEach(opp.reasons, id: \.self) { r in
                    Text("• \(r)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textDim)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(opp.score >= 6 ? Color.bgItem.opacity(0.5) : Color.clear)
    }
}
