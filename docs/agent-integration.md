<!--
  Agent integration guide for tg-ping.

  Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
          Science and Technology, Abu Dhabi, UAE).
-->

# Letting an agent report to you

The point of `tg-ping` is that a program working on its own can tell you what
matters, on your phone, without holding any of your credentials. This guide
covers what to tell an agent, and how to wire it up.

## Give the agent the tool, not the token

Install `tg-ping` and configure it once, for the user the agent runs as. The
agent then calls a command; it never sees the token, and it cannot read it back
out of the tool. `tg-ping config show` prints only a masked form.

If an agent runs in a container or on a remote machine, put the credentials in
the environment of that machine (`TG_PING_TOKEN`, `TG_PING_CHAT_ID`) rather
than into the repository.

## What to write in the project instructions

`tg-ping hook claude` and `tg-ping hook codex` print a ready section. The
substance of it is a policy about *when* to write, which matters more than the
syntax:

* when a long task starts, so you know work is under way;
* when a build, a test suite, a benchmark or a simulation ends, either way;
* when a figure, a table or a document worth reading has been produced;
* when the agent is blocked and needs a decision;
* when the objective is complete.

And a policy about *how*: one or two sentences, one message per milestone
rather than a stream, a title that reads well as a phone notification, and the
numbers that matter in `--field` rather than buried in prose.

## Claude Code

```bash
tg-ping hook claude >> CLAUDE.md
```

Hooks make the notification automatic rather than a matter of the model
remembering. `tg-ping hook hooks` prints a `.claude/settings.json` fragment
that fires when the session stops and when the agent is waiting for you.

## Codex and other agents

```bash
tg-ping hook codex >> AGENTS.md
```

Any agent that can run a shell command can use `tg-ping`. Anything that can
read `--help` will use it correctly: the help text lists every command, the
formatting rules, the exit codes and worked examples.

## Two-way work

An agent that can ask a question can keep going through the night instead of
stopping at the first fork in the road:

```bash
answer=$(tg-ping ask "The refactor touches 40 files. Continue?" \
                 -o continue -o "stop and show me the plan" \
                 --wait 1800 --default "stop and show me the plan")
```

With `--default`, an unanswered question resolves to the safe branch instead of
blocking forever. Without it, the exit code is `7` and the agent can decide
what to do.

Remember that only one process may read a given bot's updates. Two agents that
both use `ask` need two bots, which is what `--profile` is for.

## Keeping the phone calm

* `--cooldown 300 --key build` drops repeats of the same alert inside five
  minutes, which protects you from a looping agent.
* `--silent` delivers without a sound, which suits routine progress.
* `progress update` edits one message in place instead of adding new ones.
* `--level debug` is silent by default.
* `TG_PING_DISABLED=1` in continuous integration and test suites keeps
  experiments from reaching your phone at all.

## Failure should never break the work

A notification is not the task. `--soft-fail`, or `TG_PING_SOFT_FAIL=1`, makes
every delivery problem exit `0`, so a flaky network cannot fail a build whose
only sin was trying to tell you it succeeded.

## A worked example

A numerical experiment that reports properly, from start to finish:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
trap 'tg-ping --fail --title "sweep failed" --field "line=$LINENO" --meta' ERR

tg-ping --start --title "Parameter sweep" "512 runs, about 3 hours" --meta
tg-ping progress start "sweep running"

for n in $(seq 1 512); do
    ./solve --case "$n" > "out/$n.json"
    if [ $(( n % 64 )) -eq 0 ]; then
        tg-ping progress update "case $n of 512" --percent $(( n * 100 / 512 ))
    fi
done

tg-ping progress done "sweep complete"
tg-ping table out/summary.csv --title "Errors per resolution"
tg-ping photo figures/convergence.png --caption "Second order confirmed"
tg-ping math '\|u - u_h\| \leqslant C h^2' --caption "Observed rate"
tg-ping --ok --title "Sweep finished" "best error 1.4e-8 at N = 1024" --meta
```
