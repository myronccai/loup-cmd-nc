# template Loup commandline application

A GitHub template for a command-line application written in
[Loup](https://code-craft.ai/references/loup). It includes argument parsing,
command dispatch, a sample `hello` command, tests, a native build and a CI
workflow.

After creating a repository from this template, work through
[REPOSITORY_TODOS.md](REPOSITORY_TODOS.md).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`
- `clang` 17 or later for native builds. Native builds are supported on Linux
  x86-64 and arm64, and are a preview on macOS and Windows.

## Installing Loup Lite

This project is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this project needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make run ARGS="--help"            # run from source
make run ARGS="hello Ann --shout"
make check                        # type-check the program
make test                         # run the tests in tests/
make build                        # native binary: build/myapp
make ci                           # check, test, build and smoke-test the binary
make clean
```

```text
$ build/myapp --help
usage: myapp [OPTIONS] COMMAND [ARGS...]

A command-line application written in Loup.

Commands:
  hello [NAME]          Print a greeting (NAME defaults to 'world')
  help                  Show this help

Options:
  -g, --greeting TEXT   Greeting used by 'hello' (default: Hello)
      --shout           Print the greeting in upper case
  -v, --verbose         Print diagnostic messages to stderr
  -h, --help            Show this help and exit
  -V, --version         Show the version and exit
```

Exit status: `0` success, `1` runtime failure, `2` usage error.

## Layout

```text
package.lppkg            # Loup manifest
Makefile                 # run, check, test, build, ci, clean
LICENSE                  # MIT license
source/                  # the application's Loup code
├── main.loup            # entry point
├── cli/                 # argument parsing, help text, command dispatch
└── commands/            # one module per command
tests/                   # *_test.loup files
specs/                   # feature specs: requirements, design, tasks
skills/loup-programmer/  # agent skill for writing Loup
```

[AGENTS.md](AGENTS.md) has the full layout, every build and test command, and
the steps for adding a command.

## Notes on the toolchain

- On Linux x86-64, `loup` is the self-hosted driver and `loup-bootstrap` is
  Stage0. `check` and `test` use `loup-bootstrap`; on other platforms both
  names run the same tool. The Makefile handles this.
- Modules import each other by their path under `source/`
  (`from cli.args import (Options);`). Tests import them the same way, which
  is why `make test` puts `source/` on `LOUPPATH`.
- The Wasm build (`loup-bootstrap build`) is experimental: modules that use
  `i"..."` interpolation build but trap at run time, so this template builds
  native binaries.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
