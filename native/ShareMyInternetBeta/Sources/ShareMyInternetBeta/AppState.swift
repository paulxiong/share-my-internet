import Foundation
import AppKit

struct ButtonItem: Identifiable, Hashable {
    /// Canonical English id — this is what flows back through `resolve(_:)`
    /// and what the flow logic compares against, regardless of display language.
    let id: String
    let label: String
}

@MainActor
final class AppState: ObservableObject {
    @Published var bodyText: String = ""
    @Published var buttons: [ButtonItem] = []
    @Published var isBusy: Bool = false
    @Published var showWebPane: Bool = false
    @Published var webURL: URL? = nil
    @Published var reloadTrigger: Int = 0
    @Published var messagePreview: String = ""
    @Published var isLanguagePicker: Bool = true
    @Published var isWelcome: Bool = true
    @Published var language: AppLanguage = .en

    nonisolated let helperPath: String = {
        Bundle.main.resourceURL!.appendingPathComponent("core.sh").path
    }()

    private var continuation: CheckedContinuation<String, Never>?
    private var languageContinuation: CheckedContinuation<Void, Never>?
    private var sharingTurnedOn = false
    private var cleanedUp = false

    func resolve(_ choice: String) {
        continuation?.resume(returning: choice)
        continuation = nil
    }

    func chooseLanguage(_ lang: AppLanguage) {
        language = lang
        isLanguagePicker = false
        languageContinuation?.resume()
        languageContinuation = nil
    }

    func run() {
        Task { await flow() }
    }

    // MARK: - Low-level helpers

    private func ask(_ text: String, _ opts: [String]) async -> String {
        bodyText = text
        buttons = opts.map { ButtonItem(id: $0, label: L10n.button($0, language)) }
        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }

    private func core(_ args: String...) async -> String {
        isBusy = true
        defer { isBusy = false }
        let path = helperPath
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/bash")
                p.arguments = [path] + args
                let outPipe = Pipe()
                p.standardOutput = outPipe
                p.standardError = Pipe()
                do {
                    try p.run()
                } catch {
                    cont.resume(returning: "")
                    return
                }
                p.waitUntilExit()
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                cont.resume(returning: out)
            }
        }
    }

    /// Synchronous, callable from app-termination paths that can't await.
    /// Turns exit-node sharing back off if it was ever turned on and this
    /// run never got to its own clean "Stop Sharing" / quit-with-cleanup path.
    func cleanupBeforeQuitSync() {
        guard sharingTurnedOn, !cleanedUp else { return }
        cleanedUp = true
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [helperPath, "watchdog-stop"]
        try? p.run()
        p.waitUntilExit()
    }

    private func quitApp() {
        cleanupBeforeQuitSync()
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    // MARK: - Main flow (mirrors main.applescript's `on run`)

    private func flow() async {
        await withCheckedContinuation { cont in
            languageContinuation = cont
        }

        let c = await ask(L10n.welcomeBody(language), ["Cancel", "Start Sharing"])
        isWelcome = false
        if c == "Cancel" { quitApp(); return }

        // 1. Is Tailscale installed? Keep checking in place instead of
        // making the person quit and relaunch this app once they're done.
        var installedResult = await core("is-installed")
        if installedResult == "no" {
            NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/id1475387142")!)
        }
        while installedResult == "no" {
            let btn = await ask(L10n.notInstalledBody(language), ["Quit", "Check again"])
            if btn == "Quit" { quitApp(); return }
            installedResult = await core("is-installed")
        }

        // 2. Make sure Tailscale is running, signed in, and connected —
        // same check-again loop instead of a dead end.
        var runResult = await core("ensure-running")
        while runResult == "NEEDS_LOGIN" || runResult == "OFF" {
            let waitMsg = runResult == "NEEDS_LOGIN" ? L10n.needsLoginBody(language) : L10n.offBody(language)
            let btn = await ask(waitMsg, ["Quit", "Check again"])
            if btn == "Quit" { quitApp(); return }
            runResult = await core("ensure-running")
        }

        let theName = await core("get-name")

        // 3. Turn sharing on
        let turnOnResult = await core("turn-on-sharing")
        if turnOnResult.hasPrefix("ERROR:") {
            let detail = String(turnOnResult.dropFirst("ERROR:".count))
            _ = await ask(L10n.turnOnErrorBody(language, detail: detail), ["OK"])
            quitApp(); return
        }
        sharingTurnedOn = true

        // 4. Website steps (only what is still needed)
        var theLink = await core("saved-link")
        let needApproval = await core("needs-approval") == "yes"

        if needApproval || theLink.isEmpty {
            let needLink = theLink.isEmpty

            let (stepTexts, stepHelp) = L10n.steps(lang: language, name: theName, needApproval: needApproval, needLink: needLink)

            let totalSteps = stepTexts.count
            var i = 0 // 0-based index into stepTexts / stepHelp

            webURL = URL(string: "https://login.tailscale.com/admin/machines")
            showWebPane = true

            stepLoop: while true {
                let isLast = (i == totalSteps - 1)
                let body = "\(L10n.stepHeader(language, step: i + 1, total: totalSteps))\n\n\(stepTexts[i])\n\n\(L10n.tipPrefix(language))\(stepHelp[i])"
                let leftBtn = (i == 0) ? "Open the page again" : "Back"
                let rightBtn = isLast ? (needLink ? "I copied the link" : "Done") : "Next step"

                let choice = await ask(body, [leftBtn, "Quit", rightBtn])

                if choice == "Quit" {
                    quitApp(); return
                } else if choice == leftBtn && i == 0 {
                    reloadTrigger += 1
                } else if choice == "Back" {
                    i -= 1
                } else if isLast && needLink {
                    let clip = NSPasteboard.general.string(forType: .string) ?? ""
                    let validated = await core("validate-link", clip)
                    if validated.isEmpty {
                        _ = await ask(L10n.linkInvalidBody(language), ["OK"])
                    } else {
                        theLink = validated
                        _ = await core("save-link", theLink)
                        break stepLoop
                    }
                } else if isLast {
                    break stepLoop
                } else {
                    i += 1
                }
            }

            showWebPane = false
        }

        // 5. Build the message for the iPhone person and copy it
        let theMessage = await core("build-message", theLink, theName, language.rawValue)
        messagePreview = theMessage
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(theMessage, forType: .string)

        // 6. Sharing is ON: keep the Mac awake and reconnect quietly
        _ = await core("watchdog-start")

        while true {
            let choice = await ask(L10n.sharingOnBody(language), ["Copy Message", "Stop Sharing"])
            if choice == "Copy Message" {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(theMessage, forType: .string)
            } else {
                break
            }
        }

        // Turn sharing off now (not silently on app-quit) so we can
        // actually confirm it on screen before the window closes.
        messagePreview = ""
        _ = await core("watchdog-stop")
        cleanedUp = true

        _ = await ask(L10n.sharingOffBody(language), ["Close"])

        quitApp()
    }
}
