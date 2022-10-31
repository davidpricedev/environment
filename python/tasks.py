"""
Invoke tasks file
"""
import os
from invoke import task


PROJECT_FOLDER = "./project"


@task
def install_all_python_dependencies(c):
    """Install all python dependencies (for requirements-based projects)"""
    with c.cd(PROJECT_FOLDER):
        c.run("pip install -r dev-requirements.txt")


@task
def pytest(c):
    """run python tests"""
    pwd = os.path.curdir
    c.run(f'PYTHONPATH=".:{pwd}" python -m pytest {PROJECT_FOLDER}')


@task
def pylint(c):
    """run pylint"""
    c.run("echo 'running pylint for main code'")
    c.run(
        f"pylint --rcfile {PROJECT_FOLDER}/pylintrc --ignore=tests --recursive=y {PROJECT_FOLDER}")
    c.run("echo 'running pylint for test code'")
    c.run(
        f"pylint --rcfile {PROJECT_FOLDER}/tests/pylintrc {PROJECT_FOLDER}/tests")


@task(post=[pylint])
def pyformat(c):
    """Run python formatters and linters"""
    with c.cd(PROJECT_FOLDER):
        c.run("echo removing unused imports")
        c.run("autoflake --in-place .")

        c.run("echo sorting imports")
        c.run("isort .")

        c.run("echo auto-formatting code")
        c.run("black .")


@task(pre=[pylint, pytest])
def pyci(_):
    """Run python lint and test"""
