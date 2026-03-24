import SwiftUI

struct LoginView: View {
    @ObservedObject var auth = AuthService.shared

    @State private var email    = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Hintergrund
            LinearGradient(
                colors: [Color(hex: "#050d1a"), Color(hex: "#0a1628"), Color(hex: "#050d1a")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo ──────────────────────────────────────────────────────
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.bzBlue)
                            .frame(width: 4, height: 36)
                        Text("◈")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(.bzBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BZM PANEL")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.textHead)
                                .tracking(2)
                            Text("INTELLIGENCE")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.bzBlue)
                                .tracking(4)
                        }
                    }
                    Text("Professionelle Forex-Analyse")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.textMuted)
                        .tracking(1)
                }
                .padding(.bottom, 44)

                // ── Login-Card ────────────────────────────────────────────────
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Text("ANMELDEN")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.textHead)
                            .tracking(3)
                        Text("Verwende deine BZM-Website Zugangsdaten")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.textMuted)
                    }
                    .padding(.vertical, 24)

                    Divider().background(Color.borderMain)

                    VStack(spacing: 16) {
                        // E-Mail
                        VStack(alignment: .leading, spacing: 6) {
                            Text("E-MAIL")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .tracking(1.5)
                            TextField("deine@email.com", text: $email)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.textMain)
                                .autocorrectionDisabled()
                                .focused($focused, equals: .email)
                                .onSubmit { focused = .password }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.bgItem)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(focused == .email ? Color.bzBlue.opacity(0.7) : Color.borderMain, lineWidth: 1)
                                )
                        }

                        // Passwort
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORT")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .tracking(1.5)
                            HStack {
                                if showPassword {
                                    TextField("••••••••", text: $password)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.textMain)
                                        .focused($focused, equals: .password)
                                        .onSubmit { Task { await doLogin() } }
                                } else {
                                    SecureField("••••••••", text: $password)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.textMain)
                                        .focused($focused, equals: .password)
                                        .onSubmit { Task { await doLogin() } }
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 12))
                                        .foregroundColor(.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.bgItem)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focused == .password ? Color.bzBlue.opacity(0.7) : Color.borderMain, lineWidth: 1)
                            )
                        }

                        // Fehler-Meldung
                        if let err = auth.authError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.bzOrange)
                                Text(err)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.bzOrange)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(3)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#1f0e00"))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bzOrange.opacity(0.3), lineWidth: 1))
                        }

                        // Login-Button
                        Button {
                            Task { await doLogin() }
                        } label: {
                            HStack(spacing: 8) {
                                if auth.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                    Text("Anmelden…")
                                } else {
                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("ANMELDEN")
                                        .tracking(1.5)
                                }
                            }
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: canLogin && !auth.isLoading
                                        ? [Color.bzBlue, Color(hex: "#1a4fa8")]
                                        : [Color.bgItem, Color.bgItem],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(canLogin ? Color.bzBlue.opacity(0.5) : Color.borderMain, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canLogin || auth.isLoading)
                    }
                    .padding(24)
                }
                .background(Color.bgPanel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderMain, lineWidth: 1))
                .frame(width: 400)
                .shadow(color: .black.opacity(0.5), radius: 40, y: 20)

                Spacer()

                // Footer
                VStack(spacing: 4) {
                    Text("Kein Konto? Abonniere auf bzm-trading.com")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textMuted)
                    Text("Abonnement erforderlich zur Nutzung der App")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.textMuted.opacity(0.5))
                }
                .padding(.bottom, 30)
            }
        }
        .frame(width: 560, height: 540)
        .preferredColorScheme(.dark)
    }

    private var canLogin: Bool {
        !email.isEmpty && password.count >= 6
    }

    private func doLogin() async {
        guard canLogin else { return }
        let result = await auth.login(email: email, password: password)
        switch result {
        case .networkError:
            auth.authError = "Netzwerkfehler — bitte Internetverbindung prüfen"
        case .failure, .success:
            break // authError wird in AuthService gesetzt / geleert
        }
    }
}
