# dedupe the path, making reloading the zshrc more idempotent
typeset -U path

# pull in the main configuration
source "${HOME}/.zsh/index.zsh"

###--- Local Paths ---###
# use `path+=("/new/path")` to append new directories to the PATH
# use `path=("/new/path" $path)` to prepend new directories to the PATH

# uv & pipx
path+=("$HOME/.local/bin")
