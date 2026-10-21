# Bash completion for tg-ping, made by 'tg-ping completion bash'.
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).

_tg_ping_completions() {
    local cur prev dir f names
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in
        --level|-L) COMPREPLY=($(compgen -W "start info success warn error partial blocked question progress debug math" -- "$cur")); return ;;
        --format)   COMPREPLY=($(compgen -W "auto rich html markdown plain" -- "$cur")); return ;;
        --as)       COMPREPLY=($(compgen -W "auto photo video audio animation document" -- "$cur")); return ;;
        --bg|--background)
                    COMPREPLY=($(compgen -W "white transparent dark" -- "$cur")); return ;;
        --on)       COMPREPLY=($(compgen -W "always success failure never" -- "$cur")); return ;;
        --profile|-P)
            dir="${XDG_CONFIG_HOME:-$HOME/.config}/tg-ping"; names=""
            for f in "$dir"/*.env; do [ -e "$f" ] && f=${f##*/} && names="$names ${f%.env}"; done
            COMPREPLY=($(compgen -W "$names" -- "$cur")); return ;;
        --code-file|--quote-file|--out|--preamble|--env-file|--config|--token-file|--file|--log)
            COMPREPLY=($(compgen -f -- "$cur")); return ;;
        -m|--message|--text|-t|--title|--emoji|--item|--field|--code|--lang|--language|--quote|--percent|--button|--cols|--option|-o|--prefix|--reply-to|--topic|--thread|--chat|-c|--token|--api|--timeout|--retries|--cooldown|--key|--id|--max-parts|--caption|--name|--dpi|--sep|--separator|--wait|--default|--correct|--each|--math|--pages|--expected|--label|-l|--tail|--limit|--every|--stall)
            return ;;
    esac
    if [ "$COMP_CWORD" -eq 2 ]; then
        case "$prev" in
            hook|hooks) COMPREPLY=($(compgen -W "claude codex hooks bash make actions systemd python" -- "$cur")); return ;;
            progress)   COMPREPLY=($(compgen -W "start update done" -- "$cur")); return ;;
            config)     COMPREPLY=($(compgen -W "show set unset path files" -- "$cur")); return ;;
            completion) COMPREPLY=($(compgen -W "bash zsh" -- "$cur")); return ;;
            help)       COMPREPLY=($(compgen -W "send code table math photo file media pdf rich run progress wait ask poll edit delete init doctor chats config hook cheatsheet completion version help" -- "$cur")); return ;;
        esac
    fi
    case "$cur" in
        -*) COMPREPLY=($(compgen -W "--anonymous --api --as --attach --attach-log --attach-log-always --background --bg --blocked --button --caption --chat --code --code-file --collapse --cols --config --cooldown --correct --debug --default --disabled --display --dpi --dry-run --each --edit-only --emoji --env-file --error --every --exit-zero --expected --fail --field --file --format --free-text --help --html --id --info --inline --insecure --item --json --key --label --lang --language --last --latex --level --limit --log --markdown --math --max-parts --md --message --meta --multi --name --native --no-fallback --no-header --no-machine --no-meta --no-preview --no-stdin --notify-start --ok --on --option --original --out --pages --partial --percent --pin --plain --preamble --prefix --preview --profile --prose --protect --quiet --quiet-output --quote --quote-file --remote --replace --reply-to --retries --rich --sep --separator --silent --soft-fail --stall --start --strict --success --tail --tee --text --thread --timeout --title --token --token-file --topic --truncate --typst --verbose --version --wait --warn --warning" -- "$cur")) ;;
        *)  if [ "$COMP_CWORD" -eq 1 ]; then
                COMPREPLY=($(compgen -W "send code table math photo file media pdf rich run progress wait ask poll edit delete init doctor chats config hook cheatsheet completion version help" -- "$cur"))
            else
                COMPREPLY=($(compgen -f -- "$cur"))
            fi ;;
    esac
}
complete -o filenames -F _tg_ping_completions tg-ping
