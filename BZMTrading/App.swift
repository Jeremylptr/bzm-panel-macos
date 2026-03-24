import SwiftUI

@main
struct BZMPanelApp: App {
    @StateObject private var state   = AppState()
    @StateObject private var auth    = AuthService.shared
    @StateObject private var updater = UpdateService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(auth)
                .environmentObject(updater)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .defaultSize(width: 1400, height: 900)
        .windowResizability(.contentMinSize)
    }
}

// ── RootView: Auth-Gate ───────────────────────────────────────────────────────

struct RootView: View {
    @EnvironmentObject var auth:    AuthService
    @EnvironmentObject var state:   AppState
    @EnvironmentObject var updater: UpdateService

    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                SplashView()
            } else if auth.isAuthenticated {
                MainView()
                    .onAppear { state.start() }
                    .onDisappear { state.stop() }
            } else {
                LoginView()
            }
        }
        .task {
            // Auth + Update-Check parallel beim Start
            async let authCheck   = auth.verifyOnStartup()
            async let updateCheck = updater.checkForUpdates()
            _ = await (authCheck, updateCheck)
            isCheckingAuth = false
            // Hintergrund-Abo-Check starten wenn bereits angemeldet
            if auth.isAuthenticated {
                auth.startBackgroundChecks()
            }
        }
        .onChange(of: auth.isAuthenticated) { authenticated in
            if authenticated && !isCheckingAuth {
                state.start()
                auth.startBackgroundChecks()
            } else if !authenticated {
                state.stop()
                auth.stopBackgroundChecks()
            }
        }
        // Update-Banner wenn neue Version verfügbar
        .sheet(item: Binding(
            get:  { updater.updateAvailable },
            set:  { if $0 == nil { updater.dismissUpdate() } }
        )) { info in
            UpdateAlertView(info: info)
                .environmentObject(updater)
        }
    }
}

// ── UpdateAlertView ───────────────────────────────────────────────────────────

struct UpdateAlertView: View {
    let info: AppVersionInfo
    @EnvironmentObject var updater: UpdateService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#050d1a").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.bzBlue)
                        .frame(width: 3, height: 24)
                    Text("UPDATE VERFÜGBAR")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.textHead)
                        .tracking(1.5)
                    Spacer()
                    Text("v\(info.version)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.bzBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.bzBlue.opacity(0.15))
                        .cornerRadius(4)
                }
                .padding(20)
                .background(Color(hex: "#0a1628"))

                // Version info
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("AKTUELL")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .frame(width: 60, alignment: .leading)
                        Text("v\(updater.currentVersion())")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.textDim)
                    }
                    HStack(spacing: 6) {
                        Text("NEU")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .frame(width: 60, alignment: .leading)
                        Text("v\(info.version)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.bzBlue)
                    }

                    if !info.releaseNotes.isEmpty {
                    Divider().background(Color.borderMain)
                    Text("ÄNDERUNGEN")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.textMuted)
                        Text(info.releaseNotes)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.textMain)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)

                Divider().background(Color.borderMain)

                // Buttons
                HStack(spacing: 10) {
                    Button("Später") {
                        updater.dismissUpdate()
                        dismiss()
                    }
                    .buttonStyle(BZMSecondaryButtonStyle())

                    Spacer()

                    Button("Jetzt aktualisieren") {
                        updater.performUserInitiatedUpdate()
                        updater.dismissUpdate()
                        dismiss()
                    }
                    .buttonStyle(BZMPrimaryButtonStyle())
                    .disabled(info.downloadUrl.isEmpty)
                }
                .padding(20)
            }
        }
        .frame(width: 420)
        .preferredColorScheme(.dark)
    }
}

// ── Button-Styles ─────────────────────────────────────────────────────────────

struct BZMPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.bzBlue.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(5)
    }
}

struct BZMSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.textDim)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.bgPanel.opacity(configuration.isPressed ? 0.5 : 1.0))
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.borderMain, lineWidth: 1))
    }
}

// ── SplashView ────────────────────────────────────────────────────────────────

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "#050d1a").ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.bzBlue)
                        .frame(width: 4, height: 32)
                    Text("◈")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.bzBlue)
                    Text("BZM PANEL")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.textHead)
                        .tracking(2)
                }

                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.bzBlue)

                Text("Verbindung wird überprüft…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textMuted)
            }
        }
        .frame(width: 400, height: 300)
        .preferredColorScheme(.dark)
    }
}
