# Mac Setup

A great initial install setup for mac

## Homebrew

- git
- wget
- curl
- htop
- tree
- hadolint
- lazygit
- neovim
- pre-commit
- tf-summarize
- tflint
- uv

## Direct Download

- [sdkman](https://sdkman.io/install) - jvm env manager
- grandperspective - disk space analysis tool
- JetBrains Toolbox (for Intellij, WebStorm, Datagrip, Pycharm, etc.)
- VSCode
- Fork - git gui
- Firefox w/ multi-account-containers extension
- Chrome
- Wezterm
- kitty (yet another terminal)
- iterm2

## Other

- [awsum](https://github.com/davidpricedev/awsum)

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
- copy the zsh folder to ~/.zsh and add a source for its index.zsh file to ~/.zshrc
- set zsh as the default shell
