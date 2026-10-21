# Modes, files, projects and the CLI (toolchain 1.25.1)

Contents: [The six modes](#the-six-modes) · [The @mode directive](#the-mode-directive) ·
[Entry points and exit status](#entry-points-and-exit-status) ·
[Scripts and modules without a project](#scripts-and-modules-without-a-project) ·
[Projects and the manifest](#projects-and-the-manifest) · [Checking](#checking) ·
[Testing](#testing) · [Building](#building) · [Capabilities](#capabilities) ·
[Which binary on which platform](#which-binary-on-which-platform) ·
[Other commands](#other-commands)

## The six modes

| Mode | Ext. | Runs as | Entry | Module scope | Notes |
|---|---|---|---|---|---|
| `host.scripted` | `.lpscr` | OS process, interpreted | top-level statements, in order | any statement | default for a file with no directive; `await` allowed at top level |
| `host.dual` | `.loup` | interpreted by `loup run`, or AOT to Wasm/native | `func main()` | declarations and `const`/`let` initializers only | `loup init` scaffold; the usual project mode |
| `host.native` | `.lphc` | AOT native (ARC); `loup run` interprets it | `func main()` | as `host.dual` | `unique class` and `asm` allowed; `Any` gives `W_ANY_IN_AOT_MODE` |
| `web.scripted` | `.lpweb` | browser JIT (planned) | browser bootstrap (planned) | any statement | no browser runtime; `loup run` executes it on the host |
| `web.compiled` | `.lpweb` | AOT Wasm | `func main()` under `loup run` | as `host.dual` | cannot import any stdlib module (`E_COMPILED_IMPORT_SCRIPTED`); `loup build --target browser` writes a bare `.wasm` only |
| `freestanding` | `.lpfree` | bare metal, no runtime | an `@entry` function | declarations | no exceptions, no growable collections; see [freestanding.md](freestanding.md) |

Every mode has ARC semantics: classes are reference-counted references;
structs, enums, tuples and collections are values. There is no garbage
collector and no Wasm GC.

How to choose:

- A single-file tool, a quick script, glue code: `host.scripted` (`.lpscr`).
- A multi-file program or library: a project in `host.dual` (`.loup`).
- You need `unique class`, `asm` or a native binary: `host.native` (`.lphc`).
  Native builds work on Linux x86-64; macOS is a preview; Windows and Linux
  arm64 have none.
- Browser code: there is no DOM or UI API. Say so; a `web.compiled` module
  can only be built to a bare `.wasm` file.
- Kernels and firmware: `freestanding` (`.lpfree`).

A script can import `.loup` modules and the other way round; each file is
checked under its own mode.

## The @mode directive

- `@mode(...)` is the first token of the file; only comments (including a
  `#!` shebang) may precede it. A later directive is `E_MODE_POSITION`, a
  second one `E_MODE_DUPLICATE`.
- Always write it (ruling MODE-2), even though a missing directive falls back
  to the project default (`[build] mode` / `[modes]` in the manifest) or to
  `host.scripted`.
- The extension follows the mode (ruling MODE-3): `.lpscr` scripted, `.loup`
  only `host.dual`, `.lphc` native, `.lpweb` web, `.lpfree` freestanding. The
  only source extensions are these five; `.loom` and `.lm*` files are errors.
- **Retired names fail silently.** `@mode(scripted)`, `@mode(compiled)`,
  `@mode(native)` (v1.16 names) and misspellings such as `@mode(host_native)`
  run as `host.scripted`: no diagnostic, `main()` is never called, exit status
  0, no output. Map `native` → `host.native`, `compiled` → `host.dual` (host)
  or `web.compiled` (browser), `scripted` → `host.scripted`.
- `namespace a.b;` (optional) comes right after the directive.

## Entry points and exit status

```loup
@mode(host.native)

func usage(): int {
    printErr("usage: count WORD...");
    return 2;
}

func main(): int {
    let argv = runtime.args();
    if (argv.len() == 0) {
        println("no words given; counting the demo words");
        println(["alpha", "beta"].len());
        return 0;
    }
    println(argv.len());
    return 0;
}
```

```text
no words given; counting the demo words
2
```

- `main` takes **no parameters** and returns `void` or `int`
  (`E_MAIN_SIGNATURE` otherwise). The `int` is the exit status (low byte).
- Arguments: `runtime.args()` in every hosted mode; `args()` too in scripts.
  `loup run app.loup a b` and `loup run app.loup -- --flag` both pass
  arguments.
- Exit status: `return n` from `main`, or `exit(n)` anywhere. An uncaught
  exception exits 1; a compile error exits 2.
- In a script, the top-level code is the program. `__name__` is `"__main__"`
  in the file that was run, so `if (__name__ == "__main__") { ... }` keeps a
  module's self-test from running when it is imported.
- `async func main(): Task[int]` is accepted by `loup run` in `host.dual`, but
  async runs eagerly and native builds refuse `async`; prefer a plain `main`.

## Scripts and modules without a project

`loup run` needs no manifest. A script imports files next to it by path:

```text
tools/
├── report.lpscr        # from helpers import (fmt_row);  from lib.stats import (mean);
├── helpers.lpscr       # pub func fmt_row(...)
└── lib/stats.loup      # @mode(host.dual)  pub func mean(...)
```

```sh
loup run tools/report.lpscr data.csv
```

Only `pub` declarations can be imported. Imports resolve from the entry
file's directory; relative forms (`from .sibling import (x);`) also work.

## Projects and the manifest

```sh
loup init demo        # on Linux x86-64: loup-bootstrap init demo
cd demo
loup run src/main.loup
loup check
loup test
```

`loup init demo` creates:

```text
demo/
├── demo.lppkg          # the manifest (TOML)
├── src/main.loup       # @mode(host.dual) with func main(): void
└── tests/              # empty
```

The generated manifest, shortened (the scaffold also writes empty tables such
as `[dependencies]`, `[modes]`, `[linker]`, `[freestanding]`):

```toml
name = "demo"
version = "0.1.0"
loup = "1.20.0"
authors = []

[build]
entry = "src/main.loup"
delivery = "cli"
profile = "release"

[test]
pattern = "**/*_test.loup"
parallel = true
timeout = 30
```

- The file is `<name>.lppkg` or `package.lppkg`. `loup.toml` and `loup.pkg`
  are not read. Tools search the current directory and its parents.
- `[build]` keys: `entry`, `delivery` (alias `target`: `cli` default,
  `service`, `browser`, `desktop`, `native`, `freestanding`), `profile`
  (`release`/`debug`), `mode` (project default), `arch`, `panic`
  (freestanding: `"halt"` default, `"abort"`, `"custom"`).
- Other tables: `[modes]` (per-file modes), `[dependencies]` /
  `[dev_dependencies]`, `[delivery.X]` (formerly `[target.X]`), `[linker]`
  (`script`, `entry` for freestanding), `[freestanding]`, `[options]`,
  `[const_eval]`, `[exports]`, `[test]`.
- Dependencies: there is no registry, and `loup install` fails once a
  project declares a dependency. Path dependencies
  (`[dependencies]` then `libb = { path = "../libb" }`, imported as
  `from libb.greet import (hello);`) resolve in `loup build` but **not** in
  `loup run` or `loup check` in 1.25.1 (`unresolved package import`;
  `E-CHECK-DEP`). Keep code you need to run and check inside the project's
  `src/`. `LOUPPATH` (`:`-separated package roots) is the development search
  path; `loup run` honours it, `loup check` ignores it.
- Inside `src/`, modules import each other by path from `src/`:
  `from util.text import (shout);` loads `src/util/text.loup`.
- Reserved import roots (`core io data net sync concurrent web ui native lang
  debug structures`, and `loup.`) belong to the standard library; do not name
  your packages after them.

## Checking

```sh
loup check                    # in the project directory (Linux x86-64: loup-bootstrap check)
loup check --no-color --format short
loup check --format json      # one JSON object per diagnostic
```

- Project-only: outside a project it fails with
  `error[E-CHECK-MANIFEST]: manifest not found: no .lppkg manifest found in . or any parent directory`.
- It checks `[build] entry` and every module reachable through its imports.
  A file nothing imports is **not** checked: run it with `loup run`, or import
  it.
- Exit status 0 means no errors; warnings do not fail it.
- For freestanding code `check` is the only verification available off
  Linux, and it does not enforce every freestanding rule (see
  [freestanding.md](freestanding.md)).

## Testing

A test file is named `*_test.loup` or `*_test.lpscr` and contains
argument-less `func test_*(): void` functions that assert with `debug.assert`:

```loup
@mode(host.dual)

from debug.assert import (expect, expectEq, expectThrows);

func count_words(text: string): int {
    var n = 0;
    for (w in text.split(" ")) {
        if (!w.is_empty()) {
            n += 1;
        }
    }
    return n;
}

func parse_count(text: string): int {
    if (text.is_empty()) {
        throw ValueError("empty count");
    }
    return text.toInt();
}

func test_counts_words(): void {
    expectEq(count_words("a  b c"), 3, "three words");
}

func test_empty_text(): void {
    expect(count_words("") == 0, "no words in empty text");
}

func test_rejects_empty_count(): void {
    expectThrows(func(): void { parse_count(""); }, "empty count throws");
}
```

In a project the functions under test live in `src/`. A test file in `tests/`
imports them with `from ..src.words import (count_words, parse_count);`; a
test file placed in `src/` next to the module imports them directly
(`from words import (count_words);`).

```sh
loup test                        # all tests in the project
loup test --filter empty         # only tests whose name contains "empty"
loup test --file words_test.lpscr   # one file, no manifest needed
loup test --native               # host.native tests through the AOT pipeline (Linux)
```

Output, with one failing assertion (exit status 1):

```text
found 4 tests in 1 files (0 compile failures)
  ✓ tests/words_test.loup::test_counts_words (27ms)
  ✗ tests/words_test.loup::test_deliberately_wrong (29ms)
    AssertionError: two words: expected 3, got 2
  ✓ tests/words_test.loup::test_empty_text (30ms)
  ✓ tests/words_test.loup::test_rejects_empty_count (28ms)

Tests: 4 total, 3 passed, 1 failed, 0 skipped (31ms)
```

Assertions in `debug.assert`: `expect(cond, msg)`, `expectEq(actual,
expected, context)`, `expectNeq(actual, forbidden, context)`,
`expectSome(opt, context)` (returns the value), `expectContains(items, item,
context)`, `expectThrows(fn, context)` (returns the exception),
`expectNear(actual, expected, tolerance, context)`. A failed assertion throws
`AssertionError`. `testing.skipTest(reason)` skips.

On Linux x86-64 `loup test` is the self-hosted runner and takes `--strict`;
the Stage0 `loup test` (macOS, Windows, Linux arm64) has no `--strict`.

## Building

```sh
loup build                              # Wasm module: build/<name>.wasm (delivery "cli")
loup-launcher --run-bare build/demo.wasm   # run it with the toolchain's Wasm runtime
loup build --target desktop -o pkg      # packaged app: pkg/bin/main + pkg/lib/main.wasm
./pkg/bin/main arg1
loup build --target browser             # web.compiled: bare build/<name>.wasm, no HTML or JS
loup build --target native -o app       # native binary (Linux x86-64; needs clang)
loup build --target native --backend cranelift   # or llvm (default), llbe
loup build --target freestanding --arch aarch64  # bare metal (Linux; needs ld.lld and [linker] script)
```

- Wasm builds come only from Stage0 (`loup-bootstrap build` on Linux x86-64,
  where the self-hosted `loup build` refuses Wasm). The README calls compiled
  Wasm "experimental, not audited", and it is: a module that uses `i"..."`
  interpolation, `//` or `for await` builds but traps when run
  (`main trap: ... int.op_floordiv not implemented`,
  ``call_dynamic: no exported function `RenderContext` ``). Always run the
  built module. `--run-bare` does not pass program
  arguments; a desktop package does.
- Native: Linux x86-64 is supported (LLVM, Cranelift, llbe). macOS is a
  preview (LLVM only, Xcode Command Line Tools) and may fail to link. Windows
  and Linux arm64 have no native builds. Native code refuses `async`,
  template fences and `for concurrent`; `--lib shared|static` does not produce
  a native library.
- `build --target native` accepts any AOT mode; a script entry is
  `E-BUILD-COMPILED`.
- `--delivery` is the new name of `--target`; both work.
- Freestanding builds: see [freestanding.md](freestanding.md).

## Capabilities

Under Stage0 `loup run` grants file-system, process and entropy access, but
**not network**. A missing capability is a run-time `IoError`:

```text
Uncaught IoError: capability 'net' is not available: not in permission set
```

```sh
loup run --allow-net server.lpscr        # add one: --allow-fs --allow-net --allow-proc --allow-entropy --allow-debug
loup run --allow-all tool.lpscr          # everything
loup run --deny-all --allow-fs tool.lpscr
```

The self-hosted `loup run` on Linux x86-64 ignores these flags and grants
everything.

## Which binary on which platform

| Platform | `loup` is | Use `loup-bootstrap` for |
|---|---|---|
| Linux x86-64 | the self-hosted driver (interprets scripts, delegates the rest) | `check`, `init`, `repl`, `bench`, Wasm `build` |
| Linux arm64, macOS, Windows | Stage0 (`loup-bootstrap`) | nothing extra; both names work |

| Capability | Linux x86-64 | macOS | Windows | Linux arm64 |
|---|---|---|---|---|
| `loup run`, `check`, `test`, Wasm build | yes | yes | yes | yes |
| native build | yes (clang) | preview (LLVM, Xcode CLT) | no | no |
| freestanding build | yes (ld.lld; QEMU to boot-test) | no (check only) | no (check only) | no |
| `loup doc`, header tools | yes | no | no | no |
| build from source | yes | no | no | no |

## Other commands

- `loup fmt FILE...` rewrites files in place (2-space indentation, blank
  lines removed, comments kept); `--check` reports, `--stdin` filters. Do not
  run it on a user's files unless asked.
- `loup repl` and `loup bench` exist (Stage0).
- There is no `loup pkg`, `add`, `publish`, `cache`, `serve` or `lsp`
  ("unknown command"). `loup doc`, `export-headers` and `import-headers` work
  only on Linux x86-64; elsewhere they print "not yet available".
