# Mac Setup

A great initial install setup for mac

## Apple Store

- microsoft remote desktop

## Homebrew

- git
- wget
- htop
- rbenv if serious about ruby
- fnm if serious about node
- pyenv if serious about python (homebrew only)

## Direct Download

- [sdkman](https://sdkman.io/install) - jvm env manager
- github desktop
- grandperspective - disk space analysis tool
- JetBrains Toolbox (for Intellij, WebStorm, Datagrip, Pycharm, etc.)
- VSCode
- LibreOffice
- Fork - git gui
- Firefox w/ multi-account-containers extension
- Chrome
- iTerm2 - an alternative terminal

## Other

- [awsp](https://github.com/johnnyopao/awsp)

## Setup

- https://iterm2colorschemes.com/ has some good themes for the terminal
- Install a ligature-supporting font such as [Victor Mono](https://rubjo.github.io/victor-mono/), [Fira Code](https://github.com/tonsky/FiraCode), or [Monoid](https://github.com/larsenwork/monoid)

### Keyboard

- Enable key repeats: `defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false`
- In mac's system settings set the caps lock to act as an escape key (for every keyboard individually), and the key repeat delay to be fairly short, and the key repeat itself as fast as possible

### [Git Setup](git.md)

## zsh Setup

- install [ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)
- install [powerline fonts](https://github.com/powerline/fonts) - and configure iterm2 to use one of them
- drop the .zshrc into ~/
- set zsh as the default shell
