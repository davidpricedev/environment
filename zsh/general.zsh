###--- Fix zsh UX problems ---###
unsetopt share_history
setopt no_share_history
unsetopt SHARE_HISTORY
setopt NO_SHARE_HISTORY

###--- Override parts of the prompt ---###
prompt_date_part="%D{%a-%b%d}"
prompt_context() {
  prompt_segment blue black "$prompt_date_part"
  prompt_end "\n"
}
prompt_dir() {
  prompt_segment "black" "red" "%2~"
}

# uv / pipx path
export PATH="$PATH:${HOME}/.local/bin"
