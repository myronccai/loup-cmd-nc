# Loup syntax reference (toolchain 1.25.1)

Every listing here runs with `loup run` and the block after it is its real
output. Statements end with `;` in every listing; see "Statements" for why.

Contents: [Files and statements](#files-and-statements) ·
[Literals and strings](#literals-and-strings) ·
[Bindings and types](#bindings-and-types) · [Operators](#operators) ·
[Control flow](#control-flow) · [match](#match) · [Functions](#functions) ·
[Collections](#collections) · [String methods](#string-methods) ·
[Modules and imports](#modules-and-imports) ·
[Built-in functions](#built-in-functions) · [Not in the grammar](#not-in-the-grammar)

## Files and statements

- The first token of a file is `@mode(...)`; only comments may precede it. A
  second directive is `E_MODE_DUPLICATE`, a late one `E_MODE_POSITION`.
- `#` starts a comment, `##` a doc comment, `#!` a shebang on line 1.
  `//` is the floor-division operator.
- A newline ends a statement and `;` is optional, **but** a line that begins
  with `(`, `[` or `with` continues the previous expression
  (`f()` + newline + `(a + b)` is the call `f()(a + b)`). Write `;` at the end
  of every statement and you never hit this.
- Blocks use braces. Indentation is not significant.
- Identifiers: letters, digits, `_`; not starting with a digit. Names that
  begin and end with `__` are reserved (`__name__`, `__file__`).

Reserved words (cannot name a variable, parameter, field, function or type):
`abstract and as async atomic attempt await bnot borrow break catch class const
consume continue defer del do dynamic edits else enum extern false final finally
fn for from func gen global if implements import in instanceof interface is let
lifetime local macro match modifier namespace new noescape nonlocal not onstack or
override portal prefer pub reads requires return safe sealed shared shares static
struct super suspend synchronized takes template this throw true try type typeof
unique unreachable unsafe var volatile where while with yield Self`.
Contextual (usable as names elsewhere): `self get set group excl concurrent arc
operator spawn noreturn impossible box`.

## Literals and strings

```loup
@mode(host.scripted)

let count: int = 1_000_000;
let mask = 0xff + 0b1010 + 0o17;
let ratio: float = 2.5e-3;
let ready: bool = true;
let initial: char = c"A";
let header = b"\x89PNG";
println(count);
println(mask);
println(ratio);
println(ready);
println(initial);
println(header.len());
println("tab\tquote\" backslash\\ smile \u{1F600}");
println(r"C:\temp\new");
```

```text
1000000
280
0.0025
true
A
4
tab	quote" backslash\ smile 😀
C:\temp\new
```

- Unicode escapes are `\u{...}` only. `r"..."` is a raw string.
- `c"x"` is a `char`; `b"..."` is `bytes`.
- A whole float prints without `.0` (`println(1.0)` prints `1`).

**Interpolation** needs the `i` prefix and `{$ expr $}`. Filters follow `|`:

```loup
@mode(host.scripted)

let name = "  ann lee ";
let tags = ["red", "blue"];
println(i"[{$ name | trim | title $}] has {$ tags.len() $} tags: {$ tags | join(", ") $}");
println(i"{$ name | trim | upper $} / {$ "abcdefgh" | truncate(4) $} / {$ "" | default("none") $}");
println("plain strings do not interpolate: {name}");
```

```text
[Ann Lee] has 2 tags: red, blue
ANN LEE / abcd… / none
plain strings do not interpolate: {name}
```

Filters that work: `upper lower trim trim_start trim_end title length reverse
truncate(n) replace(a, b) wrap(open, close) join(sep) default(text)`.

**Multiline strings** use `"""`. The indentation of the line holding the
opening `"""` is removed from every content line; the newlines after the
opener and before the closer are dropped:

```loup
@mode(host.scripted)

func usage(): string {
    let text = """
    usage: tool [options] FILE
      -v  verbose
    """;
    return text;
}

println(usage());
```

```text
usage: tool [options] FILE
  -v  verbose
```

**Template fences** are template values; render them with `.render({})`.
Names resolve lexically:

````loup
@mode(host.scripted)

let who = "Ann";
let items = ["tea", "jam"];
let signed_in = true;
let page = ```(html):(none)
<p class="greeting">Hello, {$ who $}</p><ul>{% for (item in items) %}<li>{$ item $}</li>{% end %}</ul>
```;
println(page.render({}));
let status = ```(text):(none)
{% if (signed_in) %}signed in{% else %}signed out{% end %}
```;
println(status.render({}));
````

```text
<p class="greeting">Hello, Ann</p><ul><li>tea</li><li>jam</li></ul>
signed in
```

- Directives take parenthesized headers and close with `{% end %}`:
  `{% for (x in xs) %}...{% end %}`, `{% if (c) %}...{% else %}...{% end %}`.
  `{% for x in xs %}` / `{% endfor %}` do not parse.
- `html` fences do **not** escape values in 1.25.1 (a value of `"<b>x</b>"`
  is emitted raw): escape untrusted text yourself.
- A bare opener without `(lang):(format)` renders wrongly; four-backtick
  nesting fails. Native builds refuse fences.

## Bindings and types

```loup
@mode(host.scripted)

const MAX_RETRIES: int = 3 * 2;
let name = "loup";
var attempts = 0;
attempts += 1;
let port: int? = None;
type Celsius = float;
let room: Celsius = 21.5;
let (quotient, remainder) = (17 // 5, 17 % 5);
println(i"{$ name $} {$ attempts $}/{$ MAX_RETRIES $} port={$ port ?? 8080 $} room={$ room $}");
println(i"{$ quotient $} r {$ remainder $}");
```

```text
loup 1/6 port=8080 room=21.5
3 r 2
```

- `let` cannot be reassigned (`cannot assign to immutable binding`); `var` can.
- `const` needs a compile-time value; use `let` for anything computed at run
  time.
- `T?` is `Option[T]`.
- Primitive types: `int` (64-bit, wraps on overflow), `float` (64-bit),
  `bool`, `string`, `char`, `bytes`, sized `int8 int16 int32 int64 uint8
  uint16 uint32 uint64 float32`, and `Any`. Sized integers throw
  `NumericOverflowError` when a result or an `as` conversion does not fit.
  `bigint`, `decimal` and `complex64` are specified but poorly supported by
  `loup run` in 1.25.1; test before using them.
- Conversions: `n as float`, `x as int` (truncates), `str(v)`, `v.to_string()`,
  `"42".toInt()`, `"2.5".to_float()`. `int(x)` and `float(x)` do not exist.

## Operators

| Operators | Meaning |
|---|---|
| `+ - * **` | arithmetic; `+` also joins strings and lists |
| `/` | division; on `int` truncates toward zero (`-7 / 2` is `-3`) |
| `//` | floor division (`-7 // 2` is `-4`) |
| `%` | remainder, sign of the dividend (`-7 % 2` is `-1`) |
| `== != < <= > >=` | comparison (strings compare by value) |
| `and or not`, `&& \|\| !` | logical; both spellings are accepted |
| `& \| ^ bnot << >>` | bitwise |
| `in`, `not in` | membership in lists, dicts (keys), sets, strings |
| `is`, `as` | type test and conversion (`v is string`, `a as int`) |
| `??` | Option default: `opt ?? fallback` |
| `?.` | Option chaining: `user?.email` |
| postfix `?` | propagate an `Err` from a `Result` (only in a function returning `Result`; never apply it to an `Option`, see [errors-and-diagnostics.md](errors-and-diagnostics.md#option-and-result)) |
| `+= -= *= /=` | compound assignment |

There is no `++`/`--` and no `? :`. Integers and floats never mix:
`1.5 + 2` is `E_NUMERIC_TYPE_MISMATCH`; write `1.5 + (2 as float)`.
Integer division by zero throws `IntegerDivisionError`.

## Control flow

```loup
@mode(host.scripted)

let scores = [72, 95, 40];
for (s in scores) {
    if (s >= 90) {
        println(i"{$ s $}: excellent");
    } else if (s >= 50) {
        println(i"{$ s $}: pass");
    } else {
        println(i"{$ s $}: fail");
    }
}

let label = if (scores.len() > 2) { "many" } else { "few" };
println(label);

var i = 0;
while (i < 3) {
    i += 1;
    if (i == 2) { continue; }
    println(i"while {$ i $}");
}

for (var k = 0; k < 2; k = k + 1) { println(i"c-style {$ k $}"); }
for (n in 0..3) { print(n); }
println("");

var tries = 0;
do { tries += 1; } while (tries < 3);
println(tries);

outer: for (a in 0..3) {
    for (b in 0..3) {
        if (a * b == 2) {
            println(i"found {$ a $},{$ b $}");
            break outer;
        }
    }
}
```

```text
72: pass
95: excellent
40: fail
many
while 1
while 3
c-style 0
c-style 1
012
3
found 1,2
```

- Every condition and `for` header is parenthesized.
- `if` used as an expression needs an `else`; each branch's last expression is
  its value.
- `a..b` counts `a` to `b - 1` and is allowed only as a loop source or in a
  comprehension, not as a value.
- The `for (x in xs)` variable is immutable; write `for (var x in xs)` to
  assign it. Iterating a dict yields its keys; use `d.entries()` for pairs.
- `do { } while (c);` needs the trailing `;`.

## match

```loup
@mode(host.scripted)

enum Shape {
    Circle(radius: float),
    Rect(w: float, h: float),
    Empty,
}

func area(s: Shape): float {
    return match s {
        Shape.Circle(r) => 3.14159 * r * r,
        Shape.Rect(w, h) => w * h,
        Shape.Empty => 0.0,
    };
}

func describe(code: int): string {
    return match code {
        200 => "ok",
        404 => "not found",
        c if (c >= 500) => {
            let kind = "server error";
            i"{$ kind $} {$ c $}"
        },
        _ => "other",
    };
}

println(area(Shape.Rect(w = 2.0, h = 3.0)));
println(describe(503));
let found: Option[string] = Some("ann");
match found {
    Some(who) => println(i"found {$ who $}"),
    None => println("nobody"),
}
match (3, "x") {
    (0, _) => println("zero"),
    (n, s) => println(i"{$ n $} and {$ s $}"),
}
```

```text
6
server error 503
found ann
3 and x
```

- No parentheses around the scrutinee; arms are `pattern => expr,` and a block
  arm's last expression is its value.
- Patterns: literals, `_`, bindings, enum variants (`Shape.Circle(r)` or just
  `Circle(r)`), tuples, `Some(x)`/`None`, `Ok(v)`/`Err(e)`, union types
  (`int(n) =>`, `string(s) =>`), guards `x if (cond) =>`.
- `match` must be exhaustive: `Non-exhaustive match: missing variants X`.
- Not supported: or-patterns (`"a" | "b" =>`), `if let`, `switch`.

## Functions

```loup
@mode(host.scripted)

func greet(name: string, greeting: string = "Hello"): string {
    return i"{$ greeting $}, {$ name $}";
}

println(greet("Ann"));
println(greet("Bob", greeting = "Hi"));
println(greet(name: "Cy", greeting: "Hey"));

let double = func(x: int) => x * 2;
let add: fn(int, int): int = func(a: int, b: int): int { return a + b; };
println(add(double(3), 1));

func make_counter(): fn(): int {
    var n = 0;
    return func(): int {
        nonlocal n;
        n += 1;
        return n;
    };
}
let next_id = make_counter();
next_id();
println(next_id());

var calls = 0;
func track(): void {
    global calls;
    calls += 1;
}
track();
println(calls);

gen func evens(limit: int): Iterable[int] {
    var v = 0;
    while (v < limit) {
        yield v;
        v += 2;
    }
}
println([e for e in evens(7)]);
```

```text
Hello, Ann
Hi, Bob
Hey, Cy
7
2
1
[0, 2, 4, 6]
```

- Named arguments: `f(x = 1)` or `f(x: 1)`. Defaults are evaluated on each call.
- A closure or function that **assigns** an outer variable declares it first:
  `nonlocal n;` for an enclosing function's variable, `global n;` for a
  module variable (otherwise `E_GLOBAL_MISSING`). Reading needs nothing.
- Function types are written `fn(int, string): bool`.
- `gen func ...: Iterable[T]` with `yield` defines a generator.
- `async func f(): Task[T]` and `await` parse and run, but eagerly and in order
  (no concurrency in 1.25.1). `await` is valid only in an `async func` or at
  the top level of a script. `await group { a = spawn f(1); b = spawn f(2); }`
  assigns to existing `var`s.

## Collections

```loup
@mode(host.scripted)

var xs: list[int] = [3, 1, 2];
xs.push(9);
xs.sort(func(a: int, b: int): int { return a - b; });
println(xs);
println(i"len={$ xs.len() $} first={$ xs[0] $} last={$ xs[-1] $} slice={$ xs[1:3] $}");
println(xs.map(func(x: int): int { return x * 10; }));
println(xs.filter(func(x: int): bool { return x > 2; }));
println(xs.reduce(0, func(acc: int, x: int): int { return acc + x; }));
println(xs.contains(9));
println([s.to_uppercase() for s in ["a", "b"]]);
println([x for x in xs if x % 2 == 1]);
println([0, *xs]);

var ages: dict[string, int] = {"ann": 31};
ages["bob"] = 27;
println(ages.get("ann") ?? 0);
println(ages.get("zed").is_none());
println("bob" in ages);
for ((name, age) in ages.entries()) {
    println(i"{$ name $} is {$ age $}");
}

var seen: set[string] = {"a"};
seen.add("b");
println(seen.contains("b"));

let pair = (7, "seven");
println(pair[1]);
```

```text
[1, 2, 3, 9]
len=4 first=1 last=9 slice=[2, 3]
[10, 20, 30, 90]
[3, 9]
15
true
["A", "B"]
[1, 3, 9]
[0, 1, 2, 3, 9]
31
true
true
ann is 31
bob is 27
true
seven
```

| Type | Methods that work |
|---|---|
| `list[T]` | `push(v)` (alias `append`), `pop()`, `len()`, `is_empty()`, `contains(v)`, `index_of(v)`, `remove(i)`, `clear()`, `first()`, `last()`, `slice(a, b?)`, `reverse()` (in place), `sort(cmp)` (comparator required), `map(f)`, `filter(f)`, `reduce(init, f)`, `any(f)`, `all(f)`, `join(sep)`, `clone()` |
| `dict[K, V]` | `d[k]` (throws `KeyError`), `d[k] = v`, `get(k)` → `Option`, `set(k, v)`, `remove(k)`, `containsKey(k)`, `keys()`, `values()`, `entries()`, `len()`, `is_empty()`, `clear()` |
| `set[T]` | `add(v)`, `remove(v)`, `contains(v)`, `len()` |
| tuple | `t[0]`, destructuring `let (a, b) = t;`, `len()` |

- Collections are **values**: `var b = a;` copies, and a function cannot
  change a caller's list unless the parameter is `edits` (see
  [types-and-ownership.md](types-and-ownership.md)).
- Out-of-range indexes throw `IndexError`. Negative indexes count from the end.
- Dicts keep insertion order. A literal's values must share one type; annotate
  `dict[string, Any]` for mixed values.
- `[1, 2] == [1, 2]` is `false` in 1.25.1; compare element by element.
- More helpers (`sortBy`, `groupBy`, `zip`, `sum`, `distinct`, ...) are in
  `system.collections` ([stdlib.md](stdlib.md)).

## String methods

```loup
@mode(host.scripted)

let s = "  Hello, World  ";
let t = s.trim();
println(t.len());
println(t.to_uppercase());
println(t.toLowerCase());
println(t.split(", "));
println(t.contains("World"));
println(t.startsWith("Hell"));
println(t.ends_with("!"));
println(t.replace("World", "Loup"));
println(t.index_of("o"));
println(t[0:5]);
println(t.slice(7));
println("ab".repeat(3));
println("42".toInt() + 1);
println("x".toInt());
println("é!".chars());
```

```text
12
HELLO, WORLD
hello, world
["Hello", "World"]
true
true
false
Hello, Loup
4
Hello
World
ababab
43
0
["é", "!"]
```

- Both snake_case and camelCase spellings are accepted for most string
  methods: `starts_with`/`startsWith`, `to_uppercase`/`toUpperCase`,
  `to_int`/`toInt`, `is_empty`/`isEmpty`, `trim_start`/`trimStart`. There is
  no `upper()`, `lower()` or `.length` property.
- `.toInt()` returns `0` for text that is not a number. To validate, use
  `parseInt` from `system.text`, which returns `Result[int, string]`.
- `len()` counts code points; `byteLength()` counts UTF-8 bytes.
- `replace` replaces every occurrence. Iterating a string yields
  one-character strings.

## Modules and imports

```loup
@mode(host.scripted)

from core.math import (sqrt, floor as round_down, PI);
import system.text as text;

println(sqrt(16.0));
println(round_down(PI));
println(text.padStart("7", 3, "0"));
```

```text
4
3
007
```

- `from a.b import (x, y as z);`: the parentheses are required, even for one
  name. `import a.b as m;` binds a namespace (`m.f()`).
- No wildcard imports, no `use`, no `export`. Imports are module-level only.
- Only `pub` declarations can be imported (`cannot import private symbol`).
- Your own modules: `from util.text import (shout);` loads `util/text.loup` (or
  `.lpscr`, ...) relative to the importing file's package root (the file's
  directory for a lone script, `src/` in a project). Relative forms:
  `from .sibling import (x);`, `from ..src.wordcount import (count_words);`.
- Re-export: `pub from .counter import (Counter);`. Break import cycles with
  `from x defer import (T);`.
- In a script, `if (__name__ == "__main__") { ... }` runs only when the file is
  the entry point, not when it is imported.

## Built-in functions

Always in scope (the prelude), no import needed:

| Function | Notes |
|---|---|
| `print(v)`, `println(v)`, `printErr(v)` | exactly one argument; build strings with `i"..."` |
| `str(v)`, `repr(v)` | text and quoted forms |
| `args()` | script arguments (`runtime.args()` in any mode) |
| `env(name)` | `Option[string]` |
| `readText(path)`, `writeText(path, s)`, `readBytes`, `writeBytes`, `exists(path)` | throw `IoError` on failure; `readText("/dev/stdin")` reads standard input on Unix |
| `exec(argv)` | runs a process; result has `exit_code: int`, `stdout: bytes`, `stderr: bytes` (`.decode()` to text) |
| `execShell(cmd)` | runs through the shell, returns the exit status |
| `exit(code)` | ends the program |
| `spawnBlocking(f)` | returns a `Task` |

## Not in the grammar

These come from other languages and do not parse or do not exist:
`//` and `/* */` comments (use `#`), `fn name(...) -> T` / `def` / `function`,
`x ? a : b`, `elif`, `switch`, `case`, `i++`, `null`/`nil`/`undefined`,
`if let`, `while let`, `"{x}"` / `f"..."` / `` `${x}` `` interpolation,
`catch (e: T)`, `catch (e)`, `except`, `self.x` (use `this.x`; Stage0 tolerates `self`),
`len(x)`, `int(x)`, `float(x)`, `import x.*`, `use`, `export`, `pub use`,
`f(*args)` at a call, `arc let`, `typeof x`, `@volatile`, `panic(...)` outside
freestanding. `x instanceof T` is in the grammar but **crashes the 1.25.1
parser** (a Rust panic, exit 101): write `x is T`. `defer` parses but its body
never runs: use `try { ... } finally { ... }`.
