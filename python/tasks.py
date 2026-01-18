""" Invoke tasks file """
from invoke import task


PROJECT_FOLDER = "./project"


@task
def install_all_python_dependencies(c):
    """Install all python dependencies (for requirements-based projects)"""
    with c.cd(PROJECT_FOLDER):
        c.run("uv sync --all-extras")


@task
def pytest(c):
    """run python tests"""
    c.run("uv run --all-extras pytest")


@task
def lint(c):
    """run formattting and linting"""
    c.run("uv run --with ruff ruff format .")
    c.run("uv run --with ruff ruff check --fix .")
