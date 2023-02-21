# Mac Setup

A great initial install setup for mac

## Apple Store

- microsoft remote desktop

## Homebrew

- git
- wget
- htop
- macvim
- rbenv if serious about ruby
- fnm if serious about node
- pyenv if serious about python
- bash-git-prompt - shows git status right in the bash prompt (or oh-my-zsh for zsh)
- grc - apply color to output of common shell commands

## Direct Download

- sdkman (https://sdkman.io/install) - jvm env manager
- Karabiner Elements - to remap capslock to esc
  - I don't think this is necessary anymore, the ability to remap caps-lock to esc is built-in to macos now
- github desktop
- grandperspective - disk space analysis tool
- VimR
- JetBrains Toolbox (for Intellij, WebStorm, Datagrip, Pycharm, etc.)
- Atom
- VSCode
- LibreOffice
- Fork - great git gui
- Firefox w/ multi-account-containers extension
- Chrome
- iTerm2 - an alternative terminal

## Other

- `pip install awscli`

## Setup

- Enable key repeats: `defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false`
- Drag applications folder into dock (might not be possible anymore. The launchpad now functions similarly though)
- https://github.com/lysyi3m/osx-terminal-themes has some good themes for the terminal
- https://iterm2colorschemes.com/ has some good themes for the terminal
- In mac's system settings set the caps lock to no-action, and the key repeat delay to be fairly short, and the key repeat itself as fast as possible
- Use Karabiner-Elements to set the caps lock key to be an esc key
- Install a ligature-supporting font such as [Victor Mono](https://rubjo.github.io/victor-mono/), [Fira Code](https://github.com/tonsky/FiraCode), or [Monoid](https://github.com/larsenwork/monoid)
- run `git config --global push.default current` to make `git push` work as desired
- run `git config --global alias.root 'rev-parse --show-toplevel'` to have `git root` work to show the root folder of the repository
- run `git config --global --add --bool push.autoSetupRemote true` to have `git push` work right away (without doing all the tracking branch wiring) - Note: this one requires git version 2.37 or beyond

## zsh Setup

- install [ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)
- install [powerline fonts](https://github.com/powerline/fonts) - and configure iterm2 to use one of them
- drop the .zshrc into ~/
- set zsh as the default shell
