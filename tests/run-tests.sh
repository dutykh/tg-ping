#!/usr/bin/env bash
#
# Offline test suite for tg-ping. No network access and no Telegram account
# are needed: a stub curl records every request and answers with canned JSON.
#
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).
#
# Usage: tests/run-tests.sh [name-filter]

# Formulas such as '$E(t)$' are written in single quotes on purpose.
# shellcheck disable=SC2016

set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TG="$ROOT/bin/tg-ping"
FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0
FAILED_NAMES=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/tg-ping-tests.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT

export PATH="$ROOT/tests/stub:$PATH"
# Settings of the person running the tests must not leak in. The switches of
# the test runs themselves stay: TG_PING_AWK chooses the awk, TG_PING_HIDE
# hides programs such as jq and python3.
for var in $(env | sed -n 's/^\(TG_PING_[A-Z_]*\)=.*/\1/p; s/^\(TELEGRAM_[A-Z_]*\)=.*/\1/p'); do
    case "$var" in TG_PING_AWK|TG_PING_HIDE) continue ;; esac
    unset "$var"
done
export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$SANDBOX/home/.config"
export TG_PING_STATE_DIR="$SANDBOX/state"
export TG_PING_NO_DOTENV=1
export TG_PING_TOKEN="123456789:AAFakeTokenForTestsOnly_abcdefghijklmn"
export TG_PING_CHAT_ID="-1001234567890"
export TG_PING_DMI_DIR="$SANDBOX/dmi"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$TG_PING_STATE_DIR" "$TG_PING_DMI_DIR"
printf '10\n' > "$TG_PING_DMI_DIR/chassis_type"

# Files the media tests send, made once so that any test can run alone.
printf 'PNG' > "$SANDBOX/fig.png"
printf 'MP4' > "$SANDBOX/anim.mp4"
printf 'GIF' > "$SANDBOX/a.gif"
for i in 1 2 3 4 5 6 7 8 9 10 11; do printf 'P%s' "$i" > "$SANDBOX/p$i.png"; done

CAPTURE=""
OUTPUT=""
RC=0

start_case() {
    CAPTURE="$SANDBOX/capture.$$"
    rm -rf "$CAPTURE" "$CAPTURE.d" "$SANDBOX/queue" "$TG_PING_STATE_DIR"
    mkdir -p "$TG_PING_STATE_DIR"
    export TGP_CAPTURE="$CAPTURE"
    unset TGP_STUB_SCRIPT TGP_STUB_HTTP TGP_STUB_DIR TGP_STUB_ASK TGP_STUB_QUEUE TGP_STUB_UPDATES \
          TGP_STUB_SLOW TGP_STUB_CONFLICT TGP_STUB_WEBHOOK TGP_STUB_TOPICS 2>/dev/null || true
}

methods() {
    # The methods called so far, in order, on one line.
    [ -f "$CAPTURE" ] && grep '^METHOD' "$CAPTURE" | cut -f2 | tr '\n' ' '
}

nth_field() {
    # nth_field METHOD K FIELD -> FIELD of the K-th call of METHOD. Calls are
    # numbered in the order of the METHOD lines of the capture.
    local n
    n=$(grep '^METHOD' "$CAPTURE" 2>/dev/null | cut -f2 | grep -n "^$1\$" | sed -n "${2}p" | cut -d: -f1)
    [ -n "$n" ] && cat "$CAPTURE.d/calls/$n.$1.$3" 2>/dev/null
}

queue() {
    # queue METHOD LINE...: replies ("status<TAB>body") served to METHOD in order.
    local m="$1"
    shift
    mkdir -p "$SANDBOX/queue"
    export TGP_STUB_QUEUE="$SANDBOX/queue"
    printf '%s\n' "$@" > "$SANDBOX/queue/$m"
    rm -f "$SANDBOX/queue/$m.n"
}

valid_utf8() { printf '%s' "$1" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; }

balanced_html() {
    # True when the Telegram tags of the text open and close in order.
    printf '%s' "$1" | awk '
        { s = s $0 "\n" }
        END {
            while (match(s, /<\/?(b|i|u|s|code|pre|a|blockquote|tg-spoiler)( [^>]*)?>/)) {
                t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
                name = t; sub(/^<\/?/, "", name); sub(/[ >].*$/, "", name)
                if (substr(t, 2, 1) == "/") { if (sp == 0 || st[sp] != name) exit 1; sp-- }
                else st[++sp] = name
            }
            exit (sp == 0 ? 0 : 1)
        }'
}

tg() {
    OUTPUT=$("$TG" "$@" 2>&1)
    RC=$?
    return 0
}

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES="$FAILED_NAMES
  - $1"; printf '  FAIL %s\n     %s\n' "$1" "$2"; }

check() {
    # check NAME CONDITION_DESCRIPTION ACTUAL_STATUS
    if [ "$3" -eq 0 ]; then ok "$1"; else bad "$1" "$2"; fi
}

# A pattern, not 'printf | grep -q': grep stops reading at the first match,
# and under pipefail the cut pipe would turn a match into a failure.
contains() { case "$1" in *"$2"*) return 0 ;; esac; return 1; }

capture_has() { [ -f "$CAPTURE" ] && grep -Fq -- "$1" "$CAPTURE"; }
capture_count() { [ -f "$CAPTURE" ] && grep -c "^METHOD	$1\$" "$CAPTURE" || echo 0; }
field_value() { cat "$CAPTURE.d/$1.$2" 2>/dev/null; }

describe() {
    case "$FILTER" in
        "") return 0 ;;
        *) case "$1" in *"$FILTER"*) return 0 ;; *) SKIP=$((SKIP+1)); return 1 ;; esac ;;
    esac
}

# ---------------------------------------------------------------------------

printf 'tg-ping test suite\n\n'

# --- basic sending ---------------------------------------------------------
if describe "send: plain text reaches sendMessage"; then
    start_case
    tg "hello world"
    if [ "$RC" -eq 0 ] && [ "$(field_value sendMessage text)" = "hello world" ]; then
        ok "send: plain text reaches sendMessage"
    else
        bad "send: plain text reaches sendMessage" "rc=$RC text=$(field_value sendMessage text)"
    fi
fi

if describe "send: chat id is passed through"; then
    start_case
    tg "x"
    check "send: chat id is passed through" "chat_id was $(field_value sendMessage chat_id)" \
        "$( [ "$(field_value sendMessage chat_id)" = "-1001234567890" ] && echo 0 || echo 1 )"
fi

if describe "format: markdown becomes escaped html"; then
    start_case
    tg --title "Build" "fixed *bug* in \`solve_x_1(n)\` when n_max < 10 & rising"
    body=$(field_value sendMessage text)
    if contains "$body" "<b>Build</b>" && contains "$body" "<b>bug</b>" &&
       contains "$body" "<code>solve_x_1(n)</code>" && contains "$body" "n_max &lt; 10 &amp; rising"; then
        ok "format: markdown becomes escaped html"
    else
        bad "format: markdown becomes escaped html" "$body"
    fi
fi

if describe "format: plain sets no parse mode"; then
    start_case
    tg --plain "literal *stars* stay"
    if [ ! -f "$CAPTURE.d/sendMessage.parse_mode" ] &&
       [ "$(field_value sendMessage text)" = "literal *stars* stay" ]; then
        ok "format: plain sets no parse mode"
    else
        bad "format: plain sets no parse mode" "parse_mode=$(field_value sendMessage parse_mode)"
    fi
fi

if describe "format: html passes through untouched"; then
    start_case
    tg --html "<b>bold</b> stays"
    check "format: html passes through untouched" "$(field_value sendMessage text)" \
        "$( [ "$(field_value sendMessage text)" = "<b>bold</b> stays" ] && echo 0 || echo 1 )"
fi

if describe "compose: items, fields and buttons"; then
    start_case
    tg --ok --title "Done" --item "one" --item "two" --field "err=1e-8" \
       --button "Open=https://example.com"
    body=$(field_value sendMessage text)
    kb=$(field_value sendMessage reply_markup)
    if contains "$body" "• one" && contains "$body" "• two" &&
       contains "$body" "<b>err</b>: 1e-8" && contains "$kb" '"url":"https://example.com"'; then
        ok "compose: items, fields and buttons"
    else
        bad "compose: items, fields and buttons" "$body / $kb"
    fi
fi

if describe "compose: stdin is read when piped"; then
    start_case
    OUTPUT=$(printf 'from a pipe\n' | "$TG" --title "Piped" 2>&1); RC=$?
    check "compose: stdin is read when piped" "text=$(field_value sendMessage text)" \
        "$( contains "$(field_value sendMessage text)" "from a pipe" && echo 0 || echo 1 )"
fi

if describe "compose: --code - takes the pipe as a code block"; then
    start_case
    printf 'make: *** [all] Error 2\nsecond line\n' | "$TG" --title "make output" --code - >/dev/null 2>&1
    body=$(field_value sendMessage text)
    if contains "$body" "<pre>make: *** [all] Error 2" && contains "$body" "second line"; then
        ok "compose: --code - takes the pipe as a code block"
    else
        bad "compose: --code - takes the pipe as a code block" "$body"
    fi
fi

# --- delivery options ------------------------------------------------------
if describe "delivery: silent, topic and reply"; then
    start_case
    tg --silent --topic 42 --reply-to 7 "quiet"
    if [ "$(field_value sendMessage disable_notification)" = "true" ] &&
       [ "$(field_value sendMessage message_thread_id)" = "42" ] &&
       contains "$(field_value sendMessage reply_parameters)" '"message_id":7' &&
       contains "$(field_value sendMessage reply_parameters)" '"allow_sending_without_reply":true'; then
        ok "delivery: silent, topic and reply"
    else
        bad "delivery: silent, topic and reply" "$(cat "$CAPTURE")"
    fi
fi

if describe "delivery: several chats fan out"; then
    start_case
    tg --chat 111 --chat 222 "fan out"
    check "delivery: several chats fan out" "sent $(capture_count sendMessage) messages" \
        "$( [ "$(capture_count sendMessage)" -eq 2 ] && echo 0 || echo 1 )"
fi

if describe "delivery: pin issues pinChatMessage"; then
    start_case
    tg --pin "important"
    check "delivery: pin issues pinChatMessage" "no pin call recorded" \
        "$( capture_has "METHOD	pinChatMessage" && echo 0 || echo 1 )"
fi

# --- long messages ---------------------------------------------------------
if describe "split: a long message becomes several parts"; then
    start_case
    long=$(awk 'BEGIN{for(i=0;i<900;i++) printf "line %d of a very long log file\n", i}')
    printf '%s' "$long" | "$TG" --title "Long" >/dev/null 2>&1
    n=$(capture_count sendMessage)
    check "split: a long message becomes several parts" "got $n parts" \
        "$( [ "$n" -ge 3 ] && [ "$n" -le 8 ] && echo 0 || echo 1 )"
fi

if describe "split: truncate keeps a single message"; then
    start_case
    long=$(awk 'BEGIN{for(i=0;i<900;i++) printf "line %d of a very long log file\n", i}')
    printf '%s' "$long" | "$TG" --truncate --title "Long" >/dev/null 2>&1
    check "split: truncate keeps a single message" "got $(capture_count sendMessage)" \
        "$( [ "$(capture_count sendMessage)" -eq 1 ] && echo 0 || echo 1 )"
fi

# --- error handling --------------------------------------------------------
if describe "fallback: markup error is resent as plain text"; then
    start_case
    script="$SANDBOX/script1"
    printf '400\t{"ok":false,"error_code":400,"description":"Bad Request: can'"'"'t parse entities"}\n200\t{"ok":true,"result":{"message_id":9}}\n' > "$script"
    rm -f "$script.count"
    export TGP_STUB_SCRIPT="$script"
    tg --html "<b>broken"
    unset TGP_STUB_SCRIPT
    if [ "$RC" -eq 0 ] && [ "$(capture_count sendMessage)" -eq 2 ]; then
        ok "fallback: markup error is resent as plain text"
    else
        bad "fallback: markup error is resent as plain text" "rc=$RC calls=$(capture_count sendMessage)"
    fi
fi

if describe "fallback: --no-fallback reports the API error"; then
    start_case
    export TGP_STUB_HTTP=400
    printf '%s' '{"ok":false,"description":"Bad Request: chat not found"}' > "$SANDBOX/resp"
    mkdir -p "$SANDBOX/stubdir"
    printf '%s' '{"ok":false,"description":"Bad Request: chat not found"}' > "$SANDBOX/stubdir/sendMessage.response"
    export TGP_STUB_DIR="$SANDBOX/stubdir"
    tg --no-fallback "boom"
    unset TGP_STUB_HTTP TGP_STUB_DIR
    if [ "$RC" -eq 5 ] && contains "$OUTPUT" "chat not found"; then
        ok "fallback: --no-fallback reports the API error"
    else
        bad "fallback: --no-fallback reports the API error" "rc=$RC out=$OUTPUT"
    fi
fi

if describe "retry: 429 is honoured then the message goes out"; then
    start_case
    script="$SANDBOX/script2"
    printf '429\t{"ok":false,"error_code":429,"parameters":{"retry_after":1}}\n200\t{"ok":true,"result":{"message_id":9}}\n' > "$script"
    rm -f "$script.count"
    export TGP_STUB_SCRIPT="$script"
    tg "rate limited once"
    unset TGP_STUB_SCRIPT
    if [ "$RC" -eq 0 ] && [ "$(capture_count sendMessage)" -eq 2 ]; then
        ok "retry: 429 is honoured then the message goes out"
    else
        bad "retry: 429 is honoured then the message goes out" "rc=$RC calls=$(capture_count sendMessage)"
    fi
fi

if describe "exit: missing credentials give code 3"; then
    start_case
    OUTPUT=$(env -u TG_PING_TOKEN -u TG_PING_CHAT_ID "$TG" "no creds" 2>&1); RC=$?
    check "exit: missing credentials give code 3" "rc=$RC" "$( [ "$RC" -eq 3 ] && echo 0 || echo 1 )"
fi

if describe "exit: an unknown option gives code 2"; then
    start_case
    tg --no-such-flag "x"
    check "exit: an unknown option gives code 2" "rc=$RC" "$( [ "$RC" -eq 2 ] && echo 0 || echo 1 )"
fi

if describe "safety: soft-fail turns a failure into success"; then
    start_case
    export TGP_STUB_HTTP=400
    mkdir -p "$SANDBOX/stubdir2"
    printf '%s' '{"ok":false,"description":"Bad Request: chat not found"}' > "$SANDBOX/stubdir2/sendMessage.response"
    export TGP_STUB_DIR="$SANDBOX/stubdir2"
    tg --soft-fail --no-fallback "boom"
    unset TGP_STUB_HTTP TGP_STUB_DIR
    check "safety: soft-fail turns a failure into success" "rc=$RC" "$( [ "$RC" -eq 0 ] && echo 0 || echo 1 )"
fi

if describe "safety: TG_PING_DISABLED sends nothing"; then
    start_case
    TG_PING_DISABLED=1 "$TG" "should not be sent" >/dev/null 2>&1; RC=$?
    if [ "$RC" -eq 0 ] && [ ! -f "$CAPTURE" ]; then
        ok "safety: TG_PING_DISABLED sends nothing"
    else
        bad "safety: TG_PING_DISABLED sends nothing" "rc=$RC capture=$( [ -f "$CAPTURE" ] && echo present || echo absent)"
    fi
fi

if describe "safety: the token never appears in a dry run"; then
    start_case
    OUTPUT=$("$TG" --dry-run --verbose "secret check" 2>&1)
    if contains "$OUTPUT" "bot<TOKEN>" && ! contains "$OUTPUT" "AAFakeTokenForTestsOnly"; then
        ok "safety: the token never appears in a dry run"
    else
        bad "safety: the token never appears in a dry run" "$OUTPUT"
    fi
fi

if describe "safety: a hostile env file is not executed"; then
    start_case
    sandbox_proj="$SANDBOX/proj"; mkdir -p "$sandbox_proj"
    # shellcheck disable=SC2016  # the substitution must stay literal, that is the point
    printf 'TG_PING_CHAT_ID=$(touch %s/pwned)\nTG_PING_TOKEN=9:abc\n' "$SANDBOX" > "$sandbox_proj/.tg-ping.env"
    ( cd "$sandbox_proj" && env -u TG_PING_TOKEN -u TG_PING_CHAT_ID -u TG_PING_NO_DOTENV \
        TGP_CAPTURE="$CAPTURE" "$TG" "env test" >/dev/null 2>&1 )
    # Nothing may be executed, and the nonsense chat id must be refused.
    if [ ! -f "$SANDBOX/pwned" ] && [ ! -f "$CAPTURE" ]; then
        ok "safety: a hostile env file is not executed"
    else
        bad "safety: a hostile env file is not executed" "pwned=$( [ -f "$SANDBOX/pwned" ] && echo yes || echo no) capture=$( [ -f "$CAPTURE" ] && cat "$CAPTURE" || echo none)"
    fi
fi

if describe "safety: cooldown suppresses a repeat"; then
    start_case
    tg --cooldown 60 --key testbucket "repeated alert"
    first=$(capture_count sendMessage)
    tg --cooldown 60 --key testbucket "repeated alert"
    second=$(capture_count sendMessage)
    if [ "$first" -eq 1 ] && [ "$second" -eq 1 ]; then
        ok "safety: cooldown suppresses a repeat"
    else
        bad "safety: cooldown suppresses a repeat" "first=$first second=$second"
    fi
fi

if describe "config: .env.local supplies the namespaced keys only"; then
    start_case
    proj="$SANDBOX/proj-local"; mkdir -p "$proj"
    # A file shared with other tools: the namespaced chat is ours, the bare one is not.
    printf 'TG_PING_CHAT_ID=777\nBOT_TOKEN=999:notours\nCHAT_ID=1\n' > "$proj/.env.local"
    ( cd "$proj" && env -u TG_PING_CHAT_ID -u TG_PING_NO_DOTENV \
        TGP_CAPTURE="$CAPTURE" "$TG" "local env" >/dev/null 2>&1 )
    if [ "$(field_value sendMessage chat_id)" = "777" ]; then
        ok "config: .env.local supplies the namespaced keys only"
    else
        bad "config: .env.local supplies the namespaced keys only" "chat=$(field_value sendMessage chat_id)"
    fi
fi

if describe "config: a project file never supplies the token or the server"; then
    start_case
    proj="$SANDBOX/proj-token"; mkdir -p "$proj"
    printf 'TG_PING_TOKEN=222:projecttoken\nTG_PING_API=https://evil.example\nTG_PING_CHAT_ID=55\n' > "$proj/.tg-ping.env"
    printf 'TG_PING_TOKEN=333:localtoken\nTG_PING_API=https://evil2.example\n' > "$proj/.env.local"
    out=$( cd "$proj" && env -u TG_PING_TOKEN -u TG_PING_CHAT_ID -u TG_PING_NO_DOTENV \
        TGP_CAPTURE="$CAPTURE" "$TG" "should not leave" 2>&1 ); rc=$?
    out2=$( cd "$proj" && env -u TG_PING_NO_DOTENV "$TG" config show 2>&1 )
    if [ "$rc" -eq 3 ] && [ ! -f "$CAPTURE" ] && contains "$out2" "api root  : https://api.telegram.org" &&
       ! contains "$out2" "evil"; then
        ok "config: a project file never supplies the token or the server"
    else
        bad "config: a project file never supplies the token or the server" "rc=$rc out=$out show=$out2"
    fi
fi

if describe "config: TELEGRAM_* keys of another tool in .env.local are ignored"; then
    start_case
    proj="$SANDBOX/proj-other-bot"; mkdir -p "$proj"
    printf 'TELEGRAM_BOT_TOKEN=444:otherbot\nTELEGRAM_CHAT_ID=-100999\n' > "$proj/.env.local"
    ( cd "$proj" && env -u TG_PING_NO_DOTENV TGP_CAPTURE="$CAPTURE" "$TG" "mine" >/dev/null 2>&1 )
    if [ "$(field_value sendMessage chat_id)" = "-1001234567890" ] &&
       [ "$(field_value sendMessage bot)" = "123456789" ]; then
        ok "config: TELEGRAM_* keys of another tool in .env.local are ignored"
    else
        bad "config: TELEGRAM_* keys of another tool in .env.local are ignored" "chat=$(field_value sendMessage chat_id)"
    fi
fi

if describe "config: a bare BOT_TOKEN in .env.local is ignored"; then
    start_case
    proj="$SANDBOX/proj-bare"; mkdir -p "$proj"
    printf 'BOT_TOKEN=999:notours\nCHAT_ID=1\n' > "$proj/.env.local"
    out=$( cd "$proj" && env -u TG_PING_TOKEN -u TG_PING_CHAT_ID -u TG_PING_NO_DOTENV \
        TGP_CAPTURE="$CAPTURE" "$TG" "should not send" 2>&1 )
    rc=$?
    if [ "$rc" -eq 3 ] && [ ! -f "$CAPTURE" ]; then
        ok "config: a bare BOT_TOKEN in .env.local is ignored"
    else
        bad "config: a bare BOT_TOKEN in .env.local is ignored" "rc=$rc out=$out"
    fi
fi

if describe "config: settings other than credentials come from the file"; then
    start_case
    proj="$SANDBOX/proj-settings"; mkdir -p "$proj"
    printf 'TG_PING_TOKEN=1:x\nTG_PING_CHAT_ID=42\nTG_PING_FORMAT=plain\nTG_PING_TAIL=7\nTG_PING_MATH_DPI=600\n' \
        > "$proj/.tg-ping.env"
    out=$( cd "$proj" && env -u TG_PING_TOKEN -u TG_PING_CHAT_ID -u TG_PING_NO_DOTENV \
        "$TG" config show 2>&1 )
    if contains "$out" "format    : plain" && contains "$out" "run tail  : 7 lines" &&
       contains "$out" "600 dpi"; then
        ok "config: settings other than credentials come from the file"
    else
        bad "config: settings other than credentials come from the file" "$out"
    fi
fi

# --- media -----------------------------------------------------------------
if describe "media: a photo is uploaded"; then
    start_case
    printf 'PNGDATA' > "$SANDBOX/fig.png"
    tg photo "$SANDBOX/fig.png" --caption "a figure"
    if capture_has "METHOD	sendPhoto" && capture_has "UPLOAD	photo=$SANDBOX/fig.png" &&
       contains "$(field_value sendPhoto caption)" "a figure"; then
        ok "media: a photo is uploaded"
    else
        bad "media: a photo is uploaded" "$(cat "$CAPTURE")"
    fi
fi

if describe "media: several photos become an album"; then
    start_case
    printf 'A' > "$SANDBOX/a.png"; printf 'B' > "$SANDBOX/b.png"
    tg photo "$SANDBOX/a.png" "$SANDBOX/b.png" --caption "sweep"
    if capture_has "METHOD	sendMediaGroup" && contains "$(field_value sendMediaGroup media)" 'attach://f1'; then
        ok "media: several photos become an album"
    else
        bad "media: several photos become an album" "$(cat "$CAPTURE")"
    fi
fi

if describe "media: a document keeps its display name"; then
    start_case
    printf 'REPORT' > "$SANDBOX/r.pdf"
    tg file "$SANDBOX/r.pdf" --name "final report.pdf"
    check "media: a document keeps its display name" "$(grep UPLOAD "$CAPTURE")" \
        "$( capture_has "filename=final report.pdf" && echo 0 || echo 1 )"
fi

if describe "media: an oversized file is refused"; then
    start_case
    if command -v truncate >/dev/null 2>&1; then
        truncate -s 60M "$SANDBOX/big.bin"
        tg file "$SANDBOX/big.bin"
        rm -f "$SANDBOX/big.bin"
        check "media: an oversized file is refused" "rc=$RC" "$( [ "$RC" -eq 2 ] && echo 0 || echo 1 )"
    else
        SKIP=$((SKIP+1))
    fi
fi

# --- code and tables -------------------------------------------------------
if describe "code: a snippet becomes a highlighted block"; then
    start_case
    printf 'def f(x):\n    return x < 2\n' > "$SANDBOX/s.py"
    tg code "$SANDBOX/s.py"
    body=$(field_value sendMessage text)
    if contains "$body" '<pre><code class="language-python">' && contains "$body" 'return x &lt; 2'; then
        ok "code: a snippet becomes a highlighted block"
    else
        bad "code: a snippet becomes a highlighted block" "$body"
    fi
fi

if describe "code: an oversized snippet is sent as a document"; then
    start_case
    awk 'BEGIN{for(i=0;i<400;i++) print "a very long line of source code that repeats"}' > "$SANDBOX/big.py"
    tg code "$SANDBOX/big.py"
    check "code: an oversized snippet is sent as a document" "$(cat "$CAPTURE" | head -3)" \
        "$( capture_has "METHOD	sendDocument" && echo 0 || echo 1 )"
fi

if describe "table: columns are aligned"; then
    start_case
    printf 'N,error\n64,1.2e-4\n1024,7.9e-8\n' | "$TG" table --title "Convergence" >/dev/null 2>&1
    body=$(field_value sendMessage text)
    if contains "$body" "   N   error" && contains "$body" "1024  7.9e-8"; then
        ok "table: columns are aligned"
    else
        bad "table: columns are aligned" "$body"
    fi
fi

if describe "table: quoted commas, Greek letters and numbers on the right"; then
    start_case
    printf 'topic,λ,count\n"waves, solitary",α,7\n"Euler, equations",βγ,123\n' > "$SANDBOX/t.csv"
    tg table "$SANDBOX/t.csv"
    body=$(field_value sendMessage text)
    if contains "$body" "waves, solitary   α       7" && contains "$body" "Euler, equations  βγ    123"; then
        ok "table: quoted commas, Greek letters and numbers on the right"
    else
        bad "table: quoted commas, Greek letters and numbers on the right" "$body"
    fi
fi

if describe "table: an empty table still sends its title"; then
    start_case
    : > "$SANDBOX/empty.csv"
    tg table "$SANDBOX/empty.csv" --title "Inbox"
    if [ "$RC" -eq 0 ] && contains "$(field_value sendMessage text)" "no rows"; then
        ok "table: an empty table still sends its title"
    else
        bad "table: an empty table still sends its title" "rc=$RC $(field_value sendMessage text)"
    fi
fi

if describe "table: a long table is not taken for an empty one"; then
    start_case
    awk 'BEGIN { print "N,error"; for (i = 1; i <= 20000; i++) printf "%d,%.6e\n", i, 1 / i }' > "$SANDBOX/long.csv"
    tg table "$SANDBOX/long.csv" --title "Convergence" --max-parts 1
    text=$(nth_field sendMessage 1 text)
    if [ "$RC" -eq 0 ] && ! contains "$text" "no rows" && contains "$text" "error"; then
        ok "table: a long table is not taken for an empty one"
    else
        bad "table: a long table is not taken for an empty one" "rc=$RC $(printf '%s' "$text" | head -n 3)"
    fi
fi

# --- run -------------------------------------------------------------------
if describe "run: the exit code passes through"; then
    start_case
    "$TG" run --label "failing step" -- sh -c 'exit 7' >/dev/null 2>&1
    RC=$?
    if [ "$RC" -eq 7 ] && contains "$(field_value sendMessage text)" "exit</b>: 7"; then
        ok "run: the exit code passes through"
    else
        bad "run: the exit code passes through" "rc=$RC body=$(field_value sendMessage text)"
    fi
fi

if describe "run: success is reported with a check mark"; then
    start_case
    "$TG" run --label "good step" -- sh -c 'echo fine' >/dev/null 2>&1
    RC=$?
    body=$(field_value sendMessage text)
    if [ "$RC" -eq 0 ] && contains "$body" "good step"; then
        ok "run: success is reported with a check mark"
    else
        bad "run: success is reported with a check mark" "rc=$RC body=$body"
    fi
fi

if describe "run: failure carries a tail of the output"; then
    start_case
    "$TG" run --tail 3 -- sh -c 'echo alpha; echo beta; echo gamma; exit 1' >/dev/null 2>&1
    body=$(field_value sendMessage text)
    check "run: failure carries a tail of the output" "$body" \
        "$( contains "$body" "gamma" && echo 0 || echo 1 )"
fi

if describe "run: --on success stays quiet after a failure"; then
    start_case
    "$TG" run --on success -- sh -c 'exit 3' >/dev/null 2>&1
    RC=$?
    if [ "$RC" -eq 3 ] && [ ! -f "$CAPTURE" ]; then
        ok "run: --on success stays quiet after a failure"
    else
        bad "run: --on success stays quiet after a failure" "rc=$RC capture=$( [ -f "$CAPTURE" ] && cat "$CAPTURE" || echo none)"
    fi
fi

# --- progress --------------------------------------------------------------
if describe "progress: start then update edits one message"; then
    start_case
    id=$("$TG" progress start "Training" 2>/dev/null)
    "$TG" progress update "epoch 5" --percent 25 >/dev/null 2>&1
    if [ "$id" = "4242" ] && capture_has "METHOD	editMessageText" &&
       [ "$(field_value editMessageText message_id)" = "4242" ] &&
       contains "$(field_value editMessageText text)" "25%"; then
        ok "progress: start then update edits one message"
    else
        bad "progress: start then update edits one message" "id=$id $(grep METHOD "$CAPTURE" | tr '\n' ' ')"
    fi
fi

# --- ask -------------------------------------------------------------------
# Questions read Telegram's updates and need jq or python3.
no_json_reader() { case " ${TG_PING_HIDE:-} " in *" jq "*) case " ${TG_PING_HIDE:-} " in *" python3 "*) return 0 ;; esac ;; esac; return 1; }

if describe "ask: without jq and python3 the refusal is clear"; then
    start_case
    TG_PING_HIDE="jq python3" "$TG" ask "Anyone?" -o yes --wait 1 > "$SANDBOX/out" 2>&1; rc=$?
    if [ "$rc" -eq 3 ] && grep -q "needs jq or python3" "$SANDBOX/out" && [ ! -f "$CAPTURE" ]; then
        ok "ask: without jq and python3 the refusal is clear"
    else
        bad "ask: without jq and python3 the refusal is clear" "rc=$rc $(cat "$SANDBOX/out")"
    fi
fi

if no_json_reader; then
    SKIP=$((SKIP + 14))
else

if describe "ask: a button press is returned on stdout"; then
    start_case
    export TGP_STUB_ASK=1
    answer=$("$TG" ask "Which basis?" -o Chebyshev -o Fourier --wait 10 2>/dev/null)
    RC=$?
    unset TGP_STUB_ASK
    if [ "$RC" -eq 0 ] && [ "$answer" = "Chebyshev" ]; then
        ok "ask: a button press is returned on stdout"
    else
        bad "ask: a button press is returned on stdout" "rc=$RC answer=$answer"
    fi
fi

if describe "ask: a deadline without an answer gives code 7"; then
    start_case
    mkdir -p "$SANDBOX/stubempty"
    printf '%s' '{"ok":true,"result":[]}' > "$SANDBOX/stubempty/getUpdates.response"
    export TGP_STUB_DIR="$SANDBOX/stubempty"
    "$TG" ask "Anyone?" -o yes --wait 1 >/dev/null 2>&1
    RC=$?
    unset TGP_STUB_DIR
    check "ask: a deadline without an answer gives code 7" "rc=$RC" "$( [ "$RC" -eq 7 ] && echo 0 || echo 1 )"
fi

if describe "ask: --default is printed when nobody answers"; then
    start_case
    mkdir -p "$SANDBOX/stubempty"
    printf '%s' '{"ok":true,"result":[]}' > "$SANDBOX/stubempty/getUpdates.response"
    export TGP_STUB_DIR="$SANDBOX/stubempty"
    answer=$("$TG" ask "Anyone?" -o yes --default no --wait 1 2>/dev/null)
    RC=$?
    unset TGP_STUB_DIR
    if [ "$RC" -eq 0 ] && [ "$answer" = "no" ]; then
        ok "ask: --default is printed when nobody answers"
    else
        bad "ask: --default is printed when nobody answers" "rc=$RC answer=$answer"
    fi
fi

# --- the shared inbox (B1) ---------------------------------------------------
CHAT_JSON='"chat":{"id":-1001234567890,"type":"private"}'

if describe "ask: a typed reply answers its question"; then
    start_case
    printf '%s\n' '{"message":{"message_id":5001,'"$CHAT_JSON"',"from":{"id":77},"date":{{now}},"text":"Fourier, since the domain is periodic","reply_to_message":{"message_id":{{mid:1}}}}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    answer=$("$TG" ask "Which basis?" -o Chebyshev -o Fourier --wait 10 2>/dev/null); RC=$?
    if [ "$RC" -eq 0 ] && [ "$answer" = "Fourier, since the domain is periodic" ] &&
       contains "$(methods)" "setMessageReaction" && contains "$(field_value editMessageText text)" "answered: Fourier"; then
        ok "ask: a typed reply answers its question"
    else
        bad "ask: a typed reply answers its question" "rc=$RC answer=$answer methods: $(methods)"
    fi
fi

if describe "ask: a message right after the question answers it"; then
    start_case
    printf '%s\n' '{"message":{"message_id":{{next:1}},'"$CHAT_JSON"',"from":{"id":77},"date":{{now}},"text":"go ahead"}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    answer=$("$TG" ask "Continue?" --wait 10 2>/dev/null); RC=$?
    check "ask: a message right after the question answers it" "rc=$RC answer=$answer" \
        "$( [ "$RC" -eq 0 ] && [ "$answer" = "go ahead" ] && echo 0 || echo 1 )"
fi

if describe "ask: a sticker is not an answer"; then
    start_case
    printf '%s\n' '{"message":{"message_id":5003,'"$CHAT_JSON"',"date":{{now}},"sticker":{"file_id":"x"},"reply_to_message":{"message_id":{{mid:1}}}}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    answer=$("$TG" ask "Ready?" -o yes --wait 2 --default "no answer" 2>/dev/null); RC=$?
    check "ask: a sticker is not an answer" "rc=$RC answer=$answer" \
        "$( [ "$RC" -eq 0 ] && [ "$answer" = "no answer" ] && echo 0 || echo 1 )"
fi

if describe "ask: --json prints the answer alone"; then
    start_case
    export TGP_STUB_ASK=1
    out=$("$TG" ask "Which basis?" -o Chebyshev -o Fourier --wait 10 --json 2>/dev/null)
    unset TGP_STUB_ASK
    check "ask: --json prints the answer alone" "$out" \
        "$( [ "$out" = '{"answer":"Chebyshev","kind":"button"}' ] && echo 0 || echo 1 )"
fi

if describe "ask: a dry run shows the question and stops"; then
    start_case
    out=$("$TG" ask "Deploy?" -o yes -o no --dry-run --default no 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && contains "$out" "sendMessage" && contains "$out" "no" && [ ! -f "$CAPTURE" ]; then
        ok "ask: a dry run shows the question and stops"
    else
        bad "ask: a dry run shows the question and stops" "rc=$rc $out"
    fi
fi

if describe "ask: a press on a closed question is answered"; then
    start_case
    "$TG" ask "First?" -o a -o b --wait 1 >/dev/null 2>&1
    printf '%s\n' '{"callback_query":{"id":"cb-old","from":{"id":77},"message":{"message_id":{{mid:1}},'"$CHAT_JSON"'},"data":"{{cb:1:0}}"}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    "$TG" ask "Second?" -o c --wait 2 --default none >/dev/null 2>&1
    if contains "$(field_value answerCallbackQuery text)" "This question has closed"; then
        ok "ask: a press on a closed question is answered"
    else
        bad "ask: a press on a closed question is answered" "methods: $(methods)"
    fi
fi

if describe "ask: another computer's press is left for it"; then
    start_case
    printf '%s\n' '{"callback_query":{"id":"cb-x","from":{"id":77},"message":{"message_id":1,'"$CHAT_JSON"'},"data":"a:zzz000000:0"}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    "$TG" ask "Mine?" -o yes --wait 2 --default no >/dev/null 2>&1
    offset=$(cat "$TG_PING_STATE_DIR"/bot.*/offset 2>/dev/null)
    if [ "$offset" = "101" ] && ls "$TG_PING_STATE_DIR"/bot.*/held/101 >/dev/null 2>&1 &&
       ! contains "$(methods)" "answerCallbackQuery"; then
        ok "ask: another computer's press is left for it"
    else
        bad "ask: another computer's press is left for it" "offset=$offset methods: $(methods)"
    fi
fi

if describe "ask: two questions at once each get their answer"; then
    start_case
    printf '%s\n' \
        '{"callback_query":{"id":"cb-1","from":{"id":77},"message":{"message_id":{{mid:1}},'"$CHAT_JSON"'},"data":"{{cb:1:1}}"}}' \
        '{"message":{"message_id":5004,'"$CHAT_JSON"',"from":{"id":77},"date":{{now}},"text":"typed for the second","reply_to_message":{"message_id":{{mid:2}}}}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    "$TG" ask "First?" -o x -o y --wait 20 > "$SANDBOX/a1" 2>/dev/null &
    p1=$!
    k=0; while [ "$(capture_count sendMessage)" -lt 1 ] && [ "$k" -lt 100 ]; do sleep 0.1; k=$((k + 1)); done
    "$TG" ask "Second?" --wait 20 > "$SANDBOX/a2" 2>/dev/null &
    p2=$!
    wait "$p1"; r1=$?; wait "$p2"; r2=$?
    if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$(cat "$SANDBOX/a1")" = "y" ] &&
       [ "$(cat "$SANDBOX/a2")" = "typed for the second" ]; then
        ok "ask: two questions at once each get their answer"
    else
        bad "ask: two questions at once each get their answer" "rc=$r1,$r2 a1=$(cat "$SANDBOX/a1") a2=$(cat "$SANDBOX/a2")"
    fi
fi

if describe "ask: two computers on one bot each get their answer"; then
    start_case
    printf '%s\n' \
        '{"callback_query":{"id":"cb-b","from":{"id":77},"message":{"message_id":{{mid:2}},'"$CHAT_JSON"'},"data":"{{cb:2:1}}"}}' \
        '{"callback_query":{"id":"cb-a","from":{"id":77},"message":{"message_id":{{mid:1}},'"$CHAT_JSON"'},"data":"{{cb:1:0}}"}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates" TGP_STUB_CONFLICT=1 TGP_STUB_SLOW=0.5
    mkdir -p "$SANDBOX/stateA" "$SANDBOX/stateB"
    TG_PING_STATE_DIR="$SANDBOX/stateA" TG_PING_MACHINE_ID=laptop \
        "$TG" ask "A?" -o x -o y --wait 40 > "$SANDBOX/a1" 2>/dev/null &
    p1=$!
    k=0; while [ "$(capture_count sendMessage)" -lt 1 ] && [ "$k" -lt 100 ]; do sleep 0.1; k=$((k + 1)); done
    TG_PING_STATE_DIR="$SANDBOX/stateB" TG_PING_MACHINE_ID=desktop \
        "$TG" ask "B?" -o p -o q --wait 40 > "$SANDBOX/a2" 2>/dev/null &
    p2=$!
    wait "$p1"; r1=$?; wait "$p2"; r2=$?
    unset TGP_STUB_CONFLICT TGP_STUB_SLOW
    if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$(cat "$SANDBOX/a1")" = "x" ] && [ "$(cat "$SANDBOX/a2")" = "q" ]; then
        ok "ask: two computers on one bot each get their answer"
    else
        bad "ask: two computers on one bot each get their answer" "rc=$r1,$r2 a1=$(cat "$SANDBOX/a1") a2=$(cat "$SANDBOX/a2")"
    fi
fi

if describe "poll: --wait returns the chosen option"; then
    start_case
    printf '%s\n' '{"poll_answer":{"poll_id":"{{poll:1}}","user":{"id":77},"option_ids":[1]}}' > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    answer=$("$TG" poll "Which figure?" -o spectrum -o residual --wait 10 2>/dev/null); RC=$?
    if [ "$RC" -eq 0 ] && [ "$answer" = "residual" ] &&
       contains "$(field_value sendPoll options)" '{"text":"spectrum"}'; then
        ok "poll: --wait returns the chosen option"
    else
        bad "poll: --wait returns the chosen option" "rc=$RC answer=$answer"
    fi
fi

if describe "chats: lists the chats and confirms nothing"; then
    start_case
    printf '%s\n' '{"message":{"message_id":7,'"$CHAT_JSON"',"from":{"id":77,"first_name":"Tester"},"date":{{now}},"text":"/start"}}' \
        > "$SANDBOX/updates"
    export TGP_STUB_UPDATES="$SANDBOX/updates"
    out=$("$TG" chats 2>&1)
    if contains "$out" "-1001234567890" && contains "$out" "private" && ! ls "$TG_PING_STATE_DIR"/bot.*/offset >/dev/null 2>&1; then
        ok "chats: lists the chats and confirms nothing"
    else
        bad "chats: lists the chats and confirms nothing" "$out"
    fi
fi

fi   # questions need a JSON reader

# --- configuration ---------------------------------------------------------
if describe "config: a profile file supplies the credentials"; then
    start_case
    mkdir -p "$XDG_CONFIG_HOME/tg-ping"
    printf 'TG_PING_TOKEN=111:profiletoken\nTG_PING_CHAT_ID=555\n' > "$XDG_CONFIG_HOME/tg-ping/work.env"
    ( env -u TG_PING_TOKEN -u TG_PING_CHAT_ID TGP_CAPTURE="$CAPTURE" "$TG" --profile work "hi" >/dev/null 2>&1 )
    check "config: a profile file supplies the credentials" "chat=$(field_value sendMessage chat_id)" \
        "$( [ "$(field_value sendMessage chat_id)" = "555" ] && echo 0 || echo 1 )"
fi

if describe "config: flags win over the environment"; then
    start_case
    tg --chat 999 "override"
    check "config: flags win over the environment" "chat=$(field_value sendMessage chat_id)" \
        "$( [ "$(field_value sendMessage chat_id)" = "999" ] && echo 0 || echo 1 )"
fi

# --- the command word and the options (A1) ----------------------------------
if describe "dispatch: an option before the command word"; then
    start_case
    printf 'PNG' > "$SANDBOX/fig.png"
    tg --caption "Spectrum" photo "$SANDBOX/fig.png"
    check "dispatch: an option before the command word" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendPhoto " ] && echo 0 || echo 1 )"
fi

if describe "dispatch: an option and its value before the command word"; then
    start_case
    tg --chat 555 --title "Formula" table "$SANDBOX/fig.png"
    check "dispatch: an option and its value before the command word" "chat=$(field_value sendMessage chat_id) $(field_value sendMessage text)" \
        "$( [ "$(field_value sendMessage chat_id)" = "555" ] && contains "$(field_value sendMessage text)" "<pre>" && echo 0 || echo 1 )"
fi

if describe "dispatch: -- and quotes keep a command word as text"; then
    start_case
    tg --ok -- math
    first=$(field_value sendMessage text)
    tg --ok "math is fun"
    second=$(field_value sendMessage text)
    if contains "$first" "math" && contains "$second" "math is fun" && [ "$(methods)" = "sendMessage sendMessage " ]; then
        ok "dispatch: -- and quotes keep a command word as text"
    else
        bad "dispatch: -- and quotes keep a command word as text" "$(methods) / $first / $second"
    fi
fi

if describe "usage: an option without its value"; then
    start_case
    tg "x" --title
    if [ "$RC" -eq 2 ] && contains "$OUTPUT" "--title needs a value" && [ ! -f "$CAPTURE" ]; then
        ok "usage: an option without its value"
    else
        bad "usage: an option without its value" "rc=$RC $OUTPUT"
    fi
fi

if describe "usage: every option with a value is listed"; then
    start_case
    # Options consumed with 'shift 2' in parse_common_args must be in VALUE_OPTS.
    listed=$(sed -n '/^VALUE_OPTS="/,/"$/p' "$TG" | tr '\n' ' ')
    missing=""
    for opt in $(sed -n '/^parse_common_args() {/,/^}/p' "$TG" | grep 'shift 2' |
                 sed -n 's/^[[:space:]]*\(-[-a-zA-Z|]*\)).*/\1/p' | tr '|' ' '); do
        case "$listed " in *" $opt "*) ;; *) missing="$missing $opt" ;; esac
    done
    check "usage: every option with a value is listed" "missing:$missing" "$( [ -z "$missing" ] && echo 0 || echo 1 )"
fi

if describe "completion: every option of the parser and of run is offered"; then
    start_case
    comp_bash=$("$TG" completion bash 2>&1)
    comp_zsh=$("$TG" completion zsh 2>&1)
    missing=""
    for opt in $( { sed -n '/^parse_common_args() {/,/^}/p' "$TG"; sed -n '/^cmd_run() {/,/^}/p' "$TG"; } |
                  sed -n 's/^[[:space:]]*\(--[-a-zA-Z|]*\)).*/\1/p' | tr '|' '\n' | grep -e '^--.' | sort -u); do
        case "$comp_bash" in *" $opt "*|*" $opt\""*|*"\"$opt "*) ;; *) missing="$missing $opt(bash)" ;; esac
        case "$comp_zsh" in *" $opt "*|*"($opt "*|*" $opt)"*) ;; *) missing="$missing $opt(zsh)" ;; esac
    done
    for c in pdf rich wait edit delete; do
        case "$comp_bash" in *" $c "*) ;; *) missing="$missing $c(bash)" ;; esac
        case "$comp_zsh" in *"'$c:"*) ;; *) missing="$missing $c(zsh)" ;; esac
    done
    check "completion: every option of the parser and of run is offered" "missing:$missing" "$( [ -z "$missing" ] && echo 0 || echo 1 )"
fi

if describe "completion: the files of the repository are the generated ones"; then
    start_case
    root=$(cd "$(dirname "$TG")/.." && pwd)
    if "$TG" completion bash | cmp -s - "$root/completions/tg-ping.bash" &&
       "$TG" completion zsh | cmp -s - "$root/completions/_tg-ping" &&
       bash -n "$root/completions/tg-ping.bash"; then
        ok "completion: the files of the repository are the generated ones"
    else
        bad "completion: the files of the repository are the generated ones" "run: bin/tg-ping completion bash > completions/tg-ping.bash; bin/tg-ping completion zsh > completions/_tg-ping"
    fi
fi

if describe "usage: a missing --code-file stops the call"; then
    start_case
    tg --code-file "$SANDBOX/does-not-exist" "x"
    if [ "$RC" -eq 2 ] && [ ! -f "$CAPTURE" ]; then
        ok "usage: a missing --code-file stops the call"
    else
        bad "usage: a missing --code-file stops the call" "rc=$RC"
    fi
fi

if describe "help: init, doctor, chats and config print help and run nothing"; then
    start_case
    bad_cmds=""
    for c in init doctor chats config completion; do
        out=$("$TG" "$c" --help 2>&1); rc=$?
        [ "$rc" -eq 0 ] && contains "$out" "$c" || bad_cmds="$bad_cmds $c"
    done
    if [ -z "$bad_cmds" ] && [ ! -f "$CAPTURE" ]; then
        ok "help: init, doctor, chats and config print help and run nothing"
    else
        bad "help: init, doctor, chats and config print help and run nothing" "failed:$bad_cmds calls: $(methods)"
    fi
fi

# --- keys and settings (A3) -------------------------------------------------
if describe "config: config show never prints the token"; then
    start_case
    out=$("$TG" config show 2>&1)
    if ! contains "$out" "AAFakeTokenForTestsOnly" && contains "$out" "number 123456789" &&
       contains "$out" "token from: the environment"; then
        ok "config: config show never prints the token"
    else
        bad "config: config show never prints the token" "$out"
    fi
fi

if describe "config: a settings file read from a pipe"; then
    start_case
    out=$(env -u TG_PING_CHAT_ID "$TG" --env-file <(printf 'TG_PING_CHAT_ID=321\nTG_PING_PREFIX=[x]\n') "piped settings" 2>&1)
    if [ "$(field_value sendMessage chat_id)" = "321" ] && contains "$(field_value sendMessage text)" "[x]"; then
        ok "config: a settings file read from a pipe"
    else
        bad "config: a settings file read from a pipe" "chat=$(field_value sendMessage chat_id) $out"
    fi
fi

if describe "config: quotes, comments and booleans in a settings file"; then
    start_case
    proj="$SANDBOX/proj-parse"; mkdir -p "$proj"
    printf 'TG_PING_PREFIX="[lab] #1"  # a comment\nTG_PING_THREAD_ID=7 # the topic\n' > "$proj/.tg-ping.env"
    ( cd "$proj" && env -u TG_PING_NO_DOTENV TGP_CAPTURE="$CAPTURE" "$TG" "parsed" >/dev/null 2>&1 )
    text=$(field_value sendMessage text); topic=$(field_value sendMessage message_thread_id)
    TG_PING_DISABLED=true "$TG" "must not go" >/dev/null 2>&1
    if contains "$text" "[lab] #1" && [ "$topic" = "7" ] && [ "$(methods)" = "sendMessage " ]; then
        ok "config: quotes, comments and booleans in a settings file"
    else
        bad "config: quotes, comments and booleans in a settings file" "text=$text topic=$topic $(methods)"
    fi
fi

# --- characters, captions and long messages (A4, A5, A8) -------------------
if describe "captions: 400 mathematical symbols stay whole"; then
    start_case
    printf 'PNG' > "$SANDBOX/fig.png"
    cap=$(printf '⩽%.0s' $(seq 1 400))
    tg photo "$SANDBOX/fig.png" --plain --caption "$cap"
    sent=$(field_value sendPhoto caption)
    if [ "$sent" = "$cap" ] && valid_utf8 "$sent" && [ "$(methods)" = "sendPhoto " ]; then
        ok "captions: 400 mathematical symbols stay whole"
    else
        bad "captions: 400 mathematical symbols stay whole" "methods: $(methods) length ${#sent}"
    fi
fi

if describe "captions: a long caption continues as a reply"; then
    start_case
    long=$(awk 'BEGIN{for(i=0;i<150;i++) printf "word%d ", i}')
    tg photo "$SANDBOX/fig.png" --title "Figure" --caption "$long"
    cap=$(field_value sendPhoto caption)
    reply=$(field_value sendMessage reply_parameters)
    if contains "$cap" "(continued below)" && contains "$reply" '"message_id":4242' &&
       contains "$(field_value sendMessage text)" "word149" && balanced_html "$cap"; then
        ok "captions: a long caption continues as a reply"
    else
        bad "captions: a long caption continues as a reply" "methods: $(methods) reply=$reply"
    fi
fi

if describe "split: a line of 2000 symbols fits one message"; then
    start_case
    tg --plain "$(printf '⩽%.0s' $(seq 1 2000))"
    check "split: a line of 2000 symbols fits one message" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendMessage " ] && valid_utf8 "$(field_value sendMessage text)" && echo 0 || echo 1 )"
fi

if describe "split: every part is valid, balanced and within the limit"; then
    start_case
    { printf '```python\n'; awk 'BEGIN{for(i=0;i<300;i++) printf "x_%d = solve(a[%d]) & check(b < %d)  # λ⩽μ\n", i, i, i}'
      printf '```\n**bold** '; awk 'BEGIN{for(i=0;i<700;i++) printf "word "}'; printf '\n'; } > "$SANDBOX/long.txt"
    "$TG" --title "Long" - < "$SANDBOX/long.txt" >/dev/null 2>&1
    n=$(grep -c '^METHOD	sendMessage' "$CAPTURE")
    problems=""
    k=1
    while [ "$k" -le "$n" ]; do
        part=$(nth_field sendMessage "$k" text)
        valid_utf8 "$part" || problems="$problems $k:utf8"
        balanced_html "$part" || problems="$problems $k:tags"
        # Telegram counts the characters left once tags and entities are read.
        [ "$(printf '%s' "$part" | sed -e 's/<[^>]*>//g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' \
             -e 's/&amp;/\&/g' | wc -m | tr -d ' ')" -le 4096 ] || problems="$problems $k:length"
        k=$((k + 1))
    done
    if [ "$n" -ge 2 ] && [ -z "$problems" ]; then
        ok "split: every part is valid, balanced and within the limit"
    else
        bad "split: every part is valid, balanced and within the limit" "parts=$n problems:$problems"
    fi
fi

if describe "split: beyond --max-parts the whole text follows as a file"; then
    start_case
    awk 'BEGIN{for(i=0;i<900;i++) printf "line %d of a very long log file\n", i}' > "$SANDBOX/log.txt"
    "$TG" --max-parts 2 --title "Log" - < "$SANDBOX/log.txt" >/dev/null 2>&1
    if [ "$(methods)" = "sendMessage sendDocument " ] &&
       contains "$(field_value sendDocument reply_parameters)" '"message_id":4242'; then
        ok "split: beyond --max-parts the whole text follows as a file"
    else
        bad "split: beyond --max-parts the whole text follows as a file" "methods: $(methods)"
    fi
fi

if describe "format: Python names and argument lists stay literal"; then
    start_case
    tg "call __init__ with f(*args, **kwargs) when a || b || c"
    text=$(field_value sendMessage text)
    if contains "$text" "__init__" && contains "$text" "f(*args, **kwargs)" && contains "$text" "a || b || c" &&
       ! contains "$text" "<u>" && ! contains "$text" "<b>" && ! contains "$text" "spoiler"; then
        ok "format: Python names and argument lists stay literal"
    else
        bad "format: Python names and argument lists stay literal" "$text"
    fi
fi

if describe "json: a colour code inside a button stays valid JSON"; then
    start_case
    tg --button "$(printf 'red\033[31m')=https://example.org" "x"
    kb=$(field_value sendMessage reply_markup)
    if contains "$kb" '\u001b' && ! contains "$kb" "$(printf '\033')"; then
        ok "json: a colour code inside a button stays valid JSON"
    else
        bad "json: a colour code inside a button stays valid JSON" "$kb"
    fi
fi

# --- media (A2, A6, C4, C5) --------------------------------------------------
if describe "media: file --as video sends a video"; then
    start_case
    printf 'MP4' > "$SANDBOX/anim.mp4"
    tg file "$SANDBOX/anim.mp4" --as video
    check "media: file --as video sends a video" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendVideo " ] && capture_has "UPLOAD	video=" && echo 0 || echo 1 )"
fi

if describe "media: photo sends a GIF as an animation and an MP4 as a video"; then
    start_case
    printf 'GIF' > "$SANDBOX/a.gif"
    tg photo "$SANDBOX/a.gif"
    tg photo "$SANDBOX/anim.mp4"
    check "media: photo sends a GIF as an animation and an MP4 as a video" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendAnimation sendVideo " ] && echo 0 || echo 1 )"
fi

if describe "media: eleven pictures go as albums of six and five"; then
    start_case
    files=""
    for i in 1 2 3 4 5 6 7 8 9 10 11; do printf 'P%s' "$i" > "$SANDBOX/p$i.png"; files="$files $SANDBOX/p$i.png"; done
    # shellcheck disable=SC2086  # the file names are words on purpose
    tg photo $files --caption "Sweep"
    a=$(nth_field sendMediaGroup 1 media | grep -o '"type"' | wc -l | tr -d ' ')
    b=$(nth_field sendMediaGroup 2 media | grep -o '"type"' | wc -l | tr -d ' ')
    if [ "$(methods)" = "sendMediaGroup sendMediaGroup " ] && [ "$a" = "6" ] && [ "$b" = "5" ]; then
        ok "media: eleven pictures go as albums of six and five"
    else
        bad "media: eleven pictures go as albums of six and five" "methods: $(methods) sizes $a $b"
    fi
fi

if describe "media: each picture of an album has its own line"; then
    start_case
    tg photo "$SANDBOX/p1.png" "$SANDBOX/p2.png" --caption "Two moments" --each "the start" --each "the break"
    media=$(field_value sendMediaGroup media)
    if contains "$media" 'Two moments\nthe start' && contains "$media" '"caption":"the break"'; then
        ok "media: each picture of an album has its own line"
    else
        bad "media: each picture of an album has its own line" "$media"
    fi
fi

if describe "media: a GIF among photos travels on its own"; then
    start_case
    tg photo "$SANDBOX/p1.png" "$SANDBOX/a.gif" "$SANDBOX/p2.png"
    check "media: a GIF among photos travels on its own" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendMediaGroup sendAnimation " ] && echo 0 || echo 1 )"
fi

if describe "media: a photo over 10 MB goes as a document"; then
    start_case
    if command -v truncate >/dev/null 2>&1; then
        truncate -s 11M "$SANDBOX/big.png"
        tg photo "$SANDBOX/big.png"
        rm -f "$SANDBOX/big.png"
        check "media: a photo over 10 MB goes as a document" "methods: $(methods)" \
            "$( [ "$(methods)" = "sendDocument " ] && echo 0 || echo 1 )"
    else
        SKIP=$((SKIP+1))
    fi
fi

if describe "media: a picture Telegram refuses as a photo goes as a document"; then
    start_case
    queue sendPhoto "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: PHOTO_INVALID_DIMENSIONS\"}"
    tg photo "$SANDBOX/fig.png" --caption "tall"
    if [ "$RC" -eq 0 ] && [ "$(methods)" = "sendPhoto sendDocument " ]; then
        ok "media: a picture Telegram refuses as a photo goes as a document"
    else
        bad "media: a picture Telegram refuses as a photo goes as a document" "rc=$RC methods: $(methods)"
    fi
fi

if describe "media: a caption with refused markup is resent as plain text"; then
    start_case
    queue sendPhoto "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: can't parse entities\"}"
    tg photo "$SANDBOX/fig.png" --html --caption "<b>broken"
    if [ "$RC" -eq 0 ] && [ "$(methods)" = "sendPhoto sendPhoto " ] &&
       [ -z "$(nth_field sendPhoto 2 parse_mode)" ] && [ "$(nth_field sendPhoto 2 caption)" = "broken" ]; then
        ok "media: a caption with refused markup is resent as plain text"
    else
        bad "media: a caption with refused markup is resent as plain text" "rc=$RC methods: $(methods)"
    fi
fi

if describe "media: --soft-fail covers pictures"; then
    start_case
    queue sendPhoto "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: chat not found\"}"
    tg photo "$SANDBOX/fig.png" --soft-fail
    check "media: --soft-fail covers pictures" "rc=$RC" "$( [ "$RC" -eq 0 ] && echo 0 || echo 1 )"
fi

if describe "media: --replace edits the picture of the same message"; then
    start_case
    printf 'PNG' > "$SANDBOX/fig.png"
    tg photo "$SANDBOX/fig.png" --replace --key conv --caption "step 1"
    tg photo "$SANDBOX/fig.png" --replace --key conv --caption "step 2"
    media=$(field_value editMessageMedia media)
    if [ "$(methods)" = "sendPhoto editMessageMedia " ] && [ "$(field_value editMessageMedia message_id)" = "4242" ] &&
       contains "$media" "step 2"; then
        ok "media: --replace edits the picture of the same message"
    else
        bad "media: --replace edits the picture of the same message" "methods: $(methods) media=$media"
    fi
fi

if describe "media: a PDF figure becomes a picture, with the original"; then
    start_case
    if command -v pdftoppm >/dev/null 2>&1 && command -v typst >/dev/null 2>&1; then
        printf '#set page(width: 4cm, height: 3cm)\n$ x^2 $\n' > "$SANDBOX/fig.typ"
        typst compile "$SANDBOX/fig.typ" "$SANDBOX/fig.pdf" >/dev/null 2>&1
        tg photo "$SANDBOX/fig.pdf" --original --caption "vector figure"
        if [ "$(methods)" = "sendPhoto sendDocument " ] && capture_has "fig.png" &&
           contains "$(field_value sendDocument reply_parameters)" '"message_id":4242'; then
            ok "media: a PDF figure becomes a picture, with the original"
        else
            bad "media: a PDF figure becomes a picture, with the original" "rc=$RC methods: $(methods) $OUTPUT"
        fi
    else
        SKIP=$((SKIP+1))
    fi
fi

# --- outcome of a delivery (A6, A10, A13) ------------------------------------
if describe "exit: a network failure gives code 4"; then
    start_case
    queue sendMessage "000	"
    tg --retries 0 "x"
    check "exit: a network failure gives code 4" "rc=$RC" "$( [ "$RC" -eq 4 ] && echo 0 || echo 1 )"
fi

if describe "exit: rate limiting gives code 6"; then
    start_case
    queue sendMessage "429	{\"ok\":false,\"error_code\":429,\"parameters\":{\"retry_after\":1}}"
    tg --retries 0 "x"
    check "exit: rate limiting gives code 6" "rc=$RC" "$( [ "$RC" -eq 6 ] && echo 0 || echo 1 )"
fi

if describe "cooldown: a failed alert may be tried again"; then
    start_case
    queue sendMessage "400	{\"ok\":false,\"description\":\"Bad Request: chat not found\"}"
    tg --cooldown 600 --key retry --no-fallback "alert"
    first=$RC
    tg --cooldown 600 --key retry "alert"
    if [ "$first" -eq 5 ] && [ "$RC" -eq 0 ] && [ "$(methods)" = "sendMessage sendMessage " ]; then
        ok "cooldown: a failed alert may be tried again"
    else
        bad "cooldown: a failed alert may be tried again" "rc=$first,$RC methods: $(methods)"
    fi
fi

if describe "cooldown: the time in a footer does not defeat it"; then
    start_case
    tg --cooldown 600 --meta "same alert"
    sleep 1
    tg --cooldown 600 --meta "same alert"
    check "cooldown: the time in a footer does not defeat it" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendMessage " ] && echo 0 || echo 1 )"
fi

if describe "telegram: current fields for previews and replies"; then
    start_case
    tg --reply-to 9 "x"
    if [ "$(field_value sendMessage link_preview_options)" = '{"is_disabled":true}' ] &&
       [ ! -f "$CAPTURE.d/sendMessage.disable_web_page_preview" ] &&
       [ ! -f "$CAPTURE.d/sendMessage.reply_to_message_id" ]; then
        ok "telegram: current fields for previews and replies"
    else
        bad "telegram: current fields for previews and replies" "$(cat "$CAPTURE")"
    fi
fi

if describe "telegram: a group upgraded to a supergroup is followed"; then
    start_case
    queue sendMessage "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: group chat was upgraded to a supergroup chat\",\"parameters\":{\"migrate_to_chat_id\":-1009998887776}}"
    tg "after the upgrade"
    if [ "$RC" -eq 0 ] && [ "$(nth_field sendMessage 2 chat_id)" = "-1009998887776" ] &&
       contains "$OUTPUT" "-1009998887776"; then
        ok "telegram: a group upgraded to a supergroup is followed"
    else
        bad "telegram: a group upgraded to a supergroup is followed" "rc=$RC methods: $(methods) $OUTPUT"
    fi
fi

# --- standard input (A12) ----------------------------------------------------
if describe "stdin: a file is read only when asked with -"; then
    start_case
    printf 'from the file\n' > "$SANDBOX/in.txt"
    "$TG" --title "T" < "$SANDBOX/in.txt" >/dev/null 2>&1
    first=$(field_value sendMessage text)
    "$TG" --title "T" - < "$SANDBOX/in.txt" >/dev/null 2>&1
    second=$(field_value sendMessage text)
    printf 'from a pipe\n' | "$TG" --title "T" --no-stdin >/dev/null 2>&1
    third=$(field_value sendMessage text)
    if ! contains "$first" "from the file" && contains "$second" "from the file" && ! contains "$third" "from a pipe"; then
        ok "stdin: a file is read only when asked with -"
    else
        bad "stdin: a file is read only when asked with -" "$first / $second / $third"
    fi
fi

# --- run (A9, D1) ------------------------------------------------------------
if describe "run: the command runs without any settings"; then
    start_case
    out=$(env -u TG_PING_TOKEN -u TG_PING_CHAT_ID "$TG" run -- sh -c 'echo it ran; exit 3' 2>&1); rc=$?
    if [ "$rc" -eq 3 ] && contains "$out" "it ran" && contains "$out" "without notifications"; then
        ok "run: the command runs without any settings"
    else
        bad "run: the command runs without any settings" "rc=$rc $out"
    fi
fi

if describe "run: a suppressed report keeps the exit code"; then
    start_case
    "$TG" run --cooldown 600 --key again -- sh -c 'exit 5' >/dev/null 2>&1
    "$TG" run --cooldown 600 --key again -- sh -c 'exit 5' >/dev/null 2>&1; rc=$?
    check "run: a suppressed report keeps the exit code" "rc=$rc methods: $(methods)" \
        "$( [ "$rc" -eq 5 ] && [ "$(methods)" = "sendMessage " ] && echo 0 || echo 1 )"
fi

if describe "run: options of the message before the command"; then
    start_case
    out=$("$TG" run --silent echo hi there 2>&1); rc=$?
    if [ "$rc" -eq 0 ] && contains "$out" "hi there" && [ "$(field_value sendMessage disable_notification)" = "true" ]; then
        ok "run: options of the message before the command"
    else
        bad "run: options of the message before the command" "rc=$rc $out"
    fi
fi

if describe "run: --every keeps a status message and reports anew"; then
    start_case
    "$TG" run --every 1s --label "short job" -- sh -c 'echo a; sleep 3; echo b' >/dev/null 2>&1; rc=$?
    m=$(methods)
    if [ "$rc" -eq 0 ] && [ "${m%% *}" = "sendMessage" ] && contains "$m" "editMessageText" &&
       [ "$(printf '%s' "$m" | awk '{print $NF}')" = "sendMessage" ] &&
       contains "$(field_value sendMessage reply_parameters)" '"message_id":4242'; then
        ok "run: --every keeps a status message and reports anew"
    else
        bad "run: --every keeps a status message and reports anew" "rc=$rc methods: $m"
    fi
fi

if describe "run: --stall warns once"; then
    start_case
    "$TG" run --stall 1s --label "quiet job" -- sh -c 'echo start; sleep 4; echo end' >/dev/null 2>&1
    n=$(grep -c 'is silent' "$CAPTURE")
    check "run: --stall warns once" "warnings=$n" "$( [ "$n" -eq 1 ] && echo 0 || echo 1 )"
fi

if describe "run: --limit stops the command"; then
    start_case
    "$TG" run --limit 2s -- sleep 30 >/dev/null 2>&1; rc=$?
    if [ "$rc" -ne 0 ] && capture_has "stopped at the time limit"; then
        ok "run: --limit stops the command"
    else
        bad "run: --limit stops the command" "rc=$rc"
    fi
fi

if describe "run: --attach-log sends the log of a failure"; then
    start_case
    "$TG" run --attach-log --label "broken step" -- sh -c 'echo first; echo second; exit 2' >/dev/null 2>&1
    if [ "$(methods)" = "sendMessage sendDocument " ] && capture_has "broken_step.log"; then
        ok "run: --attach-log sends the log of a failure"
    else
        bad "run: --attach-log sends the log of a failure" "methods: $(methods)"
    fi
fi

# --- progress (A15, B2, D2) ----------------------------------------------------
if describe "progress: fractional and counted percentages"; then
    start_case
    tg --percent 45.5 "a"
    first=$(field_value sendMessage text)
    tg --percent 37/512 "b"
    second=$(field_value sendMessage text)
    if contains "$first" "46%" && contains "$second" "37/512 · 7%"; then
        ok "progress: fractional and counted percentages"
    else
        bad "progress: fractional and counted percentages" "$first / $second"
    fi
fi

if describe "progress: an update with nothing to edit opens a message"; then
    start_case
    tg progress update "epoch 3" --percent 10
    check "progress: an update with nothing to edit opens a message" "methods: $(methods)" \
        "$( [ "$(methods)" = "sendMessage " ] && echo 0 || echo 1 )"
fi

if describe "progress: elapsed time, live end, and a final reply"; then
    start_case
    tg progress start "Training" --expected 1h
    sleep 1
    tg progress update "half way" --percent 50
    upd=$(field_value editMessageText text)
    tg progress "done" "converged"
    if contains "$upd" "running for" && contains "$upd" '<tg-time unix="' &&
       [ "$(methods)" = "sendMessage editMessageText editMessageText sendMessage " ] &&
       contains "$(nth_field sendMessage 2 text)" "against 1h 00m 00s expected" &&
       contains "$(nth_field sendMessage 2 reply_parameters)" '"message_id":4242'; then
        ok "progress: elapsed time, live end, and a final reply"
    else
        bad "progress: elapsed time, live end, and a final reply" "methods: $(methods) update=$upd"
    fi
fi

if describe "progress: two projects keep two messages"; then
    start_case
    mkdir -p "$SANDBOX/projA" "$SANDBOX/projB"
    ( cd "$SANDBOX/projA" && "$TG" progress start "A" >/dev/null 2>&1 )
    ( cd "$SANDBOX/projB" && "$TG" progress start "B" >/dev/null 2>&1 )
    n=0
    for f in "$TG_PING_STATE_DIR"/progress.*; do [ -f "$f" ] && n=$((n + 1)); done
    check "progress: two projects keep two messages" "slots=$n" "$( [ "$n" -eq 2 ] && echo 0 || echo 1 )"
fi

if describe "dry run: progress and init write nothing"; then
    start_case
    tg progress start "rehearsal" --dry-run
    printf '%s' "$TG_PING_TOKEN" > "$SANDBOX/token"
    tg init --dry-run --token-file "$SANDBOX/token" --chat 5 --profile rehearsal
    if [ -z "$(ls "$TG_PING_STATE_DIR")" ] && [ ! -f "$XDG_CONFIG_HOME/tg-ping/rehearsal.env" ]; then
        ok "dry run: progress and init write nothing"
    else
        bad "dry run: progress and init write nothing" "state: $(ls "$TG_PING_STATE_DIR") $OUTPUT"
    fi
fi

# --- levels, doctor, init (A15) ------------------------------------------------
if describe "levels: partial and blocked"; then
    start_case
    tg --partial "half done"
    first=$(field_value sendMessage text)
    tg --blocked "waiting for a decision"
    second=$(field_value sendMessage text)
    if contains "$first" "🟡" && contains "$second" "⛔"; then
        ok "levels: partial and blocked"
    else
        bad "levels: partial and blocked" "$first / $second"
    fi
fi

if describe "doctor: each chat is checked and nothing is sent"; then
    start_case
    out=$("$TG" doctor 2>&1)
    if contains "$(methods)" "getChat" && ! contains "$(methods)" "sendMessage" &&
       contains "$out" "reachable (nothing was sent)"; then
        ok "doctor: each chat is checked and nothing is sent"
    else
        bad "doctor: each chat is checked and nothing is sent" "methods: $(methods)"
    fi
fi

if describe "init: the other settings of the file stay"; then
    start_case
    mkdir -p "$XDG_CONFIG_HOME/tg-ping"
    printf 'TG_PING_TOKEN=1:old\nTG_PING_MATH_DPI=600\n' > "$XDG_CONFIG_HOME/tg-ping/keep.env"
    printf '%s' "$TG_PING_TOKEN" > "$SANDBOX/token"
    tg init --token-file "$SANDBOX/token" --chat 5 --profile keep
    file="$XDG_CONFIG_HOME/tg-ping/keep.env"
    if grep -q '^TG_PING_MATH_DPI=600$' "$file" && grep -q "^TG_PING_TOKEN=$TG_PING_TOKEN\$" "$file" &&
       ! grep -q '1:old' "$file" && [ -f "$file.bak" ]; then
        ok "init: the other settings of the file stay"
    else
        bad "init: the other settings of the file stay" "rc=$RC $(cat "$file") $OUTPUT"
    fi
fi

# --- rich messages and formulas (C1, C2) ---------------------------------------
if describe "rich: formulas, tables and fields become a rich message"; then
    start_case
    tg --rich --title "Energy" 'The energy $E(t)$ obeys
$$E(t) \leqslant E(0)$$

| N | error |
|--:|--:|
| 64 | 1.2e-4 |' --math 'x^2 + y^2 = r^2' --field "runs=512"
    rm_=$(field_value sendRichMessage rich_message)
    if [ "$(methods)" = "sendRichMessage " ] && contains "$rm_" '<tg-math>E(t)</tg-math>' &&
       contains "$rm_" '<tg-math-block>E(t) \\leqslant E(0)</tg-math-block>' &&
       contains "$rm_" '<table bordered striped compact>' && contains "$rm_" '<tg-math-block>x^2 + y^2 = r^2</tg-math-block>' &&
       contains "$rm_" '<td><b>runs</b></td><td>512</td>'; then
        ok "rich: formulas, tables and fields become a rich message"
    else
        bad "rich: formulas, tables and fields become a rich message" "methods: $(methods) $rm_"
    fi
fi

if describe "rich: dollars that are not formulas stay text"; then
    start_case
    tg --rich 'it costs $5 and $10, and \$x\$ is literal'
    rm_=$(field_value sendRichMessage rich_message)
    check "rich: dollars that are not formulas stay text" "$rm_" \
        "$( contains "$rm_" "tg-math" && echo 1 || echo 0 )"
fi

if describe "rich: a refused rich message goes out in the classic form"; then
    start_case
    queue sendRichMessage "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: rich messages are not supported\"}"
    tg --rich --title "Fallback" 'the bound $x \leqslant 1$' --math 'x \leqslant 1'
    first=$(methods)
    tg --rich "the next one"
    if [ "$first" = "sendRichMessage sendMessage " ] && [ "$(methods)" = "sendRichMessage sendMessage sendMessage " ] &&
       contains "$(nth_field sendMessage 1 text)" 'x \leqslant 1'; then
        ok "rich: a refused rich message goes out in the classic form"
    else
        bad "rich: a refused rich message goes out in the classic form" "methods: $first / $(methods)"
    fi
fi

if describe "rich: a Markdown report uploads its figures"; then
    start_case
    mkdir -p "$SANDBOX/report"
    printf 'PNG' > "$SANDBOX/report/fig.png"
    printf '# Results\n\nThe error falls like $h^2$:\n\n![Convergence](fig.png)\n' > "$SANDBOX/report/r.md"
    tg rich "$SANDBOX/report/r.md" --title "Report"
    rm_=$(field_value sendRichMessage rich_message)
    if [ "$(methods)" = "sendRichMessage " ] && contains "$rm_" '"markdown":' &&
       contains "$rm_" '![Convergence](tg://photo?id=m1)' && contains "$rm_" '"media":[{"id":"m1"' &&
       capture_has "UPLOAD	m1=$SANDBOX/report/fig.png"; then
        ok "rich: a Markdown report uploads its figures"
    else
        bad "rich: a Markdown report uploads its figures" "methods: $(methods) $rm_"
    fi
fi

if describe "rich: a refused report sends its text, then its figures"; then
    start_case
    queue sendRichMessage "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: unsupported\"}"
    tg rich "$SANDBOX/report/r.md"
    if [ "$(methods)" = "sendRichMessage sendMessage sendPhoto " ] &&
       contains "$(field_value sendPhoto reply_parameters)" '"message_id":4242'; then
        ok "rich: a refused report sends its text, then its figures"
    else
        bad "rich: a refused report sends its text, then its figures" "methods: $(methods)"
    fi
    rm -f "$TG_PING_STATE_DIR/rich.refused"
fi

if describe "rich: a rich progress message is edited as rich"; then
    start_case
    tg progress start "Training" --rich
    tg progress update "epoch 2" --percent 10
    if [ -f "$CAPTURE.d/editMessageText.rich_message" ] && [ ! -f "$CAPTURE.d/editMessageText.text" ]; then
        ok "rich: a rich progress message is edited as rich"
    else
        bad "rich: a rich progress message is edited as rich" "methods: $(methods)"
    fi
fi

if describe "table: in the rich format Telegram draws the table"; then
    start_case
    printf 'N,error\n64,1.2e-4\n' | "$TG" table --rich --title "Convergence" >/dev/null 2>&1
    check "table: in the rich format Telegram draws the table" "$(field_value sendRichMessage rich_message)" \
        "$( contains "$(field_value sendRichMessage rich_message)" '<th align=\"right\">N</th>' && echo 0 || echo 1 )"
fi

if describe "math: --native lets Telegram typeset the formula"; then
    start_case
    tg math '\lambda_1 = \pi^2/4' --native --caption "First eigenvalue"
    rm_=$(field_value sendRichMessage rich_message)
    if contains "$rm_" '<tg-math-block>\\lambda_1 = \\pi^2/4</tg-math-block>' && contains "$rm_" "First eigenvalue"; then
        ok "math: --native lets Telegram typeset the formula"
    else
        bad "math: --native lets Telegram typeset the formula" "$rm_"
    fi
fi

if describe "send: --math without a renderer sends the source"; then
    start_case
    TG_PING_HIDE="latex dvipng pdflatex typst" "$TG" --title "Bound" "it holds" --math 'x \leqslant 1' >/dev/null 2>&1
    check "send: --math without a renderer sends the source" "$(field_value sendMessage text)" \
        "$( contains "$(field_value sendMessage text)" '<pre><code class="language-latex">x \leqslant 1</code></pre>' && echo 0 || echo 1 )"
fi

if command -v latex >/dev/null 2>&1 && command -v dvipng >/dev/null 2>&1; then
    if describe "send: --math draws the formula, the text as its caption"; then
        start_case
        tg --title "Bound" "it holds" --math 'x \leqslant 1' --math 'y \geqslant 0'
        if [ "$(methods)" = "sendPhoto " ] && contains "$(field_value sendPhoto caption)" "<b>Bound</b>"; then
            ok "send: --math draws the formula, the text as its caption"
        else
            bad "send: --math draws the formula, the text as its caption" "rc=$RC methods: $(methods)"
        fi
    fi
    if describe "math: several lines, environments and prose are drawn"; then
        start_case
        failed=""
        "$TG" math --dry-run 'u_t + u_{xxx} = 0 \\ u(x,0) = u_0(x)' --out "$SANDBOX/m1.png" >/dev/null 2>&1 || failed="$failed lines"
        "$TG" math --dry-run 'a &= b \\ c &= d' --out "$SANDBOX/m2.png" >/dev/null 2>&1 || failed="$failed aligned"
        "$TG" math --dry-run '\begin{align*} a &= b \\ c &= d \end{align*}' --out "$SANDBOX/m3.png" >/dev/null 2>&1 || failed="$failed align"
        "$TG" math --dry-run --prose 'For every $t \geqslant 0$ the energy $E(t)$ is conserved.' --out "$SANDBOX/m4.png" >/dev/null 2>&1 || failed="$failed prose"
        printf '%s' 'x^2' > "$SANDBOX/f.tex"
        "$TG" math --dry-run --file "$SANDBOX/f.tex" --out "$SANDBOX/m5.png" >/dev/null 2>&1 || failed="$failed file"
        for k in 1 2 3 4 5; do [ -s "$SANDBOX/m$k.png" ] || failed="$failed png$k"; done
        check "math: several lines, environments and prose are drawn" "failed:$failed" "$( [ -z "$failed" ] && echo 0 || echo 1 )"
    fi
else
    SKIP=$((SKIP + 2))
fi

# --- pages of a PDF (C3) -----------------------------------------------------------
if command -v pdftoppm >/dev/null 2>&1 && command -v typst >/dev/null 2>&1; then
    printf '#set page(width: 6cm, height: 4cm)\nOne\n#pagebreak()\nTwo\n#pagebreak()\nThree\n' > "$SANDBOX/doc.typ"
    typst compile "$SANDBOX/doc.typ" "$SANDBOX/doc.pdf" >/dev/null 2>&1
    if describe "pdf: pages become an album, the PDF follows"; then
        start_case
        tg pdf "$SANDBOX/doc.pdf" --pages 1,3 --caption "Two pages" --attach
        media=$(field_value sendMediaGroup media)
        if [ "$(methods)" = "sendMediaGroup sendDocument " ] && contains "$media" "pages 1, 3 of 3" &&
           contains "$media" '"caption":"<i>page 3</i>"' &&
           contains "$(field_value sendDocument reply_parameters)" '"message_id":4242'; then
            ok "pdf: pages become an album, the PDF follows"
        else
            bad "pdf: pages become an album, the PDF follows" "rc=$RC methods: $(methods) $media $OUTPUT"
        fi
    fi
    if describe "pdf: a page beyond the document is refused"; then
        start_case
        tg pdf "$SANDBOX/doc.pdf" --pages 9
        check "pdf: a page beyond the document is refused" "rc=$RC" "$( [ "$RC" -eq 2 ] && [ ! -f "$CAPTURE" ] && echo 0 || echo 1 )"
    fi
else
    SKIP=$((SKIP + 2))
fi

# --- quiet hours and footer fields (D4, D5) ------------------------------------
if describe "quiet hours: silent at night, errors keep their sound"; then
    start_case
    h=$(( 10#$(date +%H) )); next=$(( (h + 1) % 24 ))
    TG_PING_QUIET_HOURS="$h-$next" "$TG" --ok "at night" >/dev/null 2>&1
    TG_PING_QUIET_HOURS="$h-$next" "$TG" --fail "an error at night" >/dev/null 2>&1
    TG_PING_QUIET_HOURS="$next-$next" "$TG" --ok "outside the quiet hours" >/dev/null 2>&1
    if [ "$(nth_field sendMessage 1 disable_notification)" = "true" ] &&
       [ -z "$(nth_field sendMessage 2 disable_notification)" ] &&
       [ -z "$(nth_field sendMessage 3 disable_notification)" ]; then
        ok "quiet hours: silent at night, errors keep their sound"
    else
        bad "quiet hours: silent at night, errors keep their sound" "$(cat "$CAPTURE")"
    fi
fi

if describe "delivery: the debug level is silent, written either way"; then
    start_case
    tg --debug "a detail"
    tg --level debug "another detail"
    tg --info "news"
    if [ "$(nth_field sendMessage 1 disable_notification)" = "true" ] &&
       [ "$(nth_field sendMessage 2 disable_notification)" = "true" ] &&
       [ -z "$(nth_field sendMessage 3 disable_notification)" ]; then
        ok "delivery: the debug level is silent, written either way"
    else
        bad "delivery: the debug level is silent, written either way" "$(cat "$CAPTURE")"
    fi
fi

if describe "meta: TG_PING_META chooses the footer fields"; then
    start_case
    TG_PING_META="time" "$TG" --meta "footer" >/dev/null 2>&1
    text=$(field_value sendMessage text)
    if contains "$text" "$(date '+%Y-%m-%d')" && ! contains "$text" "$(uname -n) ·"; then
        ok "meta: TG_PING_META chooses the footer fields"
    else
        bad "meta: TG_PING_META chooses the footer fields" "$text"
    fi
fi

# --- wait, topics, edit and delete (D3, E1, E2) ------------------------------------
if describe "wait: a message when a process ends"; then
    start_case
    sleep 2 &
    p=$!
    TG_PING_WAIT_TICK=1 "$TG" wait "$p" --label "the test sleep" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 0 ] && contains "$(field_value sendMessage text)" "the test sleep has ended"; then
        ok "wait: a message when a process ends"
    else
        bad "wait: a message when a process ends" "rc=$rc $(field_value sendMessage text)"
    fi
fi

if describe "wait: a process number is required"; then
    start_case
    tg wait for me
    check "wait: a process number is required" "rc=$RC" "$( [ "$RC" -eq 2 ] && [ ! -f "$CAPTURE" ] && echo 0 || echo 1 )"
fi

if describe "topics: each project gets its topic, made once"; then
    start_case
    mkdir -p "$SANDBOX/NLS-cavity"
    ( cd "$SANDBOX/NLS-cavity" && TG_PING_TOPICS=project TG_PING_MACHINE=laptop "$TG" "first" >/dev/null 2>&1 &&
      TG_PING_TOPICS=project TG_PING_MACHINE=laptop "$TG" "second" >/dev/null 2>&1 )
    if [ "$(methods)" = "createForumTopic sendMessage sendMessage " ] &&
       [ "$(field_value createForumTopic name)" = "NLS-cavity · laptop" ] &&
       [ "$(nth_field sendMessage 1 message_thread_id)" = "900" ] && [ "$(nth_field sendMessage 2 message_thread_id)" = "900" ]; then
        ok "topics: each project gets its topic, made once"
    else
        bad "topics: each project gets its topic, made once" "methods: $(methods) name=$(field_value createForumTopic name)"
    fi
fi

if describe "topics: a deleted topic is made again"; then
    start_case
    queue sendMessage "400	{\"ok\":false,\"error_code\":400,\"description\":\"Bad Request: message thread not found\"}"
    ( cd "$SANDBOX/NLS-cavity" && TG_PING_TOPICS=project "$TG" "after the topic was deleted" >/dev/null 2>&1 )
    if [ "$(methods)" = "createForumTopic sendMessage createForumTopic sendMessage " ] &&
       [ "$(nth_field sendMessage 2 message_thread_id)" = "901" ]; then
        ok "topics: a deleted topic is made again"
    else
        bad "topics: a deleted topic is made again" "methods: $(methods)"
    fi
fi

if describe "topics: when no topic works the message goes to the main chat"; then
    start_case
    lost='400	{"ok":false,"error_code":400,"description":"Bad Request: message thread not found"}'
    queue sendMessage "$lost" "$lost"
    ( cd "$SANDBOX/NLS-cavity" && TG_PING_TOPICS=project "$TG" "first" >/dev/null 2>&1 &&
      TG_PING_TOPICS=project "$TG" "second" >/dev/null 2>&1 ); rc=$?
    if [ "$rc" -eq 0 ] &&
       [ "$(methods)" = "createForumTopic sendMessage createForumTopic sendMessage sendMessage sendMessage " ] &&
       [ -z "$(nth_field sendMessage 3 message_thread_id)" ] && [ -z "$(nth_field sendMessage 4 message_thread_id)" ] &&
       [ "$(nth_field sendMessage 3 text)" = "first" ] && [ "$(nth_field sendMessage 4 text)" = "second" ]; then
        ok "topics: when no topic works the message goes to the main chat"
    else
        bad "topics: when no topic works the message goes to the main chat" "rc=$rc methods: $(methods)"
    fi
fi

if describe "topics: a bot without topic mode writes to the main chat"; then
    start_case
    queue createForumTopic '400	{"ok":false,"error_code":400,"description":"Bad Request: BOT_FORUM_CREATE_FORBIDDEN"}'
    ( cd "$SANDBOX/NLS-cavity" && TG_PING_TOPICS=project "$TG" "first" >/dev/null 2>&1 &&
      TG_PING_TOPICS=project "$TG" "second" >/dev/null 2>&1 ); rc=$?
    if [ "$rc" -eq 0 ] && [ "$(methods)" = "createForumTopic sendMessage sendMessage " ] &&
       [ -z "$(nth_field sendMessage 1 message_thread_id)" ] && [ -z "$(nth_field sendMessage 2 message_thread_id)" ]; then
        ok "topics: a bot without topic mode writes to the main chat"
    else
        bad "topics: a bot without topic mode writes to the main chat" "rc=$rc methods: $(methods)"
    fi
fi

if describe "edit and delete: --last reaches the last message"; then
    start_case
    tg "a message with a typo"
    tg edit --last "a message without the typo"
    tg delete --last
    if [ "$(methods)" = "sendMessage editMessageText deleteMessage " ] &&
       [ "$(field_value editMessageText message_id)" = "4242" ] &&
       [ "$(field_value editMessageText text)" = "a message without the typo" ] &&
       [ "$(field_value deleteMessage message_id)" = "4242" ]; then
        ok "edit and delete: --last reaches the last message"
    else
        bad "edit and delete: --last reaches the last message" "methods: $(methods)"
    fi
fi

if describe "edit: a message number is required"; then
    start_case
    tg edit the draft
    check "edit: a message number is required" "rc=$RC" "$( [ "$RC" -eq 2 ] && [ ! -f "$CAPTURE" ] && echo 0 || echo 1 )"
fi

# --- the machine on every message (E0) ---------------------------------------
if describe "machine: an unnamed machine shows nothing"; then
    start_case
    tg --ok --title "Done" "x"
    check "machine: an unnamed machine shows nothing" "$(field_value sendMessage text)" \
        "$( contains "$(field_value sendMessage text)" "💻" && echo 1 || echo 0 )"
fi

if describe "machine: a named laptop shows on the first line"; then
    start_case
    TG_PING_MACHINE=laptop "$TG" --ok --title "Tests green" "x" >/dev/null 2>&1
    text=$(field_value sendMessage text)
    TG_PING_MACHINE=laptop "$TG" --no-machine "hidden" >/dev/null 2>&1
    hidden=$(field_value sendMessage text)
    if contains "$text" "✅ 💻 laptop · <b>Tests green</b>" && [ "$hidden" = "hidden" ]; then
        ok "machine: a named laptop shows on the first line"
    else
        bad "machine: a named laptop shows on the first line" "$text / $hidden"
    fi
fi

if describe "machine: config set machine records the icon of a desktop"; then
    start_case
    printf '3\n' > "$TG_PING_DMI_DIR/chassis_type"
    "$TG" config set machine home desktop >/dev/null 2>&1
    printf '10\n' > "$TG_PING_DMI_DIR/chassis_type"
    file="$XDG_CONFIG_HOME/tg-ping/default.env"
    env -u TG_PING_MACHINE "$TG" "from the desktop" >/dev/null 2>&1
    if grep -q '^TG_PING_MACHINE="home desktop"$' "$file" && grep -q '^TG_PING_MACHINE_ICON=🖥️$' "$file" &&
       contains "$(field_value sendMessage text)" "🖥️ home desktop · from the desktop"; then
        ok "machine: config set machine records the icon of a desktop"
    else
        bad "machine: config set machine records the icon of a desktop" "$(cat "$file" 2>/dev/null) / $(field_value sendMessage text)"
    fi
    rm -f "$file"
fi

# --- help ------------------------------------------------------------------
if describe "help: --help documents every command"; then
    start_case
    OUTPUT=$("$TG" --help 2>&1)
    missing=""
    for word in send code table math photo file media run progress ask poll init doctor chats hook; do
        contains "$OUTPUT" "  $word" || missing="$missing $word"
    done
    check "help: --help documents every command" "missing:$missing" \
        "$( [ -z "$missing" ] && echo 0 || echo 1 )"
fi

if describe "help: exit codes are documented"; then
    start_case
    OUTPUT=$("$TG" --help 2>&1)
    check "help: exit codes are documented" "no exit code section" \
        "$( contains "$OUTPUT" "EXIT CODES" && echo 0 || echo 1 )"
fi

if describe "help: every subcommand answers --help"; then
    start_case
    missing=""
    for sub in send code table math photo file run progress ask poll; do
        out=$("$TG" help "$sub" 2>&1)
        contains "$out" "$sub" || missing="$missing $sub"
    done
    check "help: every subcommand answers --help" "missing:$missing" \
        "$( [ -z "$missing" ] && echo 0 || echo 1 )"
fi

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed' "$PASS" "$FAIL"
[ "$SKIP" -gt 0 ] && printf ', %d skipped' "$SKIP"
printf '\n'
if [ "$FAIL" -gt 0 ]; then
    printf 'failing cases:%s\n' "$FAILED_NAMES"
    exit 1
fi
exit 0
