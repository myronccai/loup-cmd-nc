# Freestanding (bare metal) Loup (toolchain 1.25.1)

`@mode(freestanding)` (`.lpfree`) compiles to a bare-metal image with no
runtime: no heap by default, no ARC, no exceptions, no async, no standard
library beyond a few freestanding modules. Every listing here passes
`loup check` in a freestanding project; error outputs are `loup check
--format short`.

Contents: [Project and build](#project-and-build) · [Entry point](#entry-point) ·
[Panics](#panics) · [Errors without exceptions](#errors-without-exceptions) ·
[Memory: buffers, structs, overlays](#memory-buffers-structs-overlays) ·
[MMIO](#mmio) · [asm, unsafe, interrupts, sections](#asm-unsafe-interrupts-sections) ·
[What the checker does not catch](#what-the-checker-does-not-catch) ·
[Targets](#targets)

## Project and build

```toml
name = "kernel"
version = "0.1.0"

[build]
entry = "src/main.lpfree"
mode = "freestanding"
arch = "x86_64"
panic = "custom"          # "halt" (default when absent) | "abort" | "custom"

[linker]
script = "linker.ld"      # required for a freestanding build
entry = "kmain"

[freestanding]
bounds = "trap"           # runtime bounds checks on buffer indexes
overlays = "error"        # make a missing @unsafe on an overlay an error
stack_check = "report"    # or "enforce"
```

```sh
loup check                                        # works on every platform
loup build --target freestanding --arch aarch64   # Linux only; default backend llbe needs ld.lld
loup build --target freestanding --arch x86_64 --backend llvm
loup build --target freestanding --arch riscv64 --stack-report
loup test --freestanding                          # builds tests and boots them under QEMU (x86_64)
```

- Builds run on Linux only (macOS and Windows: `check` only). Without
  `[linker] script` the build fails with `E-BUILD-FREESTANDING: freestanding
  target requires [linker].script`.
- QEMU is needed only to boot-test images.

## Entry point

```loup
@mode(freestanding)

const UART0: uint64 = 0x10000000;

func put(ch: uint8): void {
    Volatile[uint8].at(UART0).write(ch);
}

func put_text(codes: buffer[uint8, 6], n: int): void {
    var i = 0;
    while (i < n) {
        put(codes[i]);
        i += 1;
    }
}

@entry
func kmain(): void {
    var hello: buffer[uint8, 6];
    hello[0] = 72;
    hello[1] = 105;
    hello[2] = 10;
    put_text(hello, 3);
    while (true) {}
}
```

- Exactly one `@entry` function (module level). There is no `main` and no
  top-level code.
- Do not return from the entry: end it in a loop (`while (true) {}`) or a
  halt instruction.
- No `println` (there is no console); write to a device register.

## Panics

The manifest's `[build] panic` key picks the policy: `"halt"` (default when
the key is absent), `"abort"`, or `"custom"`. **Only `"custom"` calls your
handler**; a handler without `panic = "custom"` is never called. There is no
`--panic` command-line flag.

```loup
@mode(freestanding)

const UART0: uint64 = 0x10000000;

@panic_handler
func on_panic(msg: string, file: string, line: int): noreturn {
    Volatile[uint8].at(UART0).write(33);
    while (true) {}
}

@entry
func kmain(): void {
    while (true) {}
}
```

The handler must return `noreturn` and its body must never finish:

```loup,does_not_compile
@mode(freestanding)

@panic_handler
func on_panic(msg: string, file: string, line: int): void {
    while (true) {}
}
```

```text
src/main.lpfree:1:1: error: E_PANIC_HANDLER_SIG: `@panic_handler` `on_panic` must have one of the two normative signatures — `(msg: string, file: string, line: int): noreturn` or `(msg: string, file: string, line: int, source: PanicSource): noreturn` — it returns `void`; a panic handler must be `noreturn`, because returning from it resumes into the fault it was called to report (§3-3.6)
```

- A fourth parameter is allowed, but the `PanicSource` type is not declared
  in 1.25.1; write `source: int` if you need it.
- `panic("...")` is not resolved by the Stage0 compiler in any mode
  (`undefined identifier`); trigger failures with `unreachable` or handle
  them with `Result`.

## Errors without exceptions

`throw` and `catch (T as e)` do not exist in freestanding code:

```loup,does_not_compile
@mode(freestanding)

func parse_digit(b: uint8): int {
    if (b < 48 or b > 57) {
        throw ValueError("not a digit");
    }
    return (b - 48) as int;
}
```

```text
src/main.lpfree:5:9: error: E_FREESTANDING_EXCEPTIONS: `throw` is not available in `@mode(freestanding)` — the mode has no unwinder and no `.eh_frame`. Use `Result[T, E]` with `?` or `attempt` (§1-5.10).
```

Return a `Result`, propagate with `?`, and handle it with `attempt` in a
`try` that has only `catch Err(...)` arms (and optionally `finally`):

```loup
@mode(freestanding)

func parse_digit(b: uint8): Result[int, int] {
    if (b < 48 or b > 57) {
        return Err(b as int);
    }
    return Ok((b - 48) as int);
}

func parse_pair(hi: uint8, lo: uint8): Result[int, int] {
    let h = parse_digit(hi)?;
    let l = parse_digit(lo)?;
    return Ok(h * 10 + l);
}

func read_or_zero(hi: uint8, lo: uint8): int {
    var value = 0;
    try {
        value = attempt parse_pair(hi, lo);
    } catch Err(bad) {
        value = 0;
    }
    return value;
}

@entry
func kmain(): void {
    let v = read_or_zero(52, 50);
    while (true) {}
}
```

## Memory: buffers, structs, overlays

- There is no heap unless you register one. Use structs, fixed-size
  `buffer[T, N]`, and module-level `var`s.
- Do not use `list`, `dict`, `set` or `string` building (`+`, interpolation):
  they need a heap.
- Class construction needs a registered `@allocator` / `@deallocator` pair
  (`func a(size: uint64, align: uint64): uint?` and
  `func d(ptr: uint, size: uint64, align: uint64): void`); without one the
  spec says `E_FREESTANDING_CLASS_NO_ALLOC`. Prefer structs.
- `buffer[T, N]` is declared without an initializer (`var b: buffer[uint8, 16];`,
  zero-filled). `N` is any const expression. Constant indexes are checked at
  compile time; run-time indexes only with `[freestanding] bounds = "trap"`:

```loup,does_not_compile
@mode(freestanding)

func checksum(): uint64 {
    var table: buffer[uint64, 4];
    table[0] = 1 as uint64;
    return table[4];
}
```

```text
src/main.lpfree:6:12: error: buffer index 4 is out of range for buffer[T, 4] (E_BUFFER_INDEX_RANGE; valid 0..4)
```

- A buffer initialized from an integer address is an **overlay** on existing
  memory. Mark it `@unsafe("reason")` (a warning without it in 1.25.1, an
  error with `[freestanding] overlays = "error"`):

```loup
@mode(freestanding)

func read_word(addr: uint64, index: int): uint64 {
    @unsafe("overlay: the caller passes a mapped, 8-word region")
    var regs: buffer[uint64, 8] = addr;
    return regs[index];
}
```

- Integer types: `int` (64-bit), `int8` ... `uint64`. Write explicit casts
  between widths (`x as uint32`); `int` arithmetic wraps on overflow.

## MMIO

Two ways to touch device registers. `@volatile` does not exist.

```loup
@mode(freestanding)

@repr(packed)
struct UartRegs {
    var data: uint8;
    var lsr: uint8;
}

func uart_write(volatile borrow uart: UartRegs, byte: uint8): void {
    while (uart.lsr & 0x20 == 0) {}
    uart.data = byte;
}

const UART0: uint64 = 0x10000000;

func status(): uint8 {
    return Volatile[uint8].at(UART0 + 5).read();
}

@entry
func kmain(): void {
    Volatile[uint8].at(UART0).write(65);
    let s = status();
    while (true) {}
}
```

- `Volatile[T].at(address)` gives a handle with `.read()` and `.write(v)`;
  `mmioPtr(addr)` is a shorthand for a `Volatile` byte register.
- A `volatile borrow` parameter makes every access through it volatile.
  `volatile` is valid only on `borrow` parameters and only in `freestanding`
  and `host.native`. A volatile chain starts at a function the platform calls
  (an entry, an interrupt), not from ordinary Loup code.
- `volatile` does not imply atomicity.

## asm, unsafe, interrupts, sections

```loup
@mode(freestanding)

@unsafe("port I/O to the debug console")
@interruptSafe
func outb(port: uint16, value: uint8): void {
    asm {
        "outb %al, %dx"
        in: "dx" = port, "al" = value
    }
}

func cycles(): uint64 {
    var lo: uint32 = 0;
    var hi: uint32 = 0;
    asm {
        "rdtsc"
        out: lo = "=a", hi = "=d"
    }
    return (hi as uint64 << 32) | lo as uint64;
}

@interrupt(arch: "x86_64", has_error_code: false)
func on_timer(frame: borrow InterruptFrame): void {
    outb(0xE9, 84);
}

@section(".text.boot")
@entry
func kmain(): void {
    outb(0xE9, 66);
    let t = cycles();
    unsafe("demo: a second raw write") {
        outb(0xE9, 10);
    }
    while (true) {}
}
```

- `asm { "instr" out: var = "constraint", ... in: "reg" = expr, ... clobbers: [...] }`
  with GCC/LLVM constraints. Allowed only in `freestanding` and `host.native`
  (`E_ASM_NOT_COMPILED` elsewhere). Clobber presets: `"all"`, `"memory"`, ...
- `@unsafe("reason")` (positional string, not `reason:`) on a declaration;
  `unsafe("reason") { ... }` for a region.
- `@entry`, `@interrupt(arch: "...")` and `@naked` (asm-only body, needs
  `@unsafe`) go on module-level functions. `@section(".name")` places a
  function or module `var`.
- An interrupt handler may call only functions marked `@interruptSafe`
  (`E_INTERRUPT_SAFE_VIOLATION`). Write the frame parameter
  `frame: borrow InterruptFrame`; x86_64 handlers state
  `has_error_code: true|false`, s390x and ARM handlers a `class:`. The 1.25.1
  checker still warns that the frame is marshalled by value; the warning
  does not fail the check.

## What the checker does not catch

`loup check` in 1.25.1 accepts several things the freestanding rules forbid
and the backend drops or rejects. Do not write them:

- growable collections (`var xs: list[int] = []; xs.push(1);` is accepted,
  and the LLVM lane silently drops the `push`);
- `println`, string interpolation and concatenation;
- `async func` / `await`;
- class construction without an `@allocator`;
- `weak`, `dynamic class`, template fences, `bigint`, `decimal`.

Keep freestanding code to integers, `bool`, structs, enums, `buffer[T, N]`,
`Result`/`Option`, functions and module-level `var`/`const`.

## Targets

| Architecture (`--arch`) | Status in 1.25.1 |
|---|---|
| `x86_64`, `aarch64`, `riscv64` | boot-verified under QEMU (llvm and llbe lanes) |
| `armv7`, Cortex-M (`thumbv8.1m.main`, other `thumb*`) | boot-verified |
| `riscv32` | accepted by `--arch`; not listed as boot-verified |
| x86 32-bit | C/LLVM path only |
| `loongarch64`, `mips64el`, `powerpc64le` | instruction encoding only |
| `s390x` | specified, not implemented |
| `xtensa` | not supported |

The freestanding-only stdlib modules are `debug.assert_fs`,
`debug.freestanding` and `debug.recording`. Book:
https://code-craft.ai/references/loup/freestanding
