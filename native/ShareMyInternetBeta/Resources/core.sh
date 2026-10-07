#!/bin/bash
# Share My Internet — shell helper used by the AppleScript app.
# All subcommands always exit 0 (even for "no"/"false" results) so that
# AppleScript's `do shell script` never raises an error for a normal outcome.
# Real failures are reported by printing "ERROR:<details>" instead.

APP="/Applications/Tailscale.app"
TS="$APP/Contents/MacOS/Tailscale"
LINK_FILE="$HOME/.share-my-internet-link"
LINK_MAX_AGE_DAYS=25
PID_FILE="$HOME/.share-my-internet-watchdog.pid"

status_json() { "$TS" status --json 2>/dev/null; }
state() { status_json | sed -n 's/.*"BackendState": *"\([A-Za-z]*\)".*/\1/p' | head -1; }
my_name() {
  local n
  n="$(status_json | awk '/"Self":/{f=1} f' | sed -n 's/.*"DNSName": *"\([^".]*\).*/\1/p' | head -1)"
  [ -z "$n" ] && n="$(status_json | awk '/"Self":/{f=1} f' | sed -n 's/.*"HostName": *"\([^"]*\)".*/\1/p' | head -1)"
  [ -z "$n" ] && n="$(scutil --get ComputerName 2>/dev/null)"
  echo "$n"
}
approved() { status_json | awk '/"Self":/{f=1} /"Peer":/{f=0} f' | grep -q '"0\.0\.0\.0/0"'; }
saved_link() {
  [ -f "$LINK_FILE" ] || return 1
  local when url now
  when="$(sed -n 1p "$LINK_FILE")"
  url="$(sed -n 2p "$LINK_FILE")"
  now="$(date +%s)"
  [ -n "$url" ] && [ -n "$when" ] && [ $(( (now - when) / 86400 )) -lt $LINK_MAX_AGE_DAYS ] || return 1
  echo "$url"
}

cmd="$1"; shift

case "$cmd" in

  is-installed)
    if [ -x "$TS" ]; then echo yes; else echo no; fi
    ;;

  ensure-running)
    open -g -a "$APP"
    for i in $(seq 1 20); do
      S="$(state)"
      [ -n "$S" ] && [ "$S" != "NoState" ] && break
      sleep 1
    done
    S="$(state)"
    if [ "$S" = "NeedsLogin" ] || [ -z "$S" ] || [ "$S" = "NoState" ]; then
      open -a "$APP"
      echo "NEEDS_LOGIN"
      exit 0
    fi
    if [ "$S" != "Running" ]; then
      "$TS" up >/dev/null 2>&1
      sleep 3
      if [ "$(state)" != "Running" ]; then
        echo "OFF"
        exit 0
      fi
    fi
    echo "RUNNING"
    ;;

  get-name)
    my_name
    ;;

  turn-on-sharing)
    if ! ERR="$("$TS" set --exit-node= --advertise-exit-node 2>&1)"; then
      SHORT="$(echo "$ERR" | head -3 | tr '"' "'" | tr '\n' ' ')"
      echo "ERROR:$SHORT"
      exit 0
    fi
    echo "OK"
    ;;

  needs-approval)
    if approved; then echo no; else echo yes; fi
    ;;

  saved-link)
    saved_link
    true
    ;;

  validate-link)
    CLIP="$(printf '%s' "$1" | head -1 | tr -d '[:space:]')"
    if echo "$CLIP" | grep -qiE '^https://[^ ]*tailscale[^ ]*'; then
      echo "$CLIP"
    else
      echo ""
    fi
    ;;

  save-link)
    printf '%s\n%s\n' "$(date +%s)" "$1" > "$LINK_FILE"
    echo OK
    ;;

  build-message)
    LINK="$1"; NAME="$2"; LANG_CODE="$3"
    if [ "$LANG_CODE" = "zh" ]; then
      cat <<EOF
嗨！现在你可以用我的网络上网了，步骤如下：

1. 从 App Store 下载免费的 Tailscale 应用（如果已经安装过，跳过这一步）：
   https://tailscale.com/download/ios
2. 打开 Tailscale 并登录（用 Apple 账号登录最简单）。
   你的 iPhone 会询问是否允许 VPN 连接 —— 点“允许”。
3. 点击下面这个链接并接受邀请（如果之前已经接受过，跳过这一步）——之后还有最后一步：
   $LINK
4. 最后一步：在 Tailscale 应用里确认显示“已连接”，然后点  Exit Node  并选择：  $NAME

大功告成 —— 现在你已经在用我的网络了！

随时可以停止：打开 Tailscale，点  Exit Node  选择  None。
EOF
    else
      cat <<EOF
Hi! You can now use my internet on your iPhone. Here's how:

1. Install the free Tailscale app from the App Store (skip this if you already have it):
   https://tailscale.com/download/ios
2. Open Tailscale and sign in (Sign in with Apple is the easiest way).
   Your iPhone will ask to allow a VPN connection — tap Allow.
3. Tap this link and accept the invite (skip if you already did this before) — one more step after this:
   $LINK
4. Last step: in the Tailscale app, make sure it says Connected, then tap  Exit Node  and choose:  $NAME

That's it — you're all done, and now using my internet!

To stop anytime: open Tailscale, tap  Exit Node  and choose  None.
EOF
    fi
    ;;

  watchdog-start)
    RES_DIR="$(cd "$(dirname "$0")" && pwd)"
    nohup bash "$RES_DIR/watchdog.sh" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    echo OK
    ;;

  watchdog-stop)
    if [ -f "$PID_FILE" ]; then
      PID="$(cat "$PID_FILE" 2>/dev/null)"
      [ -n "$PID" ] && kill "$PID" >/dev/null 2>&1
      rm -f "$PID_FILE"
    fi
    "$TS" set --advertise-exit-node=false >/dev/null 2>&1
    echo OK
    ;;

  *)
    echo "ERROR:unknown command $cmd"
    ;;
esac
