_glim() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local commands
    commands="$(glim __complete)"
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
}
complete -F _glim glim
