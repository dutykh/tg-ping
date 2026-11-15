<!--
  README for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# tg-ping

Expressive Telegram notifications for terminals, coding agents and research
scripts. One Bash file, one dependency (`curl`), and your phone starts
receiving the things you actually want to know: a build finished, a simulation
diverged, a figure is ready, a decision is needed, and which of your computers
is saying so.

It was written so that an autonomous agent (Claude Code, Codex, or a plain
shell script running overnight) can keep a human informed without being given
any personal credentials. The agent talks to a dedicated bot; the bot talks
to you.

```bash
tg-ping --ok --title "Sweep finished" "512 runs, best error 1.4e-8" --meta
tg-ping --ok --title "Figure ready" "The spectrum is real." --photo figures/spectrum.pdf
tg-ping photo figures/convergence.pdf --caption "Second order confirmed"
tg-ping math '\lambda_1 = \pi^2/4' --caption "First eigenvalue of the operator"
tg-ping run --label "sweep" --every 30m --stall 20m --alert 'NaN|diverg' -- julia sweep.jl
answer=$(tg-ping ask "Which basis?" -o Chebyshev -o Fourier --wait 900)
file=$(tg-ping receive "Please send the referee's PDF" --wait 15m --out inbox/)
```

## Contents

* [What it can send](#what-it-can-send)
* [Installation on Ubuntu](#installation-on-ubuntu)
* [Creating the Telegram bot](#creating-the-telegram-bot)
* [Configuration](#configuration)
* [Which machine is speaking](#which-machine-is-speaking)
* [Which agent is speaking](#which-agent-is-speaking)
* [Which project is speaking](#which-project-is-speaking)
* [A topic per project](#a-topic-per-project)
* [Everyday use](#everyday-use)
* [Message anatomy](#message-anatomy)
* [Formatting, and why it never breaks](#formatting-and-why-it-never-breaks)
* [Rich messages](#rich-messages)
* [Mathematics](#mathematics)
* [Figures, pages and videos](#figures-pages-and-videos)
* [Long jobs](#long-jobs)
* [Asking the human a question](#asking-the-human-a-question)
* [Receiving a file from the phone](#receiving-a-file-from-the-phone)
* [Correcting a message](#correcting-a-message)
* [Using it from a coding agent](#using-it-from-a-coding-agent)
* [Exit codes](#exit-codes)
* [Security](#security)
* [Troubleshooting](#troubleshooting)
* [Development](#development)
* [How to cite](#how-to-cite)
* [License and author](#license-and-author)

## What it can send

| Command | What arrives on the phone |
| --- | --- |
| `tg-ping "text"` | a plain notification |
| `tg-ping --title "Done" "text" --math 'E \leqslant E_0'` | a message with its formula |
| `tg-ping code file.py` | a highlighted block, or a document when too long |
| `tg-ping table results.csv` | aligned columns, numbers on the right |
| `tg-ping math '\int_0^1 x^2\,dx'` | a typeset formula, as a picture |
| `tg-ping --title "Done" "text" --photo fig.pdf` | a message with its figure, the text as the caption, or the pictures as a reply |
| `tg-ping photo fig.pdf` | a picture (PDF, SVG and EPS figures are drawn first), or albums |
| `tg-ping pdf paper.pdf --pages 3,7-9` | pages of a PDF as pictures |
| `tg-ping file report.pdf` | any document up to 50 MiB; a larger video is re-encoded to fit |
| `tg-ping media clip.mp4 fig.png` | each file as what its extension says: a picture, an animation, a video, a sound or a document |
| `tg-ping rich report.md` | a Markdown report as one rich message, figures included |
| `tg-ping run --alert NaN -- make test` | a report card once the command finishes, and a warning at the first `NaN` |
| `tg-ping progress update ...` | one message, edited in place as work advances |
| `tg-ping wait 41532` | a message when a process started earlier ends |
| `tg-ping ask "Ship it?" -o yes -o no` | buttons, and the answer comes back on stdout |
| `tg-ping receive "Send me the PDF"` | a file sent from the phone, saved here, its path printed |
| `tg-ping poll "Which figure?" -o a -o b` | a native Telegram poll |
| `tg-ping edit --last "corrected text"` | the last message, corrected in place |

Everything is composable: titles, bullet lists, key and value fields, code
blocks, collapsible quotes, progress bars, formulas, pictures and documents,
link buttons, silent delivery, pinning, forum topics, the name of the
machine, and a footer carrying host, repository and time.

## Installation on Ubuntu

The only requirement is `curl`. Everything else is optional and adds one
ability, with a clear message when it is missing:

| Program | What it adds | Install on Ubuntu |
| --- | --- | --- |
| `jq`, or `python3` | questions, polls with `--wait`, `chats`, and `init` finding the chat | `sudo apt install -y jq` |
| LaTeX and `dvipng` | formulas as pictures | `sudo apt install -y texlive-latex-base texlive-latex-extra dvipng` |
| `typst` | formulas written in Typst | see the typst project |
| `pdftoppm` | PDF pages and PDF figures | `sudo apt install -y poppler-utils` |
| `inkscape` or ImageMagick | SVG and EPS figures | `sudo apt install -y inkscape` |
| `ffmpeg` | videos over 50 MiB, re-encoded to fit | `sudo apt install -y ffmpeg` |

```bash
sudo apt update
sudo apt install -y curl
sudo apt install -y jq          # optional, recommended
```

### From a clone, the recommended way

```bash
git clone https://github.com/dutykh/tg-ping.git
cd tg-ping
./install.sh                    # installs into ~/.local/bin, with completions
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

Piped into a shell, the installer always downloads the script itself, whatever
folder it runs from.

### System wide

```bash
sudo ./install.sh --prefix /usr/local
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

The command `tg-ping --version`, or `tg-ping version`, prints the version
installed.

Removal is `./install.sh --uninstall` (with the same `--prefix` if you gave
one), which leaves your configuration in place.

## Creating the Telegram bot

You never hand over your own Telegram account. You create a bot that can write
to you, and give its token to the machine.

1. Open Telegram and start a chat with `@BotFather`.
2. Send `/newbot`, choose a display name, then a username ending in `bot`.
3. Copy the token. It looks like `123456789:AAExampleTokenWithLettersAndDigits`.
4. Open the chat with your new bot and send it `/start`. A bot cannot write to
   somebody who has never written to it, so this step is required.
5. Run the setup wizard, which reads the token without echo, validates it,
   finds your chat id, asks what this machine should be called, and writes the
   configuration file:

```bash
tg-ping init
```

If you prefer to do it by hand, the chat id can be read with:

```bash
TG_PING_TOKEN=123456789:AAExample tg-ping chats
```

The guide [Setting up the Telegram side](docs/telegram-setup.md) covers groups,
channels, topics and several computers in more detail.

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
* **Topics with the bot itself**: see [A topic per project](#a-topic-per-project).

## Configuration

Settings are resolved in this order, and the first value found for each setting
wins:

```text
1. command line flags
2. environment variables            TG_PING_TOKEN, TG_PING_CHAT_ID, ...
3. --env-file FILE                  or $TG_PING_ENV_FILE
4. ./.tg-ping.env                   project local: a chat, a topic, a profile
5. ./.env.local                     only TG_PING_* keys
6. ./.env                           only TG_PING_* keys
7. ~/.config/tg-ping/<profile>.env  written by 'tg-ping init'
8. /etc/tg-ping/config              system wide
9. the older TELEGRAM_* names       environment, then files 3, 4, 7 and 8
```

Configuration files are parsed as `KEY=VALUE`. They are never sourced and never
evaluated, so a hostile file cannot execute anything: a value such as
`$(rm -rf /)` stays a harmless string and is rejected as a malformed chat id. A
value may be quoted (inside double quotes a backslash escapes a quote or a
backslash, which is how `config set` writes a value holding both kinds of
quotes), a comment starts at a blank followed by `#`, and a path written in
one of them may begin with `~/`, which is expanded.

### Where the credentials belong

Put them in `~/.config/tg-ping/default.env`, which is read from every
directory. An agent working in a different project then reaches you with no
further setup:

```bash
tg-ping init          # writes that file with mode 600
```

A file in the working folder may choose a chat, a topic or a profile, but it
never supplies the token nor `TG_PING_API`: a repository cloned from somebody
else must not be able to send your messages, token included, to another bot
or another server. A project that needs another bot names one of your profiles
instead, and the token stays in your own folder:

```bash
echo 'TG_PING_PROFILE=cluster' > .tg-ping.env
```

The files `./.env.local` and `./.env` are names shared with other tools, so
only the namespaced `TG_PING_*` keys are read from them: a `BOT_TOKEN` or a
`TELEGRAM_CHAT_ID` sitting in such a file belongs to another program and is
ignored. The older names `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are still
accepted from the environment and from your own files, below every
`TG_PING_*` setting.

### Every setting, not only the credentials

Anything below can live in a configuration file, in the environment, or on the
command line, in that increasing order of priority.

| Variable | Effect | Default |
| --- | --- | --- |
| `TG_PING_TOKEN` | bot token from `@BotFather`, never from the working folder | required |
| `TG_PING_CHAT_ID` | target chat, or a comma separated list of them | required |
| `TG_PING_MACHINE` | the name of this machine, shown on every message | none |
| `TG_PING_MACHINE_ICON` | its icon, recorded by `config set machine` | detected |
| `TG_PING_AGENT` | the agent named after the machine: `auto`, `off`, or a name of your own | `auto` |
| `TG_PING_PROJECT` | `on` to end every message with its project, or a name of your own | off |
| `TG_PING_TOPICS` | `project` for one topic per project and machine | off |
| `TG_PING_QUIET_HOURS` | hours without sound, such as `23-08` | none |
| `TG_PING_THREAD_ID` | forum topic inside a group | none |
| `TG_PING_PREFIX` | fixed label in front of every message | none |
| `TG_PING_META` | fields of the `--meta` footer: `host`, `repo`, `project`, `time` | `host,repo,time` |
| `TG_PING_FORMAT` | `auto`, `rich`, `plain`, `markdown` or `html` | `auto` |
| `TG_PING_TAIL` | log lines carried by a failed `run` | `20` |
| `TG_PING_MAX_PARTS` | parts a long message may be split into | `8` |
| `TG_PING_BAR_WIDTH` | width of the `--percent` bar | `12` |
| `TG_PING_TIMEOUT` | seconds allowed per request; uploads stop only when stalled | `20` |
| `TG_PING_RETRIES` | retries on network errors, 429 and 5xx | `3` |
| `TG_PING_MATH_DPI` | resolution of a rendered formula | `400` |
| `TG_PING_MATH_BG` | `white`, `transparent` or `dark` | `white` |
| `TG_PING_MATH_PREAMBLE` | your own macros, see [Mathematics](#mathematics) | none |
| `TG_PING_MATH_REMOTE` | allow the public renderer as a fallback | `0` |
| `TG_PING_SOFT_FAIL` | never fail because a notification failed | `0` |
| `TG_PING_DISABLED` | turn every call into a silent no-op | `0` |
| `TG_PING_NO_STDIN` | never read standard input unless asked with `-` | `0` |
| `TG_PING_API` | alternative Bot API server, never from the working folder | Telegram |
| `TG_PING_NO_DOTENV` | ignore the files of the working folder | `0` |
| `TG_PING_PROFILE` | which profile to use | `default` |

The switch `TG_PING_NO_DOTENV` decides whether the files of the working folder
are read at all, so it works from the environment only; `TG_PING_PROFILE` works
from the environment, from `--profile`, and from `./.tg-ping.env`.

### Seeing and changing the settings

The command `tg-ping config show` prints what was resolved and where each
credential came from, which settles any question about precedence. The token
itself is never shown, only the public number of the bot:

```text
profile   : default
config    : /home/you/.config/tg-ping/default.env
bot       : number 123456789 (the secret part of the token is never shown)
token from: /home/you/.config/tg-ping/default.env
chat id   : 987654321
chat from : /home/you/.config/tg-ping/default.env
machine   : 💻 laptop
agent     : Claude (detected)
topics    : off
quiet     : never
format    : auto
math      : 400 dpi, white background, remote never
footer    : host,repo,time
network   : 20s timeout, 3 retries
run tail  : 20 lines
```

One setting is changed in the profile file without opening it, and without
printing any secret:

```bash
tg-ping config set machine "home desktop"
tg-ping config set quiet-hours 23-08
tg-ping config unset prefix
tg-ping config files          # every file consulted, in order
```

Start from [`.env.example`](.env.example), which documents every variable:

```bash
cp .env.example ~/.config/tg-ping/default.env
chmod 600 ~/.config/tg-ping/default.env
```

### Several bots or chats

Profiles keep separate credentials side by side:

```bash
tg-ping init --profile work
tg-ping --profile work "the cluster job finished"
TG_PING_PROFILE=work tg-ping "same thing, through the environment"
```

One message can also go to several chats at once:

```bash
tg-ping --chat 123456789 --chat -1001234567890 "released version 2.3"
```

## Which machine is speaking

One bot can serve all your computers. Give each one a name, once, and every
message says where it comes from, on its first line, right after the level
emoji, so that the notification banner shows it:

```bash
tg-ping config set machine laptop            # on the laptop
tg-ping config set machine "office desktop"  # on the desktop at work
```

```text
✅ 💻 laptop · Tests green
❌ 🖥️ office desktop · Build broke
```

The icon follows the kind of machine, detected once when the name is set: 💻
for a laptop, 🖥️ for a desktop, 🌐 for a server or a virtual machine. The
detection reads the chassis type the firmware reports, then whether the system
runs virtualised, then whether there is a battery; `config set icon` overrides
it. A machine without a name shows nothing, `TG_PING_MACHINE=auto` shows the
icon and the host name, and `--no-machine` leaves the name out of one message.
Host names are a poor guide (two of your machines may share one), which is why
the name is chosen rather than read.

## Which agent is speaking

When several coding agents report through one bot, every message also says
which of them wrote it: the agent's name follows the machine on the first
line.

```text
✅ 🖥️ office desktop · Codex · Tests green
⚠️ 💻 laptop · Grok · Needs you
🚀 💻 laptop · Claude · Opening of the sweep
```

Nothing has to be configured, and the agent does not have to sign anything:
`tg-ping` looks at the programs above it and takes the nearest one that is a
coding agent. It knows Claude Code, Codex, Grok, OpenCode, Gemini CLI,
Antigravity, Cursor, Copilot, Aider, Amp, Goose, Qwen Code, Crush, Droid,
Augment and Kiro, by the name of the program or, for one written in Node or
Python, by the name of its script. On Linux the chain is read from `/proc`,
without starting any program; elsewhere `ps` lists it. The nearest agent
wins, so an agent started by another one is named for itself. Where the agent
cannot be seen, the marks agents leave in the environment of the commands they
run decide: inside the sandbox of Codex, whose own process namespace hides
every program outside it, and in a job that outlives the agent that started it
(a computation left running with `nohup`, say). The marks of the Codex sandbox
come first, then `AI_AGENT`, then `CLAUDECODE`, `CODEX_THREAD_ID`,
`GROK_SESSION_ID`, `OPENCODE`, `ANTIGRAVITY_CONVERSATION_ID` and `GEMINI_CLI`.
A command typed by hand, a cron job or a CI run names no agent, and its
messages look as before.

The setting `TG_PING_AGENT` changes this: `off` names no agent, any other value
is the name shown (`TG_PING_AGENT="Codex (review)"`), and `auto`, the default,
finds it. For one message, `--agent NAME` gives the name and `--no-agent`
leaves it out. The commands `tg-ping config show` and `tg-ping doctor` say which
agent `tg-ping` sees from where they run:

```bash
tg-ping config show | grep agent      # agent     : Codex (detected)
tg-ping config set agent off          # never name the agent on this machine
```

## Which project is speaking

Several agents may report from one machine at the same time, each from its
own folder. With `TG_PING_PROJECT=on`, every message ends with the project
it comes from: the folder inside its git repository (`📂 typst-vault/Proofs/Zipf`,
or `📂 tg-ping` at the root of one), or the folder relative to your home
outside any repository (`📂 ~/Dropbox/iPad`):

```bash
tg-ping config set project on
```

```text
✅ 🖥️ office desktop · Codex · Tests green
142 passed in 38 s

📂 typst-vault/Proofs/Zipf
```

A folder may choose its own name in its `./.tg-ping.env`
(`TG_PING_PROJECT="Zipf paper"`), the field `project` may also be listed in
`TG_PING_META` for the footer of `--meta`, and `--no-meta` leaves the footer
out of one message.

## A topic per project

Telegram can keep topics inside the private chat with a bot. With
`TG_PING_TOPICS=project`, every message goes to the topic of its project (the
git repository, else the folder) and of its machine, made by the bot the first
time:

```text
heat-equation · laptop
heat-equation · office desktop
referee-report · laptop
```

Switch it on once for the bot: in `@BotFather`, open the settings of your bot
and turn on **Threaded Mode**; then `tg-ping doctor` says whether Telegram
reports topic mode as on, and

```bash
tg-ping config set topics project
```

turns the topics on for this machine. A deleted topic is made again with the
next message. While topics cannot be used, messages go to the main chat, so
nothing is lost, and `doctor` says why. A message sent with its own `--topic`
keeps it.

## Everyday use

```bash
# a bare notification
tg-ping "Sweep finished, best error 1.4e-8"

# a titled milestone with a green check and a footer
tg-ping --ok --title "Tests green" "142 passed in 38 s" --meta

# a failure carrying the tail of a log
tg-ping --fail --title "Build broke" --code-file build.log --lang text

# anything on a pipe
make 2>&1 | tail -n 40 | tg-ping --title "make output" --code -

# a snippet, with the language taken from the file extension
tg-ping code solver.jl --title "current solver"
git diff | tg-ping code --lang diff --title "pending changes"

# a figure, an album with a caption per picture, a document, pages of a PDF
tg-ping photo figures/spectrum.pdf --caption "Spectrum of the linearised operator"
tg-ping photo t0.png t1.png t2.png --caption "Three moments" \
        --each "the initial pulse" --each "the reflection" --each "the final state"
tg-ping file report.pdf --caption "Draft ready, section 3 is new"
tg-ping pdf report.pdf --pages 3 --caption "The new section"

# structured results
tg-ping --title "Run 42" --field "runs=512" --field "best error=1.4e-8" \
        --item "mesh converged" --item "energy conserved to 1e-12"

# quietly, without a notification sound, and pinned for later
tg-ping --silent --pin --title "Nightly report" "everything nominal"
```

The command word may come before or after the options, so
`tg-ping --caption "Spectrum" photo fig.png` sends the photo. A text message
is the default command, `send`, whose word may be written or left out:
`tg-ping send "Tests green"` is `tg-ping "Tests green"`. After `--`,
every word is text: `tg-ping --ok -- math` sends the word "math". The
option `--dry-run` prints the request instead of sending it, which shows at a
glance whether a file goes as a photo, a video or a document.

The body is read from standard input when no text is given and the input is a
pipe, never from a file or a terminal; the argument `-` asks for it
explicitly, and `--no-stdin` forbids it, which suits a trap or a hook whose
input belongs to something else.

## Message anatomy

Every part is optional and they combine in a fixed order:

```text
 emoji  machine · agent · title      --level, --emoji, the machine, the agent, --title
 body text                           positional text, -m, or stdin
 formula                             --math, repeatable
 picture, document                   --photo FILE, --document FILE, repeatable
 ▰▰▰▱▱▱▱▱ 45%                        --percent
 • bullet                            --item, repeatable
 key: value                          --field "key=value", repeatable
 collapsible quotation               --quote, --collapse
 code block                          --code, --code-file, --lang
 host · repo@branch · timestamp      --meta, fields chosen by TG_PING_META
 📂 project                          every message, with TG_PING_PROJECT=on
 [ button ] [ button ]               --button "Label=https://url"
```

Levels choose the emoji: `start` 🚀, `info` ℹ️, `success` ✅, `warn` ⚠️,
`error` ❌, `question` ❓, `progress` ⏳, `debug` 🐛, `partial` 🟡 and
`blocked` ⛔. The shorthands `--start`, `--info`, `--ok`, `--warn`, `--fail`,
`--debug`, `--partial` and `--blocked` are equivalent to `--level`. Without a
level, nothing is prefixed and the message is sent exactly as written. The
debug level is delivered without sound.

The option `--percent` takes a percentage (`45` or `45.5`) or a count
(`37/512`, shown as "37/512 · 7%"). The footer of `--meta` shows the host, the
repository with its branch, and the time; `TG_PING_META=repo,time` leaves the
host out.

Quiet hours, set with `TG_PING_QUIET_HOURS=23-08`, deliver every message
without sound between those hours of the local clock, except errors,
questions and blocked work, which keep their sound.

## Formatting, and why it never breaks

Telegram rejects a whole message when its markup is malformed, which is exactly
what happens when a program writes `n_max`, `solve_x_1(n)` or `a*b*c` into a
Markdown message. The notification is then lost at the moment it mattered.

The default format, `--format auto`, avoids that. You write light Markdown,
and it emits Telegram HTML with `&`, `<` and `>` escaped correctly. Emphasis
needs a non-blank character inside each marker and applies only at word
boundaries, so `n_max`, `a*b*c`, `__init__` and `f(*args, **kwargs)` stay
literal, and markup inside code spans and fenced blocks is never touched. If
Telegram still refuses the markup, the message is resent once as literal plain
text, so it always arrives; captions of pictures and documents get the same
rescue.

Understood in `auto` mode:

```text
**bold**   *bold*   _italic_   __underline__   ~~strike~~   ||spoiler||
`code`     ```lang fenced blocks```     [label](url)
- bullets  > quotations  # headings
```

Other modes: `--plain` sends the characters exactly as given, `--markdown`
sends Telegram MarkdownV2 and `--html` sends Telegram HTML, both with escaping
left to you, and `--rich` sends a rich message (next section). The option
`--no-fallback` turns off the plain text rescue.

Long messages are split on line boundaries, counted in the units Telegram
counts, cut only between characters, and every tag open at a cut (a code
block, a quotation, a link) is closed and reopened, so each part is valid on
its own. The option `--truncate` keeps the first part only, and
`--max-parts N` caps the number of parts: beyond it, the first part is sent and
the whole text follows as an attached file. A caption longer than Telegram's
1,024 characters keeps its opening with "(continued below)", and the full text
follows as a reply to the picture.

## Rich messages

Telegram's rich messages hold headings, lists, tables, quotations and formulas
typeset by Telegram itself, up to 32,768 characters in one message. They are
opt-in: `--rich`, or `--format rich`, or `TG_PING_FORMAT=rich`. The default
stays the classic message with formulas drawn as pictures, which every client
shows the same way.

```bash
tg-ping --rich --title "Energy" 'The energy $E(t)$ obeys

$$E(t) \leqslant E(0)\,e^{-\gamma t}$$

for every time.'
```

Between single dollars a formula sits in the line, between double dollars it
is displayed, following Pandoc's rule: no blank just inside the delimiters and
no digit right after the closing one, so "it costs $5 and $10" stays text, and
`\$` is a literal dollar. In the rich format, `--math` and `table` produce
Telegram's own formulas and tables.

A whole report written in Markdown goes as one message, its local figures
uploaded with it (paths relative to the file, at most 50, PDF, SVG and EPS
figures drawn first):

```bash
tg-ping rich opening.md --start --title "The sweep begins"
```

When Telegram refuses a rich message (an older client, a server that does not
know the method), the classic message goes out instead, with formulas as their
LaTeX source and the figures as an album, and the refusal is remembered for a
day.

## Mathematics

Telegram cannot typeset a formula in a classic message, so a formula is
rendered to a picture and sent as a photo. Rendering happens on your own
machine.

```bash
tg-ping math '\nabla^2 u = f, \quad u|_{\partial\Omega} = 0'
tg-ping math '\lambda_1 = \pi^2/4' --caption "First eigenvalue" --dpi 600
tg-ping math 'u_t + 6 u u_x + u_{xxx} = 0 \\ u(x, 0) = u_0(x)'
tg-ping math --prose 'For every $t \geqslant 0$ the energy $E(t)$ is conserved.'
tg-ping math --typst 'integral_0^1 x^2 dif x = 1/3'
tg-ping math --file problem.tex --caption "The problem"
```

A formula with `\\` is set over several lines, aligned at `&` when it has one;
the environments that make their own display (`align`, `gather`, `multline`,
`equation`, `flalign`, starred or not) are kept as written, and the others
(`aligned`, `cases`, the matrices) are put in display math. The option
`--prose` typesets a sentence with its inline formulas, which is the natural
way to send an equation with its conditions, and `--file` reads the source
from a file.

Any message can carry formulas with `--math`, repeatable. A short text becomes
the caption of the picture, a longer one is sent first with the picture as a
reply, and in the rich format Telegram typesets the formula in the message
itself; with no renderer installed, the formula travels as its LaTeX source:

```bash
tg-ping --ok --title "Lemma closed" "The energy decays for every t ⩾ 0." \
        --math 'E(t) \leqslant E(0)\,e^{-\gamma t}'
```

The renderer is chosen automatically:

| Input | Toolchain | Install on Ubuntu |
| --- | --- | --- |
| LaTeX, the default | `latex` and `dvipng`, or `pdflatex` and `pdftoppm` | `sudo apt install -y texlive-latex-base texlive-latex-extra dvipng` |
| Typst, with `--typst` | `typst compile` | see the typst project |

Useful options: `--dpi N` (400 by default, which is legible on a phone),
`--bg white|transparent|dark`, `--inline` for inline style instead of display
style, `--out FILE` to keep the picture, `--native` to let Telegram typeset the
formula in a rich message, and `--preamble FILE` to load your own macros. The
command `tg-ping doctor --math` renders a test formula with each engine,
without sending anything.

### Your own macros

Point `TG_PING_MATH_PREAMBLE`, or `--preamble FILE`, at a file of definitions.
It is inserted after `amsmath`, `amssymb`, `amsfonts` and `mathtools`, so the
notation of your papers reaches your phone unchanged:

```tex
% ~/.config/tg-ping/macros.tex
\usepackage{bm}
\let\le\leqslant                        % the slanted relations
\let\ge\geqslant
\newcommand{\R}{\mathbb{R}}
\newcommand{\eps}{\varepsilon}
\DeclarePairedDelimiter{\norm}{\lVert}{\rVert}
\DeclareMathOperator{\supp}{supp}
```

```bash
tg-ping math '\norm{u - u_h} \le C \eps^2, \quad \supp u \subset \R^2'
```

The extension decides which engine reads the file, `.tex` for LaTeX and `.typ`
for typst. The other engine ignores it and says so, rather than typesetting
your preamble into the picture. A path that cannot be read raises a warning and
the formula is rendered without it.

If no local renderer is installed, `--remote` (or `TG_PING_MATH_REMOTE=1`)
renders through the public service at `latex.codecogs.com` instead. That sends
the formula to a third party, so it is never used unless you ask for it.

For simple notation, plain Unicode needs no rendering at all and stays
searchable in the chat: `∇²u = f`, `‖u‖ ⩽ Cε`, `α β γ Σ ∫ ∂ → ⇒`.

## Figures, pages and videos

The command `photo` sends one picture, or albums when several are given. A
figure saved as PDF (its first page), SVG or EPS is drawn at 300 dpi on white
before it goes, and `--original` also sends the file itself, since Telegram
recompresses photos. Up to ten files make one album and more make balanced
albums (eleven become six and five); the caption goes with the first picture
and each `--each` gives the next picture its own line. A photo over 10 MB, or
one Telegram refuses as a photo, goes as a document.

```bash
tg-ping photo figures/mesh.pdf figures/t0.pdf figures/t_final.pdf \
        --caption "Mesh and two moments" --each "the mesh" --each "t = 0" --each "t = 10"
```

A live figure is one picture kept up to date in the same message: the first
call sends it, and the next calls with the same key replace it.

```bash
tg-ping photo residual.png --key residual --replace --caption "after 400 iterations"
```

Any message can carry pictures and documents, with `--photo FILE` and
`--document FILE`, both repeatable: a short text becomes the caption of the
picture (or of the album), a longer one is sent first and the files follow
as its reply, and so do they when the message has buttons, which an album
cannot hold. A vector figure given to `--photo` is drawn first, `--each` gives
each file its own line, and a rich message embeds the files in the message
itself. The report of `run` and the message of `wait` take them too, so the
figure a computation produces can travel with its own report:

```bash
tg-ping --ok --title "Figure ready" "The spectrum is real." --photo figures/spectrum.pdf
tg-ping --title "Results" "512 runs" --photo errors.png --document results.csv
tg-ping run --label "solver" --photo figures/residual.png -- ./solve
```

The command `pdf` sends chosen pages of a document as pictures, drawn at 200
dpi, with the caption saying which pages of how many; `--attach` adds the PDF
itself:

```bash
tg-ping pdf paper.pdf --pages 1,7-8 --caption "The corrected section" --attach
```

Videos and animations go as what they are: `photo` sends a GIF as an
animation and an MP4 as a video, `file clip.mp4 --as video` does the same from
`file`, and `media` chooses from each extension. A video over Telegram's 50 MiB
is re-encoded with ffmpeg to fit, and measured again afterwards.

## Long jobs

The command `run` wraps a command, streams its output to your terminal as
usual, times it, and reports the outcome. The exit code of the wrapped command
is passed through, and the command runs whatever happens to the notifications:
missing settings, a disabled tool or a failed delivery never stop it nor change
its exit code. Ctrl-C still reaches the command, and an interruption is
reported as such.

```bash
tg-ping run --label "test suite" -- make test
tg-ping run --label "sweep" --every 30m --stall 20m --attach-log -- julia sweep.jl
tg-ping run --label "solver" --alert 'NaN|diverg' --photo figures/residual.png -- ./solve
tg-ping run --notify-start --tail 50 --limit 2h -- python train.py
tg-ping run --on failure -- ./nightly.sh          # only complain when it breaks
```

A failure arrives with the exit code, the elapsed time and the last lines of
the output. The option `--every 30m` keeps one status message, edited silently
with the time elapsed and the last lines of output, while the final report
arrives as a new message, since an edit never rings the phone. The option
`--stall 20m` warns once when the output has been silent that long, and
`--alert PATTERN` warns at the first line of the output matching the pattern
(an extended regular expression, repeatable, each pattern warning once), with
that line and the lines before it, so a solver that starts producing `NaN`
is caught at once rather than at the end of the night. The option
`--attach-log` sends the complete log on failure (`--attach-log-always` every
time, compressed when large); `--log FILE` keeps it, and `--photo FILE` sends
a figure with the report, one the command itself may have drawn (missing, it
is left out). The options `--tail N`, `--on always|success|failure|never`,
`--limit` and `--exit-zero` complete them; durations read `90s`, `15m`, `2h`
or `1h30m`. The common options work here too, so `--chat`, `--silent`,
`--topic` and the rest may appear before the `--` that introduces the
command.

For work that reports its own progress, `progress` keeps a single message up to
date instead of filling the chat:

```bash
tg-ping progress start "Training the network" --expected 2h
for epoch in $(seq 1 20); do
    train_one_epoch "$epoch"
    tg-ping progress update "epoch $epoch of 20" --percent "$epoch/20"
done
tg-ping progress done "converged, final loss 3.1e-4"
```

Each update shows the time elapsed and, with a percentage, the expected end,
counting down on the phone. The command `done` gives the duration against
`--expected` and, since an edit never rings the phone, also sends a short reply
(`--edit-only` skips it). The message belongs to the project (or to `--key`), so
two sessions in two projects never edit the same one, and an update refused for
its rate is skipped rather than waited for.

A computation started earlier without `tg-ping` can still be followed:

```bash
tg-ping wait 41532 --label "the cavity sweep" --log sweep.log
```

Shell scripts can report their own failures wherever they occur, and their
success at the end:

```bash
set -Eeuo pipefail
trap 'rc=$?; tg-ping --no-stdin --fail --title "$(basename "$0") failed" \
      --field "line=$LINENO" --field "exit=$rc" --meta' ERR
trap '[ $? -eq 0 ] && tg-ping --no-stdin --ok --title "$(basename "$0") finished" --meta' EXIT
```

The command `tg-ping hook bash` prints that snippet, and `tg-ping hook make`,
`tg-ping hook actions`, `tg-ping hook systemd` and `tg-ping hook python` print
the equivalent for other settings.

## Asking the human a question

An unattended agent sometimes needs a decision. The command `ask` puts the
question on your phone as tappable buttons, waits, and prints your answer on
stdout.

```bash
answer=$(tg-ping ask "Which basis should I use?" \
                 -o Chebyshev -o Fourier -o "stop and wait for me" --wait 900)
case "$answer" in
    Chebyshev) ./solve --basis cheb ;;
    Fourier)   ./solve --basis fourier ;;
    *)         echo "pausing until further notice" ;;
esac
```

A typed reply is accepted as well as a button, unless `--strict` is given: a
reply to the question, or the message that directly follows it. It is
acknowledged with a 👍, and the question shows its answer once given. With no
answer before the deadline the exit code is `7`, or `--default VALUE` is
printed and the exit code is `0`, which lets an agent proceed on a sensible
assumption when you are asleep. With `--json`, the answer comes as one JSON
document.

A question about figures carries them: with `--photo`, the pictures go first
as an album and the question answers them, so that the buttons sit right
under the question on the phone; formulas given with `--math` travel the same
way.

```bash
choice=$(tg-ping ask "Which figure goes in the paper?" \
                 --photo figures/a.pdf --photo figures/b.pdf -o left -o right --wait 900)
```

Several questions may wait at the same time, from several terminals and from
several computers sharing the bot, and each answer reaches its own question.
Telegram lets one reader at a time fetch a bot's messages, so the processes of
one machine share an inbox: one of them reads, and files every answer for the
question it belongs to. Between computers, each leaves the answers of the
others for them to collect. A webhook set on the same bot still stops
questions, and `tg-ping doctor` says so.

The command `poll` sends a native Telegram poll instead, which suits a group,
and `--wait SECONDS` blocks until somebody votes.

## Receiving a file from the phone

The conversation goes both ways. The command `receive` waits for a file sent
to the bot from the phone, a photo of a whiteboard, the PDF of a paper, a
voice note, saves it here and prints its path on stdout, alone, so that an
agent can ask for a document and open it:

```bash
file=$(tg-ping receive "Please send a photo of the whiteboard" --wait 15m --out inbox/)
tg-ping receive --kind document --out referee-report.pdf
```

With a prompt, the question goes out first (the reply field opens on the
phone) and the file that answers it, or that follows it, is taken; without
one, the next file of the chat is taken, or one sent in the last ten minutes
that no other question claimed, so a file sent a moment before the agent
started waiting is not lost. The option `--out` names the folder (the working
folder by default) or the file itself; a document keeps its own name, a photo
is named after its kind and the time, and nothing is ever overwritten. The
option `--kind photo|document|video|audio|voice` takes files of that kind
only, and a file of another kind is left for a question that wants it. The
received file is acknowledged with a 👍, the prompt records what arrived, and
with `--json` the path comes with the kind, the name, the caption and the
size. Without a file before the deadline the exit code is `7`. Telegram hands
over files of up to 20 MB this way; a larger one is best sent as a link.

## Correcting a message

A message already sent can be corrected or withdrawn, by its number (printed by
`--json` or `-v`) or with `--last`, the last message sent from the same project:

```bash
tg-ping edit --last "Sweep finished, best error 1.4e-9"
tg-ping delete --last
```

Telegram lets a bot delete its messages for 48 hours. The same memory serves
`--reply-to last`, which makes a message answer the last one this project
sent, so that a follow up stays with what it follows.

## Using it from a coding agent

The output of `tg-ping --help` is written to be read once by a model and used
correctly from then on: it lists every command, every option, the exit codes
and worked examples, and `tg-ping help COMMAND` details each command. The
command `tg-ping cheatsheet` prints a compact version for pasting into project
instructions.

Add the notification policy to your project instructions:

```bash
tg-ping hook claude >> CLAUDE.md      # for Claude Code
tg-ping hook codex  >> AGENTS.md      # for Codex and similar agents
tg-ping hook hooks                    # Claude Code hooks for .claude/settings.json
```

The generated section tells the agent to ping when a long task starts, when a
build or test run finishes or fails, when a figure or document is ready, when
it is blocked on a decision, and when the objective is complete, keeping each
message to one or two sentences; it also says that a question may carry its
figures and that `receive` fetches a file from the user. The guide
[Letting an agent report to you](docs/agent-integration.md) goes further.

Each message names the agent that sent it, after the machine, as
[Which agent is speaking](#which-agent-is-speaking) explains, so the agent
never needs to sign its messages, and the hooks of `tg-ping hook hooks` name
none in their titles: Grok runs the hooks of Claude Code as well, and each
message then says which of the two is waiting.

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
| `2` | bad usage, such as an unknown option, a missing value or a missing file |
| `3` | missing or invalid configuration |
| `4` | the network or the API was unreachable |
| `5` | Telegram refused the request |
| `6` | rate limited beyond the retry budget |
| `7` | no answer before the deadline, for `ask` and `poll --wait` |

The command `run` passes the exit code of the wrapped command through
unchanged, and `--soft-fail` turns codes 4 to 6 into `0`.

## Security

* **The token never appears in the process list.** Requests are handed to curl
  through a configuration file in a private temporary folder, deleted right
  after each request, so nothing sensitive shows up in `ps`. Pass credentials
  through the environment, a configuration file or `--token-file`, never
  through `--token` on a shared machine.
* **A cloned repository cannot take your messages.** A file of the working
  folder never supplies the token nor the server address, and the generic
  `./.env` and `./.env.local` are read for `TG_PING_*` keys only.
* **Configuration files are parsed, not executed.** No `source`, no `eval`.
* **The token is never printed.** The command `config show` gives the bot's
  public number only; verbose logs, error messages and `--dry-run` replace
  anything token shaped with a marker.
* **Secrets stay out of git.** The `.gitignore` covers `.env`, `.env.local`,
  `.tg-ping.env` and `*.env`; `tg-ping init` writes its file with mode 600 and
  `tg-ping doctor` complains if the permissions are loose.
* **A bot only reaches people who wrote to it first**, and it can be revoked at
  any moment with `/revoke` in `@BotFather`. If a token leaks, revoke it: the
  old one stops working immediately.
* **Treat a chat as public.** Anything sent to a group is visible to everyone in
  it, and Telegram stores it. The option `--protect` prevents forwarding and
  saving, which is a courtesy, not a guarantee. Do not send credentials or
  private data.

## Troubleshooting

Run `tg-ping doctor` first: it checks the programs used, the configuration file
and its permissions, where the token and the chat come from, the reachability
of the API, each chat (nothing is sent), a webhook that would stop questions,
the topic mode, and your `PATH`. Add `--send` to also deliver a test message,
or `--math` to render a test formula.

| Symptom | Cause and remedy |
| --- | --- |
| `chat not found` | The bot has never met that chat. Send it `/start`, then run `tg-ping chats`. For a channel the bot must be an administrator. |
| `Unauthorized` | The token is wrong or was revoked. Ask `@BotFather` for the current one and run `tg-ping init` again. |
| `bot was blocked by the user` | Unblock the bot in Telegram and send `/start` again. |
| Nothing listed by `tg-ping chats` | Telegram only keeps unread updates for 24 hours. Send a fresh message, and make sure no webhook is set on the bot. |
| `a webhook is set for this bot` | Another program receives the bot's messages. Remove the webhook (`deleteWebhook`) or give that program another bot. |
| A message with markup never arrives | It should not happen: the plain text fallback catches it. If you passed `--no-fallback`, remove it, or use `--plain`. |
| Group messages are ignored | Telegram privacy mode. Address the bot directly, or disable privacy through `@BotFather`. |
| A setting in a file has no effect | Run `tg-ping config show` to see what was resolved and from where. An environment variable or a flag beats the file, and a token or `TG_PING_API` in a file of the working folder is ignored by design. |
| Messages go to the main chat instead of the project topic | Topic mode is off for the bot, or Telegram refused the topic. Turn on Threaded Mode in `@BotFather`; `tg-ping doctor` shows the state. |
| The machine name is missing | Name the machine: `tg-ping config set machine NAME`. |
| A script hangs or loses its input | The body is read from a pipe when no text is given. Add `--no-stdin`, or set `TG_PING_NO_STDIN=1`. |
| Formulas render without my macros | The preamble extension must match the engine, `.tex` for LaTeX and `.typ` for typst, and the path must be readable. Both cases warn on stderr. |
| `receive` gets nothing | The file must go to the chat the bot uses, as a photo or a document, and Telegram hands over files of up to 20 MB only. A webhook set on the bot stops `receive` as it stops `ask`. |
| `tg-ping: command not found` | `~/.local/bin` is not on your `PATH`. See [Installation on Ubuntu](#installation-on-ubuntu). |

## Development

The test suite runs entirely offline: a stub `curl` earlier on `PATH` records
each request and answers with canned Telegram JSON. No token and no network are
involved.

```bash
tests/run-tests.sh                         # everything
tests/run-tests.sh format                  # only the cases whose name matches
TG_PING_AWK=mawk tests/run-tests.sh        # under another awk
TG_PING_HIDE="jq python3" tests/run-tests.sh
shellcheck -x bin/tg-ping install.sh tests/run-tests.sh tests/stub/curl
```

The 175 cases cover the settings and their scopes, the safety of the parser
against a hostile file, the command word found after options, escaping and
emphasis, the splitting of long messages and captions in every awk, the
fallbacks of markup, captions, rich messages and topics, media of every kind,
the pictures and documents of a message, retries and exit codes, two
questions waiting at once on one machine and on two, the files received from
the phone, the supervision and the alerts of `run`, the progress slots, the
names of the machine, the agent and the project, the completions and the help
pages. The stub can replay a queue of answers for
each method, a conflict between two readers, slow replies and the refusals
Telegram really sends. Please add a case with any change in behaviour.

Every measure and cut of a text is made in awk under the C locale, counting
bytes; `TG_PING_AWK` chooses the awk, and without it the first awk on `PATH`
that counts bytes is used. `TG_PING_HIDE` hides programs from the tool, so the
fallbacks can be tested, and `TG_PING_STATE_DIR` moves the folder where
progress slots, topics and the inbox of questions are kept.

Portability: the tool targets Bash 3.2 and newer, so it also runs on a stock
macOS shell, with the BSD tools. Please keep to that (no associative arrays,
no `mapfile`, empty arrays guarded under `set -u`) and keep `curl` the only
hard requirement. The completions are generated by `tg-ping completion bash`
and `tg-ping completion zsh` from the lists of options in the script; see
[CONTRIBUTING](CONTRIBUTING.md).

## How to cite

A research text that relied on `tg-ping` can cite the program itself. The
file [`CITATION.cff`](CITATION.cff) describes it, and GitHub turns it into a
reference, in APA or BibTeX, through the "Cite this repository" button of the
repository page.

## License and author

Distributed under the GNU Lesser General Public License, version 2.1 or later.
See [LICENSE](LICENSE).

Written by Dr. Denys Dutykh, Mathematics Department, Khalifa University of
Science and Technology, Abu Dhabi, United Arab Emirates.
