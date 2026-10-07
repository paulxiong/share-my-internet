import Foundation

enum AppLanguage: String {
    case en
    case zh
}

/// All user-facing copy, in English and Simplified Chinese.
/// Button *values* returned to `AppState` stay the canonical English
/// strings (e.g. "Quit", "Next step") regardless of display language —
/// `button(_:_:)` only changes what's shown, not what's compared against.
enum L10n {

    // MARK: - Buttons

    static func button(_ canonical: String, _ lang: AppLanguage) -> String {
        guard lang == .zh else { return canonical }
        switch canonical {
        case "Cancel": return "取消"
        case "Start Sharing": return "开始共享"
        case "Quit": return "退出"
        case "Check again": return "重新检查"
        case "OK": return "好的"
        case "Open the page again": return "重新打开网页"
        case "Back": return "上一步"
        case "Next step": return "下一步"
        case "I copied the link": return "我已复制链接"
        case "Done": return "完成"
        case "Copy Message": return "复制消息"
        case "Stop Sharing": return "停止共享"
        case "Close": return "关闭"
        default: return canonical
        }
    }

    // MARK: - Misc UI

    static func checking(_ l: AppLanguage) -> String {
        l == .zh ? "检查中…" : "Checking…"
    }

    static func messageForIPhonePerson(_ l: AppLanguage) -> String {
        l == .zh ? "发给 iPhone 那边的人的消息：" : "Message for the iPhone person:"
    }

    static func tipPrefix(_ l: AppLanguage) -> String {
        l == .zh ? "提示：" : "Tip: "
    }

    static func tipMarker(_ l: AppLanguage) -> String {
        "\n\n" + tipPrefix(l)
    }

    static func stepHeader(_ l: AppLanguage, step: Int, total: Int) -> String {
        l == .zh ? "第 \(step) 步，共 \(total) 步" : "Step \(step) of \(total)"
    }

    static func successLine(_ l: AppLanguage) -> String {
        l == .zh ? "大功告成 —— 现在你已经在用我的网络了！"
                  : "That's it — you're all done, and now using my internet!"
    }

    // MARK: - Welcome flow

    static func welcomeBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "把你 Mac 的网络分享给某人的 iPhone —— 开启很简单，随时也能同样轻松地关掉。\n\n由 **Tailscale** 提供支持，这是一款广受认可、独立可信的应用（不是专门为这个做的）。\n\n第一次使用时可能会弹出一些登录或权限窗口 —— 这是正常的，照着提示操作就行。第一次使用时，macOS 也可能会要求输入密码或使用触控 ID 验证几次 —— 如果看到 **Allow（允许）** 和 **Always Allow（始终允许）**，选择 **Always Allow**，这样以后就不会再问了。"
        : "Share your Mac's internet with someone's iPhone — simple to turn on, and just as easy to turn off anytime.\n\nPowered by **Tailscale**, a well-known, independently trusted app (not something made just for this).\n\nA few sign-in or permission windows may pop up the first time — that's normal, just follow them. The first time only, macOS may also ask for your password or Touch ID a few times — if you see **Allow** vs **Always Allow**, pick **Always Allow** so it won't ask again."
    }

    static func notInstalledBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "你的 Mac 上还没有安装 Tailscale —— 没关系，我们现在就来解决。\n\nApp Store 已经打开：\n1. 安装 Tailscale（免费）。\n2. 打开它，选择任意一种登录方式（Google、Apple、Microsoft 或邮箱）。不需要提前注册账号 —— 第一次登录时会自动免费创建账号。\n\n完成后，点击“重新检查”。"
        : "Tailscale isn't installed on this Mac yet — no problem, let's fix that.\n\nThe App Store just opened:\n1. Install Tailscale (it's free).\n2. Open it and choose any sign-in option (Google, Apple, Microsoft, or email). You don't need an account first — signing in the first time creates one automatically, for free.\n\nOnce that's done, click \u{201c}Check again.\u{201d}"
    }

    static func needsLoginBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "Tailscale 还没有登录。\n\n1. 点击屏幕右上角菜单栏里的 **Tailscale 图标**。\n2. 选择 **Log In（登录）**。\n3. 会打开一个网页 —— 选择任意一种登录方式（Google、Apple、Microsoft 或邮箱）。还没有 Tailscale 账号？没关系 —— 第一次登录会自动免费创建账号，不需要额外注册。\n4. 如果 macOS 询问是否允许 VPN 连接，点击 **Allow（允许）**。\n\n登录完成后，点击“重新检查”。"
        : "Tailscale isn't signed in yet.\n\n1. Click the **Tailscale icon** in the menu bar (top-right of your screen).\n2. Choose **Log In**.\n3. A web page opens — choose any sign-in option (Google, Apple, Microsoft, or email). Don't have a Tailscale account yet? No problem — signing in for the first time creates one automatically, for free. No separate sign-up needed.\n4. If macOS asks to allow a VPN connection, click **Allow**.\n\nOnce you're signed in, click \u{201c}Check again.\u{201d}"
    }

    static func offBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "Tailscale 已经安装，但目前是关闭状态。\n\n1. 点击屏幕右上角菜单栏里的 **Tailscale 图标**。\n2. 把它打开。\n\n打开后，点击“重新检查”。"
        : "Tailscale is installed but switched off.\n\n1. Click the **Tailscale icon** in the menu bar (top-right of your screen).\n2. Turn it on.\n\nOnce it's on, click \u{201c}Check again.\u{201d}"
    }

    static func turnOnErrorBody(_ l: AppLanguage, detail: String) -> String {
        l == .zh
        ? "开启共享时出了点问题。\n\n可以试试退出 Tailscale，重新打开它，然后再运行一次 Share My Internet。如果还是不行，请把下面的内容发给帮你设置这个的人：\n\n技术细节：\(detail)"
        : "Something went wrong turning sharing on.\n\nTry quitting Tailscale, reopening it, and running Share My Internet again. If it keeps happening, show this to whoever set this up for you:\n\nTechnical details: \(detail)"
    }

    static func linkInvalidBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "这看起来还不是一个 Tailscale 分享链接。\n\n回到网页，再点一次“Copy share link”，然后再点一次“我已复制链接”。"
        : "That doesn't look like a Tailscale share link yet.\n\nGo back to the web page, click \u{201c}Copy share link\u{201d} once more, then click \u{201c}I copied the link\u{201d} again."
    }

    static func sharingOnBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "✅ 共享已开启\n\n下面这条消息是给 iPhone 那边的人看的。它已经包含了你刚刚复制的分享链接，是一条可以直接粘贴发送的完整消息 —— 现在就在你的剪贴板里。\n直接粘贴发给他们就行 —— 不管是在短信、微信、WhatsApp，还是你们平时聊天用的任何地方。\n\n完成后点击“停止共享”。"
        : "✅ Sharing is ON\n\nThe message below is for the iPhone person. It includes the share link you just copied, built into a complete, ready-to-paste message — that's what's on your clipboard now.\nJust paste it to them — in Messages, WeChat, WhatsApp, or wherever you talk to them.\n\nClick \u{201c}Stop Sharing\u{201d} when you're done."
    }

    static func sharingOffBody(_ l: AppLanguage) -> String {
        l == .zh
        ? "✅ 共享已关闭。\n\n你的 Mac 现在不再共享网络连接了。你可以随时关闭这个窗口。"
        : "✅ Sharing is now OFF.\n\nYour Mac is no longer sharing its internet connection. You can close this window anytime."
    }

    // MARK: - Step-by-step website walkthrough

    /// Builds the step texts/help strings, mirroring the branching in
    /// `AppState.flow()` (which steps appear depends on `needApproval`/`needLink`).
    static func steps(lang l: AppLanguage, name: String, needApproval: Bool, needLink: Bool) -> (texts: [String], help: [String]) {
        var texts: [String] = []
        var help: [String] = []

        if l == .zh {
            texts.append("如果右边的网页要求你登录，现在就用你的 Tailscale 账号登录。\n\n登录后，在设备列表里找到这台 Mac：**\(name)**。\n\n已经登录并看到设备列表了？直接点下面的“下一步”就行。")
            help.append("使用你第一次在这台 Mac 上设置 Tailscale 时用的那种登录方式（比如 **用 Google 登录** 或 **用 Apple 登录**）。\n\n如果这个网页又要求你登录，而你不确定自己有没有账号：你之前已经登录过一次才让 Tailscale 在这台 Mac 上运行起来，所以这里直接再选一次同样的方式就行 —— 是同一个账号，不是新账号。")

            if needApproval {
                texts.append("找到这台 Mac 所在的那一行 —— 名字是 **\(name)**。\n\n在那一行的最右边，点一下小小的 ••• 按钮（一排三个点）。")
                help.append("这个页面列出了登录这个 Tailscale 账号的所有设备。你的 Mac 那一行会显示 **\(name)**。••• 按钮在同一行的最右端 —— 如果看不到，可以试着把浏览器窗口拉宽一点。")

                texts.append("弹出了一个小菜单。\n\n点菜单里的 **Edit route settings**。")
                help.append("如果菜单不见了，可能是自己关掉了 —— 回到上一步，再点一次 ••• 按钮重新打开它。")

                texts.append("出现了一个关于路由（routes）的页面。\n\n找到 **Use as exit node** 旁边的开关，把它打开（应该会变成蓝色或绿色）。")
                help.append("这就是一个简单的开关 —— 点一下就行。\n\n已经是蓝色或绿色了？说明已经开着了 —— 不用改。点 **Cancel** 关闭这个面板（不保存），然后点下面的“下一步”。")

                texts.append("点击 **Save** 按钮保存刚才的更改。")
                help.append("**Save** 按钮通常在屏幕或面板的底部附近。\n\n如果开关本来就是开着的，上一步你点的是 **Cancel**，那就没有什么需要保存的 —— 直接点下面的“下一步”就行。")
            }

            if needLink {
                texts.append("回到主列表，再次找到这台 Mac 所在的那一行 —— **\(name)**。\n\n点那一行的 ••• 按钮，然后在菜单里选 **Share**。")
                help.append("和之前一样的 ••• 按钮，在这台 Mac 那一行的最右边。点一下会打开一个小菜单 —— **Share** 就是其中一个选项。")

                texts.append("弹出了一个标题为 **Share** 的窗口。\n\n勾选 **Allow use as an exit node** 这个复选框。")
                help.append("这是 **Share** 窗口里的一个小复选框 —— 点一下，出现勾号就行。")

                texts.append("如果页面问你这个链接可以被使用几次，选择“可以多次使用”的那个选项。\n\n没有看到这样的问题？没关系 —— 直接进入下一步。")
                help.append("这个问题不是每次都会出现。如果你的屏幕看起来和之前一样，没关系 —— 这里不需要点什么，直接进入下一步。")

                texts.append("点击 **Copy share link**。\n\n屏幕上不会有明显变化。Share My Internet 会读取这个链接，然后过一会儿会把剪贴板内容替换成一条包含这个链接、可以直接发送的完整消息 —— 这是正常现象，不是出错了。")
                help.append("在上一步出现的同一个 **Share** 窗口里找 —— **Copy share link** 通常在窗口的底部附近。")
            }
        } else {
            texts.append("If the page on the right is asking you to sign in, sign in now with your Tailscale account.\n\nOnce you're in, look for this Mac in the list of devices: **\(name)**.\n\nAlready signed in and see the device list? Just click \u{201c}Next step\u{201d} below.")
            help.append("Use the same sign-in option you used when you first set up Tailscale on this Mac (for example **Sign in with Google** or **Sign in with Apple**).\n\nIf this web page is asking you to sign in again and you're not sure you have an account: you already signed in once to get Tailscale running on this Mac, so just pick that same option again here — it's the same account, not a new one.")

            if needApproval {
                texts.append("Find the row for your Mac — it's named **\(name)**.\n\nOn the right side of that row, click the small ••• button (three dots in a row).")
                help.append("The page lists every device signed in to this Tailscale account. Your Mac's row shows **\(name)**. The ••• button sits at the far right end of that same row — if you don't see it, try making the browser window a bit wider.")

                texts.append("A small menu popped up.\n\nClick **Edit route settings** in that menu.")
                help.append("If the menu isn't there anymore, it probably closed on its own — go back one step and click the ••• button again to reopen it.")

                texts.append("A screen about routes appeared.\n\nFind the switch next to **Use as exit node** and turn it ON (it should turn blue or green).")
                help.append("It's a simple on/off switch — just click it once.\n\nAlready blue or green? It's already on — you don't need to change anything. Click **Cancel** to close this panel without saving, then click \u{201c}Next step\u{201d} below.")

                texts.append("Click the **Save** button to save that change.")
                help.append("The **Save** button is usually near the bottom of the screen or panel you're looking at.\n\nIf the switch was already on and you clicked **Cancel** instead in the last step, there's nothing to save — just click \u{201c}Next step\u{201d} below.")
            }

            if needLink {
                texts.append("Back on the main list, find your Mac's row again — **\(name)**.\n\nClick the ••• button on that row, then choose **Share** from the menu.")
                help.append("Same ••• button as before, at the right-hand end of your Mac's row. Clicking it opens a small menu — **Share** is one of the options in that menu.")

                texts.append("A window titled **Share** opened.\n\nTick the checkbox **Allow use as an exit node**.")
                help.append("It's a small checkbox inside that **Share** window — click once so a checkmark appears in it.")

                texts.append("If you're asked how the link can be used, choose the option for a link that can be used more than once.\n\nDon't see a question like that? No problem — just continue to the next step.")
                help.append("This only shows up sometimes. If your screen looks the same as before, it's fine — nothing to click here, just go to the next step.")

                texts.append("Click **Copy share link**.\n\nNothing will visibly change on screen. Share My Internet reads that link, then a moment from now replaces it on your clipboard with a complete, ready-to-send message that includes this link — that's expected, not a mistake.")
                help.append("Look inside the same **Share** window from the step before this one — **Copy share link** is usually near the bottom of it.")
            }
        }

        return (texts, help)
    }

    // MARK: - Welcome screen (custom view, not part of the ask/button flow)

    static func welcomeTitle(_ l: AppLanguage) -> String {
        l == .zh ? "与一台 iPhone\n共享你的网络" : "Share your internet\nwith an iPhone"
    }

    static func welcomeSubtitle(_ l: AppLanguage) -> String {
        l == .zh ? "简单、可逆、安全。" : "Simple, reversible, and safe."
    }

    static func welcomeFeature1Title(_ l: AppLanguage) -> String {
        l == .zh ? "一键开启共享" : "One click to share"
    }
    static func welcomeFeature1Detail(_ l: AppLanguage) -> String {
        l == .zh ? "想共享的时候打开它 —— 随时也能同样轻松地关掉。"
                  : "Turn it on when you want to share — and off again just as easily, anytime."
    }

    static func welcomeFeature2Title(_ l: AppLanguage) -> String {
        l == .zh ? "基于 Tailscale 构建" : "Built on Tailscale"
    }
    static func welcomeFeature2Detail(_ l: AppLanguage) -> String {
        l == .zh ? "一款广受认可、独立可信的应用 —— 并不是专门为这个而做的。真正的连接由它来处理。"
                  : "A well-known, independently trusted app — not something made just for this. It handles the actual connection."
    }

    static func welcomeFeature3Title(_ l: AppLanguage) -> String {
        l == .zh ? "出现几个弹窗是正常的" : "A few pop-ups are normal"
    }
    static func welcomeFeature3Detail(_ l: AppLanguage) -> String {
        l == .zh ? "第一次使用时可能会出现登录或权限提示窗口 —— 按照提示操作就行。"
                  : "Sign-in or permission windows may appear the first time — just follow what they say."
    }

    static func welcomeTip(_ l: AppLanguage) -> String {
        l == .zh
        ? "提示：第一次使用时，macOS 也可能会要求你输入密码或使用触控 ID 验证几次。如果看到 **Allow（允许）** 和 **Always Allow（始终允许）** 两个选项，选择 **Always Allow**，这样以后就不会再问了。"
        : "Tip: The first time only, macOS may also ask for your password or Touch ID a few times. If you see **Allow** vs **Always Allow**, pick **Always Allow** so it won't ask again."
    }

    // MARK: - Language picker (first screen)

    static let languagePickerTitle = "Share My Internet"
    static let languagePickerSubtitle = "Choose your language / 选择语言"
}
