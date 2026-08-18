import SwiftUI

/// A lightweight local "sign-in" — really a profile creation screen.
/// No backend needed: this is a personal habit tracker, so we just need
/// a name to personalize the experience and gate first launch.
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var name: String = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Theme.skyWash.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Signature element: a simple growing-plant mark, not a stock icon soup
                ZStack {
                    Circle()
                        .fill(Theme.moss.opacity(0.10))
                        .frame(width: 132, height: 132)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 46))
                        .foregroundColor(Theme.moss)
                        .rotationEffect(.degrees(-8))
                }
                .padding(.bottom, 28)

                Text("EcoGarden")
                    .font(Theme.display(34))
                    .foregroundColor(Theme.bark)

                Text("Small habits. A garden that grows with you.")
                    .font(Theme.body(15))
                    .foregroundColor(Theme.stone)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 40)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHAT SHOULD WE CALL YOU?")
                        .font(Theme.caption())
                        .foregroundColor(Theme.stone)
                        .tracking(0.5)

                    TextField("Your name", text: $name)
                        .focused($fieldFocused)
                        .font(Theme.body(17))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                .strokeBorder(fieldFocused ? Theme.moss : Theme.sage.opacity(0.3), lineWidth: fieldFocused ? 1.5 : 1)
                        )
                        .submitLabel(.done)
                        .onSubmit { begin() }
                }
                .padding(.horizontal, 28)

                Button(action: begin) {
                    Text("Start Growing")
                        .font(Theme.display(16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                .fill(canStart ? Theme.moss : Theme.moss.opacity(0.35))
                        )
                        .foregroundColor(.white)
                }
                .disabled(!canStart)
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
    }

    private var canStart: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func begin() {
        guard canStart else { return }
        appState.userName = name.trimmingCharacters(in: .whitespaces)
        appState.hasOnboarded = true
    }
}

#Preview {
    WelcomeView().environmentObject(AppState())
}
