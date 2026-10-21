<!--
  Changelog for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# Changelog

This project follows semantic versioning.

## 2.0.0

The second version makes delivery dependable before it adds anything: no
message is lost to an option in the wrong place, a long caption, a refused
markup or a network hiccup, and no answer reaches the wrong question when
several sessions or several computers share one bot. On that ground it adds
the name of the machine on every message, a topic per project, formulas typeset
by Telegram itself, figures and PDF pages, supervision of long computations,
and the correction of messages already sent. Several defaults change, listed
first.

### Changes in behaviour

* The files of the working folder (`./.tg-ping.env`, `./.env.local`, `./.env`)
  never supply the token nor `TG_PING_API`, which could otherwise send every
  request, token included, to another server. A project that needs another bot
  names one of your profiles with `TG_PING_PROFILE` in its `./.tg-ping.env`.
* The older names `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` rank below every
  `TG_PING_*` setting, and `./.env` and `./.env.local` no longer supply them,
  since projects keep their own bots under these names.
* A command word written after options is found: `tg-ping --caption X photo
  fig.png` sends the photo, where it used to send the words "photo fig.png".
  After `--` a word is text again.
* Standard input is read without being asked only from a pipe, never from a
  file or a terminal, so a script running under cron or a loop reading its
  own input is not swallowed. The argument `-` reads it explicitly, and
  `--no-stdin` (or `TG_PING_NO_STDIN=1`) forbids it.
* The command `config show` prints the bot's public number, never any part of
  the secret, and says where the token and the chat come from.
* An option given without its value stops with exit code 2 and a clear
  message; `init`, `doctor`, `chats`, `config` and `completion` print their
  help with `--help` instead of running.
* Exit codes 4 (network) and 6 (rate limited) reach the caller; every failure
  used to come back as 5. The option `--soft-fail` is honoured by every
  command, media and formulas included.
* With `TG_PING_DISABLED=1` nothing is needed, not even settings. The command
  `run` always runs its command, whatever happens to the notifications, and a
  suppressed notification never turns a failure into success.
* The progress message without `--key` belongs to the project (the top of the
  git repository, else the working folder), so two sessions in two projects no
  longer edit the same message.
* The command `ask` no longer marks pending messages as read before asking. A
  typed answer is one that replies to the question or directly follows it, and
  `ask --json` prints one JSON document.
* Emphasis needs a non-blank character inside each marker, so `__init__`,
  `f(*args, **kwargs)` and `a || b || c` stay as written.
* Durations read `90s`, `15m`, `2h` or `1h30m` wherever they are asked for;
  plain seconds still work.
* Dry runs write nothing: no settings, no progress slot, no cooldown.

### Repairs

* Media: `--as` is honoured by `photo` and `file`, so `file clip.mp4 --as video`
  sends a video; a GIF given to `photo` goes as an animation and an MP4 as a
  video; a video over 50 MiB is re-encoded with ffmpeg to fit; a photo over
  10 MB goes as a document; more than ten files go as balanced albums; uploads
  stop only when they stall, instead of after a fixed 20 seconds.
* Captions are measured in characters, not bytes. A caption over 1,024
  characters keeps its opening with "(continued below)" and the full text
  follows as a reply; a caption Telegram refuses is resent as plain text.
* Long messages are split in the units Telegram counts, at character
  boundaries, with every open tag closed and reopened, and never an empty part.
  Beyond `--max-parts` the first part is sent and the whole text follows as a
  file.
* Incoming messages are read field by field, so `poll --wait` returns its
  answer, a sticker no longer answers a question, and a `|` in an option is
  harmless.
* Tables read quoted CSV fields, align numbers on the right, count widths in
  characters, and an empty table says "no rows".
* The option `--percent` takes `45.5` and counts such as `37/512`; the levels
  `partial` and `blocked` exist.
* The cooldown is recorded after a successful send, atomically, and ignores
  the footer, so `--meta` no longer defeats it.
* Control characters are escaped in every JSON request.
* A group upgraded to a supergroup is retried once at its new id, which is
  printed; a request to wait is capped at five minutes.
* The deprecated Telegram fields are replaced by `link_preview_options`,
  `reply_parameters` and `correct_option_ids`.
* The setup wizard changes only its own lines of the settings file, keeps the
  old file as a `.bak` copy, and restores the echo of the terminal after
  Ctrl-C.
* The shell snippet of `hook bash` reports the real exit code and no longer
  says "finished" after a failure.
* The installer always downloads when piped into a shell, removes only what it
  installed within `--prefix`, and installs the zsh completion too.

### Several sessions and several computers

* Questions (`ask`, `poll --wait`) and the setup commands share one inbox per
  bot: a lock lets one process at a time read Telegram's queue and file every
  answer for the question it belongs to. Several questions may wait at once,
  from several terminals and from several computers sharing the bot, and each
  answer reaches its own question. A refusal for a concurrent reader becomes a
  short wait.
* A typed answer is acknowledged with a 👍 reaction, a press on a closed
  question with "This question has closed", and the question shows its answer
  once given.

### The machine, topics and corrections

* Every message names the machine that sent it, right after the level emoji,
  so that the notification banner shows it: "✅ 💻 laptop · Tests green". The
  name is set with `tg-ping config set machine NAME` or by `init`; the icon
  (laptop, desktop, or server and virtual machine) is detected once. An
  unnamed machine shows nothing, and `--no-machine` hides the name once.
* With `TG_PING_TOPICS=project`, each project gets its own topic in the chat,
  one per machine ("NLS-cavity · laptop"), made by the bot the first time and
  made again if deleted. When topics cannot be used, messages go to the main
  chat.
* The commands `edit` and `delete` correct or withdraw a message, by number or
  with `--last`.
* The command `config set KEY VALUE` changes one setting without printing any
  secret; `config unset`, `config path` and `config files` complete it.

### Formulas, figures and pages

* The format `rich` (`--rich`, `TG_PING_FORMAT=rich`) sends Telegram's rich
  messages: headings, lists, tables and formulas between `$` or `$$`, typeset
  by Telegram, up to 32,768 characters. When Telegram refuses one, the classic
  message goes out instead and loses nothing. The default stays `auto`, with
  formulas drawn as pictures.
* The option `--math 'LATEX'` adds a formula to any message: typeset by
  Telegram in the rich format, drawn as a picture otherwise.
* The command `rich FILE.md` sends a Markdown report as one message, with its
  local figures uploaded alongside.
* The command `math` sets a formula with `\\` over several lines (aligned at
  `&`), keeps the environments that make their own display, typesets a
  sentence with its inline formulas (`--prose`), reads a file (`--file`), and
  lets Telegram typeset it (`--native`).
* The command `pdf FILE --pages 3,7-9` sends pages of a PDF as pictures, with
  `--attach` for the PDF itself.
* The command `photo` draws PDF, SVG and EPS figures at 300 dpi first,
  `--original` adds the file itself, `--each` gives each picture of an album
  its own caption, and `--key NAME --replace` keeps one live figure up to date
  in the same message.

### Long computations

* The command `run` gains `--every 30m` (one status message edited silently
  with the time elapsed and the last lines of output), `--stall 20m` (one
  warning when the output falls silent), `--attach-log` and
  `--attach-log-always` (the complete log), and `--log FILE`. An interruption
  is reported as such, with the command's own exit code, and Ctrl-C still
  reaches the command.
* The progress message shows the time elapsed and, with a percentage, the
  expected end counting down on the phone; `progress start --expected 2h` lets
  `done` compare the duration with the prediction, and `done` also sends a
  short reply, since an edit never rings the phone.
* The command `wait PID` sends a message when a process started earlier ends,
  with the end of its log when `--log` names it.
* Quiet hours (`TG_PING_QUIET_HOURS=23-08`) deliver without sound at night,
  errors and questions excepted.
* The footer of `--meta` shows the fields named by `TG_PING_META`.

### Setup and development

* The command `doctor` checks each chat without sending anything, reports a
  webhook that would stop questions, says whether topics are on, names the
  engine of each formula syntax, and renders a test formula with `--math`.
* The completions for bash and zsh are generated from the lists the parser
  uses, so they offer every command and option.
* Every count and cut of a text is made in awk under the C locale, and the
  tests run under gawk, mawk and busybox awk, under the bash 3.2 of macOS,
  and without jq or python3. The curl stand-in of the tests replays queues of
  answers, conflicts, slow replies and the refusals Telegram really sends.

## 1.0.0

First public release.

### Messaging

* Text messages composed from optional parts: level emoji, bold title, body,
  bullet items, key and value fields, collapsible quotations, code blocks,
  progress bars, link buttons and a footer carrying host, repository, branch
  and time.
* A `auto` format that accepts light Markdown, emits correctly escaped Telegram
  HTML, applies emphasis only at word boundaries so that identifiers such as
  `n_max` survive, and resends the message as literal plain text if Telegram
  refuses the markup.
* Automatic splitting of long messages on line boundaries, with code blocks
  closed and reopened so every part stands on its own.
* Delivery options: silent, pinned, protected, replies, forum topics, several
  chats at once, and suppressed link previews by default.

### Media and mathematics

* `photo`, `file` and `media` send images, documents and albums of up to ten
  items, with captions that continue in a follow up message when they exceed
  the Telegram limit.
* `code` sends a snippet or a file as a highlighted block, and falls back to a
  document when it is too long.
* `table` aligns CSV or TSV rows into a monospace block.
* `math` typesets a LaTeX or Typst formula locally, through typst, or LaTeX
  with dvipng or pdftoppm, and sends the image. A public renderer is available
  only when explicitly requested.

### Long jobs and interaction

* `run` wraps a command, times it, streams its output, reports the outcome with
  a tail of the log on failure, and passes the exit code through.
* `progress` keeps one message updated in place.
* `ask` puts a question on the phone as buttons, accepts a typed reply as well,
  and prints the answer on stdout, with an optional default on timeout.
* `poll` sends a native Telegram poll and can wait for the tally.

### Setup, safety and integration

* `init` validates the token, discovers the chat id and writes a configuration
  file with mode 600. `doctor` diagnoses the installation. `chats` lists known
  chat ids.
* Credentials resolved from flags, environment, project files and user
  configuration, with profiles for several bots. Files are parsed, never
  sourced or evaluated.
* The bot token never reaches the process list, and is redacted from every
  message the tool prints.
* Retries with backoff on network errors, 429 with `retry_after`, and 5xx.
* `--cooldown`, `--soft-fail`, `--dry-run` and `TG_PING_DISABLED` for
  unattended and automated use.
* `hook` prints integration snippets for Claude Code, Codex, shell traps,
  Makefiles, GitHub Actions, systemd and Python.
* Shell completion for bash and zsh, an offline test suite, and
  continuous integration running ShellCheck.
