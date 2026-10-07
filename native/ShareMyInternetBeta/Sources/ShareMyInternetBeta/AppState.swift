import Foundation
import AppKit

@MainActor
final class AppState: ObservableObject {
    @Published var bodyText: String = ""
    @Published var buttons: [String] = []
    @Published var isBusy: Bool = false
    @Published var showWebPane: Bool = false
    @Published var webURL: URL? = nil
    @Published var reloadTrigger: Int = 0
    @Published var messagePreview: String = ""
    @Published var isWelcome: Bool = true

    nonisolated let helperPath: String = {
        Bundle.main.resourceURL!.appendingPathComponent("core.sh").path
    }()

    private var continuation: CheckedContinuation<String, Never>?
    private var sharingTurnedOn = false
    private var cleanedUp = false

    func resolve(_ choice: String) {
        continuation?.resume(returning: choice)
        continuation = nil
    }

    func run() {
        Task { await flow() }
    }

    // MARK: - Low-level helpers

    private func ask(_ text: String, _ opts: [String]) async -> String {
        bodyText = text
        buttons = opts
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
        let c = await ask(
            "Share your Mac's internet with someone's iPhone — simple to turn on, and just as easy to turn off anytime.\n\nPowered by **Tailscale**, a well-known, independently trusted app (not something made just for this).\n\nA few sign-in or permission windows may pop up the first time — that's normal, just follow them. The first time only, macOS may also ask for your password or Touch ID a few times — if you see **Allow** vs **Always Allow**, pick **Always Allow** so it won't ask again.",
            ["Cancel", "Start Sharing"]
        )
        isWelcome = false
        if c == "Cancel" { quitApp(); return }

        // 1. Is Tailscale installed? Keep checking in place instead of
        // making the person quit and relaunch this app once they're done.
        var installedResult = await core("is-installed")
        if installedResult == "no" {
            NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/id1475387142")!)
        }
        while installedResult == "no" {
            let btn = await ask(
                "Tailscale isn't installed on this Mac yet — no problem, let's fix that.\n\nThe App Store just opened:\n1. Install Tailscale (it's free).\n2. Open it and choose any sign-in option (Google, Apple, Microsoft, or email). You don't need an account first — signing in the first time creates one automatically, for free.\n\nOnce that's done, click “Check again.”",
                ["Quit", "Check again"]
            )
            if btn == "Quit" { quitApp(); return }
            installedResult = await core("is-installed")
        }

        // 2. Make sure Tailscale is running, signed in, and connected —
        // same check-again loop instead of a dead end.
        var runResult = await core("ensure-running")
        while runResult == "NEEDS_LOGIN" || runResult == "OFF" {
            let waitMsg: String
            if runResult == "NEEDS_LOGIN" {
                waitMsg = "Tailscale isn't signed in yet.\n\n1. Click the **Tailscale icon** in the menu bar (top-right of your screen).\n2. Choose **Log In**.\n3. A web page opens — choose any sign-in option (Google, Apple, Microsoft, or email). Don't have a Tailscale account yet? No problem — signing in for the first time creates one automatically, for free. No separate sign-up needed.\n4. If macOS asks to allow a VPN connection, click **Allow**.\n\nOnce you're signed in, click “Check again.”"
            } else {
                waitMsg = "Tailscale is installed but switched off.\n\n1. Click the **Tailscale icon** in the menu bar (top-right of your screen).\n2. Turn it on.\n\nOnce it's on, click “Check again.”"
            }
            let btn = await ask(waitMsg, ["Quit", "Check again"])
            if btn == "Quit" { quitApp(); return }
            runResult = await core("ensure-running")
        }

        let theName = await core("get-name")

        // 3. Turn sharing on
        let turnOnResult = await core("turn-on-sharing")
        if turnOnResult.hasPrefix("ERROR:") {
            let detail = String(turnOnResult.dropFirst("ERROR:".count))
            _ = await ask(
                "Something went wrong turning sharing on.\n\nTry quitting Tailscale, reopening it, and running Share My Internet again. If it keeps happening, show this to whoever set this up for you:\n\nTechnical details: \(detail)",
                ["OK"]
            )
            quitApp(); return
        }
        sharingTurnedOn = true

        // 4. Website steps (only what is still needed)
        var theLink = await core("saved-link")
        let needApproval = await core("needs-approval") == "yes"

        if needApproval || theLink.isEmpty {
            let needLink = theLink.isEmpty

            var stepTexts: [String] = []
            var stepHelp: [String] = []

            stepTexts.append("If the page on the right is asking you to sign in, sign in now with your Tailscale account.\n\nOnce you're in, look for this Mac in the list of devices: **\(theName)**.\n\nAlready signed in and see the device list? Just click “Next step” below.")
            stepHelp.append("Use the same sign-in option you used when you first set up Tailscale on this Mac (for example **Sign in with Google** or **Sign in with Apple**).\n\nIf this web page is asking you to sign in again and you're not sure you have an account: you already signed in once to get Tailscale running on this Mac, so just pick that same option again here — it's the same account, not a new one.")

            if needApproval {
                stepTexts.append("Find the row for your Mac — it's named **\(theName)**.\n\nOn the right side of that row, click the small ••• button (three dots in a row).")
                stepHelp.append("The page lists every device signed in to this Tailscale account. Your Mac's row shows **\(theName)**. The ••• button sits at the far right end of that same row — if you don't see it, try making the browser window a bit wider.")

                stepTexts.append("A small menu popped up.\n\nClick **Edit route settings** in that menu.")
                stepHelp.append("If the menu isn't there anymore, it probably closed on its own — go back one step and click the ••• button again to reopen it.")

                stepTexts.append("A screen about routes appeared.\n\nFind the switch next to **Use as exit node** and turn it ON (it should turn blue or green).")
                stepHelp.append("It's a simple on/off switch — just click it once.\n\nAlready blue or green? It's already on — you don't need to change anything. Click **Cancel** to close this panel without saving, then click **Next step** below.")

                stepTexts.append("Click the **Save** button to save that change.")
                stepHelp.append("The **Save** button is usually near the bottom of the screen or panel you're looking at.\n\nIf the switch was already on and you clicked **Cancel** instead in the last step, there's nothing to save — just click **Next step** below.")
            }

            if needLink {
                stepTexts.append("Back on the main list, find your Mac's row again — **\(theName)**.\n\nClick the ••• button on that row, then choose **Share** from the menu.")
                stepHelp.append("Same ••• button as before, at the right-hand end of your Mac's row. Clicking it opens a small menu — **Share** is one of the options in that menu.")

                stepTexts.append("A window titled **Share** opened.\n\nTick the checkbox **Allow use as an exit node**.")
                stepHelp.append("It's a small checkbox inside that **Share** window — click once so a checkmark appears in it.")

                stepTexts.append("If you're asked how the link can be used, choose the option for a link that can be used more than once.\n\nDon't see a question like that? No problem — just continue to the next step.")
                stepHelp.append("This only shows up sometimes. If your screen looks the same as before, it's fine — nothing to click here, just go to the next step.")

                stepTexts.append("Click **Copy share link**.\n\nNothing will visibly change on screen. Share My Internet reads that link, then a moment from now replaces it on your clipboard with a complete, ready-to-send message that includes this link — that's expected, not a mistake.")
                stepHelp.append("Look inside the same **Share** window from the step before this one — **Copy share link** is usually near the bottom of it.")
            }

            let totalSteps = stepTexts.count
            var i = 0 // 0-based index into stepTexts / stepHelp

            webURL = URL(string: "https://login.tailscale.com/admin/machines")
            showWebPane = true

            stepLoop: while true {
                let isLast = (i == totalSteps - 1)
                let body = "Step \(i + 1) of \(totalSteps)\n\n\(stepTexts[i])\n\nTip: \(stepHelp[i])"
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
                        _ = await ask(
                            "That doesn't look like a Tailscale share link yet.\n\nGo back to the web page, click “Copy share link” once more, then click “I copied the link” again.",
                            ["OK"]
                        )
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
        let theMessage = await core("build-message", theLink, theName)
        messagePreview = theMessage
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(theMessage, forType: .string)

        // 6. Sharing is ON: keep the Mac awake and reconnect quietly
        _ = await core("watchdog-start")

        while true {
            let choice = await ask(
                "✅ Sharing is ON\n\nThe message below is for the iPhone person. It includes the share link you just copied, built into a complete, ready-to-paste message — that's what's on your clipboard now.\nJust paste it to them — in Messages, WeChat, WhatsApp, or wherever you talk to them.\n\nClick “Stop Sharing” when you're done.",
                ["Copy Message", "Stop Sharing"]
            )
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

        _ = await ask(
            "✅ Sharing is now OFF.\n\nYour Mac is no longer sharing its internet connection. You can close this window anytime.",
            ["Close"]
        )

        quitApp()
    }
}
