# zsh

I've organized the .zshrc content into a bunch of smaller files to make things more manageable and flexible.
We'll have to leave the configurations that are machine-specific in the .zshrc file itself, but most of the configuration can be moved out elsewhere.

Example Tree Structure:

```plaintext
${HOME}/.zsh
├── aliases.zsh
├── functions.zsh
├── general.zsh
├── git.zsh
├── index.zsh
└── omz.zsh
```

I use the index file as the single entry point.
I can pull all of the config in by adding this to my ~/.zshrc file: `source "${HOME}/.zsh/index.zsh"`.
