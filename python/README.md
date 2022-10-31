# Python

This documents my preferred python project setup, so I can start projects quicker without having to reinvent this setup every time.

- Use pyenv for multi-version management - `brew install pyenv` + some configuration from their gitub readme into the shell.
- Use pipenv if possible since it is probably the best all-round dependency manager, but pip + requirements files works too and is more common
- linting / formatting:
  - `black` to auto-format
  - `autoflake` to auto-remove unused imports
  - `isort` to sort & organize imports
  - `pre-commit` to manage pre-commit hooks
  - `pycharm` or `vscode` for an ide
  - `flake8` and/or `pylint` for linting
  - `invoke` for task runner
  - `pydantic` for typing data classes
  - `factory-boy` for test factories
  - `pytest`, `expects`, and `pytest-describe` for testing
  - `toolz` for a bunch of fun utilities

Remember to set PYTHONPATH to inclue `"."` - i.e. `export PYTHONPATH="$PYTHONPATH:."`

## Python Paths

Python has some strange behaviour around paths and folders and such.
What seems to work for me is:

- put all code in a named folder, say "project" for instance
- that project folder and every single sub-folder under it needs to contain a `__init__.py` file
- run pytest and other tools with their working directoy one level up from the project folder
- use non-relative imports - they should all start with `project.` (i.e. `import project.module1` or `from project.module1 import thing`)
- the tests folder needs to live inside the project folder - iirc it is possible to break this rule, but it requires a bunch of extra junk to fiddle with paths inside the root-level __init__.py file in the tests folder.
- pytest and pylint are very particular and sometimes troublesome to get working (most other tooling seems to be easier)
  - pytest should generally be run with `python -m pytest ./project` - it seems to work significantly better than running pytest on its own
    - It may be necessary to add some folders to PYTHONPATH while running pytest. i.e. `PYTHONPATH=".:$(pwd)" python -m pytest ./project`
  - pylint, I often run with two separate configs & two seaparate runs:
    - `cd project && pylint --rcfile ./pylintrc --ignore=tests --recursive=y .`
    - `cd project && pylint --rcfile ./tests/pylintrc ./tests`

## Configs

pylintrc `disable=` section, in addition to those that are disabled out of the box:
```ini
      ## ----- Rules I don't care about -----
      missing-module-docstring,
      missing-class-docstring,
      missing-function-docstring,
      too-few-public-methods,
      too-many-instance-attributes,
      unnecessary-lambda,
      unnecessary-direct-lambda-call,
      # its just wrong
      no-name-in-module,
      import-error,
      # expressions are good, actually
      no-else-return,
```

More pylintrc disabled rules for tests:
```ini
      ## --------------- TEST SPECIFIC ---------------
      # pytest has unused arguments by design
      unused-argument,
      # cant be bothered for tests
      wrong-import-order,
      line-too-long,
      cannot-enumerate-pytest-fixtures,
      # describe blocks in tests will be longer than normally desired for a function
      too-many-statements,
      # Easier to have what you don't need than constantly having to import and remove things
      unused-import,
```

pyproject.toml
```toml
[tool.isort]
profile = "black"

[tool.pytest.ini_options]
minversion = "6.0"
addopts = [
    "--import-mode=importlib",
    "--color=yes",
    "-rx",
    "-rP",
]
testpaths = [
    "tests",
    "integration",
]
# what file names constitute a test file/function that pytest should run
python_files = [
  "*_test.py",
  "*_spec.py",
  "test_*.py",
]
python_functions = [
  "test_*",
  "it_*",
]
```
