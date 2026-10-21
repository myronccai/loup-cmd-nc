# Common mistakes: wrong code, the real message, the fix (toolchain 1.25.1)

Each entry shows code an agent coming from another language tends to write,
the exact output of `loup run` (or `loup check` for freestanding code), why
it happens, and the corrected program. Paths are shown as `main.<ext>`.

Contents: [Modes and entry points](#modes-and-entry-points) ·
[Syntax from other languages](#syntax-from-other-languages) ·
[Types and values](#types-and-values) · [Classes](#classes) ·
[Ownership](#ownership) · [Errors and Option/Result](#errors-and-optionresult) ·
[Silent behaviour gaps](#silent-behaviour-gaps)

## Modes and entry points

### 1. A retired mode name

```loup,ignore
@mode(native)

func main(): void {
    println("hello");
}
```

No diagnostic, no output, exit status 0. `native`, `compiled` and `scripted`
are v1.16 names; unknown names run the file as `host.scripted`, so `main()`
is never called. (This listing is not run by the verifier, which rejects
retired names outright.) Fix: use a current name, and the extension that goes
with it (`.lphc`):

```loup
@mode(host.native)

func main(): void {
    println("hello");
}
```

```text
hello
```

### 2. Statements at module scope in an AOT mode

```loup,does_not_compile
@mode(host.dual)

println("starting");

func main(): void {
    println("hello");
}
```

```text
main.loup:3:1: error[E_TOPLEVEL_CONTROL_AOT]: E_TOPLEVEL_CONTROL_AOT: top-level control flow is not allowed in `host.dual` — only declarations and constant initializers are permitted at module scope; the runtime invokes `main()` after module initialization (§1-2.4)
```

Fix: move the statement into `main()` (or make the file a `host.scripted`
script).

```loup
@mode(host.dual)

func main(): void {
    println("starting");
    println("hello");
}
```

### 3. Parameters on main

```loup,does_not_compile
@mode(host.dual)

func main(args: list[string]): int {
    println(args);
    return 0;
}
```

```text
main.loup:3:11: error[E_MAIN_SIGNATURE]: E_MAIN_SIGNATURE: `main` takes no parameters — command-line arguments come from `runtime.args()` (§1-2.4.5, ruling MAIN-1)
```

```loup
@mode(host.dual)

func main(): int {
    let argv = runtime.args();
    println(argv.len());
    return 0;
}
```

### 4. A web.compiled file importing the standard library

```loup,does_not_compile
@mode(web.compiled)

from core.math import (sqrt);

func main(): void {
    println(sqrt(16.0));
}
```

```text
main.lpweb:3:1: error[E0001]: `@mode(web.compiled)` module cannot import `@mode(host.scripted)` module
  note: `@mode(web.compiled)` modules can only import other `@mode(web.compiled)` modules
  note: error code: E_COMPILED_IMPORT_SCRIPTED
```

No standard-library module can be imported from `web.compiled` in 1.25.1.
Write the logic yourself, or use `host.dual` if the target is not a browser.

## Syntax from other languages

### 5. Conditions without parentheses

```loup,does_not_compile
@mode(host.scripted)

let n = 5;
if n > 3 {
    println("big");
}
```

```text
main.lpscr:4:4: error[E0001]: E_CONDITION_PARENS: the condition of `if` must be in parentheses; add them: `if (...) {`
```

```loup
@mode(host.scripted)

let n = 5;
if (n > 3) {
    println("big");
}
```

The same applies to `else if (...)`, `while (...)` and `for (x in xs)`.

### 6. `//` comments

```loup,does_not_compile
@mode(host.scripted)

// count the items
let n = 5;
println(n);
```

```text
main.lpscr:3:1: error[E0001]: expected expression
main.lpscr:3:4: error[E0003]: expected `;`
```

`//` is the floor-division operator. Comments start with `#`:

```loup
@mode(host.scripted)

# count the items
let n = 5;
println(n // 2);
```

```text
2
```

### 7. The ternary operator

```loup,does_not_compile
@mode(host.scripted)

let n = 5;
let size = n > 3 ? "big" : "small";
println(size);
```

```text
main.lpscr:4:20: error[E0003]: expected `;`
```

```loup
@mode(host.scripted)

let n = 5;
let size = if (n > 3) { "big" } else { "small" };
println(size);
```

### 8. Function syntax from Rust, Python or JavaScript

```loup,does_not_compile
@mode(host.scripted)

fn add(a: int, b: int) -> int {
    return a + b;
}

println(add(1, 2));
```

```text
main.lpscr:3:1: error[E0001]: expected expression
main.lpscr:3:4: error[E0003]: expected `;`
main.lpscr:5:1: error[E0001]: expected expression
```

```loup
@mode(host.scripted)

func add(a: int, b: int): int {
    return a + b;
}

println(add(1, 2));
```

`def` and `function` fail the same way. `fn(int): int` is only a function
type.

### 9. Import list without parentheses

```loup,does_not_compile
@mode(host.scripted)

from core.math import sqrt, floor;

println(floor(sqrt(10.0)));
```

```text
main.lpscr:3:23: error[E0001]: expected LParen, found Identifier
main.lpscr:3:34: error[E0001]: expected RParen, found Semicolon
```

```loup
@mode(host.scripted)

from core.math import (sqrt, floor);

println(floor(sqrt(10.0)));
```

### 10. Python built-ins and methods

```loup,does_not_compile
@mode(host.scripted)

var names = ["cy", "ann", "bob"];
names.sort();
println(len(names));
```

```text
main.lpscr:5:9: error[E0001]: undefined identifier `len`
```

Once `len` is fixed, the next run reports
`function 'sort' expects 1 argument(s), but 0 provided`: `sort` needs a
comparator. Name-resolution errors hide later type errors, so fix and rerun.

```loup
@mode(host.scripted)

var names = ["cy", "ann", "bob"];
names.sort(func(a: string, b: string): int { return a.compareTo(b); });
println(names);
println(names.len());
```

```text
["ann", "bob", "cy"]
3
```

Also absent: `int(x)` / `float(x)` (use `"7".toInt()`, `n as float`),
`upper()` (use `to_uppercase()`), `.length` as a property.

### 11. println with several arguments

```loup,does_not_compile
@mode(host.scripted)

let name = "Ann";
let age = 31;
println(name, age);
```

```text
main.lpscr:5:1: error[E0001]: function 'println' expects 1 argument(s), but 2 provided
```

```loup
@mode(host.scripted)

let name = "Ann";
let age = 31;
println(i"{$ name $} {$ age $}");
```

```text
Ann 31
```

### 12. A reserved word as a name

```loup,does_not_compile
@mode(host.scripted)

let type = "csv";
println(type);
```

```text
main.lpscr:3:5: error[E0001]: `type` is a reserved word (§1-3.4) and cannot name a binding
  note: rename the binding — e.g. `type_value`
main.lpscr:4:9: error[E0001]: expected expression
```

Rename it (`kind`, `format`). Other common collisions: `match`, `from`,
`in`, `is`, `with`, `new`, `this`, `static`, `global`, `shared`, `local`,
`template`, `where`, `yield`.

## Types and values

### 13. Mixing int and float

```loup,does_not_compile
@mode(host.scripted)

let count = 3;
let average = 10.0 / count;
println(average);
```

```text
main.lpscr:4:15: error[E0001]: E_NUMERIC_TYPE_MISMATCH: mixed 'float' and 'int' operands for operator '/' — convert one operand explicitly (`as float` or `as int`)
```

```loup
@mode(host.scripted)

let count = 3;
let average = 10.0 / (count as float);
println(average);
```

```text
3.3333333333333335
```

### 14. Joining a string and a number with `+`

```loup,does_not_compile
@mode(host.scripted)

let n = 5;
println("count: " + n);
```

```text
main.lpscr:4:9: error[E_OPERATOR_MISSING]: binary `+` on a string requires a string operand, found `int`;                          there is no implicit conversion — use `.to_string()`
```

```loup
@mode(host.scripted)

let n = 5;
println(i"count: {$ n $}");
println("count: " + n.to_string());
```

### 15. Interpolation without the `i` prefix

```loup,not_desired_behavior
@mode(host.scripted)

let name = "Ann";
println("Hello, {name}!");
```

```text
Hello, {name}!
```

No error: a plain string is literal. Use `i"..."` and `{$ ... $}`:

```loup
@mode(host.scripted)

let name = "Ann";
println(i"Hello, {$ name $}!");
```

```text
Hello, Ann!
```

### 16. Assigning a `let`, or a loop variable

```loup,does_not_compile
@mode(host.scripted)

let xs = [1, 2];
for (x in xs) {
    x = x * 2;
    println(x);
}
```

```text
main.lpscr:5:5: error[E0001]: cannot assign to immutable binding 'x'
```

```loup
@mode(host.scripted)

let xs = [1, 2];
for (var x in xs) {
    x = x * 2;
    println(x);
}
```

### 17. A run-time value in `const`

```loup,does_not_compile
@mode(host.scripted)

from core.time import (Instant);

const started = Instant.now();
println(started.toMillis() > 0);
```

```text
main.lpscr:5:17: error[E_CONST_NOT_EVALUABLE]: the initialiser of `const started` is not a const-expression — use `let` for a runtime value (E_CONST_NOT_EVALUABLE)
```

Fix: `let started = Instant.now();`.

### 18. A closure that assigns an outer variable

```loup,does_not_compile
@mode(host.scripted)

func count_calls(): int {
    var count = 0;
    let bump = func(): void {
        count = count + 1;
    };
    bump();
    return count;
}

println(count_calls());
```

```text
main.lpscr:6:9: error[E_GLOBAL_MISSING]: E_GLOBAL_MISSING: assignment to outer-scope `var` `count` inside a closure needs a `nonlocal count` (an enclosing function's variable) or `global count` (a module variable) declaration at the top of the closure's body (§1-7.3)
```

```loup
@mode(host.scripted)

func count_calls(): int {
    var count = 0;
    let bump = func(): void {
        nonlocal count;
        count = count + 1;
    };
    bump();
    return count;
}

println(count_calls());
```

```text
1
```

## Classes

### 19. A class field without `let`/`var`, or without `pub`

```loup,does_not_compile
@mode(host.scripted)

class Point {
    x: int;
}

println(Point(x = 1).x);
```

```text
main.lpscr:4:5: error[E0001]: E_BARE_FIELD: class field `x` must be declared `let` or `var`; write `var x: ...` (mutable) or `let x: ...` (immutable)
```

After adding `var`, reading `p.x` from outside gives
`member 'x' of class 'Point' is private`. Fix both:

```loup
@mode(host.scripted)

class Point {
    pub var x: int = 0;
}

println(Point(x = 1).x);
```

### 20. A method that assigns a field without `modifier`

```loup,does_not_compile
@mode(host.scripted)

class Counter {
    pub var count: int = 0;
    pub func bump(): void {
        this.count = this.count + 1;
    }
}

let c = Counter();
safe { c.bump(); }
println(c.count);
```

```text
main.lpscr:6:9: error[E_MODIFIER_REQUIRED]: E_MODIFIER_REQUIRED: writing to `var` field 'count' of `self` in method 'bump' of class 'Counter' requires the method to be declared as `modifier`
```

### 21. Calling a `modifier` method outside `safe`

```loup,does_not_compile
@mode(host.scripted)

class Counter {
    pub var count: int = 0;
    pub modifier func bump(): void {
        this.count = this.count + 1;
    }
}

let c = Counter();
c.bump();
println(c.count);
```

```text
main.lpscr:11:1: error[E_SAFE_CONTEXT_REQUIRED]: E_SAFE_CONTEXT_REQUIRED: `modifier` method 'bump' called on ARC receiver of type 'Counter' outside `safe {}` or `safe func` context — wrap the call in `safe { ... }` or mark the enclosing function as `safe func`
```

Assigning a field from outside (`c.count = 5;`) gives the same error. Fix:

```loup
@mode(host.scripted)

class Counter {
    pub var count: int = 0;
    pub modifier func bump(): void {
        this.count = this.count + 1;
    }
}

let c = Counter();
safe {
    c.bump();
    c.count = c.count + 10;
}
println(c.count);
```

```text
11
```

### 22. Redefining a method without `override`

```loup,does_not_compile
@mode(host.scripted)

class Base {
    pub func greet(): string { return "hi"; }
}

class Loud : Base {
    pub func greet(): string { return "HI"; }
}

println(Loud().greet());
```

```text
main.lpscr:8:5: error[E_OVERRIDE_REQUIRED]: method `greet` on class `Loud` shadows a parent method on `Base` and must be marked `override` (E_OVERRIDE_REQUIRED)
```

Fix: `pub override func greet(): string { ... }`.

## Ownership

### 23. Mutating a parameter declared without a verb

```loup,does_not_compile
@mode(host.scripted)

func add_default(tags: list[string]): void {
    tags.push("new");
}

var tags = ["a"];
add_default(tags);
println(tags);
```

```text
main.lpscr:4:5: error[E_READS_MUTATION]: E_READS_MUTATION: parameter 'tags' is a `reads` borrow (a parameter without a verb is read-only, §3-2.4.9) and cannot be mutated (`push` called on it); declare it `edits` and pass `edits: …` to change the caller's value, or copy it into a local first
```

### 24. Forgetting the verb at the call site

```loup,does_not_compile
@mode(host.scripted)

func add_default(edits tags: list[string]): void {
    tags.push("new");
}

var tags = ["a"];
add_default(tags);
println(tags);
```

```text
main.lpscr:8:13: error[E_VERB_REQUIRED]: E_VERB_REQUIRED: parameter 'tags' requires 'edits' verb acknowledgment at call site
```

```loup
@mode(host.scripted)

func add_default(edits tags: list[string]): void {
    tags.push("new");
}

var tags = ["a"];
add_default(edits: tags);
println(tags);
```

```text
["a", "new"]
```

### 25. Using a value after `takes`

```loup,does_not_compile
@mode(host.scripted)

class Conn {
    pub let id: int;
    new(id: int) { this.id = id; }
}

func close(takes c: Conn): int {
    return c.id;
}

let conn = Conn(7);
println(close(takes: conn));
println(conn.id);
```

```text
main.lpscr:14:9: error[E_USE_AFTER_TAKE]: E_USE_AFTER_TAKE: binding 'conn' was consumed by a `takes` parameter and cannot be used again
```

Read what you need before handing the value over, or do not declare the
parameter `takes`.

### 26. Using a `unique` value after a move

```loup,does_not_compile
@mode(host.native)

unique class Token {
    pub let id: int;
    new(id: int) { this.id = id; }
}

func main(): void {
    unique let a = Token(1);
    let b = a;
    println(a.id);
}
```

```text
main.lphc:11:13: error[E_USE_AFTER_MOVE]: E_USE_AFTER_MOVE: binding 'a' was moved and cannot be used again — `unique class` instances and move-only structs have single ownership
```

Use `b` after the move. A `unique class` in a `.lpscr` or `.loup` file fails
earlier with `E_UNIQUE_CLASS_ARC_BINDING`.

## Errors and Option/Result

### 27. Catch syntax from TypeScript or Kotlin

```loup,does_not_compile
@mode(host.scripted)

try {
    println(readText("settings.ini"));
} catch (e: IoError) {
    println("no settings");
}
```

```text
main.lpscr:5:11: error[E0001]: expected RParen, found Colon
main.lpscr:5:11: error[E0002]: expected `{`
main.lpscr:5:11: error[E0001]: expected expression
main.lpscr:5:13: error[E0003]: expected `;`
main.lpscr:7:1: error[E0001]: expected expression
```

```loup
@mode(host.scripted)

try {
    println(readText("settings.ini"));
} catch (IoError as e) {
    println(i"no settings (error {$ e.code $})");
}
```

```text
no settings (error 2)
```

The class is `IoError`; `IOError` gives `undefined type 'IOError'`.

### 28. camelCase Option/Result methods

```loup,does_not_compile
@mode(host.scripted)

let port: Option[int] = Some(8080);
println(port.isSome());
```

```text
main.lpscr:4:9: error[E0001]: type 'Option[int]' has no method 'isSome'
```

`unwrapOr` is worse: it compiles and fails when it runs.

```loup,throws
@mode(host.scripted)

from system.text import (parseInt);

println(parseInt("80").unwrapOr(0));
```

```text
Uncaught RuntimeError: internal interpreter limitation: unsupported instruction: CallVirtual unwrapOr on user class Result — method not found
```

```loup
@mode(host.scripted)

from system.text import (parseInt);

let port: Option[int] = Some(8080);
println(port.is_some());
println(parseInt("80").unwrap_or(0));
```

### 29. `?` on an Option

```loup,throws
@mode(host.scripted)

func first_word(text: string): Option[string] {
    let words = text.split(" ");
    if (text.is_empty()) {
        return None;
    }
    return Some(words[0]);
}

func shout_first(text: string): Result[string, string] {
    let w = first_word(text)?;
    return Ok(w.to_uppercase());
}

println(shout_first("hello world"));
println(shout_first(""));
```

```text
HELLO
Uncaught RenderError: rendered an `Err` value: Err(None)
  at <main> (main.lpscr:17:1)
```

It compiles: a `None` silently becomes `Err(None)`. Convert explicitly:

```loup
@mode(host.scripted)

func first_word(text: string): Option[string] {
    if (text.is_empty()) {
        return None;
    }
    return Some(text.split(" ")[0]);
}

func shout_first(text: string): Result[string, string] {
    let w = match first_word(text) {
        Some(found) => found,
        None => { return Err("empty text"); },
    };
    return Ok(w.to_uppercase());
}

println(shout_first("hello world").unwrap_or("?"));
println(shout_first("").unwrap_err());
```

```text
HELLO
empty text
```

### 30. `panic` in hosted code

```loup,does_not_compile
@mode(host.scripted)

func check_age(age: int): void {
    if (age < 0) {
        panic("negative age");
    }
}

check_age(3);
```

```text
main.lpscr:5:9: error[E0001]: undefined identifier `panic`
```

Fix: `throw ValueError("negative age");` (or `unreachable` for a state that
cannot happen).

## Silent behaviour gaps

These compile and run but do not do what the specification says.

### 31. `defer` never runs

```loup,not_desired_behavior
@mode(host.scripted)

func work(): void {
    defer println("cleanup");
    println("working");
}

work();
```

```text
working
```

Use `try`/`finally`:

```loup
@mode(host.scripted)

func work(): void {
    try {
        println("working");
    } finally {
        println("cleanup");
    }
}

work();
```

```text
working
cleanup
```

### 32. `toInt()` on bad input

```loup,not_desired_behavior
@mode(host.scripted)

let qty = "ten".toInt();
println(qty);
```

```text
0
```

Validate with `parseInt`, which returns a `Result`:

```loup
@mode(host.scripted)

from system.text import (parseInt);

match parseInt("ten") {
    Ok(n) => println(n),
    Err(msg) => println(i"not a number: {$ msg $}"),
}
```

```text
not a number: invalid integer: ten
```

### 33. Comparing lists with `==`

```loup,not_desired_behavior
@mode(host.scripted)

println([1, 2] == [1, 2]);
```

```text
false
```

Element-wise list equality is specified but not implemented. Compare lengths
and elements yourself (struct and enum `==` do work).

### 34. `int` overflow

```loup,not_desired_behavior
@mode(host.scripted)

let big = 9223372036854775807;
println(big + 1);
```

```text
-9223372036854775808
```

`int` wraps silently (the specification says it traps). Sized integers
(`int8` ... `uint64`) throw `NumericOverflowError`.

### 35. A line that starts with `(` continues the previous one

```loup,does_not_compile
@mode(host.scripted)

let a = 1
(a + 2)
println(a)
```

```text
main.lpscr:3:9: error[E0001]: expression of type 'int' is not callable
main.lpscr:4:2: error[E0001]: type of 'a' is not yet known
```

Without `;`, `1` newline `(a + 2)` is read as the call `1(a + 2)`. A line
starting with `[` or `with` behaves the same way. End statements with `;`.
