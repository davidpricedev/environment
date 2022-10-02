# Python

This documents my preferred python project setup, so I can start projects quicker without having to reinvent this setup every time.

- Use pyenv for multi-version management - `brew install pyenv` + some configuration from their gitub readme into the shell.
- Use pipenv if possible since it is probably the best all-round dependency manager, but pip + requirements files works too and is more common
- linting / formatting:
  - `black` to auto-format
  - `autoflake` to auto-arrange imports
  - `pre-commit` to manage pre-commit hooks
  - `pycharm` or `vscode` for an ide
  - `flake8` and/or `pylint` for linting
  - `invoke` for task runner
