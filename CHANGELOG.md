<!--
  Changelog for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# Changelog

This project follows semantic versioning.

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
