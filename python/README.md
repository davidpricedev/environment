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
  - `pydantic` for typing data classes
  - `factory-boy` for test factories
  - `pytest`, `expects`, and `pytest-describe` for testing
  - `toolz` for a bunch of fun utilities

Remember to set PYTHONPATH to inclue `"."`

Python has some strange behaviour around paths and folders and such.
What seems to work for me is:

- put all code in a named folder, say "project" for instance
- that project folder and every single sub-folder under it needs to contain a `__init__.py` file
- run pytest and other tools with their working directoy one level up from the project folder
- use non-relative imports - they should all start with `project.` (i.e. `import project.module1` or `from project.module1 import thing`)
- the tests folder needs to live inside the project folder - iirc it is possible to break this rule, but it requires a bunch of extra junk to fiddle with paths inside the root-level __init__.py file in the tests folder.
