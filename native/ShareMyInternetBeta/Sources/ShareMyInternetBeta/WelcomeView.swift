import SwiftUI

struct WelcomeView: View {
    let lang: AppLanguage
    let onChoice: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.welcomeTitle(lang))
                    .font(.title).bold()
                Text(L10n.welcomeSubtitle(lang))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "wifi",
                    title: L10n.welcomeFeature1Title(lang),
                    detail: L10n.welcomeFeature1Detail(lang)
                )
                FeatureRow(
                    icon: "checkmark.shield",
                    title: L10n.welcomeFeature2Title(lang),
                    detail: L10n.welcomeFeature2Detail(lang)
                )
                FeatureRow(
                    icon: "hand.wave",
                    title: L10n.welcomeFeature3Title(lang),
                    detail: L10n.welcomeFeature3Detail(lang)
                )
            }

            Text(LocalizedStringKey(L10n.welcomeTip(lang)))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack {
                Button(L10n.button("Cancel", lang)) { onChoice("Cancel") }
                Spacer()
                Button(L10n.button("Start Sharing", lang)) { onChoice("Start Sharing") }
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
