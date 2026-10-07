property helperPath : missing value
property watchdogStarted : false

on cancelSharing()
	try
		do shell script "bash " & quoted form of helperPath & " watchdog-stop"
	end try
end cancelSharing

on run
	set helperPath to (POSIX path of (path to me)) & "Contents/Resources/core.sh"
	
	try
		display dialog "Share your Mac's internet with someone's iPhone — simple to turn on, and just as easy to turn off anytime." & return & return & "Powered by Tailscale, a well-known, independently trusted app (not something made just for this)." & return & return & "A few sign-in or permission windows may pop up the first time — that's normal, just follow them. The first time only, macOS may also ask for your password or Touch ID a few times — if you see “Allow” vs “Always Allow,” pick “Always Allow” so it won't ask again." with title "Share My Internet" buttons {"Cancel", "Start Sharing"} default button 2 with icon note
		if button returned of result is "Cancel" then return
	on error number -128
		return
	end try
	
	-- 1. Is Tailscale installed? Keep checking in place instead of making
	-- the person quit and relaunch this app once they're done.
	set installedResult to do shell script "bash " & quoted form of helperPath & " is-installed"
	if installedResult is "no" then
		do shell script "open macappstore://apps.apple.com/app/id1475387142"
	end if
	repeat while installedResult is "no"
		try
			set theButton to button returned of (display dialog "Tailscale isn't installed on this Mac yet — no problem, let's fix that." & return & return & "The App Store just opened:" & return & "1. Install Tailscale (it's free)." & return & "2. Open it and choose any sign-in option (Google, Apple, Microsoft, or email). You don't need an account first — signing in the first time creates one automatically, for free." & return & return & "Once that's done, click “Check again.”" with title "Share My Internet" buttons {"Quit", "Check again"} default button 2 with icon note)
		on error number -128
			return
		end try
		if theButton is "Quit" then return
		set installedResult to do shell script "bash " & quoted form of helperPath & " is-installed"
	end repeat

	-- 2. Make sure Tailscale is running, signed in, and connected —
	-- same check-again loop instead of a dead end.
	set runResult to do shell script "bash " & quoted form of helperPath & " ensure-running"
	repeat while runResult is "NEEDS_LOGIN" or runResult is "OFF"
		if runResult is "NEEDS_LOGIN" then
			set waitMsg to "Tailscale isn't signed in yet." & return & return & "1. Click the Tailscale icon in the menu bar (top-right of your screen)." & return & "2. Choose “Log In.”" & return & "3. A web page opens — choose any sign-in option (Google, Apple, Microsoft, or email). Don't have a Tailscale account yet? No problem — signing in for the first time creates one automatically, for free. No separate sign-up needed." & return & "4. If macOS asks to allow a VPN connection, click Allow." & return & return & "Once you're signed in, click “Check again.”"
		else
			set waitMsg to "Tailscale is installed but switched off." & return & return & "1. Click the Tailscale icon in the menu bar (top-right of your screen)." & return & "2. Turn it on." & return & return & "Once it's on, click “Check again.”"
		end if
		try
			set theButton to button returned of (display dialog waitMsg with title "Share My Internet" buttons {"Quit", "Check again"} default button 2 with icon note)
		on error number -128
			return
		end try
		if theButton is "Quit" then return
		set runResult to do shell script "bash " & quoted form of helperPath & " ensure-running"
	end repeat
	
	set theName to do shell script "bash " & quoted form of helperPath & " get-name"
	
	-- 3. Turn sharing on
	display notification "Turning sharing on…" with title "Share My Internet"
	set turnOnResult to do shell script "bash " & quoted form of helperPath & " turn-on-sharing"
	if turnOnResult starts with "ERROR:" then
		set techDetail to text 7 thru -1 of turnOnResult
		display dialog "Something went wrong turning sharing on." & return & return & "Try quitting Tailscale, reopening it, and running Share My Internet again. If it keeps happening, show this to whoever set this up for you:" & return & return & "Technical details: " & techDetail with title "Share My Internet" buttons {"OK"} default button 1 with icon stop
		return
	end if
	
	-- 4. Website steps (only what is still needed)
	set theLink to do shell script "bash " & quoted form of helperPath & " saved-link"
	set needApproval to ((do shell script "bash " & quoted form of helperPath & " needs-approval") is "yes")
	
	if needApproval or theLink is "" then
		set needLink to (theLink is "")

		-- Build one short, plain-language instruction per physical click,
		-- plus a "more detail" line to show if the person taps "I'm stuck".
		set stepTexts to {}
		set stepHelp to {}

		set end of stepTexts to "If the page is asking you to sign in, sign in now with your Tailscale account." & return & return & "Already signed in and see a list of devices? Just click “Next step” below."
		set end of stepHelp to "Use the same sign-in option you used when you first set up Tailscale on this Mac (for example “Sign in with Google” or “Sign in with Apple”)." & return & return & "If this web page is asking you to sign in again and you're not sure you have an account: you already signed in once to get Tailscale running on this Mac, so just pick that same option again here — it's the same account, not a new one."

		if needApproval then
			set end of stepTexts to "Find the row for your Mac — it's named “" & theName & "”." & return & return & "On the right side of that row, click the small ••• button (three dots in a row)."
			set end of stepHelp to "The page lists every device signed in to this Tailscale account. Your Mac's row shows “" & theName & "”. The ••• button sits at the far right end of that same row — if you don't see it, try making the browser window a bit wider."

			set end of stepTexts to "A small menu popped up." & return & return & "Click “Edit route settings” in that menu."
			set end of stepHelp to "If the menu isn't there anymore, it probably closed on its own — go back one step and click the ••• button again to reopen it."

			set end of stepTexts to "A screen about routes appeared." & return & return & "Find the switch next to “Use as exit node” and turn it ON (it should turn blue or green)."
			set end of stepHelp to "It's a simple on/off switch — just click it once. If it already looks blue or green, it's already on, so you can continue."

			set end of stepTexts to "Click the “Save” button to save that change."
			set end of stepHelp to "The Save button is usually near the bottom of the screen or panel you're looking at."
		end if

		if needLink then
			set end of stepTexts to "Back on the main list, find your Mac's row again — “" & theName & "”." & return & return & "Click the ••• button on that row, then choose “Share” from the menu."
			set end of stepHelp to "Same ••• button as before, at the right-hand end of your Mac's row. Clicking it opens a small menu — “Share” is one of the options in that menu."

			set end of stepTexts to "A window titled “Share” opened." & return & return & "Tick the checkbox “Allow use as an exit node.”"
			set end of stepHelp to "It's a small checkbox inside that Share window — click once so a checkmark appears in it."

			set end of stepTexts to "If you're asked how the link can be used, choose the option for a link that can be used more than once." & return & return & "Don't see a question like that? No problem — just continue to the next step."
			set end of stepHelp to "This only shows up sometimes. If your screen looks the same as before, it's fine — nothing to click here, just go to the next step."

			set end of stepTexts to "Click “Copy share link.”" & return & return & "Nothing will visibly change on screen. Share My Internet reads that link, then a moment from now replaces it on your clipboard with a complete, ready-to-send message that includes this link — that's expected, not a mistake."
			set end of stepHelp to "Look inside the same “Share” window from the step before this one — “Copy share link” is usually near the bottom of it."
		end if

		set totalSteps to (count of stepTexts)
		set i to 1

		try
			set preButton to button returned of (display dialog "Next, a web page on Tailscale's website will open." & return & return & "If you're not already signed in, you'll land on a sign-in page first — that's expected." & return & return & "Once you're in, look for this Mac in the list of devices: " & theName with title "Share My Internet" buttons {"Quit", "Open the page"} default button 2 with icon note)
		on error number -128
			my cancelSharing()
			return
		end try
		if preButton is "Quit" then
			my cancelSharing()
			return
		end if
		do shell script "open https://login.tailscale.com/admin/machines"

		repeat
			set isLastStep to (i is totalSteps)
			set bodyText to "Step " & i & " of " & totalSteps & return & return & (item i of stepTexts) & return & return & "Tip: " & (item i of stepHelp)

			if i is 1 then
				set leftBtn to "Open the page again"
			else
				set leftBtn to "Back"
			end if

			if isLastStep and needLink then
				set rightBtn to "I copied the link"
			else if isLastStep then
				set rightBtn to "Done"
			else
				set rightBtn to "Next step"
			end if

			try
				set theButton to button returned of (display dialog bodyText with title "Share My Internet" buttons {leftBtn, "Quit", rightBtn} default button 3 with icon note)
			on error number -128
				my cancelSharing()
				return
			end try

			if theButton is "Quit" then
				my cancelSharing()
				return
			else if theButton is leftBtn and i is 1 then
				do shell script "open https://login.tailscale.com/admin/machines"
			else if theButton is "Back" then
				set i to i - 1
			else if isLastStep and needLink then
				set clipText to ""
				try
					set clipText to (the clipboard as text)
				end try
				set validated to do shell script "bash " & quoted form of helperPath & " validate-link " & quoted form of clipText
				if validated is "" then
					display dialog "That doesn't look like a Tailscale share link yet." & return & return & "Go back to the web page, click “Copy share link” once more, then click “I copied the link” again." with title "Share My Internet" buttons {"OK"} default button 1 with icon note
				else
					set theLink to validated
					do shell script "bash " & quoted form of helperPath & " save-link " & quoted form of theLink
					exit repeat
				end if
			else if isLastStep then
				exit repeat
			else
				set i to i + 1
			end if
		end repeat
	end if
	
	-- 5. Build the message for the iPhone person and copy it
	set theMessage to do shell script "bash " & quoted form of helperPath & " build-message " & quoted form of theLink & " " & quoted form of theName
	set the clipboard to theMessage
	
	-- 6. Sharing is ON: keep the Mac awake and reconnect quietly in the background
	do shell script "bash " & quoted form of helperPath & " watchdog-start"
	set watchdogStarted to true
	display notification "Sharing is ON. The message for the iPhone is copied." with title "Share My Internet"
	
	repeat
		try
			set theButton to button returned of (display dialog "✅ Sharing is ON" & return & return & "The message for the iPhone person includes the share link you just copied, built into a complete, ready-to-paste message — that's what's on your clipboard now." & return & "Just paste it to them — in Messages, WeChat, WhatsApp, or wherever you talk to them." & return & return & "Click \"Stop Sharing\" when you're done." with title "Share My Internet" buttons {"Copy Message Again", "Stop Sharing"} default button 1 with icon note)
		on error number -128
			exit repeat
		end try
		if theButton is "Copy Message Again" then
			set the clipboard to theMessage
			display notification "Message copied again." with title "Share My Internet"
		else
			exit repeat
		end if
	end repeat
	
	do shell script "bash " & quoted form of helperPath & " watchdog-stop"
	set watchdogStarted to false
	display notification "Sharing is now OFF." with title "Share My Internet"
end run

on quit
	if watchdogStarted then
		try
			do shell script "bash " & quoted form of helperPath & " watchdog-stop"
		end try
	end if
	continue quit
end quit

