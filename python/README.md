# Python

This documents my preferred python project setup, so I can start projects quicker without having to reinvent this setup every time.

- Use uv for everything since it handles python version management, venv handling, tool management, and makes python packaging much easier
- linting / formatting:
  - `ruff` to auto-format
  - `ruff` for linting
  - `pre-commit` to manage pre-commit hooks
  - `vscode` or `pycharm` for an ide
  - `invoke` for task runner
  - `pydantic` for typing data classes
  - `factory-boy` for test factories
  - `pytest`, `expects`, and `pytest-describe` for testing
  - `toolz` for a bunch of fun utilities

Especially without uv, it can be useful to set PYTHONPATH to inclue `"."` - i.e. `export PYTHONPATH="$PYTHONPATH:."`

## uv cheatsheet

Tooling:

- `uv run --with ruff ruff format .` will run ruff autoformat and install it as a package in the venv if not already present, useful for ci pipelines
- `uv tool install ruff` will install ruff as a tool, which can then be run via `uvx run ruff format .`

Project Commands:

- `uv run --all-extras pytest` should run pytest after ensuring all dependencies are installed
- `uv sync --all-extras` will install all dependencies
- `uv build` will generate a wheel file

## Python Paths

`uv` likes to have a folder structure that looks like this.
It is redundant and seems unnecessarily deep, but it is the only real way to go to ensure solid predictability.
If the repo will house multiple projects, each project must follow this same format.

```plaintext
project_name/
├── pyproject.toml
├── src/project_name/
│   ├── __init__.py
│   ├── module1.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   └── test_module1.py
```

Notes:

- all internal imports should look like: `from project_name.<module> import <thing>`
- pytest and any other tools can be run by cd-ing into the folder containing pyproject.toml

## (OLD pre-uv stuff) Python Paths

Python has some strange behaviour around paths and folders and such.
What seems to work for me is:

- put all code in a named folder, say "project" for instance
- that project folder and every single sub-folder under it needs to contain a `__init__.py` file
- run pytest and other tools with their working directoy one level up from the project folder
- use non-relative imports - they should all start with `project.` (i.e. `import project.module1` or `from project.module1 import thing`)
- the tests folder needs to live inside the project folder - iirc it is possible to break this rule, but it requires a bunch of extra junk to fiddle with paths inside the root-level **init**.py file in the tests folder.
- pytest and pylint are very particular and sometimes troublesome to get working (most other tooling seems to be easier)
  - pytest should generally be run with `python -m pytest ./project` - it seems to work significantly better than running pytest on its own
    - It may be necessary to add some folders to PYTHONPATH while running pytest. i.e. `PYTHONPATH=".:$(pwd)" python -m pytest ./project`
  - pylint, I often run with two separate configs & two seaparate runs:
    - `cd project && pylint --rcfile ./pylintrc --ignore=tests --recursive=y .`
    - `cd project && pylint --rcfile ./tests/pylintrc ./tests`
