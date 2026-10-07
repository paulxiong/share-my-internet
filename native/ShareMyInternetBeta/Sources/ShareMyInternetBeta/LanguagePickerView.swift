import SwiftUI

/// First screen shown on launch — picks the language for everything else.
/// Both options are labeled in their own language on purpose, so the user
/// can read them regardless of their system language.
struct LanguagePickerView: View {
    let onChoice: (AppLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.languagePickerTitle)
                    .font(.title).bold()
                Text(L10n.languagePickerSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onChoice(.en)
                } label: {
                    Text("English")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button {
                    onChoice(.zh)
                } label: {
                    Text("中文")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
    }
}
