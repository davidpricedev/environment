###--- Switch to main safely ---###
git2main() {
    # Check for uncommitted changes
    STASHED=false
    if ! git diff-index --quiet HEAD --; then
        echo "Stashing uncommitted changes..."
        git stash push -m "Auto-stash before switching to main"
        STASHED=true
    fi

    git fetch --all
    git switch main
    git pull

    # Apply stash if changes were stashed
    if [ "$STASHED" = true ]; then
        echo "Applying stashed changes..."
        git stash pop
    fi
}

git-nb() {
  if [ -z "$1" ]; then
      echo "Usage: git-nb <branch-name>"
      return 1
  fi

  git2main
  git switch -c "$1"
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
