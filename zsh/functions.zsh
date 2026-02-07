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
  if [ -z "$1" ]; then
    echo "Usage: git2new <branch-name>"
    return 1
  fi
  git2main
  git switch -c "$1"
}

###--- Surgical git rebase ---###
# rebase the commits that are unique to the current branch
#  onto the target-branch (default target is origin/main)
# Usage: gitreonto [target-branch]
gitreonto() {
  local target_branch="${1:-origin/main}"
  local branch_name="$(git branch --show-current)"

  if [[ -z "$branch_name" ]]; then
    echo "Error: Could not determine branch name" >&2
    return 1
  fi

  if [[ "$branch_name" == "$target_branch" ]]; then
    echo "Error: Refusing to rebase $branch_name onto $target_branch" >&2
    return 1
  fi

  echo "Fetching all remotes..."
  git fetch --all || return 1

  local merge_base=""
  local commit_count=0
  while read -r commit; do
    # Check if commit exists in any branch other than current
    if git branch -a --contains "$commit" | grep -vE "\b$branch_name\b" | grep -q .; then
      merge_base="$commit"
      break
    fi
    ((commit_count++))
  done < <(git rev-list "$branch_name")

  if [[ -z "$merge_base" ]]; then
    echo "Error: Could not find a shared commit with another branch" >&2
    return 1
  fi

  echo "Rebasing $commit_count commits from '$branch_name' onto '$target_branch' starting at merge base '$merge_base'..."

  git rebase --onto "$target_branch" "$merge_base" "$branch_name"
}

###--- Manually rebase a specified number of commits onto target branch ---###
gitcreonto() {
  local commit_count="$1"
  local target_branch="${2:-origin/main}"
  local branch_name="$(git branch --show-current)"

  if [[ -z "$commit_count" ]]; then
    echo "Error: Number of commits to rebase not specified" >&2
    echo "Usage: gitcreonto <number_of_commits> [target_branch]" >&2
    return 1
  fi

  if [[ -z "$branch_name" ]]; then
    echo "Error: Could not determine branch name" >&2
    return 1
  fi

  if [[ "$branch_name" == "$target_branch" ]]; then
    echo "Error: Refusing to rebase $branch_name onto $target_branch" >&2
    return 1
  fi

  echo "Fetching all remotes..."
  git fetch --all || return 1

  local merge_base="$(git rev-parse HEAD~"$commit_count")"

  echo "Rebasing $commit_count commits from '$branch_name' onto '$target_branch' starting at merge base '$merge_base'..."

  git rebase --onto "$target_branch" "$merge_base" "$branch_name"
}

###--- Squash commits ---###
squash() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: squash <number_of_commits> <commit_message>"
    return 1
  fi

  local num_commits="$1"
  local commit_message="$2"

  # Validate that num_commits is a positive integer
  if ! [[ "$num_commits" =~ ^[0-9]+$ ]] || [ "$num_commits" -le 0 ]; then
    echo "Error: Number of commits must be a positive integer"
    return 1
  fi

  # Check if we have enough commits to squash
  local total_commits=$(git rev-list --count HEAD)
  if [ "$num_commits" -gt "$total_commits" ]; then
    echo "Error: Cannot squash $num_commits commits, only $total_commits available"
    return 1
  fi

  # Perform interactive rebase with auto-squash, suppressing both editors
  GIT_SEQUENCE_EDITOR="sed -i -e '2,\$s/^pick/squash/'" GIT_EDITOR=true git rebase -i "HEAD~$num_commits"

  # Check if rebase was successful
  if [ $? -ne 0 ]; then
    echo "Error: Rebase failed"
    return 1
  fi

  # Amend the commit message
  git commit --amend -m "$commit_message"

  if [ $? -eq 0 ]; then
    echo "Successfully squashed $num_commits commits"
  else
    echo "Error: Failed to amend commit message"
    return 1
  fi
}

###--- Wrap git diff in a function so we get some auto-complete happening ---###
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
