#!/usr/bin/env bash
#
# A long numerical experiment that reports its own progress.
#
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).

set -Eeuo pipefail

CASES=${1:-512}

# Any unexpected failure reaches the phone, with its exit code (read first,
# before any other command can replace it) and the line that caused it.
# --no-stdin keeps the trap from reading whatever is piped into the script.
trap 'tg-ping --no-stdin --soft-fail --fail --field "exit=$?" \
      --field "line=$LINENO" --title "sweep failed" --meta' ERR

tg-ping --start --title "Parameter sweep" "$CASES runs, roughly three hours" --meta
tg-ping progress start "sweep running" --expected 3h --soft-fail

for n in $(seq 1 "$CASES"); do
    ./solve --case "$n" > "out/$n.json"
    if [ $(( n % 64 )) -eq 0 ]; then
        tg-ping progress update "case $n of $CASES" --percent "$n/$CASES" --soft-fail
    fi
done

tg-ping progress "done" "sweep complete" --soft-fail

# The results themselves, in the form that reads best on a phone.
tg-ping table out/summary.csv --title "Error against resolution"
tg-ping photo figures/convergence.pdf --caption "Second order confirmed"
tg-ping math '\|u - u_h\| \leqslant C h^2' --caption "Observed rate"

# One decision left to the human, with a safe default for the small hours.
next=$(tg-ping ask "Run the refinement study as well?" \
       -o "run it" -o "leave it for me" --wait 1800 --default "leave it for me")
case "$next" in
    "run it") ./refine.sh ;;
    *)        tg-ping --title "Waiting" "The refinement study is ready when you are." ;;
esac
