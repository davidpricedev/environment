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

  # Check if there are multiple worktrees
  local worktree_count
  worktree_count=$(git worktree list | wc -l)

  # Check if there are any changes to stash
  if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "Stashing uncommitted changes..."
    git stash push -u -m "git2main auto-stash $(date +%Y-%m-%d\ %H:%M:%S)"
    stashed=1                                                                                                                                                                
  fi
                                                                                                                                                                               
  git fetch --all --prune                                     

  # If multiple worktrees exist, checkout the origin SHA directly
  if [ "$worktree_count" -gt 1 ]; then
    echo "Multiple worktrees detected, checking out origin/$default_branch SHA..."
    git checkout --detach "origin/$default_branch"
  else
    git switch "$default_branch" && git pull
  fi

  # Apply stash if changes were stashed and previous command succeeded
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
  local commit_count
  local branch_name
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

  branch_name="$(git branch --show-current)"

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
  git config --local --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  local default_branch
  default_branch=$(git-default-branch)
  git worktree add main "$default_branch"
  if [ -f .pre-commit-config.yaml ]; then
    cd main
    pre-commit install
    cd -
  fi
  cd -
}

###--- Git Worktree Add - always based on origin/main ---###
gitw-add() {
  if [ -z "$1" ]; then
    echo "Usage: gitw-add <new-branch/folder-name>"
    return 1
  fi
  local dest="$1"
  local default_branch
  default_branch=$(git-default-branch)
  git worktree add --no-track -b "$dest" "$dest" "origin/$default_branch"
  cd "$dest"
  if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
  fi
  cd -
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

###--- List listening Ports ---###
function list-ports {
  local isLinux
  isLinux=false
  if [[ "$(uname)" == "Linux" ]]; then
    isLinux=true
  fi
  if "$isLinux"; then
    ss -tulnp | grep LISTEN
  else
    netstat -an | grep LISTEN
  fi
}


###--- git stack (chain) helpers ---###
# A "stack" (or "chain") is a set of branches where each branch is based on the
# one below it, all the way down to the default branch:
#
#   default <- A <- B <- C
#   (base)  (oldest)   (top)
#
# The stack is discovered from how the branches were created: each branch's
# reflog records its creation ("branch: Created from A"), which stays correct
# even after the parent advances (the normal "stack went stale" case). Without
# a reflog the code falls back to a refs-only heuristic (deepest ancestor
# branch tip), which only works while lower branches haven't advanced past
# where higher branches were based. The stack of a branch is the line from the
# default branch to the stack's root (the branch directly on the default
# branch), and up to the stack's top (its deepest descendant). Running an
# operation on a middle branch covers the whole stack.
#
# State for a paused operation lives in <git-dir>/stack/:
#   mode          "rebase" or "inject"
#   on            the branch the user was on at start (restored at the end)
#   stash         "1" if the worktree was auto-stashed (popped back at the end)
#   oldtips       one "<branch> <sha>" per line: tips before the operation began
#   step          "cherry-pick" or "rebase" (where a paused operation is stuck)
#   resume        first line = paused branch, rest = remaining branches
#   walk          the rebase walk list, one branch per line (inject mode)
#   inject-target / inject-commit (inject mode)
#
# All branch lists are newline-separated so the code behaves the same in zsh
# and bash (no unquoted word splitting).

###--- state dir for the current repo (worktree-aware) ---###
_stack_state_dir() {
  local g
  g=$(git rev-parse --absolute-git-dir 2>/dev/null) || return 1
  echo "$g/stack"
}

###--- default (base) branch for stack operations ---###
# Unlike git-default-branch, this never falls back to the *current* branch
# (which would corrupt stack discovery in repos without a remote): it uses the
# remote HEAD symref, then a bare repo's HEAD, then a remote query, then the
# common branch names (this environment sets init.defaultBranch main).
# Set STACK_DEFAULT_BRANCH to override the detection for a specific repo.
_stack_default_branch() {
  local branch
  if [ -n "${STACK_DEFAULT_BRANCH:-}" ]; then
    echo "$STACK_DEFAULT_BRANCH"
    return 0
  fi
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -n "$branch" ]; then
    echo "$branch"
    return 0
  fi
  if [ "$(git rev-parse --is-bare-repository 2>/dev/null)" = "true" ]; then
    branch=$(git symbolic-ref HEAD 2>/dev/null | sed 's@^refs/heads/@@')
    if [ -n "$branch" ]; then
      echo "$branch"
      return 0
    fi
  fi
  branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
  if [ -n "$branch" ]; then
    echo "$branch"
    return 0
  fi
  # local-only repos: guess from the common default branch names
  for branch in main master develop trunk; do
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      echo "$branch"
      return 0
    fi
  done
  echo "main"
}

###--- is a plain git rebase in progress right now? ---###
_stack_in_rebase_progress() {
  local gd
  gd=$(git rev-parse --git-dir 2>/dev/null) || return 1
  [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ]
}

###--- path of another worktree checking out the branch (empty if none/this one) ---###
_stack_worktree_of() {
  local br="$1"
  git worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$br" '
    /^worktree / { p = $2 }
    $1 == "branch" && $2 == b { print p }
  '
}

###--- old tip of a branch, from the saved state ---###
_stack_oldtip() {
  local state_dir br sha
  state_dir=$(_stack_state_dir) || return 1
  br="$1"
  sha=$(awk -v b="$br" '$1 == b { print $2 }' "$state_dir/oldtips" 2>/dev/null)
  [ -n "$sha" ] || return 1
  echo "$sha"
}

###--- is the commit on the mainline (reachable from the default branch)? ---###
# $1 = commit, $2 = local default tip (may be empty), $3 = origin/default tip (may be empty)
_stack_on_mainline() {
  local s="$1" ml="$2" mr="$3"
  if [ -n "$ml" ] && git merge-base --is-ancestor "$s" "$ml" 2>/dev/null; then
    return 0
  fi
  if [ -n "$mr" ] && git merge-base --is-ancestor "$s" "$mr" 2>/dev/null; then
    return 0
  fi
  return 1
}

###--- pick the parent from a set of candidate branches (newline-separated) ---###
# $1 = the branch being resolved, $2 = candidate list, $3 = the creation sha.
# Prints the parent branch, or nothing if the source is on no candidate.
# Errors out if several candidates match and none is clearly the source.
_stack_pick_unambiguous_parent() {
  local branch="$1" candidates="$2" source="$3"
  local n c exact=""
  n=$(printf '%s' "$candidates" | grep -c . || true)
  case "$n" in
    0) return 0 ;;
    1) printf '%s' "$candidates"; return 0 ;;
  esac
  # several candidates pass through the source commit: prefer the one whose tip
  # still IS the source commit (created straight from it, has not advanced)
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    [ "$(git rev-parse "refs/heads/$c")" = "$source" ] && exact="$c"
  done <<< "$candidates"
  if [ -n "$exact" ]; then
    printf '%s' "$exact"
    return 0
  fi
  echo "Error: branch '$branch' was created from $source, which lies on several branches:" >&2
  printf '%s' "$candidates" | sed 's/^/  /' >&2
  echo "Stack operations require one linear chain per stack. Delete or rebase the extra branches so only one remains, then try again." >&2
  return 1
}

###--- parent of a branch in the stack (empty if it sits on the default branch) ---###
# Primary: the branch's reflog records where it was created ("branch: Created
# from <branch>|HEAD|<sha>"), which stays correct even after the parent branch
# advances (the normal "stack went stale" situation).
# Fallback (no reflog / source unmappable): the deepest local branch tip that
# is an ancestor of the branch's tip (only valid while lower stack branches
# have not advanced past this branch's base point).
_stack_parent_of() {
  local branch="$1"
  local default="${2:-$(_stack_default_branch)}"
  local creation token sha candidate parents="" parent
  local mainline_local="" mainline_remote=""

  mainline_local=$(git rev-parse --verify --quiet "refs/heads/$default" 2>/dev/null) || mainline_local=""
  mainline_remote=$(git rev-parse --verify --quiet "refs/remotes/origin/$default" 2>/dev/null) || mainline_remote=""

  # --- primary: the most recent "Created from" record in the branch's reflog ---
  creation=$(git reflog show --format='%H %gs' "refs/heads/$branch" 2>/dev/null | grep -m1 'Created from')
  if [ -n "$creation" ]; then
    sha=${creation%% *}
    token=$(printf '%s\n' "$creation" | sed -n 's/.*Created from //p')

    case "$token" in
      "")
        : # unparseable - fall through to the heuristic
        ;;
      "$default"|"origin/$default")
        # created straight off the default branch: this branch is a stack root
        return 0
        ;;
      *)
        if [ "$token" = "HEAD" ] || printf '%s\n' "$token" | grep -qE '^[0-9a-f]{40}$'; then
          # created from a detached HEAD / explicit commit: $sha is the source tip
          if _stack_on_mainline "$sha" "$mainline_local" "$mainline_remote"; then
            return 0
          fi
          while read -r candidate; do
            [ -z "$candidate" ] && continue
            [ "$candidate" = "$branch" ] && continue
            [ "$candidate" = "$default" ] && continue
            [ "$candidate" = "HEAD" ] && continue
            git show-ref --verify --quiet "refs/heads/$candidate" || continue
            git merge-base --is-ancestor "$sha" "refs/heads/$candidate" 2>/dev/null && \
              parents="$parents$candidate"$'\n'
          done < <(git for-each-ref refs/heads --format='%(refname:short)')
          parent=$(_stack_pick_unambiguous_parent "$branch" "$parents" "$sha") || return 1
          [ -n "$parent" ] && { echo "$parent"; return 0; }
        else
          # created from a named ref
          if git show-ref --verify --quiet "refs/heads/$token"; then
            if [ "$token" = "$default" ]; then
              return 0
            fi
            # a branch that sits on the mainline (an old branch of the default
            # branch) acts as a stack root, not a parent
            if _stack_on_mainline "$(git rev-parse "refs/heads/$token")" "$mainline_local" "$mainline_remote"; then
              return 0
            fi
            echo "$token"
            return 0
          fi
          if ! git show-ref --verify --quiet "refs/remotes/origin/$token"; then
            # the named source no longer exists (deleted/renamed): use the sha
            if _stack_on_mainline "$sha" "$mainline_local" "$mainline_remote"; then
              return 0
            fi
            while read -r candidate; do
              [ -z "$candidate" ] && continue
              [ "$candidate" = "$branch" ] && continue
              [ "$candidate" = "$default" ] && continue
              [ "$candidate" = "HEAD" ] && continue
              git show-ref --verify --quiet "refs/heads/$candidate" || continue
              git merge-base --is-ancestor "$sha" "refs/heads/$candidate" 2>/dev/null && \
                parents="$parents$candidate"$'\n'
            done < <(git for-each-ref refs/heads --format='%(refname:short)')
            parent=$(_stack_pick_unambiguous_parent "$branch" "$parents" "$sha") || return 1
            [ -n "$parent" ] && { echo "$parent"; return 0; }
          fi
          # created from a remote branch other than origin/<default>:
          # nothing local to hang the stack on - fall through to the heuristic
        fi
        ;;
    esac
  fi

  # --- fallback: deepest ancestor branch tip (skips old mainline branches) ---
  local best="" best_sha="" tip
  while read -r candidate; do
    [ -z "$candidate" ] && continue
    [ "$candidate" = "$branch" ] && continue
    [ "$candidate" = "$default" ] && continue
    [ "$candidate" = "HEAD" ] && continue
    git show-ref --verify --quiet "refs/heads/$candidate" || continue
    tip=$(git rev-parse --verify --quiet "refs/heads/$candidate^{commit}") || continue
    # candidate's tip must be an ancestor of branch's tip
    git merge-base --is-ancestor "$tip" "refs/heads/$branch" 2>/dev/null || continue
    # skip branches that are just (old) commits on the default branch's line
    _stack_on_mainline "$tip" "$mainline_local" "$mainline_remote" && continue
    # among the candidates, the deepest tip (a descendant of the others) is the parent
    if [ -z "$best_sha" ]; then
      best="$candidate"
      best_sha="$tip"
    elif git merge-base --is-ancestor "$best_sha" "$tip" 2>/dev/null; then
      best="$candidate"
      best_sha="$tip"
    elif ! git merge-base --is-ancestor "$tip" "$best_sha" 2>/dev/null; then
      # two unrelated ancestor tips: the stack isn't a single line
      echo "Error: cannot determine the stack parent of '$branch': branches '$best' and '$candidate' both sit below it but are unrelated to each other." >&2
      echo "Stack operations require one linear chain per stack. Move or delete the side branch, or rebase it, then try again." >&2
      return 1
    fi
  done < <(git for-each-ref refs/heads --format='%(refname:short)')
  [ -n "$best" ] && echo "$best"
  return 0
}
###--- stack children of a branch (branches based directly on it) ---###
# Errors out if the branch has more than one stack child (a fan-out / diamond):
# stack operations require a single line of branches per stack.
_stack_children_of() {
  local branch="$1"
  local default="${2:-$(_stack_default_branch)}"
  local candidate kids="" kid n
  while read -r candidate; do
    [ -z "$candidate" ] && continue
    [ "$candidate" = "$branch" ] && continue
    [ "$candidate" = "$default" ] && continue
    [ "$candidate" = "HEAD" ] && continue
    git show-ref --verify --quiet "refs/heads/$candidate" || continue
    kid=$(_stack_parent_of "$candidate" "$default") || return 1
    [ "$kid" = "$branch" ] && kids="$kids$candidate"$'\n'
  done < <(git for-each-ref refs/heads --format='%(refname:short)')
  n=$(printf '%s' "$kids" | grep -c . || true)
  if [ "$n" -gt 1 ]; then
    echo "Error: branch '$branch' has multiple stack children:" >&2
    printf '%s' "$kids" | sed 's/^/  /' >&2
    echo "Stack operations require a single line of branches per stack." >&2
    return 1
  fi
  printf '%s' "$kids"
  return 0
}

###--- full stack (root->top, newline-separated) of the stack a branch belongs to ---###
# Down from $branch to the root (the branch directly on the default branch),
# then up from $branch to the deepest descendant (the top).
_stack_chain() {
  local branch="$1"
  local default="${2:-$(_stack_default_branch)}"
  local root="$branch" top="$branch" parent kids cur up="" guard=0

  # walk down to the root (the branch directly on the default branch)
  root="$branch"
  while [ "$guard" -lt 1000 ]; do
    parent=$(_stack_parent_of "$root" "$default") || return 1
    [ -z "$parent" ] && break
    root="$parent"
    guard=$((guard + 1))
  done

  # walk up from $branch to the deepest branch of the stack (the top)
  top="$branch"
  guard=0
  while [ "$guard" -lt 1000 ]; do
    kids=$(_stack_children_of "$top" "$default") || return 1
    [ -z "$kids" ] && break
    top="$kids"
    guard=$((guard + 1))
  done

  # collect from top down to root. Each element is prepended, so by the time
  # the walk reaches the root, $up is already in root->top order (top last).
  cur="$top"
  up=""
  guard=0
  while [ "$cur" != "$root" ] && [ "$guard" -lt 1000 ]; do
    up="$cur"$'\n'"$up"
    cur=$(_stack_parent_of "$cur" "$default") || return 1
    guard=$((guard + 1))
  done
  if [ -n "$up" ]; then
    printf '%s\n%s\n' "$root" "$up"
  else
    printf '%s\n' "$root"
  fi
  return 0
}

###--- resolve the rebase base: origin/<default> if it exists, else local <default> ---###
_stack_base_ref() {
  local default="${1:-$(_stack_default_branch)}"
  if git show-ref --verify --quiet "refs/remotes/origin/$default"; then
    echo "origin/$default"
  else
    echo "$default"
  fi
}

###--- make the worktree clean, stashing if needed (0=clean, 1=stashed, 2=failure) ---###
_stack_ensure_clean() {
  if git diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    return 0
  fi
  echo "Stashing uncommitted changes (they'll be popped back at the end)..."
  if git stash push -u -m "stack auto-stash $(date +%Y-%m-%d\ %H:%M:%S)"; then
    return 1
  fi
  echo "Error: could not stash the uncommitted changes; commit or clean them and retry." >&2
  return 2
}

###--- rebase a list of branches (root->top, newline-separated) onto their new parents ---###
# $1 = onto ref for the walk's first branch (a branch name or the base ref)
# $2 = upstream (old) ref for the walk's first branch
# $3 = newline-separated branch list, oldest->newest
# On a pausable conflict it saves state (step + resume) and returns 1.
# Returns 0 when the whole walk has completed.
_stack_walk_rebase() {
  local onto_first="$1" upstream_first="$2" list="$3"
  local state_dir br onto upstream out rc br_prev="" idx=0
  state_dir=$(_stack_state_dir) || return 1

  while IFS= read -r br; do
    [ -z "$br" ] && continue
    idx=$((idx + 1))
    if [ "$idx" -eq 1 ]; then
      onto="$onto_first"
      upstream="$upstream_first"
    else
      onto="$br_prev"
      upstream=$(_stack_oldtip "$br_prev") || return 1
    fi

    echo "Rebasing '$br' onto '$onto' (upstream: $upstream)..."
    out=$(git rebase --onto "$onto" "$upstream" "$br" 2>&1)
    rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'

    if [ "$rc" -ne 0 ]; then
      if _stack_in_rebase_progress; then
        # pausable conflict: save where we are and stop
        local remaining
        remaining=$(printf '%s\n' "$list" | tail -n +"$((idx + 1))")
        echo "rebase" > "$state_dir/step"
        {
          printf '%s\n' "$br"
          printf '%s' "$remaining"
        } > "$state_dir/resume"
        echo ""
        echo "Stack rebase PAUSED on a conflict in '$br'."
        echo "Resolve the conflicted files, stage them (git add ...), then run the"
        echo "same command again to resume - it picks up where it left off and"
        echo "finishes the rest of the stack. To give up, run it with --abort."
        echo "(If a commit ended up empty, 'git rebase --skip' it first.)"
        echo ""
        echo "Conflicted files:"
        git diff --name-only --diff-filter=U | sed 's/^/  /'
        return 1
      fi
      echo "Error: rebase of '$br' failed (not a pausable conflict)." >&2
      return "$rc"
    fi
    br_prev="$br"
  done <<< "$list"
  return 0
}

###--- finish up: report tips, restore the user's branch, pop stash, clear state ---###
_stack_finalize() {
  local state_dir on br old new mode
  state_dir="$1"
  on=$(cat "$state_dir/on" 2>/dev/null)
  mode=$(cat "$state_dir/mode" 2>/dev/null)

  echo ""
  echo "New branch tips after the stack operation:"
  while read -r br old; do
    [ -z "$br" ] && continue
    new=$(git rev-parse --short "refs/heads/$br" 2>/dev/null) || continue
    if [ "$new" != "$(git rev-parse --short "$old")" ]; then
      echo "  $br: $(git rev-parse --short "$old") -> $new   (use stack-push -f to update the remote)"
    else
      echo "  $br: unchanged at $new"
    fi
  done < "$state_dir/oldtips"

  if [ -n "$on" ]; then
    git switch "$on" >/dev/null 2>&1 || echo "warning: could not switch back to '$on'"
  fi

  if [ -f "$state_dir/stash" ] && [ "$(cat "$state_dir/stash")" = "1" ]; then
    echo "Applying your stashed changes back..."
    git stash pop || echo "warning: 'git stash pop' hit conflicts; your changes are safe in 'git stash list'"
  fi

  rm -rf "$state_dir"

  if [ "$mode" = "inject" ]; then
    echo "Commit moved; the stack is back in line."
  else
    echo "Stack rebase complete."
  fi
  return 0
}

###--- abort a paused stack operation and restore what can be restored ---###
_stack_abort() {
  local state_dir on gd
  state_dir=$(_stack_state_dir) || { echo "Error: not in a git repository" >&2; return 1; }
  if [ ! -d "$state_dir" ]; then
    echo "No stack operation in progress." >&2
    return 1
  fi
  on=$(cat "$state_dir/on" 2>/dev/null)
  gd=$(git rev-parse --git-dir 2>/dev/null)

  if _stack_in_rebase_progress; then
    echo "Aborting the in-progress rebase..."
    git rebase --abort || true
  fi
  if [ -f "$gd/CHERRY_PICK_HEAD" ]; then
    echo "Aborting the in-progress cherry-pick..."
    git cherry-pick --abort || true
  fi

  echo "Note: branches that were already rebased before the pause keep their new tips."
  echo "To restore one of them: git switch <branch> && git reset --hard <branch>@{1} (check git reflog)."

  if [ -n "$on" ]; then
    git switch "$on" >/dev/null 2>&1 || true
  fi
  if [ -f "$state_dir/stash" ] && [ "$(cat "$state_dir/stash")" = "1" ]; then
    git stash pop || true
  fi

  rm -rf "$state_dir"
  echo "Aborted."
  return 0
}

###--- resume a paused REBASE step (either stack command), then finish the walk ---###
_stack_resume_rebase() {
  local state_dir="$1"
  local resume_line paused remaining out rc ref_old ref_now
  resume_line=$(cat "$state_dir/resume" 2>/dev/null)
  if [ -z "$resume_line" ]; then
    echo "Error: stack state exists but no paused rebase is recorded." >&2
    echo "Run '<command> --abort' to clean up, or start over." >&2
    return 1
  fi
  paused=$(printf '%s\n' "$resume_line" | head -1)
  remaining=$(printf '%s\n' "$resume_line" | tail -n +2)
  ref_old=$(_stack_oldtip "$paused") || {
    echo "Error: no old tip recorded for '$paused'; state is corrupt." >&2
    echo "Run '<command> --abort' to clean up." >&2
    return 1
  }

  if _stack_in_rebase_progress; then
    # the normal pause case: the user resolved the conflict, we continue
    echo "Finishing the rebase of '$paused'..."
    out=$(GIT_EDITOR=true git rebase --continue 2>&1)
    rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'
    if [ "$rc" -ne 0 ]; then
      if _stack_in_rebase_progress; then
        echo "Still in progress (another conflict?). Resolve the files, stage them,"
        echo "then run the same stack command again to continue."
        echo "(If a commit ended up empty, 'git rebase --skip' it first.)"
        git diff --name-only --diff-filter=U | sed 's/^/  /'
        return 1
      fi
      echo "Error: 'git rebase --continue' failed and no rebase is in progress anymore." >&2
      return 1
    fi
  else
    # no rebase in progress: the user handled the paused rebase manually
    ref_now=$(git rev-parse --verify --quiet "refs/heads/$paused") || {
      echo "Error: branch '$paused' no longer exists; state is stale." >&2
      echo "Run '<command> --abort' to clean up." >&2
      return 1
    }
    if [ "$ref_now" = "$ref_old" ]; then
      echo "The paused rebase of '$paused' appears to have been aborted (its tip is unchanged)."
      echo "Run '<command> --abort' to clean up the state, or run the command to start over."
      return 1
    fi
    echo "The rebase of '$paused' was finished manually; continuing with the rest of the stack..."
  fi

  if [ -n "$remaining" ]; then
    echo "Continuing with: $(printf '%s' "$remaining" | tr '\n' ' ')"
    if _stack_walk_rebase "$paused" "$ref_old" "$remaining"; then
      _stack_finalize "$state_dir"
      return 0
    fi
    echo "(state saved - run the same command again to resume, or --abort to give up)"
    return 1
  fi

  _stack_finalize "$state_dir"
  return 0
}

###--- stack-rebase: rebase an entire stack (chain) onto the default branch ---###
# Rebase the full stack that a branch belongs to (oldest->top) onto the default
# branch - origin/<default> when it exists, otherwise local <default>.
#
# Usage:
#   stack-rebase             rebase the stack of the current branch
#   stack-rebase <branch>    rebase the stack of <branch>
#   stack-rebase --abort     abort a paused rebase and restore what can be restored
#
# On a conflict the operation pauses and saves state; resolve the files, run the
# same command again, and it resumes and finishes the rest of the stack.
stack-rebase() {
  local state_dir default base root chain stashed=0 ec upstream_root br wt
  local start_branch

  state_dir=$(_stack_state_dir) || { echo "Error: not in a git repository" >&2; return 1; }

  if [ "${1:-}" = "--abort" ]; then
    _stack_abort
    return $?
  fi

  # resume a paused stack-rebase
  if [ -d "$state_dir" ] && [ "$(cat "$state_dir/mode" 2>/dev/null)" = "rebase" ]; then
    _stack_resume_rebase "$state_dir"
    return $?
  fi

  if _stack_in_rebase_progress; then
    echo "Error: a git rebase is already in progress (not started by stack-rebase)." >&2
    if [ -d "$state_dir" ] && [ "$(cat "$state_dir/mode" 2>/dev/null)" = "inject" ]; then
      echo "A stack-inject is paused; run 'stack-inject' (no args) to resume it." >&2
    fi
    echo "Or finish it first (git rebase --continue / --abort)." >&2
    return 1
  fi

  start_branch="${1:-$(git branch --show-current)}"
  if [ -z "$start_branch" ]; then
    echo "Usage: stack-rebase [<branch> | --abort]" >&2
    echo "Error: you're on a detached HEAD; pass the top branch of the stack" >&2
    return 1
  fi
  if ! git show-ref --verify --quiet "refs/heads/$start_branch"; then
    echo "Error: no such branch: $start_branch" >&2
    return 1
  fi

  default=$(_stack_default_branch)
  if [ "$start_branch" = "$default" ]; then
    echo "Already on the default branch ('$default'); nothing to rebase." >&2
    return 1
  fi

  chain=$(_stack_chain "$start_branch" "$default") || return 1
  if [ -z "$chain" ]; then
    echo "Error: could not determine a stack for branch '$start_branch'" >&2
    return 1
  fi
  root=$(printf '%s\n' "$chain" | head -1)
  echo "Stack (oldest->top): $(printf '%s' "$chain" | tr '\n' ' ')"

  # guard: no branch of the stack may be checked out in another worktree
  while IFS= read -r br; do
    [ -z "$br" ] && continue
    wt=$(_stack_worktree_of "$br")
    if [ -n "$wt" ] && [ "$wt" != "$(git rev-parse --show-toplevel)" ]; then
      echo "Error: branch '$br' is checked out in another worktree ($wt)." >&2
      echo "Rebase it from that worktree, or remove it first: git worktree remove $wt" >&2
      return 1
    fi
  done <<< "$chain"

  base=$(_stack_base_ref "$default")
  echo "Rebasing the stack onto $base"
  if [ -n "$(git remote)" ]; then
    echo "Fetching remotes..."
    git fetch --all --prune || echo "warning: fetch failed; continuing with local refs"
  fi

  _stack_ensure_clean
  ec=$?
  [ "$ec" -eq 2 ] && return 1
  [ "$ec" -eq 1 ] && stashed=1

  mkdir -p "$state_dir"
  echo "rebase" > "$state_dir/mode"
  echo "$(git branch --show-current)" > "$state_dir/on"
  [ "$stashed" = "1" ] && echo 1 > "$state_dir/stash"
  : > "$state_dir/oldtips"
  while IFS= read -r br; do
    [ -z "$br" ] && continue
    echo "$br $(git rev-parse "refs/heads/$br")" >> "$state_dir/oldtips"
  done <<< "$chain"
  echo "rebase" > "$state_dir/step"

  upstream_root=$(git merge-base "$base" "refs/heads/$root")
  if [ -z "$upstream_root" ]; then
    echo "Error: no common history between $base and '$root'" >&2
    rm -rf "$state_dir"
    return 1
  fi

  if _stack_walk_rebase "$base" "$upstream_root" "$chain"; then
    _stack_finalize "$state_dir"
    return 0
  fi
  echo "(state saved - run 'stack-rebase' again to resume, or 'stack-rebase --abort' to give up)"
  return 1
}

###--- stack-inject: move a commit from the current branch onto an earlier branch ---###
# You're on a branch of a stack but a fix belongs on an earlier branch of the
# same stack. This takes a commit (by default the top commit of the current
# branch), cherry-picks it onto the earlier branch, then rebases the branches
# from there up to the top of the stack so the chain stays linear. The original
# commit is dropped from the current branch automatically (git detects the
# duplicate patch contents).
#
# Usage:
#   stack-inject <target-branch> [commit]
#       commit defaults to the top commit (HEAD) of the current branch; it must
#       be a commit on the current branch
#   stack-inject             (resume a paused inject)
#   stack-inject --abort     abort a paused inject and restore what can be restored
#
# On a conflict the operation pauses and saves state; resolve the files, run
# 'stack-inject' again, and it resumes (cherry-pick first, then the rebases).
stack-inject() {
  local state_dir default source target commit walk chain stashed=0 ec
  local tpos=0 spos=0 pos=0 past=0 br wt out rc step ref_old ref_now

  state_dir=$(_stack_state_dir) || { echo "Error: not in a git repository" >&2; return 1; }

  if [ "${1:-}" = "--abort" ]; then
    _stack_abort
    return $?
  fi

  # resume a paused stack-inject
  if [ -d "$state_dir" ] && [ "$(cat "$state_dir/mode" 2>/dev/null)" = "inject" ]; then
    step=$(cat "$state_dir/step" 2>/dev/null)
    target=$(cat "$state_dir/inject-target" 2>/dev/null)
    commit=$(cat "$state_dir/inject-commit" 2>/dev/null)
    walk=$(cat "$state_dir/walk" 2>/dev/null)

    if [ "$step" = "cherry-pick" ]; then
      if [ -f "$(git rev-parse --git-dir)/CHERRY_PICK_HEAD" ]; then
        echo "Resuming stack-inject: finishing the cherry-pick of '$commit' onto '$target'..."
        out=$(GIT_EDITOR=true git cherry-pick --continue 2>&1)
        rc=$?
        [ -n "$out" ] && printf '%s\n' "$out"
        if [ "$rc" -ne 0 ]; then
          if [ -f "$(git rev-parse --git-dir)/CHERRY_PICK_HEAD" ]; then
            echo "Cherry-pick still in progress. Resolve the files (git add ...),"
            echo "then run 'stack-inject' again to continue."
            git diff --name-only --diff-filter=U | sed 's/^/  /'
            return 1
          fi
          echo "Error: 'git cherry-pick --continue' failed and the cherry-pick is gone." >&2
          return 1
        fi
      else
        # no cherry-pick in progress: it was handled manually
        ref_old=$(_stack_oldtip "$target") || {
          echo "Error: no old tip recorded for '$target'; state is corrupt." >&2
          echo "Run 'stack-inject --abort' to clean up." >&2
          return 1
        }
        ref_now=$(git rev-parse --verify --quiet "refs/heads/$target") || {
          echo "Error: branch '$target' no longer exists; state is stale." >&2
          echo "Run 'stack-inject --abort' to clean up." >&2
          return 1
        }
        if [ "$ref_now" = "$ref_old" ]; then
          echo "The paused cherry-pick onto '$target' appears to have been aborted (its tip is unchanged)."
          echo "Run 'stack-inject --abort' to clean up the state, or run it again to start over."
          return 1
        fi
        echo "The cherry-pick onto '$target' was finished manually; continuing..."
      fi
      echo "Cherry-pick complete; rebasing the rest of the stack onto the updated '$target'..."
      echo "rebase" > "$state_dir/step"
      if _stack_walk_rebase "$target" "$(_stack_oldtip "$target")" "$walk"; then
        _stack_finalize "$state_dir"
        return 0
      fi
      echo "(state saved - run 'stack-inject' again to resume, or 'stack-inject --abort' to give up)"
      return 1
    fi

    # step = rebase
    _stack_resume_rebase "$state_dir"
    return $?
  fi

  if _stack_in_rebase_progress; then
    echo "Error: a git rebase is already in progress (not started by stack-inject)." >&2
    if [ -d "$state_dir" ] && [ "$(cat "$state_dir/mode" 2>/dev/null)" = "rebase" ]; then
      echo "A stack-rebase is paused; run 'stack-rebase' (no args) to resume it." >&2
    fi
    return 1
  fi

  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: stack-inject <target-branch> [commit] | --abort" >&2
    echo "  commit defaults to the top commit (HEAD) of the current branch" >&2
    return 1
  fi
  target="$1"

  if ! git show-ref --verify --quiet "refs/heads/$target"; then
    echo "Error: no such branch: $target" >&2
    return 1
  fi

  source=$(git branch --show-current)
  if [ -z "$source" ]; then
    echo "Error: you must be on a branch (detached HEAD is not supported)" >&2
    return 1
  fi
  if [ "$source" = "$target" ]; then
    echo "Error: target must be an EARLIER branch in the chain, not the current one ('$source')" >&2
    return 1
  fi

  commit="${2:-HEAD}"
  if ! git rev-parse --verify --quiet "${commit}^{commit}" >/dev/null; then
    echo "Error: '$commit' is not a commit in this repo" >&2
    return 1
  fi
  commit=$(git rev-parse "${commit}^{commit}")
  if ! git merge-base --is-ancestor "$commit" "refs/heads/$source"; then
    echo "Error: '$commit' is not a commit on branch '$source'" >&2
    return 1
  fi

  default=$(_stack_default_branch)
  chain=$(_stack_chain "$source" "$default") || return 1
  while IFS= read -r br; do
    [ -z "$br" ] && continue
    pos=$((pos + 1))
    [ "$br" = "$target" ] && tpos=$pos
    [ "$br" = "$source" ] && spos=$pos
  done <<< "$chain"
  if [ "$tpos" -eq 0 ]; then
    echo "Error: '$target' is not in the same stack as '$source'." >&2
    echo "Stack (oldest->top): $(printf '%s' "$chain" | tr '\n' ' ')" >&2
    return 1
  fi
  if [ "$tpos" -ge "$spos" ]; then
    echo "Error: target '$target' must be EARLIER (below) than '$source' in the stack." >&2
    return 1
  fi
  if git merge-base --is-ancestor "$commit" "refs/heads/$target"; then
    echo "Error: that commit is already on '$target'; nothing to move." >&2
    return 1
  fi

  # branches that will be rebased: everything AFTER $target up to the TOP of the
  # stack (branches above $source are affected too - their base moves as well).
  # $target itself is NOT rebased: it was just extended by the cherry-pick.
  walk=""
  past=0
  while IFS= read -r br; do
    [ -z "$br" ] && continue
    [ "$past" = "1" ] && walk="$walk$br"$'\n'
    [ "$br" = "$target" ] && past=1
  done <<< "$chain"

  # guard: none of the affected branches may be checked out in another worktree
  while IFS= read -r br; do
    [ -z "$br" ] && continue
    wt=$(_stack_worktree_of "$br")
    if [ -n "$wt" ] && [ "$wt" != "$(git rev-parse --show-toplevel)" ]; then
      echo "Error: branch '$br' is checked out in another worktree ($wt)." >&2
      echo "Do the inject from that worktree, or remove it first: git worktree remove $wt" >&2
      return 1
    fi
  done <<< "$target"$'\n'"$walk"

  _stack_ensure_clean
  ec=$?
  [ "$ec" -eq 2 ] && return 1
  [ "$ec" = "1" ] && stashed=1

  mkdir -p "$state_dir"
  echo "inject" > "$state_dir/mode"
  echo "$source" > "$state_dir/on"
  [ "$stashed" = "1" ] && echo 1 > "$state_dir/stash"
  echo "$target" > "$state_dir/inject-target"
  echo "$commit" > "$state_dir/inject-commit"
  printf '%s' "$walk" > "$state_dir/walk"
  : > "$state_dir/oldtips"
  echo "$target $(git rev-parse "refs/heads/$target")" >> "$state_dir/oldtips"
  while IFS= read -r br; do
    [ -z "$br" ] && continue
    echo "$br $(git rev-parse "refs/heads/$br")" >> "$state_dir/oldtips"
  done <<< "$walk"
  echo "cherry-pick" > "$state_dir/step"

  echo "Moving '$(git log --no-walk --pretty=format:'%h %s' "$commit")' from '$source' onto '$target'..."
  if ! git switch "$target"; then
    echo "Error: could not switch to '$target'" >&2
    rm -rf "$state_dir"
    return 1
  fi

  out=$(git cherry-pick "$commit" 2>&1)
  rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  if [ "$rc" -eq 0 ]; then
    echo "Cherry-pick complete; rebasing the rest of the stack onto the updated '$target'..."
    echo "rebase" > "$state_dir/step"
    if _stack_walk_rebase "$target" "$(_stack_oldtip "$target")" "$walk"; then
      _stack_finalize "$state_dir"
      return 0
    fi
    echo "(state saved - run 'stack-inject' again to resume, or 'stack-inject --abort' to give up)"
    return 1
  fi

  if [ -f "$(git rev-parse --git-dir)/CHERRY_PICK_HEAD" ]; then
    echo ""
    echo "Cherry-pick PAUSED on a conflict. Resolve the files, stage them (git add ...),"
    echo "then run 'stack-inject' again to continue - it will finish the cherry-pick,"
    echo "then rebase the rest of the stack."
    echo ""
    echo "Conflicted files:"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    return 1
  fi

  echo "Error: cherry-pick of the commit onto '$target' failed (not a pausable conflict)." >&2
  git cherry-pick --abort 2>/dev/null
  rm -rf "$state_dir"
  git switch "$source" >/dev/null 2>&1 || true
  return 1
}

###--- stack-push: push the branches in the stack to origin, oldest->newest ---###
# Pushes each branch of the stack in order so the remote chain ends up in the
# same order as the local one. Branches whose remote copy is already up to
# date are skipped.
#
# Branches that were rewritten (e.g. by a stack-rebase) have a remote copy
# that no longer matches: by default they are refused with a hint to run
# 'git fpush <branch>'; with -f/--force they are pushed with
# --force-with-lease (which still protects against overwriting remote commits
# that you don't have locally).
#
# Usage:
#   stack-push             push the stack of the current branch
#   stack-push <branch>    push the stack of <branch>
#   stack-push -f [--branch]  use force-with-lease for rewritten branches
stack-push() {
  local state_dir default start_branch br out rc failed=0 force=0
  local local_tip remote_tip chain
  local remote="origin"

  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--force) force=1 ;;
      --) shift; break ;;
      -*) echo "Error: unknown option: $1" >&2; echo "Usage: stack-push [-f|--force] [<branch>]" >&2; return 1 ;;
      *) break ;;
    esac
    shift
  done

  state_dir=$(_stack_state_dir) || { echo "Error: not in a git repository" >&2; return 1; }

  if _stack_in_rebase_progress || [ -f "$(git rev-parse --git-dir 2>/dev/null)/CHERRY_PICK_HEAD" ]; then
    echo "Error: a rebase/cherry-pick is in progress; finish it first (run 'stack-rebase' or 'stack-inject' to resume, or --abort to give up)." >&2
    return 1
  fi

  start_branch="${1:-$(git branch --show-current)}"
  if [ -z "$start_branch" ]; then
    echo "Usage: stack-push [-f|--force] [<branch>]" >&2
    echo "Error: you're on a detached HEAD; pass the top branch of the stack" >&2
    return 1
  fi
  if ! git show-ref --verify --quiet "refs/heads/$start_branch"; then
    echo "Error: no such branch: $start_branch" >&2
    return 1
  fi
  if ! git remote get-url "$remote" >/dev/null 2>&1; then
    echo "Error: no '$remote' remote in this repo; add one (git remote add origin <url>) or push manually." >&2
    return 1
  fi

  default=$(_stack_default_branch)
  if [ "$start_branch" = "$default" ]; then
    echo "On the default branch ('$default'); push it the normal way (git push)." >&2
    return 1
  fi

  chain=$(_stack_chain "$start_branch" "$default") || return 1
  echo "Pushing the stack to $remote (oldest->newest): $(printf '%s' "$chain" | tr '\n' ' ')"

  while IFS= read -r br; do
    [ -z "$br" ] && continue
    local_tip=$(git rev-parse "refs/heads/$br")
    if git show-ref --verify --quiet "refs/remotes/$remote/$br"; then
      remote_tip=$(git rev-parse "refs/remotes/$remote/$br")
      if [ "$local_tip" = "$remote_tip" ]; then
        echo "  $br: already up to date"
        continue
      fi
      if ! git merge-base --is-ancestor "$remote_tip" "refs/heads/$br" 2>/dev/null; then
        if [ "$force" = 1 ]; then
          out=$(git push --force-with-lease="$br:$remote_tip" "$remote" "$br" 2>&1)
          rc=$?
          [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'
          if [ "$rc" -ne 0 ]; then
            echo "Error: force push of '$br' to $remote failed (is $remote/$br updated by someone else?)." >&2
            failed=1
            break
          fi
          echo "  $br: force-pushed (with lease)"
          continue
        fi
        if git merge-base --is-ancestor "$local_tip" "$remote_tip" 2>/dev/null; then
          echo "Error: $remote/$br is AHEAD of $br (it has commits you don't have)." >&2
          echo "Update your branch first (e.g. stack-rebase) or push manually." >&2
        else
          echo "Error: $remote/$br has diverged from $br - typical after a stack-rebase, the remote copy is stale." >&2
          echo "Push it with force-with-lease:  stack-push -f     (or: git fpush $br)" >&2
        fi
        failed=1
        break
      fi
    fi
    out=$(git push "$remote" "$br" 2>&1)
    rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/  /'
    if [ "$rc" -ne 0 ]; then
      echo "Error: push of '$br' to $remote failed." >&2
      failed=1
      break
    fi
    echo "  $br: pushed"
  done <<< "$chain"

  if [ "$failed" = 1 ]; then
    return 1
  fi
  echo "Stack pushed."
  return 0
}
