import SwiftUI

struct NewsPanelView: View {
    @EnvironmentObject var state: AppState
    @State private var filterText = ""

    var filteredNews: [NewsItem] {
        let base: [NewsItem]
        if filterText.isEmpty {
            base = state.news
        } else {
            let q = filterText.lowercased()
            base = state.news.filter {
                $0.title.lowercased().contains(q) ||
                $0.source.lowercased().contains(q) ||
                ($0.analysis?.headline ?? "").lowercased().contains(q)
            }
        }
        // Neueste zuerst (Veröffentlichungsdatum + Uhrzeit)
        return base.sorted { $0.published > $1.published }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LIVE NEWS  ·  \(state.news.count)")
                    .panelHeader()
                Spacer()
                Circle()
                    .fill(state.newsFetchHealthy ? Color.bzGreen : Color.bzRed)
                    .frame(width: 8, height: 8)
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textMuted)
                    .font(.system(size: 11))
                TextField("Filter…", text: $filterText)
                    .font(terminalFontSmall)
                    .foregroundColor(.textMain)
                    .textFieldStyle(.plain)
                if !filterText.isEmpty {
                    Button { filterText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.textMuted)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.bgItem)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDim), alignment: .bottom)

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredNews) { item in
                        NewsRowView(item: item, isSelected: state.selectedNews?.id == item.id)
                            .onTapGesture {
                                state.selectedNews = item
                            }
                    }
                }
            }
            .background(Color.bgMain)
        }
        .background(Color.bgPanel)
        .overlay(Rectangle().frame(width: 1).foregroundColor(.borderMain), alignment: .trailing)
    }

}

struct NewsRowView: View {
    let item: NewsItem
    let isSelected: Bool

    var displayScore: Double { max(1, item.analysis?.score ?? item.score) }
    var displayHeadline: String { item.analysis?.headline.isEmpty == false ? item.analysis!.headline : item.title }
    var urgency: String { item.analysis?.urgency ?? "" }

    var urgencyIcon: String {
        switch urgency {
        case "immediate": return "⚡"
        case "hours":     return "⏱"
        case "days":      return "📅"
        default:          return ""
        }
    }

    var directionStr: String {
        guard let pairs = item.analysis?.pairs, !pairs.isEmpty else { return "" }
        let bulls = pairs.values.filter { $0 == "bullish" }.count
        let bears = pairs.values.filter { $0 == "bearish" }.count
        if bulls > bears { return "▲" }
        if bears > bulls { return "▼" }
        return "↕"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                // Score badge
                if displayScore > 0 {
                    Text("\(Int(displayScore))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.scoreColor(displayScore))
                        .frame(width: 20, height: 20)
                        .background(Color.scoreColor(displayScore).opacity(0.15))
                        .cornerRadius(3)
                } else {
                    Color.bgItem.frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Source + time
                    HStack {
                        Text(item.source.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .tracking(1)
                        Spacer()
                        TimelineView(.periodic(from: .now, by: 10)) { context in
                            Text(relativePublishedTime(item.published, now: context.date))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.textMuted)
                        }
                        if !urgencyIcon.isEmpty {
                            Text(urgencyIcon)
                                .font(.system(size: 9))
                        }
                        if !directionStr.isEmpty {
                            Text(directionStr)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(directionStr == "▲" ? .bzGreen : directionStr == "▼" ? .bzRed : .bzYellow)
                        }
                    }

                    // Headline / title
                    Text(displayHeadline)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(isSelected ? .textHead : .textMain)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // Short analysis
                    if let ana = item.analysis?.analysis, !ana.isEmpty {
                        Text(ana)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textDim)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)

            Divider()
                .background(Color.borderDim)
        }
        .background(isSelected ? Color.bgSelected : item.score >= 8 ? Color(hex: "#160a0a") : Color.clear)
        .contentShape(Rectangle())
    }

    private func relativePublishedTime(_ date: Date, now: Date) -> String {
        let sec = max(0, Int(now.timeIntervalSince(date)))
        if sec < 30  { return "gerade eben" }
        if sec < 60  { return "vor \(sec)s" }
        let m = sec / 60
        if m < 60    { return "vor \(m) min" }
        let h = m / 60
        if h < 24    { return "vor \(h) h" }
        let d = h / 24
        return "vor \(d) d"
    }
}
