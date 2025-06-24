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
- `alias git-add-all="git add -A"` - add all regardles of current location within the repo
- `alias git-plc="git commit --amend --no-edit && git push --force-with-lease"` - plc or patch-last-commit - quick way to sneak a typo fix into the last commit (assumes you've staged the changes you want to push)
- `alias git-aplc="git add -A && git commit --amend --no-edit && git push --force-with-lease"` - aplc or all-patch-last-commit - quick way to sneak a typo fix into the last commit, automatically including all changes
- `alias git-restage="git reset --soft HEAD"` - undo the last commit, turning it into a staged set of changes
- `alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"` - show a list of the last 10 branches I've worked on
  - useful when juggling a few different work streams
- `alias git-fetch-all="git fetch --all && git fetch --tags --all --force"` - the "all" you expected from all 

Altogether: 

```shell
alias git2main="git fetch --all && git switch main && git pull"
alias git-add-all="git add -A"
alias git-plc="git commit --amend --no-edit && git push --force-with-lease"
alias git-restage="git reset --soft HEAD"
alias gitls="git for-each-ref --count=10 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(color:green)%(committerdate:relative)%(color:reset))'"
```

## Notes on cli usage

use `git switch` instead of the older and more confusing `git checkout`.

- use `git switch <branchname>` to switch branches
- use `git switch -c <branchname>` to create a new branch and switch to it

## Other Tools

- Git Graph - nice graphical extension for VSCode
- Fork - nice graphical git client for macos and windows
- lazygit - powerful command line tool to manipulate git (really good at squashing)

## Credits

- Some of this was borrowed from Scott Chacon's "So you think you know git" talk
