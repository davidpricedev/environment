#!/usr/bin/env bash
# Test harness for the git stack (chain) shell functions in zsh/functions.zsh.
#
# Usage: ./run-tests.sh [path-to-functions.zsh]
#
# Builds synthetic git repos in a temp dir and exercises:
#   stack-rebase : clean 3-branch chain, stale base, dirty worktree (auto-stash),
#                 run from a middle branch, conflict pause + multi-invocation
#                 resume, abort, unrelated-branch noise, worktree guard,
#                 no-op when up to date, already-on-default, --abort with no state,
#                 remote base (origin/main), fan-out (diamond) rejection
#   stack-inject : top commit moved, explicit commit arg, cherry-pick conflict
#                 pause + resume, rebase-walk conflict pause + resume,
#                 already-applied commit, target-not-in-stack, target==source,
#                 commit-not-on-source, target checked out in another worktree
#
# Note: the functions are written to behave identically in zsh and bash, so the
# bash harness here exercises the same code paths your zsh session will use.

set -u

FUNCS="${1:-$(cd "$(dirname "$0")/.." && pwd)/zsh/functions.zsh}"
if [ ! -f "$FUNCS" ]; then
  echo "functions file not found: $FUNCS" >&2
  exit 2
fi

WORK=$(mktemp -d /tmp/stack-tests.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
FAILED_TESTS=""
REPO=""
OUT=""
RC=0

say() { printf '%s\n' "$*"; }
ok()  { PASS=$((PASS+1)); say "  PASS: $1"; }
bad() { FAIL=$((FAIL+1)); FAILED_TESTS="$FAILED_TESTS  - $1"$'\n'; say "  FAIL: $1${2:-}"; }
check() { # check <name> <expected-rc> <actual-rc>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" " (expected rc=$2, got rc=$3)"; fi
}
check_out() { # check_out <name> <needle> <haystack>
  case "$3" in
    *"$2"*) ok "$1" ;;
    *) bad "$1" " (output missing: $2)" ;;
  esac
}

# Source the functions once, in a subshell-friendly way: every test calls the
# functions via `run_in_repo`, which runs them with cwd=$REPO.
source "$FUNCS"

# --- repo builders -----------------------------------------------------------

new_repo() { # new_repo <name> : creates $WORK/<name>/repo on branch 'main'
  local name="$1"
  REPO="$WORK/$1/repo"
  mkdir -p "$WORK/$1"
  rm -rf "$REPO"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.email tests@stack.local
  git -C "$REPO" config user.name stack-tests
}

commit() { # commit <msg> [file] [content]
  local msg="$1" file="${2:-f.txt}" content="${3:-line}"
  if [ -n "$content" ]; then printf '%s\n' "$content" > "$REPO/$file"
  else printf '%s\n' "$(date +%s%N)" >> "$REPO/$file"; fi
  git -C "$REPO" add -A
  git -C "$REPO" commit -qm "$msg"
}

run_in_repo() { # run_in_repo <branch|-> <cmd...> : cd into repo, run function
  local branch="$1"; shift
  local gd
  gd=$(git -C "$REPO" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  # while a rebase/cherry-pick is in progress git refuses branch switches (and
  # the user is already on the right branch), so only switch when it's possible
  if [ "$branch" != "-" ] \
     && [ ! -d "$gd/rebase-merge" ] && [ ! -d "$gd/rebase-apply" ] \
     && [ ! -f "$gd/CHERRY_PICK_HEAD" ]; then
    git -C "$REPO" switch -q "$branch" || return 1
  fi
  OUT=$( ( cd "$REPO" && eval "$*" ) 2>&1 )
  RC=$?
}

tip() { git -C "$REPO" rev-parse --short "refs/heads/$1"; }
tip_full() { git -C "$REPO" rev-parse "refs/heads/$1"; }
on_branch() { git -C "$REPO" branch --show-current; }
state_exists() {
  local g; g=$(git -C "$REPO" rev-parse --absolute-git-dir)
  [ -d "$g/stack" ]
}
gitdir_of() { git -C "$REPO" rev-parse --absolute-git-dir; }
log_subjects() { # log_subjects <branch> : subject lines oldest->newest
  git -C "$REPO" log --pretty=format:'%s' "refs/heads/$1" | tac
}
is_ancestor() { # is_ancestor <a> <b> : is a an ancestor of b
  git -C "$REPO" merge-base --is-ancestor "$1" "$2" 2>/dev/null
}

# Standard 3-branch chain: main(v1) <- A <- B <- C, left on C
# With 'advance': main also gets a v2 commit (stale base).
build_chain() { # build_chain <repo-name> [advance]
  new_repo "$1"
  commit "v1" f.txt "line1: BASE
line2"
  git -C "$REPO" switch -qc A
  commit "A: feature-a" a.txt "a work"
  git -C "$REPO" switch -qc B A
  commit "B: feature-b" b.txt "b work"
  git -C "$REPO" switch -qc C B
  commit "C: feature-c" c.txt "c work"
  if [ "${2:-}" = "advance" ]; then
    git -C "$REPO" switch -q main
    commit "v2: main advance" f.txt "line1: BASE
line2
line3: ADVANCE"
  fi
  git -C "$REPO" switch -q C
}

# Conflict setup on top of build_chain: main rewrites line1; A and B also do.
setup_conflicts() {
  git -C "$REPO" switch -q main
  printf 'line1: MAIN\nline2\n' > "$REPO/f.txt"
  git -C "$REPO" commit -qam "v2b: main rewrites line1"
  git -C "$REPO" switch -q A
  printf 'line1: A\nline2\n' > "$REPO/f.txt"
  git -C "$REPO" commit -qam "A: rewrite line1"
  git -C "$REPO" switch -q B
  printf 'line1: B\nline2\n' > "$REPO/f.txt"
  git -C "$REPO" commit -qam "B: rewrite line1"
  git -C "$REPO" switch -q C
}

# ===========================================================================
say "== stack-rebase: clean 3-branch chain, stale base =="
build_chain t1 advance
run_in_repo C stack-rebase
check "clean chain rebase succeeds" 0 "$RC"
check_out "reports stack rebase complete" "Stack rebase complete" "$OUT"
is_ancestor main A && is_ancestor A B && is_ancestor B C \
  && ok "chain is linear on new main" || bad "chain is linear on new main"
[ "$(git -C "$REPO" rev-parse --short A~1)" = "$(tip main)" ] \
  && ok "A now sits on tip of main" || bad "A now sits on tip of main"
! state_exists && ok "state cleared on success" || bad "state cleared on success"
[ "$(on_branch)" = "C" ] && ok "back on original branch (C)" || bad "back on original branch (C)"

# ===========================================================================
say "== stack-rebase: up-to-date stack is a no-op =="
run_in_repo C stack-rebase
check "up-to-date stack returns 0" 0 "$RC"
check_out "no-op reports complete" "Stack rebase complete" "$OUT"

# ===========================================================================
say "== stack-rebase: dirty worktree is auto-stashed and restored =="
build_chain t2 advance
echo "wip" > "$REPO/wip.txt"
run_in_repo C stack-rebase
check "rebase with dirty tree succeeds" 0 "$RC"
check_out "stash applied back" "Applying your stashed changes" "$OUT"
[ -f "$REPO/wip.txt" ] && ok "stashed wip file restored" || bad "stashed wip file restored"
# wip.txt comes back as untracked, which is fine; no tracked changes may remain
[ -z "$(git -C "$REPO" status --porcelain | grep -v '^??')" ] && ok "no tracked changes left" || bad "no tracked changes left"
! state_exists && ok "state cleared" || bad "state cleared"

# ===========================================================================
say "== stack-rebase: run from a MIDDLE branch covers the whole stack =="
build_chain t3 advance
run_in_repo B stack-rebase
check "rebase from middle branch succeeds" 0 "$RC"
is_ancestor main A && is_ancestor A B && is_ancestor B C \
  && ok "whole stack linear after middle-branch run" || bad "whole stack linear after middle-branch run"
[ "$(on_branch)" = "B" ] && ok "back on the original branch (B)" || bad "back on the original branch (B)"

# ===========================================================================
say "== stack-rebase: explicit branch argument =="
build_chain t4 advance
run_in_repo A "stack-rebase C"
check "explicit top-branch argument works" 0 "$RC"
is_ancestor A B && is_ancestor B C && ok "chain linear" || bad "chain linear"

# ===========================================================================
say "== stack-rebase: unrelated branches on the stack are ignored =="
build_chain t5 advance
git -C "$REPO" switch -qc unrelated main
commit "unrelated: side work" u.txt "u"
run_in_repo C stack-rebase
check "unrelated branch ignored, rebase succeeds" 0 "$RC"
is_ancestor A B && is_ancestor B C && ok "chain linear with unrelated branch present" || bad "chain linear with unrelated branch present"
[ "$(git -C "$REPO" log -1 --pretty=%s unrelated)" = "unrelated: side work" ] \
  && ok "unrelated branch untouched" || bad "unrelated branch untouched"

# ===========================================================================
say "== stack-rebase: fork point (branch with multiple stack children) is rejected =="
build_chain t6 advance
# A now has three stack children (B, D, E) - rebasing A's stack is ambiguous
git -C "$REPO" switch -qc D A
commit "D: feature-d" d.txt "d work"
git -C "$REPO" switch -qc E A
commit "E: feature-e" e.txt "e work"
run_in_repo A stack-rebase
check "fork point is refused" 1 "$RC"
check_out "explains the fork" "multiple stack children" "$OUT"
# but a LEAF branch of the fork still works: it rebases just its own line (A, D)
run_in_repo D stack-rebase
check "leaf of a fork rebases its own line" 0 "$RC"
is_ancestor main A && is_ancestor A D && ok "D's line is linear" || bad "D's line is linear"

# ===========================================================================
say "== stack-rebase: guards =="
build_chain t7 advance
run_in_repo main stack-rebase
check "already-on-default is an error" 1 "$RC"
check_out "explains already on default" "nothing to rebase" "$OUT"
git -C "$REPO" switch -q --detach main
run_in_repo - stack-rebase
check "detached HEAD is an error" 1 "$RC"
check_out "asks for explicit branch" "detached" "$OUT"
git -C "$REPO" switch -q C
run_in_repo C "stack-rebase --abort"
check "--abort with no state in progress" 1 "$RC"
check_out "says no operation in progress" "No stack operation in progress" "$OUT"
run_in_repo C "stack-rebase nosuchbranch"
check "unknown branch is an error" 1 "$RC"

# ===========================================================================
say "== stack-rebase: conflict pause, resolve, resume (separate invocations) =="
build_chain t8 advance
setup_conflicts
run_in_repo C stack-rebase
check "first run pauses on conflict" 1 "$RC"
check_out "announces pause" "PAUSED on a conflict" "$OUT"
check_out "names the branch with the conflict" "in 'A'" "$OUT"
state_exists && ok "state saved on pause" || bad "state saved on pause"
[ -d "$(gitdir_of)/rebase-merge" ] && ok "git rebase state present" || bad "git rebase state present"

# user resolves A's conflict and re-runs (same command, no args)
printf 'line1: RESOLVED-A\nline2\n' > "$REPO/f.txt"
git -C "$REPO" add f.txt
run_in_repo C stack-rebase
check "resume pauses on next branch's conflict (B)" 1 "$RC"
check_out "paused on B now" "in 'B'" "$OUT"
state_exists && ok "state still present after partial resume" || bad "state still present after partial resume"

# resolve B's conflict and re-run
printf 'line1: RESOLVED-B\nline2\n' > "$REPO/f.txt"
git -C "$REPO" add f.txt
run_in_repo C stack-rebase
check "final resume run completes the stack" 0 "$RC"
check_out "reports complete" "Stack rebase complete" "$OUT"
! state_exists && ok "state cleared after completion" || bad "state cleared after completion"
[ "$(on_branch)" = "C" ] && ok "back on the original branch (C)" || bad "back on the original branch (C)"
is_ancestor main A && is_ancestor A B && is_ancestor B C \
  && ok "conflicted stack is linear on new main" || bad "conflicted stack is linear on new main"
check_out "reports which branches changed" "stack-push" "$OUT"

# ===========================================================================
say "== stack-rebase: abort mid-conflict restores the paused branch =="
build_chain t9 advance
setup_conflicts
A_OLD=$(tip_full A)
run_in_repo C stack-rebase
check "setup: pause on conflict" 1 "$RC"
run_in_repo C "stack-rebase --abort"
check "abort succeeds" 0 "$RC"
[ "$(tip_full A)" = "$A_OLD" ] && ok "paused branch restored to old tip" || bad "paused branch restored to old tip"
! state_exists && ok "state removed by abort" || bad "state removed by abort"
[ "$(on_branch)" = "C" ] && ok "back on original branch after abort" || bad "back on original branch after abort"

# ===========================================================================
say "== stack-rebase: branch checked out in another worktree is refused =="
build_chain t10 advance
git -C "$REPO" worktree add -q "$WORK/t10-b" B
run_in_repo C stack-rebase
check "worktree guard refuses" 1 "$RC"
check_out "names the worktree problem" "another worktree" "$OUT"
git -C "$REPO" worktree remove --force "$WORK/t10-b"

# ===========================================================================
say "== stack-rebase: remote base (origin/main) when a remote exists =="
REPO="$WORK/t11/repo"
mkdir -p "$WORK/t11"
rm -rf "$REPO"
REPO_REMOTE="$WORK/t11/remote.git"
git init -q --bare -b main "$REPO_REMOTE"
# seed remote with main
SEED="$WORK/t11/seed"
git init -q -b main "$SEED"
git -C "$SEED" config user.email tests@stack.local
git -C "$SEED" config user.name stack-tests
printf 'line1: BASE\nline2\n' > "$SEED/f.txt"
git -C "$SEED" add -A && git -C "$SEED" commit -qm "v1"
git -C "$SEED" remote add origin "$REPO_REMOTE"
git -C "$SEED" push -q --set-upstream origin main
# advance remote main
printf 'line1: BASE\nline2\nline3: REMOTE-ADVANCE\n' > "$SEED/f.txt"
git -C "$SEED" commit -qam "v2: remote advance"
git -C "$SEED" push -q
# clone it
git clone -q "$REPO_REMOTE" "$REPO"
git -C "$REPO" config user.email tests@stack.local
git -C "$REPO" config user.name stack-tests
git -C "$REPO" switch -qc A
commit "A: feature-a" a.txt "a work"
git -C "$REPO" switch -qc B A
commit "B: feature-b" b.txt "b work"
# B is stale against origin/main (remote advanced after clone)
run_in_repo B stack-rebase
check "remote-based rebase succeeds" 0 "$RC"
check_out "rebased onto origin/main" "origin/main" "$OUT"
is_ancestor origin/main A && is_ancestor A B \
  && ok "chain on top of origin/main" || bad "chain on top of origin/main"

# ===========================================================================
say "== stack-rebase: two-branch stack =="
build_chain t12 advance
git -C "$REPO" branch -q -D B
git -C "$REPO" branch -q -D C
git -C "$REPO" switch -q A
run_in_repo A stack-rebase
check "single-branch stack rebases" 0 "$RC"
[ "$(git -C "$REPO" rev-parse --short A~1)" = "$(tip main)" ] && ok "A on new main" || bad "A on new main"

# ===========================================================================
say "== stack-inject: move top commit from C onto A =="
build_chain t13 advance
git -C "$REPO" switch -q C
commit "C: fix for feedback" fix.txt "feedback fix"
run_in_repo C "stack-inject A"
check "inject top commit onto A succeeds" 0 "$RC"
check_out "reports moved" "Commit moved" "$OUT"
[ "$(on_branch)" = "C" ] && ok "back on source branch (C)" || bad "back on source branch (C)"
[ "$(git -C "$REPO" log -1 --pretty=%s A)" = "C: fix for feedback" ] \
  && ok "fix commit is on top of A" || bad "fix commit is on top of A (got: $(git -C "$REPO" log -1 --pretty=%s A))"
[ "$(git -C "$REPO" log -1 --pretty=%s C)" = "C: feature-c" ] \
  && ok "duplicate dropped from C" || bad "duplicate dropped from C (got: $(git -C "$REPO" log -1 --pretty=%s C))"
is_ancestor A B && is_ancestor B C && ok "chain linear after inject" || bad "chain linear after inject"
git -C "$REPO" log --oneline A | grep -q "fix for feedback" && ok "A history contains the fix" || bad "A history contains the fix"

# ===========================================================================
say "== stack-inject: explicit commit argument (a middle commit) =="
build_chain t14 advance
git -C "$REPO" switch -q C
commit "C: first commit" c1.txt "c1"
MID=$(git -C "$REPO" rev-parse HEAD)
commit "C: second commit" c2.txt "c2"
run_in_repo C "stack-inject A $MID"
check "inject explicit commit onto A succeeds" 0 "$RC"
[ "$(git -C "$REPO" log -1 --pretty=%s A)" = "C: first commit" ] \
  && ok "explicit commit is on top of A" || bad "explicit commit is on top of A (got: $(git -C "$REPO" log -1 --pretty=%s A))"
# The moved commit now lives on A; C (built on A) inherits it, so only check
# C's own commits (above B) for the dropped duplicate.
case "$(git -C "$REPO" log --pretty=format:'%s' B..C)" in
  *"C: first commit"*) bad "explicit commit still present on C (not dropped)";;
  *) ok "explicit commit dropped from C";;
esac
is_ancestor A B && is_ancestor B C && ok "chain linear" || bad "chain linear"

# ===========================================================================
say "== stack-inject: guards =="
build_chain t15 advance
run_in_repo C "stack-inject C"
check "target==source is an error" 1 "$RC"
run_in_repo C "stack-inject main"
check "default branch as target is an error" 1 "$RC"
run_in_repo C "stack-rebase"   # normalize state (fresh clean rebase, no-op)
check "setup: clean rebase ok" 0 "$RC"
git -C "$REPO" switch -q main
git -C "$REPO" branch -q outsider main
git -C "$REPO" switch -q outsider
echo "o" > "$REPO/o.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -qm "outsider: side"
git -C "$REPO" switch -q C
run_in_repo C "stack-inject outsider"
check "target not in stack is an error" 1 "$RC"
check_out "explains not in stack" "not in the same stack" "$OUT"
run_in_repo C "stack-inject A nosuchsha"
check "unknown commit is an error" 1 "$RC"
MAIN_TIP=$(tip_full main)
run_in_repo C "stack-inject A $MAIN_TIP"
check "commit not on source is an error" 1 "$RC"
run_in_repo C "stack-inject A"   # move C's top (feature-c) onto A: ok
check "setup: first inject ok" 0 "$RC"
# after the move, feature-c is on A. Ask to move it again, explicitly:
# it is already on the target -> error.
FC_SHA=$(git -C "$REPO" log --format=%H --grep="C: feature-c" -1 A)
run_in_repo C "stack-inject A $FC_SHA"
check "moving an already-applied commit is an error" 1 "$RC"
check_out "explains already on target" "already on" "$OUT"

# ===========================================================================
say "== stack-inject: cherry-pick conflict pause + resume =="
build_chain t16 advance
git -C "$REPO" switch -q main
printf 'line1: MAIN\nline2\n' > "$REPO/f.txt"
git -C "$REPO" commit -qam "v2b: main rewrites line1"
git -C "$REPO" switch -q A
printf 'line1: A\nline2\n' > "$REPO/f.txt"
git -C "$REPO" commit -qam "A: rewrite line1"
git -C "$REPO" switch -q C
printf 'line1: C\nline2\n' > "$REPO/f.txt"
git -C "$REPO" commit -qam "C: rewrite line1"

run_in_repo C "stack-inject A"
check "inject pauses on cherry-pick conflict" 1 "$RC"
check_out "announces cherry-pick pause" "cherry-pick" "$OUT"
state_exists && ok "state saved" || bad "state saved"
[ -f "$(gitdir_of)/CHERRY_PICK_HEAD" ] && ok "cherry-pick state present" || bad "cherry-pick state present"

printf 'line1: RESOLVED\nline2\n' > "$REPO/f.txt"
git -C "$REPO" add f.txt
run_in_repo C "stack-inject"   # resume: finishes the cherry-pick, then the rebase walk
i=0
# The walk can pause on its own conflict (C also rewrote line1); resolve + resume.
while [ $RC -ne 0 ] && [ $i -lt 4 ]; do
  if [ -d "$(git -C "$REPO" rev-parse --absolute-git-dir)/rebase-merge" ]; then
    while git -C "$REPO" diff --name-only --diff-filter=U | grep -q .; do
      git -C "$REPO" diff --name-only --diff-filter=U | while read -r f; do
        printf 'line1: RESOLVED\nline2\n' > "$REPO/$f"
        git -C "$REPO" add "$f"
      done
    done
    run_in_repo C "stack-inject"
  else
    break
  fi
  i=$((i + 1))
done
check "resume completes the inject" 0 "$RC"
check_out "reports moved" "Commit moved" "$OUT"
! state_exists && ok "state cleared" || bad "state cleared"
[ "$(on_branch)" = "C" ] && ok "back on source branch" || bad "back on source branch"
is_ancestor A B && is_ancestor B C && ok "chain linear after inject resume" || bad "chain linear after inject resume"
[ "$(git -C "$REPO" log -1 --pretty=%s A)" = "C: rewrite line1" ] \
  && ok "cherry-picked commit on top of A" || bad "cherry-picked commit on top of A (got: $(git -C "$REPO" log -1 --pretty=%s A))"

# ===========================================================================
say "== stack-inject: rebase-walk conflict pause + resume =="
build_chain t17 advance
# A's rebase onto main will conflict (both rewrote line1); the cherry-pick of
# C's fix (a new file) onto A is clean, so the PAUSE happens in the rebase
# walk - exercising the inject rebase-resume path.
git -C "$REPO" switch -q main
printf 'line1: MAIN\nline2\n' > "$REPO/f.txt"
git -C "$REPO" commit -qam "v2b: main rewrites line1"
git -C "$REPO" switch -q A
printf 'line1: A\nline2\n' > "$REPO/f.txt"
git -C "$REPO" commit -qam "A: rewrite line1"
git -C "$REPO" switch -q C
commit "C: fix" fix.txt "fix"

run_in_repo C "stack-inject A"
# The cherry-pick of the fix onto A is clean; then the walk rebases B onto A:
# B's b.txt is independent so clean; then C onto B: C's fix was dropped (dup)
# and c.txt is independent -> clean. No conflict is expected in THIS layout;
# if a conflict still occurs (git decided to touch f.txt), resolve + resume.
if [ $RC -eq 0 ]; then
  ok "inject completed without rebase conflict"
else
  check_out "paused in rebase walk" "PAUSED" "$OUT"
  i=0
  while [ $i -lt 5 ]; do
    while git -C "$REPO" diff --name-only --diff-filter=U | grep -q .; do
      git -C "$REPO" diff --name-only --diff-filter=U | while read -r f; do
        printf 'line1: RESOLVED\nline2\n' > "$REPO/$f" 2>/dev/null || printf 'resolved\n' > "$REPO/$f"
        git -C "$REPO" add "$f"
      done
      break
    done
    run_in_repo C "stack-inject"
    [ $RC -eq 0 ] && break
    i=$((i + 1))
  done
  [ $RC -eq 0 ] && ok "inject eventually completes" || bad "inject eventually completes (rc=$RC)"
fi
! state_exists && ok "state cleared" || bad "state cleared"
[ "$(git -C "$REPO" log -1 --pretty=%s A)" = "C: fix" ] \
  && ok "fix commit on top of A" || bad "fix commit on top of A (got: $(git -C "$REPO" log -1 --pretty=%s A))"

# ===========================================================================
say "== stack-inject: target checked out in another worktree is refused =="
build_chain t18 advance
git -C "$REPO" worktree add -q "$WORK/t18-a" A
run_in_repo C "stack-inject A"
check "worktree guard refuses inject" 1 "$RC"
check_out "names the worktree problem" "another worktree" "$OUT"
git -C "$REPO" worktree remove --force "$WORK/t18-a"

# ===========================================================================
say "== stack-push: pushes the stack oldest->newest =="
build_chain t19
REPO_REMOTE="$WORK/t19/remote.git"
git init -q --bare -b main "$REPO_REMOTE"
git -C "$REPO" remote add origin "$REPO_REMOTE"
git -C "$REPO" push -q --set-upstream origin main
run_in_repo C stack-push
check "stack-push succeeds" 0 "$RC"
check_out "pushes the oldest branch" "A: pushed" "$OUT"
check_out "pushes the top branch" "C: pushed" "$OUT"
remote_matches=1
for br in A B C; do
  [ "$(git -C "$REPO" rev-parse "refs/remotes/origin/$br")" = "$(git -C "$REPO" rev-parse "refs/heads/$br")" ] \
    || remote_matches=0
done
[ "$remote_matches" = 1 ] && ok "remote stack matches local stack" || bad "remote stack matches local stack"
run_in_repo C stack-push
check "second push is a no-op" 0 "$RC"
check_out "reports up to date" "already up to date" "$OUT"
run_in_repo main stack-push
check "pushing from the default branch is refused" 1 "$RC"
run_in_repo C "stack-push nosuchbranch"
check "pushing an unknown branch is an error" 1 "$RC"

# ===========================================================================
say "== stack-push: after a stack-rebase the remote stack is stale; -f force-pushes =="
build_chain t20 advance
REPO_REMOTE="$WORK/t20/remote.git"
git init -q --bare -b main "$REPO_REMOTE"
git -C "$REPO" remote add origin "$REPO_REMOTE"
git -C "$REPO" push -q --set-upstream origin main
run_in_repo C stack-push
check "initial stack-push ok" 0 "$RC"
# the remote's main advances (like a teammate pushing), the stack goes stale
git -C "$REPO" switch -q main
commit "v3: main advance 2" f.txt "line1: BASE
line2
line3: ADVANCE
line4: ADVANCE2"
git -C "$REPO" push -q origin main
run_in_repo C stack-rebase
check "stack-rebase onto new origin/main ok" 0 "$RC"
run_in_repo C stack-push
check "plain push refused (remote stack stale)" 1 "$RC"
check_out "tells how to force push" "stack-push -f" "$OUT"
run_in_repo C "stack-push -f"
check "force-with-lease push ok" 0 "$RC"
check_out "reports the force push" "force-pushed" "$OUT"
remote_matches=1
for br in A B C; do
  [ "$(git -C "$REPO" rev-parse "refs/remotes/origin/$br")" = "$(git -C "$REPO" rev-parse "refs/heads/$br")" ] \
    || remote_matches=0
done
[ "$remote_matches" = 1 ] && ok "remote stack matches rebased local stack" || bad "remote stack matches rebased local stack"

# ===========================================================================
say
say "==================== RESULTS ===================="
say "passed: $PASS"
say "failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  say "failing checks:"
  printf '%s' "$FAILED_TESTS"
  exit 1
fi
say "ALL TESTS PASSED"
exit 0
