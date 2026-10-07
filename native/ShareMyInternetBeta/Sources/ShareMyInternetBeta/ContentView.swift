import SwiftUI

struct ContentView: View {
    @ObservedObject var app: AppState

    /// Step dialogs append a localized "\n\nTip: <...>" marker to bodyText;
    /// split that off so it can render smaller/secondary — it's a hint, not
    /// the instruction.
    private var tipMarker: String { L10n.tipMarker(app.language) }

    private var mainText: String {
        if let range = app.bodyText.range(of: tipMarker) {
            return String(app.bodyText[app.bodyText.startIndex..<range.lowerBound])
        }
        return app.bodyText
    }

    private var tipText: String? {
        if let range = app.bodyText.range(of: tipMarker) {
            return String(app.bodyText[range.upperBound...])
        }
        return nil
    }

    /// Renders Markdown **bold** as usual, but additionally calls out any
    /// "•••" (the Tailscale row menu button) in bold + accent color — on
    /// its own, bold barely registers for three tiny dots.
    private func styledText(_ raw: String) -> Text {
        let pieces = raw.components(separatedBy: "•••")
        var result = Text("")
        for (index, piece) in pieces.enumerated() {
            result = result + Text(LocalizedStringKey(piece))
            if index < pieces.count - 1 {
                result = result + Text("•••").bold().foregroundColor(.accentColor)
            }
        }
        return result
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                if app.isLanguagePicker {
                    LanguagePickerView { app.chooseLanguage($0) }
                } else if app.isWelcome {
                    WelcomeView(lang: app.language) { app.resolve($0) }
                } else {
                    regularContent
                }
            }
            .padding(20)
            .frame(minWidth: 360, idealWidth: 420, maxWidth: 480)

            Group {
                if app.showWebPane, let url = app.webURL {
                    WebPane(url: url, reloadTrigger: app.reloadTrigger)
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 920, minHeight: 650)
    }

    @ViewBuilder
    private var regularContent: some View {
        Text("Share My Internet")
            .font(.title2).bold()

        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                styledText(mainText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                if let tip = tipText {
                    (Text(L10n.tipPrefix(app.language)) + styledText(tip))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                if !app.messagePreview.isEmpty {
                    messagePreviewBox
                }
            }
        }

        Spacer()

        if app.isBusy {
            HStack {
                ProgressView().scaleEffect(0.7)
                Text(L10n.checking(app.language)).foregroundColor(.secondary).font(.caption)
            }
        }

        HStack {
            ForEach(app.buttons) { item in
                Button(item.label) { app.resolve(item.id) }
                    .keyboardShortcut(item.id == app.buttons.last?.id ? .defaultAction : .none)
            }
        }
        .disabled(app.isBusy)
    }

    private var messagePreviewBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.messageForIPhonePerson(app.language))
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(app.messagePreview.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    if line == L10n.successLine(app.language) {
                        Text(line)
                            .font(.callout).bold()
                            .foregroundColor(.green)
                    } else {
                        Text(line.isEmpty ? " " : line)
                            .font(.callout)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .textSelection(.enabled)
        }
    }
}
