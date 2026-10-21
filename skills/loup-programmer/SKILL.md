---
name: loup-programmer
description: Writes, reviews, debugs and explains code in the Loup programming language (toolchain 1.25.1). Chooses the execution mode and file extension, applies Loup's syntax, ownership and error-handling rules, and verifies the result with the loup CLI. Use for any task that involves Loup source files (.lpscr, .loup, .lphc, .lpweb, .lpfree), .lppkg manifests, @mode(...) directives, or the loup / loup-bootstrap commands.
---

# Loup programmer

Loup is a statically typed language with Python-like scripting, ARC memory
management in every mode, ownership verbs, and six execution modes (scripts,
hosted programs, native binaries, Wasm, bare metal). This skill describes
**Loup 1.25.1** as the toolchain actually behaves. Where the specification
describes something the toolchain does not implement, this skill says so.
Trust `loup run` and `loup check` over any document, including this one.

Loup is not Rust, Python, TypeScript or Go. Code that looks right in those
languages usually does not compile. Read section 3 before writing any code.

## Full documentation

- Overview of the four books: https://code-craft.ai/references/loup
- Scripting (`host.scripted`): https://code-craft.ai/references/loup/scripting
- Native (`host.dual`, `host.native`): https://code-craft.ai/references/loup/native
- Web (`web.scripted`, `web.compiled`; mostly planned): https://code-craft.ai/references/loup/web
- Freestanding (bare metal): https://code-craft.ai/references/loup/freestanding
- Every page is also available as Markdown: add `.md` to its URL, e.g.
  https://code-craft.ai/references/loup/scripting/ch01-getting-started.md
- Index for language models: https://code-craft.ai/llms.txt

## Install

Use the official installers (no admin rights needed; installs to `~/.loup/bin`
or `%LOCALAPPDATA%\Programs\Loup` and adds it to PATH):

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh    # Linux, macOS
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex        # Windows PowerShell
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh -s -- --version 1.25.1   # pin a version
loup --version
```

`loup-lang.org` does not exist; never point users to it. Builds are not
notarized: after a browser download on macOS run
`xattr -dr com.apple.quarantine <dir>`.

## 1. Choose a mode and a file extension

Every file starts with `@mode(...)` as its first token (only comments may come
before it). The extension must match the mode (ruling MODE-3).

| `@mode(...)` | Extension | Entry point | Use it for | Run it today |
|---|---|---|---|---|
| `host.scripted` | `.lpscr` | top-level statements | scripts, tools, glue, tests | `loup run x.lpscr` |
| `host.dual` | `.loup` | `func main()` | programs and libraries (the `loup init` default) | `loup run src/main.loup`; `loup build` → Wasm |
| `host.native` | `.lphc` | `func main()` | AOT native binaries, `unique class`, `asm` | `loup run x.lphc`; `loup build --target native` (Linux x86-64) |
| `web.scripted` | `.lpweb` | (browser, planned) | nothing yet: no browser runtime exists | `loup run` runs it on the host |
| `web.compiled` | `.lpweb` | `func main()` under `loup run` | Wasm modules; cannot import any stdlib module (`E_COMPILED_IMPORT_SCRIPTED`) | `loup build --target browser` → bare `.wasm` |
| `freestanding` | `.lpfree` | `@entry` function | kernels, firmware | `loup check` anywhere; builds on Linux only |

- Default choice: a one-file tool is `host.scripted` (`.lpscr`); a project is
  `host.dual` (`.loup`); use `host.native` only when you need its features.
- **Only these six names exist.** `@mode(scripted)`, `@mode(compiled)`,
  `@mode(native)` (retired in v1.17) and misspellings are silently treated as
  `host.scripted`: an AOT `main()` never runs and the program exits 0 with no
  output. If a program prints nothing, check the mode line first.
- AOT modes (`host.dual`, `host.native`, `web.compiled`) allow only
  declarations and `const`/`let` initializers at module scope; statements go in
  `main()`.

Details: [references/modes-and-projects.md](references/modes-and-projects.md).

## 2. Program skeletons

A script (`report.lpscr`):

```loup
@mode(host.scripted)

from io.path import (basename);

let argv = args();
let target = if (argv.len() > 0) { argv[0] } else { "/tmp/example.txt" };
println(i"file name: {$ basename(target) $}");
```

```text
file name: example.txt
```

A program (`src/main.loup` in a project, or a lone `app.loup`):

```loup
@mode(host.dual)

const GREETING: string = "hello";

func greet(name: string): string {
    return i"{$ GREETING $}, {$ name $}";
}

func main(): int {
    let argv = runtime.args();
    let who = if (argv.len() > 0) { argv[0] } else { "world" };
    println(greet(who));
    return 0;
}
```

```text
hello, world
```

`main` takes no parameters and returns `void` or `int` (the exit status).
Arguments come from `runtime.args()` (`args()` also works in scripts).
`host.native` uses the same shape with `@mode(host.native)` in a `.lphc` file.

A freestanding entry point (`src/main.lpfree`; see
[references/freestanding.md](references/freestanding.md)):

```loup
@mode(freestanding)

const UART0: uint64 = 0x10000000;

func put(ch: uint8): void {
    Volatile[uint8].at(UART0).write(ch);
}

@entry
func kmain(): void {
    put(72);
    while (true) {}
}
```

A project: `loup init demo` writes `demo/demo.lppkg` (TOML), `demo/src/main.loup`
(`@mode(host.dual)`) and an empty `demo/tests/`.

## 3. Rules that differ from the languages you know

The idiomatic program below uses most of them. Its output follows it.

```loup
@mode(host.scripted)

from system.text import (parseInt);

class Inventory {
    var counts: dict[string, int] = {};
    pub var total: int = 0;

    pub modifier func add(item: string, qty: int): void {
        let current = this.counts.get(item) ?? 0;
        this.counts[item] = current + qty;
        this.total = this.total + qty;
    }

    pub func count(item: string): int {
        return this.counts.get(item) ?? 0;
    }
}

func parse_line(line: string): Result[(string, int), string] {
    let parts = line.split(",");
    if (parts.len() != 2) {
        return Err(i"expected 'item,qty', got '{$ line $}'");
    }
    let qty = parseInt(parts[1].trim())?;
    return Ok((parts[0].trim(), qty));
}

func load(edits inv: Inventory, lines: list[string]): int {
    var bad = 0;
    for (line in lines) {
        match parse_line(line) {
            Ok((item, qty)) => { safe { inv.add(item, qty); } },
            Err(msg) => {
                println(i"skipped: {$ msg $}");
                bad += 1;
            },
        }
    }
    return bad;
}

let inv = Inventory();
let bad = load(edits: inv, ["apple, 3", "pear,2", "oops", "apple,4"]);
let label = if (bad == 0) { "clean" } else { i"{$ bad $} bad line(s)" };
println(i"apples={$ inv.count("apple") $} total={$ inv.total $} ({$ label $})");
```

```text
skipped: expected 'item,qty', got 'oops'
apples=7 total=9 (1 bad line(s))
```

**Lexical and statements**

1. Comments are `#` (and `##` for doc comments). **`//` is floor division**, not a comment. Avoid `/* */`.
2. End statements with `;`. Newlines also end statements, but a line that starts with `(`, `[` or `with` continues the previous expression.
3. Conditions take parentheses: `if (x > 0) {`, `} else if (y) {`, `while (ok) {`, `for (x in xs) {`, `for (i in 0..n) {`. There is no `elif`, `switch` or `++`/`--`.
4. Functions are `func name(a: int, b: string = "x"): int { ... }`. Not `fn`, `def`, `function`, and no `->`. `fn(int): int` exists only as a function type. Lambdas: `func(x: int): int { return x * 2; }` or `func(x: int) => x * 2`.
5. `let` is immutable, `var` mutable, `const` compile-time only (`const LIMIT: int = 4 * 8;`; a runtime value is `E_CONST_NOT_EVALUABLE`). To assign a loop variable write `for (var x in xs)`.
6. There is no ternary. `if` is an expression: `let s = if (n > 3) { "big" } else { "small" };`.
7. `match v { A(x) => e, B => { ... }, n if (n > 0) => e, _ => e, }`: no parentheses around `v`, guards in parentheses, must be exhaustive. No or-patterns (`"a" | "b" =>`) and no `if let`; match on `Some(x)` / `None` instead.
8. Reserved words cannot be names: `type`, `match`, `from`, `new`, `in`, `is`, `with`, `this`, `static`, `global`, `shared`, `local`, `template`, `where`, `yield`, `unique`, `safe`, `takes`, ... Rename (`kind`, `src`).

**Values and types**

9. Interpolation needs the `i` prefix and `{$ ... $}`: `i"Hi {$ name $}"`. `"Hi {name}"` prints the braces literally. `"n=" + 5` is an error: use `i"n={$ n $}"`, `str(n)` or `n.to_string()`.
10. No implicit int/float mixing: `1.5 + (n as float)`. On ints `/` truncates toward zero and `//` floors. `int` overflow wraps silently.
11. No `null`/`nil`: use `Option[T]` (`T?`), `Some(x)`, `None`, `x ?? default`, `x?.field`. `Result[T, E]` with `Ok(v)` / `Err(e)` and postfix `?`. Use `?` only on a `Result`: on an `Option` inside a Result-returning function it compiles and turns `None` into `Err(None)`.
12. Option/Result methods are snake_case: `unwrap()`, `expect(msg)`, `unwrap_or(d)`, `is_some()`, `is_none()`, `is_ok()`, `is_err()`, `map(f)`, `map_err(f)`, `unwrap_err()`. `isSome` does not compile; `unwrapOr` and `ok()` fail at run time.
13. Built-in functions: `print`, `println` (exactly one argument), `printErr`, `str`, `repr`, `exit(code)`, `readText`, `writeText`, `exists`, `exec`, `args`, `env`. There is no `len(x)`, `int(x)` or `float(x)`: use `x.len()`, `"42".toInt()` (returns 0 on bad input; use `system.text.parseInt` to validate), `n as float`.
14. Lists, dicts, sets, tuples and structs are values: `var b = a;` copies. Class instances are shared references (ARC).
15. Collections: `xs.push(v)`, `xs.len()`, `xs.pop()`, `xs.contains(v)`, `xs.map(f)`, `xs.filter(f)`, `xs.join(", ")`, `xs.sort(func(a: int, b: int): int { return a - b; })` (a comparator is required). `d.get(k)` returns an Option; `d[k]` throws `KeyError` when missing.

**Classes and ownership**

16. Fields need `let` or `var` and are private to the class unless `pub`: `pub var count: int = 0;`.
17. The constructor is `new(name: string) { this.name = name; }` (one per class); create objects with `Point(1, 2)` (Loup style has no `new` at the call; Stage0 happens to accept `new Point(...)`). Without `new(...)` the class gets a constructor taking its fields: `Point(x = 1, y = 2)`. Write `this.x`, not `self.x`. `super(args)` and `super.m()` work.
18. Mark every redefinition of an inherited method `override` (1.25.1 requires it even when implementing an abstract method). Abstract methods with a non-`void` return type do not compile in 1.25.1: use an `interface` instead.
19. A method that assigns a `var` field must be `modifier`. Calling a `modifier` method, or assigning a field, from outside the class needs `safe { ... }` or an enclosing `safe func`. Changing an object received as a parameter needs both `edits` on the parameter and a safe context.
20. Parameters are read-only (`reads`) by default. To change the caller's list, struct or object declare `edits xs: list[int]` and call `f(edits: xs)`. `takes` consumes the argument (`f(takes: c)`; using `c` afterwards is `E_USE_AFTER_TAKE`). `shares` is acknowledged as `f(shares: c)`.
21. `unique let a = Obj();` gives single ownership: `let b = a;` moves it. `unique class` is accepted only in `host.native` and `freestanding`.

**Errors, modules, generics**

22. `throw ValueError("bad");` and `try { ... } catch (IoError as e) { ... } catch (A | B as e) { ... } finally { ... }`. Not `catch (e: IoError)`. The class is `IoError`, not `IOError` (the runtime raises it; you cannot construct it). Declare missing ones: `class ParseError : Exception {}`. Read `e.message`.
23. Hosted code cannot call `panic(...)` (undefined); throw an exception. `defer` parses but does not run in 1.25.1: use `try { ... } finally { ... }`.
24. Import lists need parentheses: `from core.math import (sqrt, floor as fl);`, or `import core.math as m;`. No wildcard, `use` or `export`. Mark functions, classes and constants `pub` to import them from another module.
25. Generics use brackets: `func first[T](xs: list[T]): Option[T]`, `class Box[T]`, `dict[string, int]`. Put bounds in a `where` clause: `func max_of[T](xs: list[T]): T where T: Comparable[T]`.
26. A closure that assigns an outer variable starts with `nonlocal x;` (enclosing function) or `global x;` (module variable).
27. `async func f(): Task[int]` and `await` exist, but calls run eagerly and sequentially in 1.25.1, and native builds refuse `async`. Do not rely on concurrency.

Full syntax: [references/syntax.md](references/syntax.md). Types and ownership:
[references/types-and-ownership.md](references/types-and-ownership.md).

## 4. Workflow

```sh
loup run app.lpscr arg1 arg2         # run any single file (a .loup/.lphc file's main() is called)
loup run --allow-net server.lpscr    # run grants fs, proc and entropy by default; net needs a flag
loup init demo                       # new project (demo.lppkg, src/main.loup, tests/)
loup check                           # in the project directory: type-check the entry and its imports
loup test                            # run *_test.loup / *_test.lpscr files: func test_*(): void
loup test --file add_test.lpscr      # test one file without a manifest
loup build                           # Wasm: build/<name>.wasm; run with loup-launcher --run-bare (see the caveat below)
loup build --target native -o app    # native binary: Linux x86-64 (needs clang); macOS is a preview
```

- Which binary: on Linux x86-64 `loup` is the self-hosted driver and refuses
  `check`; use `loup-bootstrap check`, `loup-bootstrap init` and
  `loup-bootstrap build` (Wasm) there. On macOS, Windows and Linux arm64 `loup`
  is `loup-bootstrap`, so both names work.
- Wasm builds are experimental: a `.wasm` that uses `i"..."` interpolation,
  `//` or `for await` builds but traps at run time, although `loup run`
  executes the same code. Run the built module before you report success.
- `loup check` only works inside a project (a lone file gives
  `E-CHECK-MANIFEST`) and only checks files reachable by imports from
  `[build] entry`. Check a lone file with `loup run`.
- Write the code, run it, read the first diagnostic, fix, repeat. Parse errors
  stop the run before type checking, so new errors can appear after you fix
  them.
- Tests: put `func test_name(): void { ... }` in a `*_test` file and assert
  with `from debug.assert import (expect, expectEq);`. A test in `tests/`
  imports project code with `from ..src.module import (name);`; a test next to
  the code in `src/` imports it directly.

Details: [references/modes-and-projects.md](references/modes-and-projects.md).

## 5. Reading diagnostics

`loup run` prints one line per error and exits 2:

```text
main.lpscr:3:4: error[E0001]: E_CONDITION_PARENS: the condition of `if` must be in parentheses; add them: `if (...) {`
```

- Format: `file:line:col: error[CODE]: message`. Many rules share the generic
  code `E0001`; the specific rule name is then the first word of the message
  (`E_CONDITION_PARENS`). `E0002` is a missing delimiter, `E0003` a missing `;`
  (often caused by foreign syntax on that line: `? :`, `->`, `//`).
- `loup check` prints the same errors rustc-style (`error[...]`, ` --> file`,
  gutter, carets). Add `--no-color`; `--format short` gives one line each;
  `--format json` one JSON object per line.
- An uncaught exception exits 1 and prints `Uncaught ValueError: message`
  followed by `  at func (file:line:col)` frames.
- Warnings (`W_...`) print after the program output and do not fail the run.

Most frequent fixes:

| You see | Fix |
|---|---|
| `E_CONDITION_PARENS` | wrap the `if`/`while`/`for` condition in `( )` |
| `expected expression` / ``expected `;` `` at `//`, `?`, `->`, `fn` | use `#` comments, `if` expressions, `func name(): T` |
| `E_NUMERIC_TYPE_MISMATCH` | convert with `as float` / `as int` |
| `E_BARE_FIELD` | declare the field `let` or `var` |
| `member 'x' of class 'P' is private` | add `pub` to the field |
| `E_MODIFIER_REQUIRED` | add `modifier` to the method that writes `this.field` |
| `E_SAFE_CONTEXT_REQUIRED` | wrap the call or field assignment in `safe { ... }` |
| `E_READS_MUTATION` | declare the parameter `edits` and call `f(edits: x)` |
| `E_VERB_REQUIRED` / `E_VERB_MISMATCH` | write the parameter's verb at the call: `f(edits: x)`, `f(takes: x)` |
| `E_USE_AFTER_TAKE` / `E_USE_AFTER_MOVE` | use the new owner, or do not consume the value |
| `expected RParen, found Colon` in `catch` | `catch (IoError as e)` |
| `expected LParen, found Identifier` after `import` | `import (a, b);` |
| `E_TOPLEVEL_CONTROL_AOT` | move the statement into `main()` |
| `E_MAIN_SIGNATURE` | `func main(): int` with no parameters; use `runtime.args()` |
| `has no method 'isSome'` | snake_case: `is_some()`, `unwrap_or()` |
| `Non-exhaustive match: missing variants X` | add the arm or `_ =>` |
| `E_OVERRIDE_REQUIRED` | add `override` |
| `` `type` is a reserved word `` | rename the binding |
| program prints nothing, exit 0 | the `@mode(...)` name is wrong; use a current name |

More, with real output for each: [references/errors-and-diagnostics.md](references/errors-and-diagnostics.md)
and [references/common-mistakes.md](references/common-mistakes.md).

## 6. Do not generate these: they do not exist in 1.25.1

Language features that are specified but not implemented (or broken):

- `arc let` / `arc var` (parse error), `if let`, or-patterns in `match`,
  call-site spread `f(*xs)` (literal spread `[0, *xs]` works), `typeof`,
  `instanceof` (crashes the parser; use `is`).
- `panic(...)` in hosted code (undefined; throw instead), `@volatile`
  (use `Volatile[T]` or a `volatile borrow` parameter), `@unsafe(reason: "...")`
  (write `@unsafe("...")`).
- Working `defer` (accepted, never runs; do not rely on it), real `async`
  concurrency (runs eagerly), `for concurrent`, `shared C(...)` under
  `loup run`, `weak` references (partial; lowered as strong natively).
- Wasm output for code that uses `i"..."`, `//` or `for await` (traps at run
  time), and standard-library imports from `web.compiled` files.
- HTML auto-escaping in `html` template fences (output is raw), element-wise
  `==` on lists (`[1, 2] == [1, 2]` is `false`), overflow traps (`int` wraps).

Standard library modules with no implementation (importing one is a compile error):
`loup.cli`, `loup.config`, `core.reflect`, `core.inspect`, `core.serialization`,
`net.tls`, `net.dns`, `net.ws`, any HTTP client (`net.http` is a server only),
every `sync.*` module, `thisapp`, every `web.*` and `ui.*` module,
`native.{simd,ffi,mem,gpu,webgpu,hal,tpu,window,audio}`, `lang.interop.*`,
`lang.macro`, `loup.tensor`, `loup.autodiff`, `debug.browser`, and the packages
`loup.http`, `loup.schema`, `loup.cache`, `loup.ai`, `loup.queue`. JSON is
`system.json` (there is no `data.json`).

Tooling that does not exist: a browser runtime (`loup-rt.js`, DOM access,
reactive UI, Web Components, workers), `loup serve`, `loup lsp`, `loup pkg`,
`loup add`, `loup publish`, a package registry, and `loup doc` outside Linux
x86-64. `loup install` fails once a project has dependencies.

When a user asks for one of these, say it is not available in Loup 1.25.1 and
offer what exists. Full list: [references/stdlib.md](references/stdlib.md).

## 7. Before you finish

- [ ] The first line of every file is `@mode(...)` with one of the six current
      names, and the extension matches it.
- [ ] You ran the code: `loup run <file>` exits 0 with the expected output, or
      `loup check` and `loup test` pass in the project. Paste real output; do not
      predict it.
- [ ] AOT files have `func main()` (no parameters, `void` or `int`) and no
      top-level statements.
- [ ] No foreign syntax: `//` comments, `? :`, `fn`/`->`, `self.`, `null`,
      `len(x)`, `catch (e: T)`, `"{x}"` without `i`, import lists without
      parentheses, `elif`, `++`.
- [ ] Every mutation is declared: `var` fields, `modifier` methods, `safe { }`
      at call sites, `edits`/`takes` on parameters and at calls.
- [ ] No absent module, retired mode name or planned feature from section 6.
- [ ] If you explain a limitation (native builds on macOS, browser output,
      async), say it is the 1.25.1 state, not the language design.

## Reference files

- [references/syntax.md](references/syntax.md): complete syntax with runnable examples.
- [references/modes-and-projects.md](references/modes-and-projects.md): modes, extensions, entry points, manifests, CLI, tests, builds, platform limits.
- [references/types-and-ownership.md](references/types-and-ownership.md): structs, classes, enums, interfaces, generics, ARC, verbs, `unique`, borrows, `modifier`/`safe`.
- [references/errors-and-diagnostics.md](references/errors-and-diagnostics.md): exceptions, Option/Result, `attempt`, panics, diagnostic formats, a table of diagnostics.
- [references/stdlib.md](references/stdlib.md): the modules that ship, their main functions, and the absent ones.
- [references/freestanding.md](references/freestanding.md): bare-metal rules, manifest, entry, panic handler, MMIO, `asm`.
- [references/common-mistakes.md](references/common-mistakes.md): wrong code, the real diagnostic, the fix.
