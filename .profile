## Enable color for prompt
force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

## bash-git-prompt
GIT_PROMPT_ONLY_IN_REPO=1
GIT_PROMPT_SHOW_UNTRACKED_FILES=all
GIT_PROMPT_THEME=Solarized
if [ -f "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh" ]; then
  __GIT_PROMPT_DIR=$(brew --prefix)/opt/bash-git-prompt/share
  source "$(brew --prefix)/opt/bash-git-prompt/share/gitprompt.sh"
fi

## Normal prompt
if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;32m\]\u@mac\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@mbp:\w\$'
fi

## NVM
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

## Add dotnet core to command line
export PATH="$PATH:/usr/local/share/dotnet/"

## NPM Local Tools
export PATH="$PATH:./node_modules/.bin"

## Aliases
alias vi="vim"
alias la="ls -alhF"
alias ls="ls -hF"
alias diff="git diff"
# install grc aliases
source "`brew --prefix`/etc/grc.bashrc"
