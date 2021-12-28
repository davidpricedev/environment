
###---  ohmyzsh configs ---### 
export ZSH="/Users/davidp/.oh-my-zsh"
ZSH_THEME="agnoster"
# CASE_SENSITIVE="true"
HYPHEN_INSENSITIVE="true"
zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' frequency 13
# DISABLE_UNTRACKED_FILES_DIRTY="true"
HIST_STAMPS="yyyy-mm-dd"
plugins=(git colorize)

source $ZSH/oh-my-zsh.sh


###--- Aliases ---###
alias zshconfig="vi ~/.zshrc"
alias ohmyzsh="vi ~/.oh-my-zsh"
alias vi="vim"
alias la="ls -alhF"
alias ls="ls -hF"
alias diff="git diff"
alias pip="pip3"
alias python="python3"
# list 10 latest modified branches
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"


###--- Override the parts of the prompt ---###
prompt_date_part="%D{%a-%b%d}"
prompt_context() {
  prompt_segment blue black "$prompt_date_part"
}
prompt_dir() {
  prompt_segment "black" "red" "%2~"
}


###--- Setup GRC (the output colorizer) ---###
[[ -s "/usr/local/etc/grc.zsh" ]] && source /usr/local/etc/grc.zsh

