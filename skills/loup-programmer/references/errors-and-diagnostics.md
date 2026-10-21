# Errors and diagnostics (toolchain 1.25.1)

Contents: [Exceptions](#exceptions) · [Option and Result](#option-and-result) ·
[attempt](#attempt) · [Panics and unreachable](#panics-and-unreachable) ·
[Choosing a strategy](#choosing-a-strategy) ·
[Diagnostic formats](#diagnostic-formats) ·
[Table of diagnostics](#table-of-diagnostics)

## Exceptions

```loup
@mode(host.scripted)

class ConfigError : Exception {}

func load(path: string): string {
    if (!exists(path)) {
        throw ConfigError(i"missing config: {$ path $}");
    }
    return readText(path);
}

try {
    load("/no/such/app.toml");
} catch (ConfigError as e) {
    println(i"config error: {$ e.message $}");
} finally {
    println("cleanup runs");
}

try {
    let xs = [1, 2];
    println(xs[5]);
} catch (IndexError | KeyError as e) {
    println(i"lookup failed: {$ e.message $}");
}

try {
    readText("/no/such/file");
} catch (IoError as e) {
    println(i"io error {$ e.code $}");
}

func wrap(): void {
    try {
        throw ValueError("inner");
    } catch (ValueError as e) {
        throw RuntimeError("outer") from e;
    }
}

try {
    wrap();
} catch (Exception as e) {
    println(i"{$ e.message $} (has cause: {$ e.cause.is_some() $})");
}

try {
    println(10 // 0);
} catch {
    println("caught anything");
}
```

```text
config error: missing config: /no/such/app.toml
cleanup runs
lookup failed: list index 5 out of range (len 2)
io error 2
outer (has cause: true)
caught anything
```

- Syntax: `catch (Type as name)`, `catch (A | B as name)`, `catch (Exception as e)`
  for everything catchable, or a bare `catch { }`. Never `catch (e: Type)`,
  `catch (e)` or `except`.
- Every exception has `message: string`, `cause: Option[Any]` and
  `stackTrace` (a list of frames with `file`, `line`, `column`, `function`).
  `IoError` adds `code` (the OS error number).
- Built-in classes you can throw: `Exception`, `ValueError`, `TypeError`,
  `KeyError`, `IndexError`, `RuntimeError`, `TimeoutError`,
  `IntegerDivisionError`, `NumericOverflowError`, `UnwrapError`.
  `IoError` is raised by the runtime and can be caught, but `IoError("...")`
  is `'IoError' is not callable`. There is no `IOError`, `FileNotFoundError`,
  `PermissionError`, `ParseError`, `NotImplementedError` or `Error`: declare
  your own (`class ParseError : Exception {}`).
- Only classes extending `Exception` can be thrown (`throw "text"` is
  `E_THROW_NON_ERROR`).
- `throw New("...") from e;` chains a cause; an uncaught chain prints
  `Caused by:`.
- `finally` always runs. `defer` does **not** run in 1.25.1; use `finally`.
- Freestanding code has no exceptions at all (see [freestanding.md](freestanding.md)).

An uncaught exception prints to stderr and exits 1:

```loup,throws
@mode(host.scripted)

func parse_age(text: string): int {
    let n = text.toInt();
    if (n <= 0) {
        throw ValueError(i"not an age: '{$ text $}'");
    }
    return n;
}

println(parse_age("42"));
println(parse_age("abc"));
```

```text
42
Uncaught ValueError: not an age: 'abc'
  at parse_age (main.lpscr:6:15)
  at <main> (main.lpscr:12:9)
```

A native binary prints only the first line (`ValueError: not an age: 'abc'`)
and exits 1. A Wasm module run by `loup-launcher` prints `Uncaught T: msg`
with `at fn (<wasm>:index)` frames.

## Option and Result

```loup
@mode(host.scripted)

from system.text import (parseInt);

func port_of(s: string): Result[int, string] {
    let n = parseInt(s)?;
    if (n < 1 or n > 65535) {
        return Err(i"port out of range: {$ n $}");
    }
    return Ok(n);
}

match port_of("99999") {
    Ok(p) => println(i"port {$ p $}"),
    Err(msg) => println(i"error: {$ msg $}"),
}
println(port_of("22").is_ok());
println(port_of("22").map(func(p: int): int { return p + 1; }).unwrap_or(0));
println(port_of("x").map_err(func(e: string): string { return "E: " + e; }).unwrap_err());

let maybe: Option[int] = Some(5);
let none: Option[int] = None;
println(maybe.is_some());
println(none ?? -1);
println(maybe.map(func(v: int): int { return v * 2; }).unwrap_or(0));
println(maybe.and_then(func(v: int): Option[int] { return if (v > 3) { Some(v) } else { None }; }).unwrap_or(0));
println(maybe.filter(func(v: int): bool { return v > 10; }).is_none());
println(maybe.expect("must be set"));
```

```text
error: port out of range: 99999
true
23
E: invalid integer: x
true
-1
10
5
true
5
```

| Type | Methods that work in 1.25.1 |
|---|---|
| `Option[T]` (`T?`) | `is_some()`, `is_none()`, `unwrap()`, `expect(msg)`, `unwrap_or(d)`, `map(f)`, `and_then(f)`, `filter(f)`, plus `opt ?? d` and `opt?.member` |
| `Result[T, E]` | `is_ok()`, `is_err()`, `unwrap()`, `expect(msg)`, `unwrap_or(d)`, `unwrap_err()`, `map(f)`, `map_err(f)`, plus postfix `?` |

- **snake_case only.** `isSome()` / `isOk()` are compile errors
  (`type 'Option[int]' has no method 'isSome'`). `unwrapOr(...)` and `ok()`
  compile and then fail at run time with
  `Uncaught RuntimeError: internal interpreter limitation: ... method not found`.
- `unwrap()` on `None` or `Err` throws `UnwrapError`
  (``called `unwrap()` on a None value``,
  ``called `unwrap()` on an Err value: <error>``).
- Postfix `?` belongs on a `Result`, inside a function that returns a
  `Result`; elsewhere it is `E_PROPAGATE_WRONG_RETURN` (also in a function
  returning `Option`). Never apply it to an `Option`: inside a
  Result-returning function that compiles, and a `None` becomes `Err(None)`
  (printing it gives ``Uncaught RenderError: rendered an `Err` value: Err(None)``).
  For an `Option` use `??`, `?.` or `match`.
- `println(opt)` prints the value for `Some(v)` and an empty line for `None`.
- There is no `if let`; use `match` or `??`.

## attempt

`attempt expr` evaluates a `Result`: an `Ok(v)` gives `v`, an `Err(e)` jumps
to the enclosing `try`'s `catch Err(e)` arm. It works in every mode and is the
only `try` form allowed in freestanding code.

```loup
@mode(host.scripted)

from system.text import (parseInt);

func describe(s: string): string {
    try {
        let n = attempt parseInt(s);
        return i"number {$ n $}";
    } catch Err(msg) {
        return i"not a number: {$ msg $}";
    }
}

println(describe("17"));
println(describe("seventeen"));
```

```text
number 17
not a number: invalid integer: seventeen
```

## Panics and unreachable

- `panic("...")` is **undefined** in hosted code in 1.25.1
  (``undefined identifier `panic` ``). Throw an exception instead.
- `unreachable` is an expression of type `noreturn`. Reaching it ends the
  program; it cannot be caught:

```loup,panics
@mode(host.scripted)

func grade(n: int): string {
    if (n >= 0) {
        return "ok";
    }
    unreachable
}

println(grade(1));
println(grade(-1));
```

```text
ok
Uncaught RuntimeError: panic: reached an `unreachable` expression
```

- Freestanding panics go to a `@panic_handler` chosen by the manifest's
  `[build] panic` policy; see [freestanding.md](freestanding.md).
- `int` arithmetic does not trap on overflow: it wraps. Sized integers
  (`int8` ... `uint64`) throw `NumericOverflowError`; integer division by zero
  throws `IntegerDivisionError`.

## Choosing a strategy

- Expected failures a caller should handle (parsing, validation, lookups):
  return `Result[T, string]` or `Result[T, MyError]` and propagate with `?`.
- Missing values: `Option[T]` with `??` / `match`.
- Environmental failures (files, processes, network): the runtime throws
  `IoError`; catch it where you can recover.
- Programming errors and impossible states: throw `RuntimeError` or use
  `unreachable`.
- Validate untrusted numbers with `system.text.parseInt` / `parseFloat`
  (Result); `"x".toInt()` silently returns `0`.

## Diagnostic formats

**`loup run`** (compile errors; exit 2), one line per error, no snippet:

```text
main.lpscr:3:4: error[E0001]: E_CONDITION_PARENS: the condition of `if` must be in parentheses; add them: `if (...) {`
main.lpscr:2:11: error[E0001]: `this` is a reserved word (§1-3.4) and cannot name a parameter
  note: rename the parameter — e.g. `this_value`
```

- The bracket holds the code. `E0001` is shared by many rules; a specific rule
  name then starts the message. `E0002` is a missing delimiter, `E0003` a
  missing `;`.
- Parse errors are reported before type errors; after fixing them, run again.
- Warnings print after the program's output:
  `main.lphc:3:14: warning: W_ANY_IN_AOT_MODE: ...`.
- On Linux x86-64 the self-hosted `loup run` writes diagnostics to stdout;
  Stage0 writes them to stderr.

**`loup check`** (project), rustc-style; add `--no-color`:

```text
error[E0001]: E_BARE_FIELD: class field `x` must be declared `let` or `var`; write `var x: ...` (mutable) or `let x: ...` (immutable)
 --> src/main.loup:4:5
  |
4 |     x: int;
  |     ^
  |
```

`--format short` gives `src/main.loup:4:5: error: E_BARE_FIELD: ...` (no
code); `--format json` gives one object per line with `code`, `file`,
`line`, `column`, `message`, `severity`, `notes`. A diagnostic without a file
(manifest and build errors such as `E-CHECK-MANIFEST`, `E-BUILD-NATIVE`) is
rendered with an empty ` --> :1:1` snippet; read the message line.

**Run-time errors** print `Uncaught <Class>: <message>` plus `at` frames
(see [Exceptions](#exceptions)) and exit 1. Errors that start with
`internal interpreter limitation:` mean the program used something the
1.25.1 interpreter does not implement (for example `unwrapOr`,
`shared C(...)`): rewrite the code, do not retry.

**Silent failures** (no diagnostic at all): a retired or misspelled
`@mode(...)` (the file runs as `host.scripted`; an AOT `main()` never runs),
a plain `"...{x}..."` string (printed literally), `defer` (never runs),
`"abc".toInt()` (returns `0`), `int` overflow (wraps), `[1, 2] == [1, 2]`
(`false`).

## Table of diagnostics

All messages below were produced by the 1.25.1 toolchain (`loup run`; file
names shortened to `main.<ext>`). Many are shown in full, with the wrong and
fixed code, in [common-mistakes.md](common-mistakes.md).

| Message (start) | Cause | Fix |
|---|---|---|
| ``error[E0001]: expected expression`` + ``error[E0003]: expected `;` `` | `//` comment, `? :`, `fn`/`def`/`function`, `->`, `elif`, `i++` | `#`, `if` expression, `func f(): T`, `else if`, `i += 1` |
| ``E_CONDITION_PARENS: the condition of `if` must be in parentheses`` | `if x > 0 {` | `if (x > 0) {` |
| `expected RParen, found Colon` | `catch (e: IoError)` | `catch (IoError as e)` |
| `undefined type 'e'` | `catch (e)` | `catch (Exception as e)` or `catch { }` |
| `undefined type 'IOError'` | wrong class name | `IoError` |
| `expected LParen, found Identifier` | `from m import a, b` | `from m import (a, b);` |
| `E_NUMERIC_TYPE_MISMATCH: mixed 'float' and 'int' operands` | `1.5 + 2` | `1.5 + (2 as float)` |
| `cannot assign 'int' to binding 'x' of type 'float'` | `let x: float = 3` | `3.0` or `3 as float` |
| ``binary `+` on a string requires a string operand, found `int` `` | `"n=" + 5` | `i"n={$ n $}"` or `str(n)` |
| `cannot assign to immutable binding 'x'` | assigning a `let` or a `for` variable | `var x`, `for (var x in xs)` |
| `E_CONST_NOT_EVALUABLE` | `const` with a run-time value | `let` |
| `E_GLOBAL_MISSING` | closure assigns an outer variable | `nonlocal x;` / `global x;` first in the closure |
| `E_BARE_FIELD` | class field without `let`/`var` | `pub var x: int = 0;` |
| `member 'x' of class 'P' is private` | field without `pub` | add `pub` |
| `E_MODIFIER_REQUIRED` | method assigns `this.field` | `pub modifier func` |
| `E_SAFE_CONTEXT_REQUIRED` | `modifier` call or field assignment on an object | `safe { ... }` or `safe func` |
| `E_READS_MUTATION` | mutating a parameter without a verb | `edits p: T` and `f(edits: x)` |
| `E_VERB_REQUIRED` | call omits `edits:` / `takes:` / `shares:` | write the verb at the call |
| `E_VERB_MISMATCH` | wrong verb at the call | use the parameter's verb |
| `E_USE_AFTER_TAKE` | value used after `takes:` | use it before, or pass a copy |
| `E_USE_AFTER_MOVE` | `unique` value used after a move | use the new binding |
| `E_MOVE_OUT_OF_BORROW` | moving a borrowed parameter | declare it `takes` |
| `E_UNIQUE_CLASS_ARC_BINDING` | `unique class` outside host.native/freestanding | move it to a `.lphc` file or drop `unique` |
| `E_OVERRIDE_REQUIRED` | redefining an inherited method | add `override` |
| `class 'A' does not implement all methods of interface 'I'` | missing interface method | implement it |
| `method 'f' may not return a value on all code paths` | missing `return`, or a non-void `abstract func` | add the `return`; use an interface |
| `Non-exhaustive match: missing variants X` | `match` without every case | add arms or `_ =>` |
| `expected FatArrow, found Pipe` | or-pattern `"a" \| "b" =>` | separate arms |
| `type 'Option[int]' has no method 'isSome'` | camelCase Option/Result method | `is_some()` |
| `E_PROPAGATE_WRONG_RETURN` | `?` in a function that does not return `Result` | return `Result`; for an Option use `??`/`match` |
| `E_THROW_NON_ERROR` | `throw "text"` | `throw ValueError("text")` |
| `'IoError' is not callable` | constructing `IoError` | declare your own exception class |
| `E_MAIN_SIGNATURE` | `func main(args: ...)` | `func main(): int` + `runtime.args()` |
| `E_TOPLEVEL_CONTROL_AOT` | statements at module scope in an AOT mode | move them into `main()` |
| `E_MODE_POSITION` / `E_MODE_DUPLICATE` | `@mode` not first / twice | one directive, first line |
| `` `type` is a reserved word (§1-3.4) and cannot name a binding `` | reserved word as a name | rename |
| `function 'println' expects 1 argument(s), but 2 provided` | `println(a, b)` | `println(i"{$ a $} {$ b $}")` |
| ``undefined identifier `len` `` / `'int' is not callable` | Python built-ins | `xs.len()`, `s.toInt()`, `x as float` |
| `function 'sort' expects 1 argument(s), but 0 provided` | `xs.sort()` | `xs.sort(func(a: int, b: int): int { return a - b; })` |
| ``undefined identifier `panic` `` | `panic(...)` in hosted code | `throw RuntimeError(...)` |
| ``cannot import private symbol `f` from module`` | importing a non-`pub` name | add `pub` |
| `'data.json' is not a standard-library module` | absent or misnamed module | see [stdlib.md](stdlib.md) (`system.json`) |
| `unresolved package import 'x/y'` | file not found from the package roots | check the path; in `tests/` use `from ..src.x import (...)` |
| `` `sync.thread` is not available in the scripted runtime `` | any `sync.*` import (any mode) | not available in 1.25.1 |
| `E_FREESTANDING_EXCEPTIONS` | `throw`/`catch (T as e)` in freestanding | `Result` + `attempt` |
| `E_PANIC_HANDLER_SIG` | handler returns `void` | `: noreturn` |
| `error[E-CHECK-MANIFEST]: manifest not found` | `loup check` outside a project | run in the project, or use `loup run` |
| `capability 'net' is not available` (run time) | network without permission | `loup run --allow-net` |
| `internal interpreter limitation: ...` (run time) | unimplemented feature | rewrite without it |
| `thread 'loup-main' panicked at ... parser/expr.rs` (exit 101) | `instanceof` | use `x is T` |
| `E_COMPILED_IMPORT_SCRIPTED` | a `web.compiled` file imports a stdlib (or scripted) module | no stdlib in `web.compiled` in 1.25.1 |
| `main trap: ... int.op_floordiv not implemented` / ``no exported function `RenderContext` `` (Wasm run) | `//` or `i"..."` in a Wasm build | avoid them in code you ship as Wasm, or run it with `loup run` |
