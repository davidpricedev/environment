###--- Fix zsh UX problems ---###
unsetopt share_history
setopt no_share_history
unsetopt SHARE_HISTORY
setopt NO_SHARE_HISTORY

# uv / pipx path
export PATH="$PATH:${HOME}/.local/bin"
