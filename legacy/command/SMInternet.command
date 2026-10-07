#!/bin/bash
# ------------------------------------------------------------
#  Share My Internet
#  1. Double-click this file on the Mac.
#  2. It copies a message for you. Paste it to the iPhone person.
#  3. Close this window to stop sharing.
#  Every run explains every step. Nothing to remember.
# ------------------------------------------------------------

APP="/Applications/Tailscale.app"
TS="$APP/Contents/MacOS/Tailscale"
TITLE="Share My Internet"
ADMIN_URL="https://login.tailscale.com/admin/machines"
LINK_FILE="$HOME/.share-my-internet-link"   # remembers the last invite link
LINK_MAX_AGE_DAYS=25                         # invite links expire after 30 days
TOTAL_STEPS=4

# ---------- helpers: dialogs ----------
popup() {
  osascript -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"$TITLE\"" >/dev/null 2>&1
}
ask() {   # ask "message" "Left button" "Right (default) button" -> clicked button
  osascript -e "button returned of (display dialog \"$1\" buttons {\"$2\", \"$3\"} default button 2 with title \"$TITLE\")" 2>/dev/null
}
ask3() {  # ask3 "message" "Left" "Middle" "Right (default)" -> clicked button
  osascript -e "button returned of (display dialog \"$1\" buttons {\"$2\", \"$3\", \"$4\"} default button 3 with title \"$TITLE\")" 2>/dev/null
}
notify() {
  osascript -e "display notification \"$1\" with title \"$TITLE\"" >/dev/null 2>&1
}
cancel_sharing() {   # turns exit-node sharing back off if the user bails out mid-setup
  "$TS" set --advertise-exit-node=false >/dev/null 2>&1
}

# ---------- helpers: Tailscale status ----------
status_json() { "$TS" status --json 2>/dev/null; }
state() {
  status_json | sed -n 's/.*"BackendState": *"\([A-Za-z]*\)".*/\1/p' | head -1
}
my_name() {
  local n
  n="$(status_json | awk '/"Self":/{f=1} f' | sed -n 's/.*"DNSName": *"\([^".]*\).*/\1/p' | head -1)"
  [ -z "$n" ] && n="$(status_json | awk '/"Self":/{f=1} f' | sed -n 's/.*"HostName": *"\([^"]*\)".*/\1/p' | head -1)"
  [ -z "$n" ] && n="$(scutil --get ComputerName 2>/dev/null)"
  echo "$n"
}
approved() {
  status_json | awk '/"Self":/{f=1} /"Peer":/{f=0} f' | grep -q '"0\.0\.0\.0/0"'
}
saved_link() {   # prints the saved link if it is still fresh
  [ -f "$LINK_FILE" ] || return 1
  local when url now
  when="$(sed -n 1p "$LINK_FILE")"
  url="$(sed -n 2p "$LINK_FILE")"
  now="$(date +%s)"
  [ -n "$url" ] && [ -n "$when" ] && [ $(( (now - when) / 86400 )) -lt $LINK_MAX_AGE_DAYS ] || return 1
  echo "$url"
}

# ---------- helpers: look & feel ----------
# Colors only switch on when we're really in a terminal that supports them.
# If not, every c_* helper quietly prints nothing — plain text still works fine.
if [ -t 1 ] && tput setaf 1 >/dev/null 2>&1; then USE_COLOR=1; else USE_COLOR=0; fi
c_bold()   { [ "$USE_COLOR" = 1 ] && tput bold; }
c_reset()  { [ "$USE_COLOR" = 1 ] && tput sgr0; }
c_green()  { [ "$USE_COLOR" = 1 ] && tput setaf 2; }
c_yellow() { [ "$USE_COLOR" = 1 ] && tput setaf 3; }
c_red()    { [ "$USE_COLOR" = 1 ] && tput setaf 1; }

banner() {   # banner "Title text"
  local title="$1"
  local rule="────────────────────────────────────────────"
  echo ""
  echo "  $(c_bold)$(c_green)${rule}$(c_reset)"
  echo "  $(c_bold)$(c_green)  ${title}$(c_reset)"
  echo "  $(c_bold)$(c_green)${rule}$(c_reset)"
  echo ""
}
step() {        # step N TOTAL "what's happening"
  echo "  $(c_bold)$(c_green)●$(c_reset) Step $1 of $2 — $3"
}
step_skip() {   # step_skip N TOTAL "what's already done"
  echo "  $(c_bold)$(c_green)✓$(c_reset) Step $1 of $2 — $3"
}

clear
banner "📡  Share My Internet"
echo "  $(c_bold)Share your Mac's internet with someone's iPhone$(c_reset) — simple to"
echo "  turn on, and just as easy to turn off anytime."
echo ""
echo "  Powered by $(c_bold)Tailscale$(c_reset), a well-known, independently trusted app"
echo "  (not something made just for this)."
echo ""
echo "  A few sign-in or permission windows may pop up the first time —"
echo "  that's normal, just follow them."
echo ""
echo "  $(c_bold)$(c_yellow)The first time only$(c_reset), macOS may also ask for your password or"
echo "  Touch ID a few times. If you see \"Allow\" vs \"Always Allow,\" pick"
echo "  \"Always Allow\" so it won't ask again."
echo ""

# ---------- 1) Tailscale installed? ----------
# Keep checking in place instead of making the person quit and
# double-click this file again once they're done.
if [ ! -x "$TS" ]; then
  open "macappstore://apps.apple.com/app/id1475387142"
fi
while [ ! -x "$TS" ]; do
  ANSWER="$(ask "Tailscale isn't installed on this Mac yet — no problem, let's fix that.\n\nThe App Store just opened:\n1. Install Tailscale (it's free).\n2. Open it and choose any sign-in option (Google, Apple, Microsoft, or email). You don't need an account first — signing in the first time creates one automatically, for free.\n\nOnce that's done, click “Check again.”" "Quit" "Check again")"
  [ "$ANSWER" != "Check again" ] && exit 0
done

# ---------- 2) Tailscale running, signed in, connected ----------
step 1 "$TOTAL_STEPS" "Starting the sharing app (Tailscale)..."
open -g -a "$APP"
while true; do
  for i in $(seq 1 20); do
    S="$(state)"
    [ -n "$S" ] && [ "$S" != "NoState" ] && break
    sleep 1
  done
  S="$(state)"
  if [ "$S" = "NeedsLogin" ] || [ -z "$S" ] || [ "$S" = "NoState" ]; then
    open -a "$APP"
    ANSWER="$(ask "Tailscale isn't signed in yet.\n\n1. Click the Tailscale icon in the menu bar (top-right of your screen).\n2. Choose “Log In.”\n3. A web page opens — choose any sign-in option (Google, Apple, Microsoft, or email). Don't have a Tailscale account yet? No problem — signing in for the first time creates one automatically, for free. No separate sign-up needed.\n4. If macOS asks to allow a VPN connection, click  Allow.\n\nOnce you're signed in, click “Check again.”" "Quit" "Check again")"
    [ "$ANSWER" != "Check again" ] && exit 0
    continue
  fi
  if [ "$S" != "Running" ]; then
    "$TS" up >/dev/null 2>&1
    sleep 3
    if [ "$(state)" != "Running" ]; then
      ANSWER="$(ask "Tailscale is installed but switched off.\n\n1. Click the Tailscale icon in the menu bar (top-right of your screen).\n2. Turn it on.\n\nOnce it's on, click “Check again.”" "Quit" "Check again")"
      [ "$ANSWER" != "Check again" ] && exit 0
      continue
    fi
  fi
  break
done
NAME="$(my_name)"

# ---------- 3) Turn on sharing ----------
step 2 "$TOTAL_STEPS" "Turning sharing ON..."
if ! ERR="$("$TS" set --exit-node= --advertise-exit-node 2>&1)"; then
  SHORT="$(echo "$ERR" | head -3 | tr '"' "'" | tr '\n' ' ')"
  echo "  $(c_red)There was a problem turning sharing on.$(c_reset)"
  popup "Something went wrong turning sharing on.\n\nTry quitting Tailscale, reopening it, and running Share My Internet again. If it keeps happening, show this to whoever set this up for you:\n\nTechnical details (for troubleshooting):\n$SHORT"
  exit 1
fi
sleep 2

# ---------- 4) Website steps (only what is still needed) ----------
LINK="$(saved_link)"
NEED_APPROVAL=0; approved || NEED_APPROVAL=1

if [ $NEED_APPROVAL -eq 1 ] || [ -z "$LINK" ]; then
  step 3 "$TOTAL_STEPS" "A few clicks on the Tailscale website..."

  # One short, plain-language instruction per physical click, plus a
  # "more detail" line to show if the person taps "I'm stuck".
  STEP_TEXTS=()
  STEP_HELP=()

  STEP_TEXTS+=("If the page is asking you to sign in, sign in now with your Tailscale account.\n\nAlready signed in and see a list of devices? Just click “Next step” below.")
  STEP_HELP+=("Use the same sign-in option you used when you first set up Tailscale on this Mac (for example “Sign in with Google” or “Sign in with Apple”).\n\nIf this web page is asking you to sign in again and you're not sure you have an account: you already signed in once to get Tailscale running on this Mac, so just pick that same option again here — it's the same account, not a new one.")

  if [ $NEED_APPROVAL -eq 1 ]; then
    STEP_TEXTS+=("Find the row for your Mac — it's named “$NAME”.\n\nOn the right side of that row, click the small ••• button (three dots in a row).")
    STEP_HELP+=("The page lists every device signed in to this Tailscale account. Your Mac's row shows “$NAME”. The ••• button sits at the far right end of that same row — if you don't see it, try making the browser window a bit wider.")

    STEP_TEXTS+=("A small menu popped up.\n\nClick “Edit route settings” in that menu.")
    STEP_HELP+=("If the menu isn't there anymore, it probably closed on its own — go back one step and click the ••• button again to reopen it.")

    STEP_TEXTS+=("A screen about routes appeared.\n\nFind the switch next to “Use as exit node” and turn it ON (it should turn blue or green).")
    STEP_HELP+=("It's a simple on/off switch — just click it once. If it already looks blue or green, it's already on, so you can continue.")

    STEP_TEXTS+=("Click the “Save” button to save that change.")
    STEP_HELP+=("The Save button is usually near the bottom of the screen or panel you're looking at.")
  fi

  if [ -z "$LINK" ]; then
    STEP_TEXTS+=("Back on the main list, find your Mac's row again — “$NAME”.\n\nClick the ••• button on that row, then choose “Share” from the menu.")
    STEP_HELP+=("Same ••• button as before, at the right-hand end of your Mac's row. Clicking it opens a small menu — “Share” is one of the options in that menu.")

    STEP_TEXTS+=("A window titled “Share” opened.\n\nTick the checkbox “Allow use as an exit node.”")
    STEP_HELP+=("It's a small checkbox inside that Share window — click once so a checkmark appears in it.")

    STEP_TEXTS+=("If you're asked how the link can be used, choose the option for a link that can be used more than once.\n\nDon't see a question like that? No problem — just continue to the next step.")
    STEP_HELP+=("This only shows up sometimes. If your screen looks the same as before, it's fine — nothing to click here, just go to the next step.")

    STEP_TEXTS+=("Click “Copy share link.”\n\nNothing will visibly change on screen. Share My Internet reads that link, then a moment from now replaces it on your clipboard with a complete, ready-to-send message that includes this link — that's expected, not a mistake.")
    STEP_HELP+=("Look inside the same “Share” window from the step before this one — “Copy share link” is usually near the bottom of it.")
  fi

  TOTAL_SUBSTEPS=${#STEP_TEXTS[@]}
  i=0   # 0-based index into STEP_TEXTS / STEP_HELP

  PRE_MSG="Next, a web page on Tailscale's website will open.\n\nIf you're not already signed in, you'll land on a sign-in page first — that's expected.\n\nOnce you're in, look for this Mac in the list of devices: $NAME"
  ANSWER="$(ask "$PRE_MSG" "Quit" "Open the page")"
  if [ "$ANSWER" != "Open the page" ]; then cancel_sharing; exit 0; fi
  open "$ADMIN_URL"

  while true; do
    STEP_NUM=$((i + 1))
    BODY="Step $STEP_NUM of $TOTAL_SUBSTEPS\n\n${STEP_TEXTS[$i]}\n\nTip: ${STEP_HELP[$i]}"

    if [ "$i" -eq 0 ]; then LEFT="Open the page again"; else LEFT="Back"; fi

    IS_LAST=0
    [ "$STEP_NUM" -eq "$TOTAL_SUBSTEPS" ] && IS_LAST=1

    if [ "$IS_LAST" -eq 1 ] && [ -z "$LINK" ]; then
      RIGHT="I copied the link"
    elif [ "$IS_LAST" -eq 1 ]; then
      RIGHT="Done"
    else
      RIGHT="Next step"
    fi

    ANSWER="$(ask3 "$BODY" "$LEFT" "Quit" "$RIGHT")"
    if [ -z "$ANSWER" ] || [ "$ANSWER" = "Quit" ]; then cancel_sharing; exit 0; fi

    if [ "$ANSWER" = "Open the page again" ]; then
      open "$ADMIN_URL"
    elif [ "$ANSWER" = "Back" ]; then
      i=$((i - 1))
    elif [ "$IS_LAST" -eq 1 ] && [ -z "$LINK" ]; then
      CLIP="$(pbpaste 2>/dev/null | head -1 | tr -d '[:space:]')"
      if echo "$CLIP" | grep -qiE '^https://[^ ]*tailscale[^ ]*'; then
        LINK="$CLIP"
        printf '%s\n%s\n' "$(date +%s)" "$LINK" > "$LINK_FILE"
        break
      fi
      popup "That doesn't look like a Tailscale share link yet.\n\nGo back to the web page, click “Copy share link” once more, then click “I copied the link” again."
    elif [ "$IS_LAST" -eq 1 ]; then
      break
    else
      i=$((i + 1))
    fi
  done
else
  step_skip 3 "$TOTAL_STEPS" "Website setup (already done earlier, skipping)"
fi

# ---------- 5) Build the message for the iPhone person ----------
step 4 "$TOTAL_STEPS" "Preparing the message for the iPhone person..."
MSG="Hi! You can now use my internet on your iPhone. Here's how:

1. Install the free Tailscale app from the App Store (skip this if you already have it):
   https://tailscale.com/download/ios
2. Open Tailscale and sign in (Sign in with Apple is the easiest way).
   Your iPhone will ask to allow a VPN connection — tap Allow.
3. Tap this link and accept the invite (skip if you already did this before) — one more step after this:
   $LINK
4. Last step: in the Tailscale app, make sure it says Connected, then tap  Exit Node  and choose:  $NAME

That's it — you're all done, and now using my internet!

To stop anytime: open Tailscale, tap  Exit Node  and choose  None."
printf '%s' "$MSG" | pbcopy

# ---------- 6) Sharing is ON: keep Mac awake, clean up on close ----------
caffeinate -dims &
CAF=$!
stop_sharing() {
  "$TS" set --advertise-exit-node=false >/dev/null 2>&1
  kill "$CAF" >/dev/null 2>&1
  exit 0
}
trap stop_sharing EXIT HUP INT TERM

draw_screen() {
  clear
  banner "✅  SHARING IS ON"
  echo "  $(c_bold)$(c_yellow)📋 The message below is already copied.$(c_reset)"
  echo "  It includes the share link you just copied, built into a"
  echo "  complete message — that's what's on your clipboard now."
  echo "  Just paste it to the iPhone person — in Messages, WeChat,"
  echo "  WhatsApp, or however you usually talk to them."
  echo ""
  echo "$MSG" | sed 's/^/    │ /'
  echo ""
  echo "  $(c_bold)Keep this running:$(c_reset)"
  echo "    • Leave this window open"
  echo "    • Keep the Mac plugged in, with the lid open"
  echo ""
  echo "  $(c_bold)Good to know:$(c_reset)"
  echo "    • To STOP sharing — just close this window"
  echo "    • Press ENTER anytime to copy the message again"
  echo ""
}
draw_screen
notify "Sharing is ON. The message for the iPhone is copied."
ANSWER="$(ask "Sharing is ON! ✅\n\nThe message for the iPhone person includes the share link you just copied, built into a complete, ready-to-paste message — that's what's on your clipboard now.\nJust paste it to them — in Messages, WeChat, WhatsApp, or wherever you talk to them.\n\nTo stop sharing later, just close this window." "OK" "Open Messages")"
[ "$ANSWER" = "Open Messages" ] && open -a Messages

# ---------- 7) Stay alive; reconnect quietly; ENTER re-copies ----------
while true; do
  if read -r -t 30; then
    printf '%s' "$MSG" | pbcopy
    draw_screen
    notify "Message copied again."
  fi
  if [ "$(state)" != "Running" ]; then
    "$TS" up >/dev/null 2>&1
    "$TS" set --exit-node= --advertise-exit-node >/dev/null 2>&1
  fi
done
