<!--
  README for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# tg-ping

Expressive Telegram notifications for terminals, coding agents and research
scripts. One Bash file, one dependency (`curl`), and your phone starts
receiving the things you actually want to know: a build finished, a simulation
diverged, a figure is ready, a decision is needed.

It was written so that an autonomous agent (Claude Code, Codex, or a plain
shell script running overnight) can keep a human informed without being given
any personal credentials. The agent talks to a dedicated bot; the bot talks
to you.

```bash
tg-ping --ok --title "Sweep finished" "512 runs, best error 1.4e-8" --meta
tg-ping photo figures/convergence.png --caption "Second order confirmed"
tg-ping math '\lambda_1 = \pi^2/4' --caption "First eigenvalue of the operator"
answer=$(tg-ping ask "Which basis?" -o Chebyshev -o Fourier --wait 900)
```

## Contents

* [What it can send](#what-it-can-send)
* [Installation on Ubuntu](#installation-on-ubuntu)
* [Creating the Telegram bot](#creating-the-telegram-bot)
* [Configuration](#configuration)
* [Everyday use](#everyday-use)
* [Message anatomy](#message-anatomy)
* [Formatting, and why it never breaks](#formatting-and-why-it-never-breaks)
* [Mathematics](#mathematics)
* [Long jobs](#long-jobs)
* [Asking the human a question](#asking-the-human-a-question)
* [Using it from a coding agent](#using-it-from-a-coding-agent)
* [Exit codes](#exit-codes)
* [Security](#security)
* [Troubleshooting](#troubleshooting)
* [Development](#development)
* [License and author](#license-and-author)

## What it can send

| Command | What arrives on the phone |
| --- | --- |
| `tg-ping "text"` | a plain notification |
| `tg-ping code file.py` | a syntax highlighted block, or a document when too long |
| `tg-ping table results.csv` | aligned columns in a monospace block |
| `tg-ping math '\int_0^1 x^2\,dx'` | a typeset formula, rendered as an image |
| `tg-ping photo fig.png` | an image, or an album when several are given |
| `tg-ping file report.pdf` | any document up to 50 MiB |
| `tg-ping run -- make test` | a report card once the command finishes |
| `tg-ping progress update ...` | one message, edited in place as work advances |
| `tg-ping ask "Ship it?" -o yes -o no` | buttons, and the answer comes back on stdout |
| `tg-ping poll "Which figure?" -o a -o b` | a native Telegram poll |

Everything is composable: titles, bullet lists, key and value fields, code
blocks, collapsible quotes, progress bars, link buttons, silent delivery,
pinning, forum topics, and a footer carrying host, repository and branch.

## Installation on Ubuntu

`curl` is the only requirement. `jq` is optional and makes the commands that
read incoming updates (`ask`, `poll --wait`, `chats`) a little faster; without
it, `python3` is used instead.

```bash
sudo apt update
sudo apt install -y curl
sudo apt install -y jq          # optional, recommended
```

### From a clone, the recommended way

```bash
git clone https://github.com/dutykh/tg-ping.git
cd tg-ping
./install.sh                    # installs into ~/.local/bin
```

### With one command

Read the script before piping anything into a shell. If you would rather
check it first:

```bash
curl -fsSL https://raw.githubusercontent.com/dutykh/tg-ping/main/install.sh -o install.sh
less install.sh
bash install.sh
```

The direct form, once you trust the source:

```bash
curl -fsSL https://raw.githubusercontent.com/dutykh/tg-ping/main/install.sh | bash
```

### System wide

```bash
sudo install -m 0755 bin/tg-ping /usr/local/bin/tg-ping
```

### Making sure the command is found

Ubuntu adds `~/.local/bin` to `PATH` at login, but only if that directory
already existed when you logged in. If `tg-ping` is not found:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then confirm the installation:

```bash
tg-ping doctor
```

Removal is `./install.sh --uninstall`, which leaves your configuration in
place.

## Creating the Telegram bot

You never hand over your own Telegram account. You create a bot that can write
to you, and give its token to the machine.

1. Open Telegram and start a chat with `@BotFather`.
2. Send `/newbot`, choose a display name, then a username ending in `bot`.
3. Copy the token. It looks like `123456789:AAExampleTokenWithLettersAndDigits`.
4. Open the chat with your new bot and send it `/start`. A bot cannot write to
   somebody who has never written to it, so this step is required.
5. Run the setup wizard, which validates the token, finds your chat id and
   writes the configuration file:

```bash
tg-ping init
```

If you prefer to do it by hand, the chat id can be read with:

```bash
TG_PING_TOKEN=123456789:AAExample tg-ping chats
```

### Groups, channels and topics

* **Group**: add the bot to the group and post one message. Group ids are
  negative, for example `-987654321`, and supergroups look like
  `-1001234567890`. Telegram privacy mode hides ordinary group messages from
  bots; either address the bot directly or turn privacy off through
  `@BotFather` with `/setprivacy`.
* **Channel**: add the bot as an administrator with permission to post. Use the
  numeric id, or `@channel_name` for a public channel.
* **Forum topic**: pass `--topic ID`, or set `TG_PING_THREAD_ID`, to keep each
  project in its own thread of the same group.

## Configuration

Settings are resolved in this order, and the first value found for each setting
wins:

```text
1. command line flags
2. environment variables            TG_PING_TOKEN, TG_PING_CHAT_ID
3. --env-file FILE                  or $TG_PING_ENV_FILE
4. ./.tg-ping.env                   project local, read in full
5. ./.env.local                     only TG_PING_* and TELEGRAM_* keys
6. ./.env                           only TG_PING_* and TELEGRAM_* keys
7. ~/.config/tg-ping/<profile>.env  written by 'tg-ping init'
8. /etc/tg-ping/config              system wide
```

Configuration files are parsed as `KEY=VALUE`. They are never sourced and never
evaluated, so a hostile file cannot execute anything: a value such as
`$(rm -rf /)` stays a harmless string and is rejected as a malformed chat id.

Start from [`.env.example`](.env.example), which documents every variable:

```bash
cp .env.example .tg-ping.env
chmod 600 .tg-ping.env
```

### Several bots or chats

Profiles keep separate credentials side by side:

```bash
tg-ping --profile work init
tg-ping --profile work "the cluster job finished"
TG_PING_PROFILE=work tg-ping "same thing, through the environment"
```

One message can also go to several chats at once:

```bash
tg-ping --chat 123456789 --chat -1001234567890 "released version 2.3"
```

## Everyday use

```bash
# a bare notification
tg-ping "Sweep finished, best error 1.4e-8"

# a titled milestone with a green check and a footer
tg-ping --ok --title "Tests green" "142 passed in 38 s" --meta

# a failure carrying the tail of a log
tg-ping --fail --title "Build broke" --code-file build.log --lang text

# anything on a pipe
make 2>&1 | tg-ping --title "make output" --code -

# a figure, an album, a document
tg-ping photo figures/spectrum.png --caption "Spectrum of the linearised operator"
tg-ping photo fig1.png fig2.png fig3.png --caption "Parameter sweep"
tg-ping file report.pdf --caption "Draft ready, section 3 is new"

# structured results
tg-ping --title "Run 42" --field "runs=512" --field "best error=1.4e-8" \
        --item "mesh converged" --item "energy conserved to 1e-12"

# quietly, without a notification sound, and pinned for later
tg-ping --silent --pin --title "Nightly report" "everything nominal"
```

## Message anatomy

Every part is optional and they combine in a fixed order:

```text
 emoji  bold title                   --level, --emoji, --title
 body text                           positional text, -m, or stdin
 ▰▰▰▰▱▱▱▱ 45%                        --percent
 • bullet                            --item, repeatable
 key: value                          --field "key=value", repeatable
 collapsible quotation               --quote, --collapse
 code block                          --code, --code-file, --lang
 host · repo@branch · timestamp      --meta
 [ button ] [ button ]               --button "Label=https://url"
```

Levels choose the emoji: `start` 🚀, `info` ℹ️, `success` ✅, `warn` ⚠️,
`error` ❌, `question` ❓, `progress` ⏳, `debug` 🐛. The shorthands
`--start`, `--info`, `--ok`, `--warn`, `--fail` and `--debug` are equivalent to
`--level`. Without a level, nothing is prefixed and the message is sent exactly
as written.

## Formatting, and why it never breaks

Telegram rejects a whole message when its markup is malformed, which is exactly
what happens when a program writes `n_max`, `solve_x_1(n)` or `a*b*c` into a
Markdown message. The notification is then lost at the moment it mattered.

`tg-ping` defaults to `--format auto`, which behaves like this:

* you write light Markdown;
* it emits Telegram HTML with `&`, `<` and `>` escaped correctly;
* emphasis is only applied at word boundaries, so `n_max` and `a*b*c` stay
  literal;
* markup inside code spans and fenced blocks is never touched;
* if Telegram still refuses the markup, the message is resent once as literal
  plain text, so it always arrives.

Understood in `auto` mode:

```text
**bold**   *bold*   _italic_   __underline__   ~~strike~~   ||spoiler||
`code`     ```lang fenced blocks```     [label](url)
- bullets  > quotations  # headings
```

Other modes: `--plain` sends the characters exactly as given, `--markdown`
sends Telegram MarkdownV2 and `--html` sends Telegram HTML, both with escaping
left to you. `--no-fallback` turns off the plain text rescue.

Long messages are split on line boundaries, and a code block that straddles a
split is closed and reopened so that each part is valid on its own.
`--truncate` cuts instead, and `--max-parts N` caps the number of parts.

## Mathematics

Telegram cannot typeset, so a formula is rendered to an image and sent as a
photo. Rendering happens on your own machine.

```bash
tg-ping math '\nabla^2 u = f, \quad u|_{\partial\Omega} = 0'
tg-ping math '\lambda_1 = \pi^2/4' --caption "First eigenvalue" --dpi 600
tg-ping math --typst 'integral_0^1 x^2 dif x = 1/3'
tg-ping math '\hat{u}(k)' --out formula.png --as document
```

The renderer is chosen automatically:

| Input | Toolchain | Install on Ubuntu |
| --- | --- | --- |
| LaTeX, the default | `latex` and `dvipng`, or `pdflatex` and `pdftoppm` | `sudo apt install -y texlive-latex-base texlive-latex-extra dvipng` |
| Typst, with `--typst` | `typst compile` | see the typst project |

Useful options: `--dpi N` (400 by default, which is legible on a phone),
`--bg white|transparent|dark`, `--inline` for inline style instead of display
style, `--out FILE` to keep the image, and `--preamble FILE` to load your own
macros, so the notation of your papers reaches your phone unchanged.

If no local renderer is installed, `--remote` (or `TG_PING_MATH_REMOTE=1`)
falls back to the public service at `latex.codecogs.com`. That sends the
formula to a third party, so it is never used unless you ask for it.

For simple notation, plain Unicode needs no rendering at all and stays
searchable in the chat: `∇²u = f`, `‖u‖ ⩽ Cε`, `α β γ Σ ∫ ∂ → ⇒`.

## Long jobs

`run` wraps a command, streams its output to your terminal as usual, times it,
and reports the outcome. The exit code of the wrapped command is passed
through, so a build step keeps its meaning.

```bash
tg-ping run --label "test suite" -- make test
tg-ping run --notify-start --tail 50 --limit 3600 -- python train.py
tg-ping run --on failure -- ./nightly.sh          # only complain when it breaks
```

A failure arrives with the exit code, the elapsed time and the last lines of
the output. `--tail N` sets how many, `--on` takes `always`, `success`,
`failure` or `never`, `--limit SECONDS` applies a deadline, and `--exit-zero`
keeps a failing command from failing your script.

For work that reports its own progress, `progress` keeps a single message up to
date instead of filling the chat:

```bash
tg-ping progress start "Training the network"
for epoch in $(seq 1 20); do
    train_one_epoch "$epoch"
    tg-ping progress update "epoch $epoch of 20" --percent $(( epoch * 5 ))
done
tg-ping progress done "converged, final loss 3.1e-4"
```

Shell scripts can report their own failures wherever they occur:

```bash
set -Eeuo pipefail
trap 'tg-ping --fail --title "$(basename "$0") failed" --field "line=$LINENO" --meta' ERR
```

`tg-ping hook bash` prints that snippet, and `tg-ping hook make`,
`tg-ping hook actions`, `tg-ping hook systemd` and `tg-ping hook python` print
the equivalent for other settings.

## Asking the human a question

An unattended agent sometimes needs a decision. `ask` puts the question on your
phone as tappable buttons, waits, and prints your answer on stdout.

```bash
answer=$(tg-ping ask "Which basis should I use?" \
                 -o Chebyshev -o Fourier -o "stop and wait for me" --wait 900)
case "$answer" in
    Chebyshev) ./solve --basis cheb ;;
    Fourier)   ./solve --basis fourier ;;
    *)         echo "pausing until further notice" ;;
esac
```

A typed reply is accepted as well as a button, unless `--strict` is given. With
no answer before the deadline the exit code is `7`, or `--default VALUE` is
printed and the exit code is `0`, which lets an agent proceed on a sensible
assumption when you are asleep.

`poll` sends a native Telegram poll instead, which suits a group, and
`--wait SECONDS` blocks until somebody votes.

Only one process may read a bot's updates at a time. `ask`, `poll --wait`,
`chats` and any webhook on the same bot therefore cannot run concurrently. Use
a second bot through `--profile` if two things must listen at once.

## Using it from a coding agent

`tg-ping --help` is written to be read once by a model and used correctly from
then on: it lists every command, every option, the exit codes and worked
examples. `tg-ping cheatsheet` prints a compact version for pasting into
project instructions.

Add the notification policy to your project instructions:

```bash
tg-ping hook claude >> CLAUDE.md      # for Claude Code
tg-ping hook codex  >> AGENTS.md      # for Codex and similar agents
tg-ping hook hooks                    # Claude Code hooks for .claude/settings.json
```

The generated section tells the agent to ping when a long task starts, when a
build or test run finishes or fails, when a figure or document is ready, when
it is blocked on a decision, and when the objective is complete, keeping each
message to one or two sentences.

Two options exist for the agent's own safety: `--cooldown SECONDS` drops
repeats of the same alert, which protects your phone from a looping agent, and
`--soft-fail` makes a delivery failure exit `0` so a notification never breaks
a pipeline. `TG_PING_DISABLED=1` turns every call into a silent no-op, which is
what you want inside test suites and continuous integration.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | delivered, or deliberately suppressed |
| `1` | generic failure |
| `2` | bad usage, such as an unknown option or a missing file |
| `3` | missing or invalid configuration |
| `4` | the network or the API was unreachable |
| `5` | Telegram refused the request |
| `6` | rate limited beyond the retry budget |
| `7` | no answer before the deadline, for `ask` and `poll --wait` |

`run` passes the exit code of the wrapped command through unchanged.

## Security

* **The token never appears in the process list.** Requests are handed to curl
  through a configuration file on standard input, so nothing sensitive shows up
  in `ps`. Pass credentials through the environment, a configuration file or
  `--token-file`, never through `--token` on a shared machine.
* **Configuration files are parsed, not executed.** No `source`, no `eval`.
* **Secrets stay out of git.** `.gitignore` covers `.env` and `*.env`;
  `tg-ping init` writes its file with mode 600 and `tg-ping doctor` complains
  if the permissions are loose.
* **Output is redacted.** Verbose logs, error messages and `--dry-run` replace
  anything token shaped with a marker.
* **A bot only reaches people who wrote to it first**, and it can be revoked at
  any moment with `/revoke` in `@BotFather`. If a token leaks, revoke it: the
  old one stops working immediately.
* **Treat a chat as public.** Anything sent to a group is visible to everyone in
  it, and Telegram stores it. `--protect` prevents forwarding and saving, which
  is a courtesy, not a guarantee. Do not send credentials or private data.

## Troubleshooting

Run `tg-ping doctor` first: it checks curl, the configuration file and its
permissions, the shape of the token, the reachability of the API, the chat id
and your `PATH`. Add `--send` to also deliver a test message.

| Symptom | Cause and remedy |
| --- | --- |
| `chat not found` | The bot has never met that chat. Send it `/start`, then run `tg-ping chats`. For a channel the bot must be an administrator. |
| `Unauthorized` | The token is wrong or was revoked. Ask `@BotFather` for the current one. |
| `bot was blocked by the user` | Unblock the bot in Telegram and send `/start` again. |
| Nothing listed by `tg-ping chats` | Telegram only keeps unread updates for 24 hours, and only one reader at a time. Send a fresh message and make sure no other poller or webhook is running. |
| `another process is already reading this bot's updates` | Stop the other `ask`, `poll --wait` or webhook, or use a second bot through `--profile`. |
| A message with markup never arrives | It should not happen: the plain text fallback catches it. If you passed `--no-fallback`, remove it, or use `--plain`. |
| Group messages are ignored | Telegram privacy mode. Address the bot directly, or disable privacy through `@BotFather`. |
| `tg-ping: command not found` | `~/.local/bin` is not on your `PATH`. See [Installation on Ubuntu](#installation-on-ubuntu). |

## Development

The test suite runs entirely offline: a stub `curl` earlier on `PATH` records
each request and answers with canned Telegram JSON. No token and no network are
involved.

```bash
tests/run-tests.sh                 # everything
tests/run-tests.sh format          # only the cases whose name matches
shellcheck -x bin/tg-ping install.sh tests/run-tests.sh
```

It covers configuration precedence, the safety of the `.env` parser, HTML
escaping, message splitting, retries on 429, the plain text fallback, media
uploads, exit codes, the two-way `ask` flow and the help output. Please add a
case with any change in behaviour.

Portability: the tool targets Bash 3.2 and newer, so it also runs on a stock
macOS shell. Please keep to that (no associative arrays, no `mapfile`) and keep
`curl` the only hard requirement.

## License and author

Distributed under the GNU Lesser General Public License, version 2.1 or later.
See [LICENSE](LICENSE).

Written by Dr. Denys Dutykh, Mathematics Department, Khalifa University of
Science and Technology, Abu Dhabi, United Arab Emirates.
