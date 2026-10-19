import SwiftUI

// Sign up / log in (local account, see AccountStore).
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    private enum Mode { case signUp, logIn }
    private enum Field { case name, username, password }

    // One account per device: if it already exists, the only thing to do is log in.
    @State private var mode: Mode = AccountStore.load() == nil ? .signUp : .logIn
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var showResetConfirm = false
    @FocusState private var focus: Field?

    var body: some View {
        ZStack {
            ScreenBackground()

            // Scrollable so the fields stay reachable when the keyboard is up.
            ScrollView {
                VStack(spacing: 0) {
                    hero
                        .padding(.top, 48)
                        .padding(.bottom, 32)

                    form
                        .padding(20)
                        .ecoCard()
                        .padding(.horizontal, 20)

                    footer
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            // Keeps the name of anyone who used the app before logins.
            if name.isEmpty { name = appState.userName }
        }
    }

    private var hero: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Theme.moss.opacity(0.10))
                    .frame(width: 104, height: 104)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Theme.moss)
                    .rotationEffect(.degrees(-8))
            }
            .padding(.bottom, 18)

            Text("Rooted")
                .font(Theme.heading(32))
                .foregroundColor(Theme.bark)

            Text("Small acts. A community that grows with you.")
                .font(Theme.body(14))
                .foregroundColor(Theme.stone)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 40)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == .signUp ? "Create your account" : "Welcome back")
                .font(Theme.display(20, weight: .semibold))
                .foregroundColor(Theme.bark)

            if mode == .signUp {
                EcoField(label: "Name", prompt: "What should we call you?", text: $name)
                    .focused($focus, equals: .name)
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .onSubmit { focus = .username }
            }

            EcoField(label: "Username", prompt: "Username", text: $username)
                .focused($focus, equals: .username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focus = .password }

            EcoField(label: "Password", prompt: mode == .signUp ? "At least 6 characters" : "Password", text: $password, isSecure: true)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(Theme.body(13))
                    .foregroundColor(Theme.ember)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(mode == .signUp ? "Start Growing" : "Log In", action: submit)
                .buttonStyle(EcoPrimaryButtonStyle())
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if mode == .signUp {
            Text("Your account stays on this device.")
                .font(Theme.body(12.5))
                .foregroundColor(Theme.stone)
        } else {
            Button("Forgot password?") { showResetConfirm = true }
                .font(Theme.caption(13))
                .foregroundColor(Theme.moss)
                // Attached to the button so iOS 26 anchors the dialog here, not mid-screen.
                .confirmationDialog(
                    "Reset this device's account?",
                    isPresented: $showResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Erase Account and Garden", role: .destructive) {
                        appState.resetEverything()
                        password = ""
                        username = ""
                        name = ""
                        errorMessage = nil
                        mode = .signUp
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Passwords can't be recovered because the account only exists on this device. Resetting erases the garden, coins and progress so you can start again.")
                }
        }
    }

    private func submit() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanUsername = username.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .signUp:
            guard !cleanName.isEmpty else { return fail("Add your name so we know what to call you.") }
            guard cleanUsername.count >= 3, !cleanUsername.contains(" ") else {
                return fail("Usernames need at least 3 characters and no spaces.")
            }
            guard password.count >= 6 else { return fail("Passwords need at least 6 characters.") }
            guard AccountStore.create(username: cleanUsername, password: password) else {
                return fail("Couldn't save the account on this device. Try again.")
            }
            appState.userName = cleanName
            appState.hasOnboarded = true
            appState.isLoggedIn = true

        case .logIn:
            guard AccountStore.verify(username: cleanUsername, password: password) else {
                password = ""
                return fail("That username and password don't match.")
            }
            appState.isLoggedIn = true
        }
    }

    private func fail(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) { errorMessage = message }
    }
}

#Preview {
    WelcomeView().environmentObject(AppState())
}
