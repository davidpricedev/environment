
###---  ohmyzsh configs ---### 
export ZSH="$HOME/.oh-my-zsh"
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
alias reload="source ~/.zshrc"
alias vscodeconfig="vi ~/Library/Application\ Support/Code/User/settings.json"
alias vi="nvim"
alias la="ls -alhF"
alias ls="ls -hF"
alias diff="git diff"
alias pip="pip3"
alias python="python3"
# list 10 latest modified branches
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias git2main="git fetch --all && git switch main && git pull"
alias coderoot="code `git root`"
alias coder="coderoot"
alias git-add-all="git add `git root`"
alias git-plc="git commit --amend --no-edit && git push --force"
alias git-restage="git reset --soft HEAD"
alias aws-whoami="aws sts get-caller-identity | cat"
alias gem-clear="gem uninstall -aIx"
alias awsp="source _awsp"

###--- Run command on cd ---###
function chpwd {
    git check-ignore -q . 2>/dev/null
    if [[ $? -eq 1 ]]; then
        export GIT_ROOT="$(git root)"
    else
        unset GIT_ROOT
    fi
}

###--- Override the parts of the prompt ---###
prompt_date_part="%D{%a-%b%d}"
prompt_context() {
  prompt_segment blue black "$prompt_date_part"
}
prompt_dir() {
  prompt_segment "black" "red" "%2~"
}


# jump to a previous branch
# input: number of gitls output to jump back to
gitback() {
    DEPTH=$1
    BRANCH=$(git for-each-ref --count=${DEPTH} --sort=-committerdate refs/heads/ --format='%(refname:short)' | tail -n 1)
    git switch ${BRANCH}
}

# jump to a new/existing branch
# input: branch name
gitjump() {
    BRANCH_NAME="$1"
    BASE_BRANCH_NAME="origin/main"
    echo "fetching ... "
    git fetch --all
    echo "checking if branch ${BRANCH_NAME} exists ... "
    git branch -l | grep $BRANCH_NAME
    EXIT_CODE=$?
    if [ $EXIT_CODE -gt 0 ]; then
        echo "branch appears to be a new one"
        # if it is a new branch
        git2main
        git checkout -b $BRANCH_NAME
    else
        echo "branch already exists"
        # if it is an existing branch
        git switch $BRANCH_NAME
    fi
}

###--- Setup GRC (the output colorizer) ---###
[[ -s "/usr/local/etc/grc.zsh" ]] && source /usr/local/etc/grc.zsh


###--- Fix zsh UX nightmare ---###
unsetopt share_history
setopt no_share_history
unsetopt SHARE_HISTORY
setopt NO_SHARE_HISTORY
