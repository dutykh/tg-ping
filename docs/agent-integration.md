<!--
  Agent integration guide for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# Letting an agent report to you

The point of `tg-ping` is that a program working on its own can tell you what
matters, on your phone, without holding any of your credentials. This guide
covers what to tell an agent, how to wire it up, and how to let it show its
work rather than describe it.

## Give the agent the tool, not the token

Install `tg-ping` and configure it once, for the user the agent runs as. The
agent then calls a command; it never sees the token, and it cannot read it back
out of the tool: `tg-ping config show` prints the bot's public number and where
each setting comes from, never the secret. A repository the agent clones
cannot redirect the messages either, since a file of the working folder never
supplies the token nor the address of the server.

If an agent runs in a container or on a remote machine, put the credentials in
the environment of that machine (`TG_PING_TOKEN`, `TG_PING_CHAT_ID`) rather
than into the repository, and give the machine a name
(`tg-ping config set machine "cluster"`, or `TG_PING_MACHINE`), so that you
know which one is speaking.

## What to write in the project instructions

`tg-ping hook claude` and `tg-ping hook codex` print a ready section. The
substance of it is a policy about *when* to write, which matters more than the
syntax: when a long task starts, so you know work is under way; when a build,
a test suite, a benchmark or a simulation ends, either way; when a figure, a
table or a document worth reading has been produced; when the agent is blocked
and needs a decision; and when the objective is complete.

And a policy about *how*: one or two sentences, one message per milestone
rather than a stream, a title that reads well as a phone notification, and the
numbers that matter in `--field` rather than buried in prose. The command word
may come before or after the options, and `--dry-run` shows the request
without sending it, which is the quickest way for an agent to check that an
attachment really goes as a photo or a document.

## Claude Code

```bash
tg-ping hook claude >> CLAUDE.md
```

Hooks make the notification automatic rather than a matter of the model
remembering. `tg-ping hook hooks` prints a `.claude/settings.json` fragment
that fires when the session stops and when the agent is waiting for you. Each
hook command carries `--no-stdin`, since Claude Code hands every hook a JSON
document on standard input, and the stop hook a `--cooldown`, so that a burst
of short sessions makes one message.

## Codex and other agents

```bash
tg-ping hook codex >> AGENTS.md
```

Any agent that can run a shell command can use `tg-ping`. Anything that can
read `--help` will use it correctly: the help text lists every command, the
formatting rules, the exit codes and worked examples, and `tg-ping help
COMMAND` details each command.

## Show rather than describe

A result reads best in the form it has. A figure goes as a picture, and a
figure saved as PDF, SVG or EPS is drawn first; a document goes as the PDF
itself, or as pictures of the pages that changed; a formula is typeset; numbers
go as a table:

```bash
tg-ping photo figures/convergence.pdf --caption "Second order confirmed"
tg-ping pdf paper.pdf --pages 7-8 --caption "The corrected section" --attach
tg-ping math 'u_t + 6 u u_x + u_{xxx} = 0 \\ u(x, 0) = u_0(x)' --caption "The problem"
tg-ping table results.csv --title "Errors per resolution"
tg-ping --ok --title "Lemma closed" "The energy decays." --math 'E(t) \leqslant E(0)'
```

A longer report written in Markdown, with its figures, goes as one rich
message, where Telegram typesets the formulas itself:

```bash
tg-ping rich opening.md --start --title "The sweep begins"
```

## Long computations

A command wrapped in `run` reports how it ended, with the end of its output on
failure, and passes its exit code through. For a computation of hours, one
status message is edited silently along the way, and a single warning arrives
if the output falls silent:

```bash
tg-ping run --label "sweep" --every 30m --stall 20m --attach-log -- julia sweep.jl
```

A computation started earlier without `tg-ping` can still be followed:

```bash
tg-ping wait 41532 --label "the cavity sweep" --log sweep.log
```

## Two-way work

An agent that can ask a question can keep going through the night instead of
stopping at the first fork in the road:

```bash
answer=$(tg-ping ask "Forty files change. Continue?" \
                 -o continue -o "stop and show me the plan" \
                 --wait 1800 --default "stop and show me the plan")
```

With `--default`, an unanswered question resolves to the safe branch instead of
blocking forever. Without it, the exit code is `7` and the agent can decide
what to do.

Several agents may ask at the same time, from several terminals or from
several computers sharing the bot: each answer reaches its own question. A
button press carries the identity of its question; a typed answer counts when
it replies to the question or directly follows it, and it is acknowledged with
a 👍.

## Keeping the phone calm

The option `--cooldown 300 --key build` drops repeats of the same alert inside
five minutes, which protects you from a looping agent. The option `--silent`
delivers without a sound, which suits routine progress, and quiet hours
(`TG_PING_QUIET_HOURS=23-08`) do the same at night, errors and questions
excepted. The commands `progress update` and `run --every` edit one message in
place instead of adding new ones, and `--level debug` is silent by default.
With `TG_PING_TOPICS=project`, each project writes into its own topic of the
chat. In continuous integration and test suites, `TG_PING_DISABLED=1` keeps
experiments from reaching your phone at all.

## Failure should never break the work

A notification is not the task. `--soft-fail`, or `TG_PING_SOFT_FAIL=1`, makes
every delivery problem exit `0`, so a flaky network cannot fail a build whose
only sin was trying to tell you it succeeded. The command `run` goes further:
it runs its command even when the settings are missing, and its exit code is
always the command's own.

## A worked example

A numerical experiment that reports properly, from start to finish:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'tg-ping --no-stdin --fail --field "exit=$?" --field "line=$LINENO" \
      --title "sweep failed" --meta' ERR

tg-ping --start --title "Parameter sweep" "512 runs, about 3 hours" --meta
tg-ping progress start "sweep running" --expected 3h

for n in $(seq 1 512); do
    ./solve --case "$n" > "out/$n.json"
    if [ $(( n % 64 )) -eq 0 ]; then
        tg-ping progress update "case $n of 512" --percent "$n/512"
    fi
done

tg-ping progress "done" "sweep complete"
tg-ping table out/summary.csv --title "Errors per resolution"
tg-ping photo figures/convergence.pdf --caption "Second order confirmed"
tg-ping math '\|u - u_h\| \leqslant C h^2' --caption "Observed rate"
tg-ping --ok --title "Sweep finished" "best error 1.4e-8 at N = 1024" --meta
```

The trap reads the exit code first, before any other command can replace it,
and `--no-stdin` keeps it from reading whatever is piped into the script.
