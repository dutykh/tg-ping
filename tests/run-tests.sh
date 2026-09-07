#!/usr/bin/env bash
#
# Offline test suite for tg-ping. No network access and no Telegram account
# are needed: a stub curl records every request and answers with canned JSON.
#
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).
#
# Usage: tests/run-tests.sh [name-filter]

set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TG="$ROOT/bin/tg-ping"
FILTER="${1:-}"
PASS=0; FAIL=0; SKIP=0
FAILED_NAMES=""

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/tg-ping-tests.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT

export PATH="$ROOT/tests/stub:$PATH"
export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$SANDBOX/home/.config"
export TG_PING_STATE_DIR="$SANDBOX/state"
export TG_PING_NO_DOTENV=1
export TG_PING_TOKEN="123456789:AAFakeTokenForTestsOnly_abcdefghijklmn"
export TG_PING_CHAT_ID="-1001234567890"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$TG_PING_STATE_DIR"

CAPTURE=""
OUTPUT=""
RC=0

start_case() {
    CAPTURE="$SANDBOX/capture.$$"
    rm -rf "$CAPTURE" "$CAPTURE.d"
    export TGP_CAPTURE="$CAPTURE"
    unset TGP_STUB_SCRIPT TGP_STUB_HTTP TGP_STUB_DIR TGP_STUB_ASK 2>/dev/null || true
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

contains() { printf '%s' "$1" | grep -Fq -- "$2"; }

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
       [ "$(field_value sendMessage reply_to_message_id)" = "7" ]; then
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
    if contains "$body" "N     error" && contains "$body" "1024  7.9e-8"; then
        ok "table: columns are aligned"
    else
        bad "table: columns are aligned" "$body"
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
