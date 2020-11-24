# hardlink this file to ~/.bash_profile, ~/.profile, and ~/.bashrc - so it works correctly in all contexts

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

## Iterm2 "badge"
function iterm2_print_user_vars() {
  iterm2_set_user_var gitBranch $((git branch 2> /dev/null) | grep \* | cut -c3-)
}

## NVM
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

## Add /usr/local/bin
export PATH="/usr/local/bin:$PATH"

## Add dotnet core to command line
export PATH="$PATH:/usr/local/share/dotnet/"

## NPM Local Tools
export PATH="$PATH:./node_modules/.bin/"

## Others
export PATH="$PATH:/usr/local/sbin/"

## Aliases
alias vi="vim"
alias la="ls -alhF"
alias ls="ls -hF"
alias diff="git diff"
alias pip="pip3"
alias python="python3"
# list 10 latest modified branches
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"

# install grc aliases
source "`brew --prefix`/etc/grc.bashrc"

## PyEnv
eval "$(pyenv init -)"

# git completion
if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/$USER/.sdkman"
[[ -s "/Users/$USER/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/$USER/.sdkman/bin/sdkman-init.sh"
