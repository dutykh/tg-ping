#!/usr/bin/env bash
#
# A long numerical experiment that reports its own progress.
#
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).

set -Eeuo pipefail

CASES=${1:-512}

# Any unexpected failure reaches the phone, with the line that caused it.
trap 'tg-ping --soft-fail --fail --title "sweep failed" \
      --field "line=$LINENO" --field "exit=$?" --meta' ERR

tg-ping --start --title "Parameter sweep" "$CASES runs, roughly three hours" --meta
tg-ping progress start "sweep running" --percent 0

for n in $(seq 1 "$CASES"); do
    ./solve --case "$n" > "out/$n.json"
    if [ $(( n % 64 )) -eq 0 ]; then
        tg-ping --soft-fail progress update "case $n of $CASES" \
                --percent $(( n * 100 / CASES ))
    fi
done

tg-ping progress "done" "sweep complete"

# The results themselves, in the form that reads best on a phone.
tg-ping table out/summary.csv --title "Error against resolution"
tg-ping photo figures/convergence.png --caption "Second order confirmed"
tg-ping math '\|u - u_h\| \leqslant C h^2' --caption "Observed rate"

# One decision left to the human, with a safe default for the small hours.
next=$(tg-ping ask "Run the refinement study as well?" \
       -o "run it" -o "leave it for me" --wait 1800 --default "leave it for me")
case "$next" in
    "run it") ./refine.sh ;;
    *)        tg-ping --title "Waiting" "The refinement study is ready when you are." ;;
esac
