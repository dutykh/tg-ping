# Bash completion for tg-ping.
# Author: Dr. Denys Dutykh (Mathematics Department, Khalifa University of
#         Science and Technology, Abu Dhabi, UAE).

_tg_ping_completions() {
    local cur prev commands options
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    commands="send code table math photo file media run progress ask poll init doctor chats config hook cheatsheet completion version help"
    options="--message --title --level --emoji --item --field --code --code-file --lang --quote --quote-file --collapse --percent --button --cols --option --meta --prefix --format --plain --html --markdown --no-fallback --silent --pin --protect --reply-to --topic --preview --no-preview --chat --token-file --profile --env-file --api --timeout --retries --dry-run --json --verbose --quiet --tee --soft-fail --disabled --cooldown --key --id --truncate --max-parts --caption --name --as --dpi --bg --typst --latex --inline --display --remote --out --preamble --sep --no-header --wait --default --free-text --strict --multi --anonymous --correct --ok --fail --warn --start --info --debug --help --version"
    case "$prev" in
        --level|-L) COMPREPLY=($(compgen -W "start info success warn error question debug progress" -- "$cur")); return ;;
        --format)   COMPREPLY=($(compgen -W "auto plain markdown html" -- "$cur")); return ;;
        --as)       COMPREPLY=($(compgen -W "auto photo document video audio animation" -- "$cur")); return ;;
        --bg)       COMPREPLY=($(compgen -W "white transparent dark" -- "$cur")); return ;;
        hook)       COMPREPLY=($(compgen -W "claude codex hooks bash make actions systemd python" -- "$cur")); return ;;
        progress)   COMPREPLY=($(compgen -W "start update done" -- "$cur")); return ;;
        --code-file|--quote-file|--out|--preamble|--env-file|--token-file)
                    COMPREPLY=($(compgen -f -- "$cur")); return ;;
    esac
    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$commands $options" -- "$cur"))
    else
        COMPREPLY=($(compgen -W "$options" -- "$cur") $(compgen -f -- "$cur"))
    fi
}
complete -F _tg_ping_completions tg-ping
