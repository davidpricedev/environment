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

# if eza is installed, use it for ls aliases
if command -v eza &> /dev/null; then
  alias la="eza -alhF"
  alias ls="eza -hF"
else
  alias la="ls -alhF"
  alias ls="ls -hF"
fi

alias diff="git diff"

if [[ "$(uname)" == "Darwin" ]]; then
  # On a mac
  alias pip="pip3"
  alias python="python3"
fi

# git aliases
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias git-plc="git commit --amend --no-edit && git push --force"
alias git-aplc="git add -A && git commit --amend --no-edit && git push --force"
alias git-restage="git reset --soft HEAD"
alias git-fetch-all="git fetch --all --prune && git fetch --tags --all --force"

alias port-list="sudo lsof -i -P | grep LISTEN | grep :\$PORT"
alias k="kubectl"

alias aws-whoami="aws sts get-caller-identity | cat"
alias aws-list-deleted-secrets="aws secretsmanager list-secrets --include-planned-deletion --output json | jq -r '.SecretList[] | select(.DeletedDate!=null) | .Name'"
alias gem-clear="gem uninstall -aIx"
