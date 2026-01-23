###--- Switch to main safely ---###
git2main() {
    local stashed=0
    # Check if there are any changes to stash
    if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "Stashing uncommitted changes..."
        git stash push -u -m "git2main auto-stash $(date +%Y-%m-%d\ %H:%M:%S)"
        stashed=1
    fi

    git fetch --all --prune && git switch main && git pull

    # Apply stash if changes were stashed
    if [ "$stashed" -eq 1 ] && [ $? -eq 0 ]; then
        echo "Applying stashed changes..."
        git stash pop
    fi
}

###--- Switch to new branch based on origin/main ---###
git2new() {
    local newname="$1"
    git2main
    git switch -c "$1"
}

###--- Wrap git diff in a function so hopefully we get some auto-complete happening ---###
fdiff() {
  local f1="$1"
  local f2="$2"
  git diff "$f1" "$f2"
}

###--- Python Cleanup ---###
pyclean () {
  find . -type f -name '*.py[co]' -delete -o -type d -name __pycache__ -delete
}

###--- Run command on cd ---###
function chpwd {
    # Check if in a Git repository
    if git rev-parse --is-inside-work-tree &> /dev/null; then
        git check-ignore -q . 2>/dev/null
        if [[ $? -eq 1 ]]; then
            export GIT_ROOT="$(git root)"
        else
            unset GIT_ROOT
        fi
    else
        unset GIT_ROOT
    fi
}
