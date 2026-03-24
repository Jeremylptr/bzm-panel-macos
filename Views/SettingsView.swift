import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: UpdateService
    @ObservedObject private var auth = AuthService.shared
    @State private var config: Config = Config()
    @State private var saved = false
    @State private var pairsText = ""
    @State private var extrasText = ""
    @State private var showLogoutConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("EINSTELLUNGEN")
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .foregroundColor(.textHead)
                Spacer()
                Button("Schließen") {
                    state.showSettings = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.textDim)
            }
            .padding(16)
            .background(Color.bgHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Account / Abonnement
                    SettingsSection(title: "KONTO") {
                        // E-Mail
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.bzBlue)
                                .frame(width: 14)
                            Text(auth.userEmail.isEmpty ? "–" : auth.userEmail)
                                .font(terminalFontSmall).foregroundColor(.textDim)
                        }

                        // Plan-Badge
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.bzGreen)
                                .frame(width: 14)
                            if auth.planName.isEmpty {
                                Text("Abonnement: Aktiv")
                                    .font(terminalFontSmall).foregroundColor(.bzGreen)
                            } else {
                                HStack(spacing: 6) {
                                    Text("Abonnement:")
                                        .font(terminalFontSmall).foregroundColor(.textDim)
                                    Text(auth.planName)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(auth.planName.lowercased().contains("+") ? .bzPurple : .bzGreen)
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(
                                            auth.planName.lowercased().contains("+")
                                                ? Color.bzPurple.opacity(0.15)
                                                : Color.bzGreen.opacity(0.15)
                                        )
                                        .cornerRadius(3)
                                }
                            }
                        }

                        // Ablaufdatum
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 10))
                                .foregroundColor(.bzYellow)
                                .frame(width: 14)
                            if let expiry = auth.subscriptionExpiry {
                                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
                                let expiryStr = DateFormatter.localizedString(from: expiry, dateStyle: .medium, timeStyle: .none)
                                HStack(spacing: 6) {
                                    Text("Gültig bis: \(expiryStr)")
                                        .font(terminalFontSmall).foregroundColor(.textDim)
                                    Text("(\(daysLeft) Tage)")
                                        .font(terminalFontSmall)
                                        .foregroundColor(daysLeft < 7 ? .bzOrange : .textMuted)
                                }
                            } else {
                                Text("Ablaufdatum: –")
                                    .font(terminalFontSmall).foregroundColor(.textMuted)
                            }
                        }

                        Divider().background(Color.borderDim).padding(.vertical, 2)

                        // Letzter Check
                        HStack(spacing: 8) {
                            if auth.isCheckingInBackground {
                                ProgressView().scaleEffect(0.55).frame(width: 14, height: 14)
                                Text("Wird geprüft…")
                                    .font(terminalFontSmall).foregroundColor(.textMuted)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10))
                                    .foregroundColor(.textMuted)
                                    .frame(width: 14)
                                if let last = auth.lastCheckedAt {
                                    Text("Zuletzt geprüft: \(relativeTime(last))")
                                        .font(terminalFontSmall).foregroundColor(.textMuted)
                                } else {
                                    Text("Noch nicht geprüft")
                                        .font(terminalFontSmall).foregroundColor(.textMuted)
                                }
                            }
                        }

                        Button {
                            showLogoutConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 11))
                                Text("Abmelden")
                                    .font(terminalFontSmall)
                            }
                            .foregroundColor(.bzOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#1f0e00"))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.bzOrange.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .alert("Abmelden?", isPresented: $showLogoutConfirm) {
                            Button("Abmelden", role: .destructive) {
                                state.showSettings = false
                                auth.logout()
                            }
                            Button("Abbrechen", role: .cancel) { }
                        } message: {
                            Text("Du wirst aus der App ausgeloggt und musst dich beim nächsten Start erneut anmelden.")
                        }
                    }

                    // AI Status Info (read-only — Keys sind pre-coded in APIKeys.swift)
                    SettingsSection(title: "KI-STATUS") {
                        HStack(spacing: 8) {
                            Circle().fill(Color.bzGreen).frame(width: 8, height: 8)
                            Text("Claude API: Integriert")
                                .font(terminalFontSmall).foregroundColor(.textDim)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(Color.bzBlue).frame(width: 8, height: 8)
                            Text("OpenAI TTS: Integriert")
                                .font(terminalFontSmall).foregroundColor(.textDim)
                        }
                        if !state.aiModel.isEmpty {
                            HStack(spacing: 8) {
                                Circle().fill(Color.bzPurple).frame(width: 8, height: 8)
                                Text("Aktives Modell: \(state.aiModel)")
                                    .font(terminalFontSmall).foregroundColor(.bzPurple)
                            }
                        }
                    }

                    SettingsSection(title: "APP") {
                        HStack(spacing: 8) {
                            Text("Version")
                                .font(terminalFontSmall)
                                .foregroundColor(.textDim)
                                .frame(width: 160, alignment: .leading)
                            Text("v\(updater.currentVersion())")
                                .font(terminalFontSmall)
                                .foregroundColor(.bzBlue)
                        }
                    }

                    // Market
                    SettingsSection(title: "MARKT-PAARE") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Haupt-Paare (kommagetrennt)")
                                .font(terminalFontSmall)
                                .foregroundColor(.textMuted)
                            TextField("EUR/USD, GBP/USD, …", text: $pairsText)
                                .textFieldStyle(.roundedBorder)
                                .font(terminalFontSmall)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Extras (kommagetrennt)")
                                .font(terminalFontSmall)
                                .foregroundColor(.textMuted)
                            TextField("DXY, XAU/USD, …", text: $extrasText)
                                .textFieldStyle(.roundedBorder)
                                .font(terminalFontSmall)
                        }
                    }

                    // Timing
                    SettingsSection(title: "INTERVALLE") {
                        HStack {
                            Text("Preis-Refresh (s)")
                                .font(terminalFontSmall)
                                .foregroundColor(.textDim)
                                .frame(width: 160, alignment: .leading)
                            Stepper("\(config.priceRefreshSeconds)s",
                                    value: $config.priceRefreshSeconds, in: 5...120, step: 5)
                                .font(terminalFontSmall)
                        }
                        HStack {
                            Text("Mindest-Score Alarm")
                                .font(terminalFontSmall)
                                .foregroundColor(.textDim)
                                .frame(width: 160, alignment: .leading)
                            Stepper("\(Int(config.alertMinScore))",
                                    value: $config.alertMinScore, in: 1...10, step: 1)
                                .font(terminalFontSmall)
                        }
                    }

                    SettingsSection(title: "NEWS-SOUND") {
                        HStack {
                            Text("Normal (Impact 1-7)")
                                .font(terminalFontSmall)
                                .foregroundColor(.textDim)
                                .frame(width: 160, alignment: .leading)
                            Picker("", selection: $config.newsSoundNormal) {
                                ForEach(AudioPlayerService.availableNewsSounds, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                AudioPlayerService.playNamedSound(config.newsSoundNormal)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.bzBlue)
                        }

                        HStack {
                            Text("High Impact (8-10)")
                                .font(terminalFontSmall)
                                .foregroundColor(.textDim)
                                .frame(width: 160, alignment: .leading)
                            Picker("", selection: $config.newsSoundHighImpact) {
                                ForEach(AudioPlayerService.availableNewsSounds, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                AudioPlayerService.playNamedSound(config.newsSoundHighImpact)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.bzPurple)
                        }
                    }

                    // Config path info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GESPEICHERT UNTER")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .tracking(1.5)
                        Text(Config.defaultConfigPath())
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.textDim)
                    }
                    .padding(12)
                    .background(Color.bgItem)
                    .cornerRadius(6)
                }
                .padding(16)
            }

            // Save button
            HStack {
                if saved {
                    Text("✓ Gespeichert — App neu starten für alle Änderungen")
                        .font(terminalFontSmall)
                        .foregroundColor(.bzGreen)
                }
                Spacer()
                Button("Speichern") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .font(terminalFontSmall)
            }
            .padding(16)
            .background(Color.bgHeader)
        }
        .frame(width: 520, height: 640)
        .background(Color.bgMain)
        .preferredColorScheme(.dark)
        .onAppear {
            config = state.config
            pairsText  = state.config.marketPairs.joined(separator: ", ")
            extrasText = state.config.marketExtras.joined(separator: ", ")
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let sec = Int(Date().timeIntervalSince(date))
        if sec < 60  { return "gerade eben" }
        let m = sec / 60
        if m < 60    { return "vor \(m) Min" }
        let h = m / 60
        if h < 24    { return "vor \(h) Std" }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }

    private func saveConfig() {
        config.marketPairs  = pairsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        config.marketExtras = extrasText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        try? config.save()
        state.config = config
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { saved = false }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1.5)
            content()
        }
        .padding(12)
        .background(Color.bgItem)
        .cornerRadius(6)
    }
}

struct SettingsField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(terminalFontSmall)
                .foregroundColor(.textDim)
                .frame(width: 100, alignment: .leading)
            if secure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(terminalFontSmall)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(terminalFontSmall)
            }
        }
    }
}
