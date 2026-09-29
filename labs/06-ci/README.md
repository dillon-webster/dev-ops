# Lab 06: Continuous Integration

**Time:** 1–2 hours · **You'll learn:** virtualenvs, Makefiles, linting and testing, GitHub Actions workflows, job dependencies, caching

## The idea

**CI** means every push automatically gets checked: lint it, test it, build it. If anything fails, the change is "red" and shouldn't be merged. The golden rule is that **CI should run the same commands you run on your laptop**. That's why we'll put the commands in a `Makefile` and have CI call `make`.

## Part 1: run the checks locally

Python projects keep their dependencies in a **virtual environment** (venv), a private folder of packages for this project only:

```bash
cd ~/Code/devops-practice
python3 -m venv .venv                         # create it (once)
source .venv/bin/activate                     # activate it (every new terminal; your prompt changes)
pip install -r app/requirements-dev.txt       # install flask, pytest, ruff, ...
which python                                  # it points inside .venv now
```

(Your `act` alias does the `source` step for you. 😉)

Try the tools directly:

```bash
ruff check app                                # linter: finds bugs and style problems
REDIS_HOST=x pytest app/tests                 # tests (the app needs REDIS_HOST set to import)
```

**The linter should fail.** There's a problem in `app/app.py`. Fix it. This is exactly the kind of thing CI exists to catch.

### Makefile

`make lint` runs the commands under `lint:` in the `Makefile` at the repo root. Fill in the three targets:

- `lint` runs ruff on `app/`
- `test` runs pytest on `app/tests` (remember `REDIS_HOST`)
- `build` builds `devops-app:latest` from `app/`

⚠️ **Makefiles need a real TAB character** at the start of each command line, not spaces. Most editors handle this for you in a file named `Makefile`.

## Part 2: the workflow

Create `.github/workflows/ci.yml` (at the **repo root**, not in this folder). GitHub runs any workflow file in that folder.

Requirements:

1. Runs on **push** and on **pull_request**.
2. A job called **`test`** on `ubuntu-latest` that:
   - checks out the code (`actions/checkout@v5`)
   - sets up Python **3.12** (`actions/setup-python@v6`) **with pip caching** turned on
   - installs `app/requirements-dev.txt`
   - runs `make lint` and `make test`
3. A job called **`build`** that **only runs if `test` passed** (`needs:`) and runs `make build`.

Grade it (activate your venv first):

```bash
./labs/06-ci/check.sh
```

## Seeing it run for real (optional)

The checker only validates your file locally. To watch it actually run, create a new repo on GitHub, push this folder to it, and open the **Actions** tab. Then try pushing a commit that breaks a test and watch it go red.

## Hints

<details><summary>Makefile targets</summary>

```make
lint:
	ruff check app

test:
	REDIS_HOST=localhost pytest app/tests
```
</details>

<details><summary>Workflow skeleton</summary>

```yaml
name: CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-python@v6
        with:
          python-version: "3.12"
          # caching goes here
      - run: pip install -r app/requirements-dev.txt
      # ...

  build:
    # ...
```
</details>

<details><summary>What does pip caching do?</summary>

Every CI run starts on a fresh machine. Without a cache, it downloads every package every time. `cache: pip` saves pip's download cache keyed on your requirements files, which makes runs much faster.
</details>

## Stretch goals

- Add a **smoke test** job: `docker compose up -d --wait` the Lab 03 stack and `curl -f localhost:8300/ready`.
- Push the image to GitHub Container Registry (`ghcr.io`) only on the `main` branch (`if: github.ref == 'refs/heads/main'`).
- Run the test job on a **matrix** of Python 3.11, 3.12, and 3.13.
