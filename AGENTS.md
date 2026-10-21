# AGENTS.md

This repository is a GitHub template for building a command-line application
in the Loup programming language. The program is built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, ci, clean
├── LICENSE                      # MIT license (copyright Code Craft AI LLC)
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args()
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(), dispatch(): routes commands, maps errors to exit statuses
│   └── commands/                # one module per command
│       └── hello.loup           # sample command: run_hello()
├── tests/                       # tests: <module>_test.loup files with func test_*(): void
│   ├── app_test.loup
│   ├── args_test.loup
│   └── hello_test.loup
├── specs/                       # feature specs: <feature>/requirements.md, design.md, tasks.md
│   ├── README.md
│   └── command-line-interface/
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="hello Ann --shout"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter value"` | tests whose name contains `value` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/myapp` |
| Run the binary | `build/myapp --help` | |
| Everything CI runs | `make ci` | check, test, build, then `build/myapp --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Write or update the spec in `specs/<feature>/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update tests in `tests/`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/<feature>/tasks.md`.

To add a command:

1. Create `source/commands/<name>.loup` with `@mode(host.dual)` and
   `pub func run_<name>(opts: Options): int`, returning an exit status from
   `appinfo`.
2. Add an arm for it to `dispatch` in `source/cli/app.loup`.
3. Describe it in `usage()` in `source/cli/usage.loup`.
4. Add any new options to `Options` and `parse_args` in `source/cli/args.loup`.
5. Add `tests/<name>_test.loup`.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
