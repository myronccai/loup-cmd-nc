# Types and ownership (toolchain 1.25.1)

Contents: [Values and references](#values-and-references) · [Structs](#structs) ·
[Enums](#enums) · [Classes](#classes) · [Abstract classes](#abstract-classes) ·
[Interfaces and operators](#interfaces-and-operators) · [Generics](#generics) ·
[Union types](#union-types) · [modifier and safe](#modifier-and-safe) ·
[Parameter verbs](#parameter-verbs) ·
[unique, borrow and lifetimes](#unique-borrow-and-lifetimes) ·
[weak and shared](#weak-and-shared) · [Not implemented](#not-implemented)

## Values and references

| Kind | Semantics | Examples |
|---|---|---|
| value | assignment and argument passing copy (or borrow read-only) | `int`, `float`, `bool`, `string`, `struct`, `enum`, tuples, `list`, `dict`, `set` |
| reference | assignment shares one ARC-counted object | `class` instances, values behind an `interface` |

Every mode uses ARC (reference counting); there is no tracing garbage
collector. Reference cycles leak unless one side is `weak`.

```loup
@mode(host.scripted)

struct Size { var w: int; var h: int; }

class Box {
    pub var size: Size = Size(w = 1, h = 1);
}

var a = [1, 2];
var b = a;
b.push(3);
println(a);

var s1 = Size(w = 2, h = 3);
var s2 = s1;
s2.w = 10;
println(s1.w);

let box1 = Box();
let box2 = box1;
safe { box2.size = Size(w = 5, h = 5); }
println(box1.size.w);
```

```text
[1, 2]
2
5
```

## Structs

```loup
@mode(host.scripted)

struct Point {
    x: float;
    y: float;
    var label: string = "";

    func dist(): float {
        return (this.x * this.x + this.y * this.y) ** 0.5;
    }

    func moved(dx: float): Point {
        return this with (x = this.x + dx);
    }
}

var p = Point(x = 3.0, y = 4.0);
println(p.dist());
p.label = "start";
let q = p.moved(1.0);
println(q);
println(p == Point(x = 3.0, y = 4.0, label = "start"));
```

```text
5
Point(x: 4.0, y: 4.0, label: "start")
true
```

- Write struct fields without a keyword (immutable) or with `var`.
  Assigning an immutable field is
  `cannot assign to immutable field 'x' of struct 'P'`. Declare the binding
  `var` when you assign fields (1.25.1 does not yet enforce that part).
- Construct with named arguments (`Point(x = 1.0, y = 2.0)`); fields with a
  default may be left out. `p with (x = 9.0)` copies with changes.
- Struct methods are plain `func` (no `modifier`; `E_MODIFIER_ON_STRUCT`).
  `==` compares fields.
- A struct may not hold a class reference in a field
  (`E_STRUCT_CLASS_FIELD`); make it a class, or store a value type.

## Enums

```loup
@mode(host.scripted)

enum Token {
    Num(value: int),
    Word(text: string),
    End,
}

let tokens = [Token.Num(value = 4), Token.Word(text = "go"), Token.End];
for (t in tokens) {
    let shown = match t {
        Token.Num(v) => i"num {$ v $}",
        Token.Word(w) => i"word {$ w $}",
        Token.End => "end",
    };
    println(shown);
}
println(Token.Num(value = 1) == Token.Num(value = 1));
```

```text
num 4
word go
end
true
```

- Payload variants are constructed with named arguments. A variant with no
  payload is written `Token.End`.
- An enum must have at least one variant (use `impossible` for "no value").
- `==` on enums is structural. Native builds refuse tuple and `Result`
  payloads inside enums.

## Classes

```loup
@mode(host.scripted)

interface Describable {
    func name(): string;
    func describe(): string { return i"<{$ this.name() $}>"; }
}

class Animal implements Describable {
    pub let species: string;
    new(species: string) { this.species = species; }
    pub func name(): string { return this.species; }
    pub func sound(): string { return "..."; }
}

final class Dog : Animal {
    pub let nick: string;
    new(nick: string) {
        super("dog");
        this.nick = nick;
    }
    pub override func sound(): string { return "woof"; }
    pub override func name(): string { return i"{$ super.name() $} {$ this.nick $}"; }
}

class Settings {
    pub static let DEFAULT_PORT: int = 8080;
    pub let host: string;
    pub var port: int = 8080;

    pub static func dev(): Settings {
        return Settings(host = "localhost");
    }
}

let pets: list[Animal] = [Animal("cat"), Dog("rex")];
for (a in pets) {
    println(i"{$ a.describe() $} says {$ a.sound() $}");
}
println(pets[1] is Dog);
let cfg = Settings.dev();
println(i"{$ cfg.host $}:{$ cfg.port $} default {$ Settings.DEFAULT_PORT $}");
```

```text
<cat> says ...
<dog rex> says woof
true
localhost:8080 default 8080
```

- Header: `[pub] [final|abstract] [sealed] class Name[T] : Base implements I, J { ... }`.
  Single inheritance; any number of interfaces.
- Fields: `pub let` / `pub var` / `let` / `var`, with optional default. A field
  without `pub` is private to the class (`member 'x' of class 'P' is private`).
  Methods and top-level declarations without `pub` are private to the module.
- Constructor: `new(...) { this.f = ...; }`, at most one. Call it as
  `Animal("cat")` (no `new` keyword). Use `pub static func` factories for other
  ways to construct.
- No constructor declared: the class gets one that takes its fields,
  ancestors' first, by name (`Settings(host = "x", port = 1)`); fields with
  defaults may be omitted; a missing required field is an error.
- `super(args)` must run before the subclass touches `this`; `super.m()` calls
  the parent's method.
- `override` is required on every method that redefines an inherited one
  (`E_OVERRIDE_REQUIRED`), including implementations of abstract methods.
- A method that only reads may mutate collections inside fields
  (`this.items.push(x)`) without `modifier` in 1.25.1; assigning a field
  (`this.count = ...`) needs `modifier`.
- `x is T` tests the runtime class; `x as T` converts.

## Abstract classes

Abstract methods with a non-`void` return type do not compile in 1.25.1:

```loup,does_not_compile
@mode(host.scripted)

abstract class Shape {
    abstract func area(): float;
}

class Square : Shape {
    pub let side: float;
    new(side: float) { this.side = side; }
    pub override func area(): float { return this.side * this.side; }
}

println(Square(3.0).area());
```

```text
main.lpscr:4:5: error[E0001]: method 'area' may not return a value on all code paths
```

Use an interface for the contract:

```loup
@mode(host.scripted)

interface Shape {
    func area(): float;
}

class Square implements Shape {
    pub let side: float;
    new(side: float) { this.side = side; }
    pub func area(): float { return this.side * this.side; }
}

let shapes: list[Shape] = [Square(3.0)];
println(shapes[0].area());
```

```text
9
```

`abstract func run(): void;` works. Instantiating an abstract class is not
rejected in 1.25.1, so do not rely on the compiler to stop it.

## Interfaces and operators

```loup
@mode(host.scripted)

class Version implements Comparable[Version] {
    pub let major: int;
    pub let minor: int;
    new(major: int, minor: int) {
        this.major = major;
        this.minor = minor;
    }
    pub func compareTo(other: Version): int {
        if (this.major != other.major) {
            return this.major - other.major;
        }
        return this.minor - other.minor;
    }
}

class Money implements Add[Money, Money] {
    pub let cents: int;
    new(cents: int) { this.cents = cents; }
    pub operator func +(other: Money): Money {
        return Money(this.cents + other.cents);
    }
}

println(Version(1, 2) < Version(1, 10));
println((Money(150) + Money(275)).cents);
```

```text
true
425
```

- An interface lists method signatures; a method with a body is a default.
  A class must implement every method without a default
  (`class 'A' does not implement all methods of interface 'Named'`).
- Implementing `Comparable[T]` (`compareTo`) enables `<`, `>`, `<=`, `>=`.
- Operators: `pub operator func +(o: T): R` plus `implements Add[T, R]` (two
  type arguments). Likewise `Sub`, `Mul`, ....

## Generics

```loup
@mode(host.scripted)

func largest[T](xs: list[T]): T where T: Comparable[T] {
    var best = xs[0];
    for (x in xs) {
        if (x > best) { best = x; }
    }
    return best;
}

class Stack[T] {
    var items: list[T] = [];
    pub func push(item: T): void { this.items.push(item); }
    pub func pop(): Option[T] {
        if (this.items.is_empty()) { return None; }
        return Some(this.items.pop());
    }
}

println(largest([3, 9, 2]));
println(largest(["pear", "apple"]));
let stack: Stack[int] = Stack();
stack.push(1);
stack.push(2);
println(stack.pop().unwrap_or(0));
```

```text
9
pear
2
```

- Type parameters go in brackets after the name. Put bounds in a `where`
  clause: an inline bound (`func f[T: Comparable[T]]`) does not make the
  operators available in 1.25.1 (`type 'T0' has no method 'compareTo'`).
- Give a generic class instance its type with an annotation
  (`let s: Stack[int] = Stack();`). `Stack[int]()` leaves `T` unbound.

## Union types

```loup
@mode(host.scripted)

func describe(v: int | string): string {
    return match v {
        int(n) => i"int {$ n $}",
        string(s) => i"string {$ s $}",
    };
}

func shout(v: string | int): string {
    if (v is string) {
        return v.to_uppercase();
    }
    return "(not text)";
}

println(describe(3));
println(describe("x"));
println(shout("hey"));
println(shout(4));
let anything: Any = 5;
println((anything as int) + 1);
```

```text
int 3
string x
HEY
(not text)
6
```

`v is T` narrows `v` to `T` inside that `if` branch only; the code after it
still sees the whole union (and `as` works only from `Any`), so use `match`
to handle every member. `Any` holds any value; convert with `as`. Avoid `Any`
in AOT modes (`W_ANY_IN_AOT_MODE`).

## modifier and safe

```loup
@mode(host.scripted)

class Counter {
    pub var count: int = 0;

    pub modifier func bump(): void {
        this.count = this.count + 1;
    }

    pub modifier func bump_twice(): void {
        this.bump();
        this.bump();
    }
}

safe func reset(edits c: Counter): void {
    c.count = 0;
}

let c = Counter();
safe {
    c.bump();
    c.bump_twice();
}
println(c.count);
reset(edits: c);
println(c.count);
```

```text
3
0
```

- A method that assigns a `var` field of `this` must be `modifier`
  (`E_MODIFIER_REQUIRED`).
- Calling a `modifier` method on an object, or assigning one of its fields,
  from outside the class needs a safe context: a `safe { ... }` block or a
  `safe func` (`E_SAFE_CONTEXT_REQUIRED`). Inside a `modifier` method,
  calls on `this` need nothing extra.
- Mutating an object passed as a parameter needs both: the parameter declared
  `edits` (else `E_READS_MUTATION`) and a safe context for the field write or
  `modifier` call (else `E_SAFE_CONTEXT_REQUIRED`), as `reset` shows.
- Overriding a `modifier` method must keep `modifier`.

## Parameter verbs

The verb goes **before** the parameter name; the call site repeats it for
`edits`, `takes` and `shares`:

| Declaration | Call | Meaning |
|---|---|---|
| `f(xs: list[int])` or `f(reads xs: ...)` | `f(xs)` | read-only borrow (default); mutating it is `E_READS_MUTATION` |
| `f(edits xs: list[int])` | `f(edits: xs)` | the function may change the caller's value |
| `f(takes c: Conn)` | `f(takes: c)` | ownership moves in; `c` is unusable after (`E_USE_AFTER_TAKE`) |
| `f(shares c: Conn)` | `f(shares: c)` | the function may keep a reference |
| `f(borrow c: Conn)` | `f(borrow c)` | explicit borrow (prefix form) |
| `f(excl borrow p: Point)` | `f(p)` | exclusive borrow of a struct or `unique` value |

```loup
@mode(host.scripted)

class Conn {
    pub let id: int;
    new(id: int) { this.id = id; }
}

struct Cursor { var pos: int; }

func add_item(edits xs: list[int], n: int): void {
    xs.push(n);
}

func advance(edits c: Cursor): void {
    c.pos = c.pos + 1;
}

func total(xs: list[int]): int {
    var t = 0;
    for (x in xs) { t += x; }
    return t;
}

func close(takes c: Conn): int {
    return c.id;
}

func remember(shares c: Conn): Conn {
    return c;
}

var nums = [1, 2];
add_item(edits: nums, 3);
println(i"{$ nums $} sum={$ total(nums) $}");
var cur = Cursor(pos = 0);
advance(edits: cur);
println(cur.pos);
let conn = Conn(7);
let kept = remember(shares: conn);
println(close(takes: conn));
println(kept.id);
```

```text
[1, 2, 3] sum=6
1
7
7
```

- Writes through `excl borrow` do not reach the caller under `loup run` in
  1.25.1; use `edits` to change a caller's struct.
- Receiver verbs go on methods: `pub reads func size(): int`,
  `pub takes func close(): int` (calling `close` consumes the object).

## unique, borrow and lifetimes

```loup
@mode(host.native)

unique class Handle {
    pub let fd: int;
    new(fd: int) { this.fd = fd; }
    pub reads func number(): int { return this.fd; }
    pub takes func close(): int {
        println(i"closing {$ this.fd $}");
        return 0;
    }
}

class Shared {
    pub let id: int;
    new(id: int) { this.id = id; }
}

func inspect(borrow h: Handle): int {
    return h.number();
}

func finish(takes h: Handle): int {
    return h.close();
}

func longer[lifetime ~a](borrow[~a] x: string, borrow[~a] y: string): borrow[~a] string {
    if (x.len() >= y.len()) {
        return x;
    }
    return y;
}

func main(): void {
    unique let h = Handle(3);
    println(inspect(borrow h));
    let moved = h;
    println(moved.number());
    println(finish(takes: moved));
    unique let u = Shared(4);
    let counted = consume u;
    println(counted.id);
    println(longer(borrow "abc", borrow "de"));
}
```

```text
3
3
closing 3
0
4
abc
```

- `unique let x = ...;` (any mode) makes a single-owner binding: `let y = x;`
  moves it and a later use of `x` is `E_USE_AFTER_MOVE`.
- `unique class` is accepted only in `host.native` and `freestanding`
  (`E_UNIQUE_CLASS_ARC_BINDING` elsewhere, with a message that still says
  `@mode(native)`).
- `consume x` turns a `unique let` of an ordinary class into an ARC
  reference; only in `host.native` and `host.dual`, and not for a
  `unique class` (`E_UNIQUE_CLASS_CONSUME`).
- Moving out of a borrowed parameter is `E_MOVE_OUT_OF_BORROW`; declare it
  `takes`. A move inside a loop reports "...in a previous iteration of the
  loop".
- A closure capture of a `unique` value is a move. A collection of `unique`
  values: inserting consumes, `pop`/`remove` move out, indexing borrows, and
  `clone`, slices and `+` are refused.
- Lifetimes: declare `[lifetime ~a]` and use `borrow[~a] T`. Labels use `~`,
  never `'a`.

## weak and shared

```loup
@mode(host.dual)

class Node {
    pub let name: string;
    pub weak var parent: Node?;
    new(name: string) {
        this.name = name;
        this.parent = None;
    }
}

func main(): void {
    let root = Node("root");
    let leaf = Node("leaf");
    safe { leaf.parent = Some(root); }
    println(leaf.parent?.name ?? "none");
}
```

```text
root
```

- `weak` fields are declared `pub weak var f: T?` and assigned `Some(x)`.
  Native builds lower `weak` and `unowned` as strong references in 1.25.1, so
  cycles still leak there. `[weak self]` capture lists work only in
  `host.dual` and `host.native`.
- `shared class` (thread-shareable) requires every field to be Shareable:
  `string`, collections, ordinary classes and `Task` are not
  (`E_SHARED_FIELD_NOT_SHAREABLE`). Constructing one with `shared C(...)` fails
  under `loup run` ("unsupported instruction: NewSharedObject").

## Not implemented

- `arc let` / `arc var`: parse error (`expected ';'`) in every mode.
- `E_BORROW_ESCAPE` and `E_SAFE_ALIAS_MUTABLE` are specified but not checked.
- A `let` field of a class can still be reassigned in some paths; do not rely
  on the compiler to enforce it.
- `[1, 2] == [1, 2]` is `false` (element-wise equality is not implemented);
  struct and enum `==` work.
- `typeof` and `core.reflect` do not exist.
