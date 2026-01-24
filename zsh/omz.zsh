###---  ohmyzsh configs ---###
export ZSH="$HOME/.oh-my-zsh"

export ZSH_THEME="agnoster"
export ZSH_THEME="davidpricedev"

export ZSH_DISABLE_COMPFIX="true"
export ZSH_COLORIZE_STYLE="colorful"
export ZSH_COLORIZE_TOOL="pygmentize"
export CLICOLOR=1

HYPHEN_INSENSITIVE="true"
zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 13
HIST_STAMPS="yyyy-mm-dd"

plugins=(git colorize dotenv colorize copybuffer copyfile dirhistory jsontools z)

source $ZSH/oh-my-zsh.sh
