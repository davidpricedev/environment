###---  ohmyzsh configs ---###
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
HYPHEN_INSENSITIVE="true"
zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 13
HIST_STAMPS="yyyy-mm-dd"
plugins=(git colorize)
source $ZSH/oh-my-zsh.sh
