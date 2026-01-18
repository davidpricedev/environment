# zsh config handling
alias zshconfig="vi ~/.zshrc"
alias reload="source ~/.zshrc"

# config shortcuts
alias ohmyzsh="vi ~/.oh-my-zsh"
alias vscodeconfig="vi ~/Library/Application\ Support/Code/User/settings.json"

if command -v nvim &> /dev/null; then
  alias vi="nvim"
else
  alias vi="vim"
fi

alias la="ls -alhF"
alias ls="ls -hF"
alias diff="git diff"

if [[ "$(uname)" == "Darwin" ]]; then
  # On a mac
  alias pip="pip3"
  alias python="python3"
fi

# list 10 latest modified branches
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"

# git quick-patch (manual staging)
alias git-plc="git commit --amend --no-edit && git push --force"
# git quick-patch everything
alias git-aplc="git add -A && git commit --amend --no-edit && git push --force"

# deletes a commit, moving the commit to staging
alias git-restage="git reset --soft HEAD"


alias aws-whoami="aws sts get-caller-identity | cat"
alias gem-clear="gem uninstall -aIx"
