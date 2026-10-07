import SwiftUI

struct WelcomeView: View {
    let onChoice: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Share your internet\nwith an iPhone")
                    .font(.title).bold()
                Text("Simple, reversible, and safe.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "wifi",
                    title: "One click to share",
                    detail: "Turn it on when you want to share — and off again just as easily, anytime."
                )
                FeatureRow(
                    icon: "checkmark.shield",
                    title: "Built on Tailscale",
                    detail: "A well-known, independently trusted app — not something made just for this. It handles the actual connection."
                )
                FeatureRow(
                    icon: "hand.wave",
                    title: "A few pop-ups are normal",
                    detail: "Sign-in or permission windows may appear the first time — just follow what they say."
                )
            }

            Text("Tip: The first time only, macOS may also ask for your password or Touch ID a few times. If you see **Allow** vs **Always Allow**, pick **Always Allow** so it won't ask again.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button("Cancel") { onChoice("Cancel") }
                Spacer()
                Button("Start Sharing") { onChoice("Start Sharing") }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
