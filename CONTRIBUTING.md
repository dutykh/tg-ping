<!--
  Contribution notes for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# Contributing

Bug reports, ideas and patches are welcome.

## Before opening a pull request

```bash
tests/run-tests.sh
TG_PING_AWK=mawk tests/run-tests.sh
TG_PING_AWK="busybox awk" tests/run-tests.sh
TG_PING_HIDE="jq python3" tests/run-tests.sh
shellcheck -x bin/tg-ping install.sh tests/run-tests.sh tests/stub/curl
```

The test suite is offline: a stub `curl` records every request and answers with
canned Telegram JSON, so no token and no network are needed. The stub can also
replay a queue of answers for one method, a conflict between two readers, a
slow reply and the refusals Telegram really sends, which is how the questions,
the topics and the fallbacks are tested. Please add a case for any change in
behaviour, and make sure `tg-ping --help` and the help of the command still
describe what you added.

The awk runs matter because every measure and cut of a text is made in awk:
`TG_PING_AWK` chooses the program, and `TG_PING_HIDE` hides programs such as
`jq` and `python3` from the tool, so the fallbacks run too. The continuous
integration repeats the suite under the bash 3.2 of macOS, with its BSD tools.

The completions are generated from the lists of options in `bin/tg-ping`. After
adding an option, put it in `VALUE_OPTS` or `FLAG_OPTS` (a test checks it), then
regenerate the two files:

```bash
bin/tg-ping completion bash > completions/tg-ping.bash
bin/tg-ping completion zsh  > completions/_tg-ping
```

## Design constraints

These are deliberate, and a patch that breaks one of them will be asked to
change:

* **One file.** `bin/tg-ping` stays self contained, so it can be installed by
  copying a single file.
* **`curl` is the only hard dependency.** The programs `jq`, `python3`,
  `typst`, LaTeX, `pdftoppm`, `inkscape`, `ffmpeg` and `flock` are optional,
  and every path degrades gracefully without them, with a message saying what
  to install.
* **Bash 3.2 compatibility**, so the tool also runs on a stock macOS shell. No
  associative arrays, no `mapfile`, no `${var,,}`, and an array that may be
  empty is expanded as `${a[@]+"${a[@]}"}`, since `set -u` rejects the plain
  form before bash 4.4.
* **Portable tools.** No option that only GNU or only BSD knows (`stat -c`,
  `date -d`, `sed -i`, `ps -o etimes`) without a fallback. Texts are measured in
  awk under `LC_ALL=C` with byte classes, never with `head -c` or `cut -c`,
  whose units differ between implementations.
* **Credentials never reach the process list**, configuration files are parsed
  rather than sourced, and a file of the working folder never supplies the
  token nor the address of the server.
* **A notification is never lost to formatting.** Anything that can fail to
  parse must have a fallback, and a refused rich message, caption or topic
  falls back to a form that Telegram accepts.

## Style

Four space indentation in shell, functions in lower case with underscores,
comments that explain intent rather than syntax. Error messages tell the reader
what to do next, not only what went wrong.

## Reporting a security issue

Please report anything sensitive privately by electronic mail rather than in a
public issue.
