_GIT_CONFIG_TRACKING_FILE="${HOME}/.config/.gitconfiged_v1"
if [ ! -f "${_GIT_CONFIG_TRACKING_FILE}" ]; then
  echo "configuring git global settings ... "

  # Configure push to work easily
  git config --global push.default current
  git config --global --add --bool push.autoSetupRemote true

  # Save time on merge conflict resolutions
  git config --global rerere.enabled true

  # Set main as the default branch name for new repositories
  git config --global init.defaultBranch main

  # Setup some aliases
  git config --global alias.root 'rev-parse --show-toplevel'
  git config --global alias.fpush "push --force-with-lease"
  git config --global alias.staash "stash --all"
  git config --global alias.tree "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all"

  date -Iseconds > "${_GIT_CONFIG_TRACKING_FILE}"
fi
