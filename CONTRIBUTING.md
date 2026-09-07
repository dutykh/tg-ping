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
shellcheck -x bin/tg-ping install.sh tests/run-tests.sh
```

The test suite is offline: a stub `curl` records every request and answers with
canned Telegram JSON, so no token and no network are needed. Please add a case
for any change in behaviour, and make sure `tg-ping --help` still describes
what you added.

## Design constraints

These are deliberate, and a patch that breaks one of them will be asked to
change:

* **One file.** `bin/tg-ping` stays self contained, so it can be installed by
  copying a single file.
* **`curl` is the only hard dependency.** `jq`, `python3`, `typst` and LaTeX are
  optional and every path degrades gracefully without them.
* **Bash 3.2 compatibility**, so the tool also runs on a stock macOS shell. No
  associative arrays, no `mapfile`, no `${var,,}`.
* **Credentials never reach the process list**, and configuration files are
  parsed rather than sourced.
* **A notification is never lost to formatting.** Anything that can fail to
  parse must have a fallback.

## Style

Two space indentation in shell, functions in lower case with underscores,
comments that explain intent rather than syntax. Error messages tell the reader
what to do next, not only what went wrong.

## Reporting a security issue

Please report anything sensitive privately by electronic mail rather than in a
public issue.
