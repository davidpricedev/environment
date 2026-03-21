###--- Detect the default branch name for the current git repo ---###
git-default-branch() {
  local branch
  # Try remote HEAD symref (no network call)
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [[ -n "$branch" ]]; then
    echo "$branch"
    return 0
  fi
  # Try local HEAD (useful in bare clones)
  branch=$(git symbolic-ref HEAD 2>/dev/null | sed 's@^refs/heads/@@')
  if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
    echo "$branch"
    return 0
  fi
  # Fall back to remote query (requires network)
  branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  if [[ -n "$branch" ]]; then
    echo "$branch"
    return 0
  fi
  echo "main"
}

###--- Switch to main safely ---###
git2main() {
    local stashed=0
    local default_branch
    default_branch=$(git-default-branch)
    # Check if there are any changes to stash
    if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "Stashing uncommitted changes..."
        git stash push -u -m "git2main auto-stash $(date +%Y-%m-%d\ %H:%M:%S)"
        stashed=1
    fi

    git fetch --all --prune && git switch "$default_branch" && git pull

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

###--- find the nearest ancestor commit shared with another non-linear branch ---###
_git_count_to_nearest_shared_ancestor() {
  local branch_name="$1"
  local merge_base=""
  local count=0

  # Get all branches the HEAD commit belongs to and exclude them
  local excluded_branches_array
  excluded_branches_array=$(git branch -a --contains HEAD | \
    sed 's/^[* ] //')
  local excluded_branches_regex
  # exbr.map(x => `\\b${x}\\b`).join('|') translated to shell
  excluded_branches_regex=$(echo "$excluded_branches_array" | \
    sed 's/^/\\b/' | \
    sed 's/$/\\b/' | \
    tr '\n' '|' | \
    sed 's/|$//')

  while read -r commit; do
    # Check if commit exists in any branch other than the excluded branches
    if git branch -a --contains "$commit" | grep -vE "$excluded_branches_regex" | grep -q .; then
      merge_base="$commit"
      break
    fi
    ((count++))
  done < <(git rev-list "$branch_name")
  echo "$count"
}

###--- Rebase commits onto target branch ---###
# rebase one or more commits from the current branch
#  onto the target-branch (default target is origin/<default-branch>)
# Without the -c option, it will rebase all commits that are unique to the current branch
# With the -c option, it will rebase the specified number of commits from the current branch
# Usage: gitreonto [-c <commit_count>] [-t <target-branch>]
git-reonto() {
  local target_branch
  target_branch="origin/$(git-default-branch)"

  while [[ $# -gt 0 ]]; do
    case $1 in
      -c)
        commit_count="$2"
        shift 2
        ;;
      -t)
        target_branch="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: git-reonto [-c <number_of_commits>] [-t <target_branch>]" >&2
        return 1
        ;;
    esac
  done

  local branch_name="$(git branch --show-current)"

  if [[ -z "$branch_name" ]]; then
    echo "Error: Could not determine branch name" >&2
    return 1
  fi

  if [[ "$branch_name" == "$target_branch" ]]; then
    echo "Error: Refusing to rebase $branch_name onto $target_branch" >&2
    return 1
  fi

  if [[ -z "$commit_count" ]]; then
    read commit_count <<< $(_git_count_to_nearest_shared_ancestor "$branch_name") || return 1
  fi

  merge_base="$(git rev-parse HEAD~"$commit_count")"
  if [[ -z "$merge_base" ]]; then
    echo "Error: Could not determine merge base for $commit_count commits" >&2
    return 1
  fi

  echo "Fetching all remotes..."
  git fetch --all || return 1

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

###--- Git Worktree Clone ---###
gitw-clone () {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: gitw-clone <uri> <destination-folder>"
    return 1
  fi
  local uri="$1"
  local dest="$2"
  mkdir "$dest"
  cd "$dest"
  git clone --bare "$1" .git
  local default_branch
  default_branch=$(git-default-branch)
  git worktree add main "$default_branch"
  if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
  fi
  cd -
}

###--- Git Worktree Add ---###
gitw-add() {
  if [ -z "$1" ]; then
    echo "Usage: gitw-add <new-branch/folder-name>"
    return 1
  fi
  local dest="$1"
  git worktree add "$dest"
  cd "$dest"
  if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
  fi
  cd -
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
