import SwiftUI

// ── Daten-Struct für Event-Erklärung ──────────────────────────────
struct EventExplanation {
    let title: String
    let paragraphs: [String]
}

// Kalender-Event Detail-Dialog — 1:1 Python EconomyEventDetailDialog
struct CalendarEventDetailView: View {
    @Environment(\.dismiss) var dismiss
    let event: CalendarEvent

    private var explanation: EventExplanation {
        Self.explainEvent(event.event)
    }

    var impactColor: Color {
        switch event.impact {
        case .high:    return .bzRed
        case .medium:  return .bzYellow
        case .low:     return .bzBlue
        default:       return .textMuted
        }
    }

    var impactLabel: String {
        switch event.impact {
        case .high:    return "HOCH  ●●●"
        case .medium:  return "MITTEL  ●●○"
        case .low:     return "NIEDRIG  ●○○"
        default:       return "—  ○○○"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("◈  WIRTSCHAFTSKALENDER — DETAIL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.bzPurple)
                        .tracking(1)
                    Text(event.event)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(.textHead)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Schließen") { dismiss() }
                    .buttonStyle(.plain)
                    .font(terminalFontSmall)
                    .foregroundColor(.textDim)
            }
            .padding(18)
            .background(Color.bgHeader)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.borderMain), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Datentabelle ─────────────────────────────
                    VStack(spacing: 0) {
                        DataRow(key: "Datum / Zeit (lokal)", value: localDatetime(event.time))
                        DataRow(key: "Zeit (UTC)",           value: utcDatetime(event.time))
                        DataRow(key: "Rohzeit (Quelle)",     value: event.timeDisplay)
                        DataRow(key: "Währung / Region",     value: "\(event.currency)  (\(event.country))")

                        // Impact mit Farbe
                        HStack {
                            Text("Impact")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .frame(width: 180, alignment: .leading)
                            Text(impactLabel)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(impactColor)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.bgItem)
                        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDim), alignment: .bottom)

                        if !event.forecast.isEmpty {
                            DataRow(key: "Prognose (Forecast)",   value: event.forecast)
                        }
                        if !event.previous.isEmpty {
                            DataRow(key: "Vorperiode (Previous)", value: event.previous)
                        }
                        if !event.actual.isEmpty {
                            DataRow(key: "Ist-Wert (Actual)",     value: event.actual, highlight: true)
                        }
                        DataRow(key: "Ereignis-ID", value: event.id)
                    }
                    .background(Color.bgItem)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.borderDim, lineWidth: 1))

                    Divider().background(Color.borderDim)

                    // ── Was ist das? ─────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WAS IST DAS?")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzCyan)
                            .tracking(2)

                        Text(explanation.title)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.bzYellow)

                        ForEach(explanation.paragraphs, id: \.self) { para in
                            Text(para)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.textMain)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.bgItem)
                                .cornerRadius(6)
                        }
                    }

                    // ── Countdown ────────────────────────────────
                    if !event.isAllDay, let mins = event.minutesUntil {
                        HStack(spacing: 8) {
                            Image(systemName: mins > 0 ? "clock" : "checkmark.circle")
                                .foregroundColor(mins > 0 && mins <= 30 ? .bzYellow : .textMuted)
                            if mins <= 0 {
                                Text("Ereignis ist bereits vorbei")
                                    .font(terminalFontSmall).foregroundColor(.textMuted)
                            } else if mins < 60 {
                                Text("Findet statt in \(Int(mins)) Minuten")
                                    .font(terminalFontSmall).foregroundColor(.bzYellow)
                            } else {
                                let h = Int(mins / 60)
                                let m = Int(mins.truncatingRemainder(dividingBy: 60))
                                Text("Findet statt in \(h)h \(String(format: "%02d", m))m")
                                    .font(terminalFontSmall).foregroundColor(.textDim)
                            }
                        }
                        .padding(10)
                        .background(Color.bgItem)
                        .cornerRadius(6)
                    }

                    // Hinweis
                    Text("Hinweis: Keine Anlageberatung — immer eigenes Risiko und Kontext (Trend, Korrelationen, andere Termine am selben Tag) beachten.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
            .background(Color.bgMain)
        }
        .frame(width: 560, height: 580)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
    }

    // ── Datums-Helfer ──────────────────────────────────────────────
    private func localDatetime(_ raw: String) -> String {
        guard let d = parseDate(raw) else { return raw }
        let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy  HH:mm"
        let tz = TimeZone.current.abbreviation() ?? "lokal"
        return df.string(from: d) + " (\(tz))"
    }

    private func utcDatetime(_ raw: String) -> String {
        guard let d = parseDate(raw) else { return "—" }
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy  HH:mm"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.string(from: d) + " UTC"
    }

    private func parseDate(_ raw: String) -> Date? {
        let fmts = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        for fmt in fmts {
            let df = DateFormatter(); df.dateFormat = fmt
            if let d = df.date(from: raw) { return d }
        }
        return nil
    }

    // ── Event-Erklärung (1:1 Python _calendar_event_explanation) ──
    static func explainEvent(_ name: String) -> EventExplanation {
        let n = name.lowercased()
        let entries: [([String], String, [String])] = [
            (["fomc","federal funds rate","fed interest rate","fed rate decision","fomc statement","fomc press conference","powell"],
             "FOMC / US-Notenbank (Fed)", [
                "Die Federal Open Market Committee (FOMC) entscheidet über den Leitzins (Federal Funds Rate) und gibt eine Einschätzung zur Geldpolitik ab.",
                "Für Forex und Aktien ist das einer der wichtigsten Termine: Höhere Zinsen stützen oft den US-Dollar, während Dovish-Töne oder Zinssenkungen ihn schwächen können.",
                "Prognose vs. Ist: Der Markt hat die Erwartung oft schon eingepreist — überrascht die Fed (Dot Plot, Statement, Pressekonferenz), folgen starke Bewegungen.",
            ]),
            (["cpi","consumer price index","core cpi","inflation rate","pce","core pce"],
             "Inflation / Verbraucherpreise (CPI & Co.)", [
                "Der CPI (Consumer Price Index) misst die Preisentwicklung eines Warenkorbs — Kern-CPI (ohne Energie & Nahrungsmittel) gilt oft als 'sauberer' Trendindikator.",
                "Hohe Inflation kann die Notenbank zu strafferer Geldpolitik drängen → oft stützend für die Währung kurzfristig, mittelfristig abhängig von Rezessionsängsten.",
                "PCE ist die von der Fed bevorzugte Inflationskennzahl (USA).",
            ]),
            (["nfp","non-farm","nonfarm payroll","employment change","adp employment","jobless claims","unemployment rate","jolts"],
             "Arbeitsmarkt USA (NFP & Co.)", [
                "Der Non-Farm Payrolls (NFP)-Bericht zeigt, wie viele Jobs außerhalb der Landwirtschaft entstanden oder weggefallen sind — Kerndaten für die Fed.",
                "Starker Arbeitsmarkt kann zu höheren Zinsen und einem stärkeren USD führen; schwache Daten können das Gegenteil erwarten lassen.",
                "ADP ist ein Vorläufer, Initial Jobless Claims wöchentlich — alle beeinflussen Erwartungen vor dem NFP-Freitag.",
            ]),
            (["gdp","gross domestic product"],
             "Bruttoinlandsprodukt (BIP / GDP)", [
                "Das BIP misst den Wert aller Güter und Dienstleistungen — Hauptindikator für Wachstum oder Konjunkturabschwung.",
                "Überraschungen gegenüber Prognose können die betroffene Währung und Risiko-Assets deutlich bewegen; Revisionen späterer Daten sind üblich.",
            ]),
            (["ecb","european central bank","lagarde","deposit facility","refinancing rate"],
             "EZB (Europäische Zentralbank)", [
                "Die ECB steuert die Geldpolitik der Eurozone (Leitzins, Ankaufprogramme, Forward Guidance).",
                "Pressekonferenz und Statement bewegen EUR-Paare oft stärker als die reine Zinsentscheidung.",
            ]),
            (["boe","bank of england","bailey"],
             "Bank of England (BoE)", [
                "Die BoE entscheidet über den britischen Leitzins und ihre Inflations- und Wachstumseinschätzung.",
                "Wichtig für GBP und EUR/GBP; politische Nachrichten können zusätzlich wirken.",
            ]),
            (["boj","bank of japan","jgb","yield curve control"],
             "Bank of Japan (BoJ)", [
                "Die BoJ ist bekannt für ultralockere Politik und hat historisch YCC genutzt — Änderungen gelten als selten aber marktbewegend für JPY.",
            ]),
            (["snb","swiss national bank"],
             "Schweizerische Nationalbank (SNB)", [
                "Die SNB beeinflusst CHF durch Zinsentscheidungen und früher auch durch Devisenmarkt-Interventionen.",
            ]),
            (["rba","reserve bank of australia"],
             "Reserve Bank of Australia (RBA)", [
                "Die RBA setzt die australische Geldpolitik — wichtig für AUD und Rohstoffkorrelationen.",
            ]),
            (["boc","bank of canada"],
             "Bank of Canada (BoC)", [
                "Die BoC steuert die kanadische Geldpolitik — CAD reagiert oft auf Ölpreise und US-Konjunktur.",
            ]),
            (["pmi","purchasing managers","ism manufacturing","services pmi"],
             "PMI / Einkaufsmanagerindizes", [
                "PMI-Werte über 50 deuten auf Expansion, unter 50 auf Kontraktion — Frühindikatoren vor offiziellen BIP-Daten.",
                "US-ISM und S&P Global PMI für viele Länder werden eng beobachtet.",
            ]),
            (["retail sales"],
             "Einzelhandelsumsätze", [
                "Zeigen die Konsumstärke — wichtig für Wachstum und Währung, wenn Daten stark von der Prognose abweichen.",
            ]),
            (["industrial production","factory orders","durable goods"],
             "Industrie & Aufträge", [
                "Indikatoren für industrielle Produktion und Investitionsgüter — Rückschlüsse auf Konjunkturzyklus und Exporte.",
            ]),
            (["trade balance","current account","exports","imports"],
             "Handel & Leistungsbilanz", [
                "Exporte, Importe und Handelsbilanz beeinflussen die Nachfrage nach einer Währung.",
            ]),
            (["building permits","housing starts","existing home sales"],
             "Immobilien / Bau", [
                "Daten zum Wohnungsbau und Immobilienmarkt — Sensibel für Zinsen; in den USA eng mit Fed-Zyklen verknüpft.",
            ]),
            (["consumer confidence","sentiment","gfk","ifo","zew"],
             "Konjunktur- & Verbrauchervertrauen", [
                "Umfragen spiegeln Erwartungen wider — können sich auf Konsum und Investitionen vorauswirken.",
            ]),
            (["crude oil","eia","api weekly","natural gas storage"],
             "Energielager & EIA/API", [
                "US-Lagerdaten für Rohöl bewegen oft WTI, CAD und manchmal breitere Risikostimmung.",
            ]),
            (["speech","testimony","remarks","governor speaks","chair speaks"],
             "Rede / Testimony einer Notenbank", [
                "Einzelne Aussagen von Notenbankern können so wirksam sein wie Zinsentscheidungen — Markt sucht nach Hinweisen auf den nächsten Schritt ('hawkish' vs. 'dovish').",
            ]),
        ]

        for (keys, title, paras) in entries {
            if keys.contains(where: { n.contains($0) }) {
                return EventExplanation(title: title, paragraphs: paras)
            }
        }

        let generic = "Dies ist ein terminierter Wirtschaftsdatensatz oder ein offizielles Ereignis (Behörde, Zentralbank oder Statistikamt). Die Veröffentlichung erfolgt zu einer festen Zeit; Broker und Datenanbieter zeigen oft Prognose (Forecast), Vorperiode (Previous) und nach Release den Ist-Wert (Actual)."
        return EventExplanation(title: "Allgemein: Wirtschaftstermin", paragraphs: [generic])
    }
}

// ── Sub-Views ──────────────────────────────────────────────────────
private struct DataRow: View {
    let key: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textMuted)
                .frame(width: 180, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12, weight: highlight ? .bold : .regular, design: .monospaced))
                .foregroundColor(highlight ? .bzYellow : .textMain)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.bgItem)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.borderDim), alignment: .bottom)
    }
}
