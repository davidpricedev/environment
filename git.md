# Git

## Config

- run `git config --global push.default current` to make `git push` work as desired
- run `git config --global --add --bool push.autoSetupRemote true` to have `git push` work right away (without doing all the tracking branch wiring) - Note: this one requires git version 2.37 or beyond
- run `git config --global rerere.enabled true` to have git save the result of a merge conflict resolution (REuse REcorded REsolution). If git sees the same conflict again, it can resolve it in the same way automatically. Especially useful for rebasing
- run `git config --global init.defaultBranch main` to set the default branch name to main

Altogether:

```shell
git config --global push.default current
git config --global --add --bool push.autoSetupRemote true
git config --global rerere.enabled true
git config --global init.defaultBranch main
```

## Per repo optimizations

- run `git maintenance start` - will start running several repo optimizations behind the scenes - especially useful on repos with long histories or large repos.

## Aliases

- run `git config --global alias.root 'rev-parse --show-toplevel'` to have `git root` work to show the root folder of the repository
  - useful for scripts that need to traverse around within a repo
- run `git config --global alias.fpush "push --force-with-lease"` to have `git fpush` force push with lease which is a safer alternative for force pushing
- run `git config --global alias.staash "stash --all"` to have a command to stash everything which is usually what you want

Altogether:

```shell
git config --global alias.root 'rev-parse --show-toplevel'
git config --global alias.fpush "push --force-with-lease"
git config --global alias.staash "stash --all"
```

## Shell Scripts

- `alias git2main="git fetch --all && git switch main && git pull"` - jump back to main with everything refreshed
  - this is a naive implementation, it can be improved by adding auto-stashing
- `alias git-add-all="git add -A"` - add all regardles of current location within the repo
- `alias git-plc="git commit --amend --no-edit && git push --force-with-lease"` - plc or patch-last-commit - quick way to add a typo fix into the last commit (assumes you've staged the changes you want to push)
- `alias git-aplc="git add -A && git commit --amend --no-edit && git push --force-with-lease"` - aplc or all-patch-last-commit - quick way to add a typo fix into the last commit, automatically including all changes
- `alias git-restage="git reset --soft HEAD"` - undo the last commit, turning it into a staged set of changes
- `alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"` - show a list of the last 10 branches I've worked on
  - useful when juggling a few different work streams
- `alias git-fetch-all="git fetch --all && git fetch --tags --all --force"` - the "all" you expected from all

Altogether:

```shell
alias git2main="git fetch --all && git switch main && git pull"
alias git-add-all="git add -A"
alias git-plc="git commit --amend --no-edit && git push --force-with-lease"
alias git-aplc="git add -A && git commit --amend --no-edit && git push --force-with-lease"
alias git-restage="git reset --soft HEAD"
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"
```

## Stack (chain) of branches

Some work happens as a stack (sometimes called a chain) of branches: branch A off of the default branch, branch B off of A, branch C off of B, and so on. These functions operate on the whole stack at once. The stack is discovered from how the branches were created (each branch's reflog records what it was created from, e.g. `branch: Created from A`), so no extra bookkeeping is needed. The default branch is detected automatically (from the remote HEAD, or the common branch names for local-only repos), so it doesn't matter if it's `main`, `master`, or something else; when an `origin` remote exists the stack is rebased onto `origin/<default>`.

- `stack-rebase` - rebase the whole stack the current branch belongs to onto the default branch
  - `stack-rebase` rebases the stack of the branch you're on (from its oldest branch up to the top of that stack)
  - `stack-rebase <branch>` rebases the stack of `<branch>` (you don't have to be on it)
  - `stack-rebase --abort` gives up on a paused rebase and restores what it can
  - rebases the oldest branch first, then each branch in turn onto the updated one below it, so the chain stays linear on top of the new default branch
  - uncommitted changes are stashed first and popped back at the end
  - on a conflict it PAUSES and saves its state: resolve the conflicted files (`git add` them), then run the same command again to resume - it picks up where it left off and finishes the rest of the stack
  - if a commit ends up empty during the rebase, `git rebase --skip` it before resuming
  - when done it reports the new branch tips; push them with `stack-push -f` (the history was rewritten, so the lease-checked force push is what's needed)
  - the worktree must be clean (it will auto-stash if it isn't), and no branch of the stack may be checked out in another worktree
- `stack-inject <target-branch> [commit]` - move a commit from the current branch onto an earlier branch in the chain
  - `stack-inject <target-branch>` moves the top commit (HEAD) of the current branch onto `<target-branch>`
  - `stack-inject <target-branch> <commit>` moves a specific commit (it must be on the current branch) - handy when you committed a fix on the wrong (too new) branch and want to move it down
  - the commit is cherry-picked onto the target branch, then every branch above the target is rebased so the chain stays linear; a copy of the moved commit that ends up duplicated on a higher branch is dropped automatically
  - `stack-inject` (no args) resumes a paused inject; `stack-inject --abort` gives up
  - on a conflict (in the cherry-pick or in the rebase walk) it PAUSES and saves state: resolve the files, `git add` them, run `stack-inject` again to resume
  - `<target-branch>` must be an earlier branch in the same stack as the current branch
- `stack-push` - push the branches in the stack to the remote, in order (oldest first)
  - `stack-push` pushes the stack of the branch you're on; `stack-push <branch>` pushes the stack of `<branch>`
  - branches that are already up to date on the remote are skipped
  - after a `stack-rebase` the remote copies are stale (rewritten history): a plain `stack-push` refuses and tells you to run `stack-push -f`, which pushes with `--force-with-lease` - the lease still protects against clobbering remote commits you don't have locally
  - it never pushes the default branch (push that with plain `git push`)
- limitations, for both: the stack must be a single LINE (one branch per level; a branch with two or more stack children is refused - rebase or delete the extra branches first). Branches that are just old commits of the default branch are ignored, and unrelated branches are left alone. Branch reflogs (enabled by default) are used to track the chain; if they are disabled the functions fall back to a heuristic that only works while lower branches haven't advanced past where higher branches were based. In repos without a remote the default branch is guessed from the common names (`main`, `master`, ...) - set `STACK_DEFAULT_BRANCH` to override if the guess is wrong.
- a test suite that exercises all three functions (clean rebases, conflicts with pause/resume across separate invocations, aborts, remote-based stacks, worktree guards, commit injection, dedup, and stack pushes including force-with-lease) lives in `stack-tests/run-tests.sh` - run it after changing the functions

## Security

Use `git config --global --add safe.directory $DIR` to mark a directory as safe to use git in.
Seems to mostly be used around dev containers, but may have other uses too.

## Notes on cli usage

use `git switch` instead of the older and more confusing `git checkout`.

- use `git switch <branchname>` to switch branches
- use `git switch -c <branchname>` to create a new branch and switch to it

## Other Tools

- Git Graph - nice graphical extension for VSCode
- Fork - nice graphical git client for macos and windows
- lazygit - powerful command line UI tool to manipulate git

## Credits

- Some of this was borrowed from Scott Chacon's "So you think you know git" talk
