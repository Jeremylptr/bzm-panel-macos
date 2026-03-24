import SwiftUI

struct CalendarPanelView: View {
    @EnvironmentObject var state: AppState

    var grouped: [(Date, String, [CalendarEvent])] {
        let sorted = state.calendar.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        let df = DateFormatter()
        df.dateFormat = "EEEE dd.MM."
        let cal = Calendar.current

        var dict: [Date: [CalendarEvent]] = [:]
        for ev in sorted {
            let dayAnchor = cal.startOfDay(for: ev.date ?? Date.distantFuture)
            dict[dayAnchor, default: []].append(ev)
        }
        return dict
            .map { ($0.key, df.string(from: $0.key), $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            if state.calendar.isEmpty {
                VStack(spacing: 12) {
                    Spacer(minLength: 30)
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(.textMuted)
                    Text("Lade Kalender…")
                        .font(terminalFontSmall)
                        .foregroundColor(.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(grouped, id: \.0) { _, day, events in
                        Section {
                            ForEach(events) { ev in
                                CalendarEventRow(event: ev)
                                    .contentShape(Rectangle())
                                    .onTapGesture { state.selectedCalendarEvent = ev }
                                Divider().background(Color.borderDim)
                            }
                        } header: {
                            Text(day.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .tracking(1.5)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.bgHeader)
                        }
                    }
                }
            }
        }
        .background(Color.bgMain)
        .sheet(item: $state.selectedCalendarEvent) { ev in
            CalendarEventDetailView(event: ev)
        }
    }
}

struct CalendarEventRow: View {
    let event: CalendarEvent

    var impactColor: Color {
        switch event.impact {
        case .high:   return .bzRed
        case .medium: return .bzYellow
        case .low:    return .bzBlue
        default:      return .textMuted
        }
    }

    var impactLabel: String {
        switch event.impact {
        case .high:   return "●●●"
        case .medium: return "●●○"
        case .low:    return "●○○"
        default:      return "○○○"
        }
    }

    var countdown: String {
        if event.isAllDay { return "" }
        guard let mins = event.minutesUntil else { return "" }
        if mins < 0  { return "Vorbei" }
        if mins < 60 { return "in \(Int(mins))m" }
        let h = Int(mins / 60); let m = Int(mins.truncatingRemainder(dividingBy: 60))
        return "in \(h)h \(String(format: "%02d", m))m"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Impact dots
            Text(impactLabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(impactColor)
                .frame(width: 28)

            // Currency
            Text(event.currency)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.textDim)
                .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.event)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textMain)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !event.forecast.isEmpty {
                        Text("P: \(event.forecast)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textMuted)
                    }
                    if !event.actual.isEmpty {
                        Text("A: \(event.actual)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzYellow)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.timeDisplay)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textDim)
                if !countdown.isEmpty {
                    Text(countdown)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(event.minutesUntil.map { $0 <= 30 ? Color.bzYellow : .textMuted } ?? .textMuted)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(event.impact == .high ? Color(hex: "#160a0a") : Color.bgMain)
    }
}
