# Standard library (toolchain 1.25.1)

The standard library ships 47 modules. Many modules described in the
specification do not exist yet; importing one is a compile error. Check this
file before importing anything.

Contents: [Prelude](#prelude) · [Module map](#module-map) · [JSON](#json) ·
[Files and paths](#files-and-paths) · [Text and regex](#text-and-regex) ·
[Collections](#collections) · [Math, time, random, ids](#math-time-random-ids) ·
[Processes and environment](#processes-and-environment) ·
[Data formats](#data-formats) · [Logging and structures](#logging-and-structures) ·
[HTTP and TCP](#http-and-tcp) · [Absent modules](#absent-modules)

## Prelude

Always in scope, no import: `print`, `println`, `printErr`, `str`, `repr`,
`exit`, `args`, `env`, `readText`, `writeText`, `readBytes`, `writeBytes`,
`exists`, `exec`, `execShell`, `execReplace`, `spawnBlocking`, `runtime`
(`runtime.args()`), the exception classes, `Ok`/`Err`/`Some`/`None`,
`Volatile`, `mmioPtr`. `panic` is specified but undefined in hosted code.

## Module map

| Import | Main contents |
|---|---|
| `system.json` | `parse(s): Result[Any, string]`, `stringify(v)`, `stringifyIndented(v, indent)`, `getString/getInt/getFloat/getBool/getObject/getArray(v, key): Result` |
| `system.text` | `parseInt`, `parseIntBase`, `parseFloat`, `parseBool` (all `Result`), `split`, `splitN`, `join`, `trim*`, `padStart`, `padEnd`, `count`, `indexOf` (`Option`), `replaceAll`, `capitalize`, `repeat`, `reverse`, `toUpper`, `toLower`, `toBase64`, `fromBase64`, `toHex`, `fromHex`, `toBytes`, `fromBytes` |
| `system.regex` | `Regex(pattern)` (throws `RegexError`), `Regex.compile(p): Result`, `.isMatch(s)`, `.findFirst(s): Option[Match]`, `.findAll(s)`, `.replace(s, repl)` (first match; `$1`, `${name}`); `Match.value`, `.start`, `.end`, `.groupByIndex(i)`, `.groupByName(n)` |
| `system.collections` | `map`, `filter`, `reduce`, `flatMap`, `filterMap`, `find`, `findIndex`, `any`, `all`, `none`, `sortBy`, `sortByDesc`, `groupBy`, `partition`, `zip`, `unzip`, `distinct`, `distinctBy`, `flatten`, `chunk`, `range`, `rangeFrom`, `rangeStep`, `repeat`, `tabulate`, `sum`, `sumFloat`, `min`, `max`, `minBy`, `maxBy`, `countWhere`, `mapValues`, `filterKeys`, `mergeWith`, `fromEntries`, `toEntries` |
| `system.env` | `get(key): Option[string]`, `getOrDefault(key, d)`, `loadDotenv(path)`, `validate(config, schema)`, `platform()` (returns the delivery kind, e.g. `cli`, not the OS) |
| `system.time` | raw clocks: `monotonicNs()`, `realtimeNs()`, `processCpuNs()`, `threadCpuNs()`, `sleepNs(ns)`, `resolutionNs(clock)` |
| `io.fs` | `exists`, `isFile`, `isDir`, `readText`, `writeText`, `appendText`, `readBytes`, `writeBytes`, `readLines`, `writeLines`, `listDir`, `walk`, `createDir`, `remove`, `removeDir`, `copy`, `rename` |
| `io.path` | `join(parts: list[string])`, `basename`, `dirname`, `extname`, `splitExt`, `isAbsolute`, `normalize` |
| `io.proc` | `run(argv): ProcResult`, `output(argv): string`, `exitCode(argv)`, `check(argv)` |
| `io.streams` | `ByteReader`, `ByteWriter`, `ByteBuffer`, `BufferedReader` (`readLine`), `BufferedWriter`, `copyStream`, `concat` |
| `core.math` | `PI`, `TAU`, `E`, `INF`, `NAN`, `sqrt`, `pow`, `floor`, `ceil`, `round`, `trunc`, `abs`, `absInt`, `min`, `max`, `minInt`, `maxInt`, `clamp`, `gcd`, `lcm`, `sin` ... `atan2`, `exp`, `log*`, `hypot`, `isNan`, `isFinite` (float functions take `float`) |
| `core.time` | `Duration` (`ofMillis`, `ofSeconds`, `seconds(n)`, `toMillis`, `toSeconds`, `+`, `-`), `Instant` (`now`, `epoch`, `fromIso`, `toIso`, `-` gives a `Duration`), `sleep(d)`, `timeIt(fn)` |
| `core.datetime` | `Date(y, m, d)`, `Date.today()`, `Date.fromIsoformat(s)`, `.addDays(n)`, `.daysUntil(d)`, `.weekday()`, `.isoformat()`; `Time`, `DateTime.now()`, `DateTime.utcNow()`, `Timezone` |
| `core.random` | `Random(seed)`, `Random.fromClock()`; `modifier` methods `intRange(lo, hi)`, `float01()`, `boolWith(p)`, `choice(xs)`, `shuffle(xs)` (call inside `safe { }`) |
| `core.uuid` | `Uuid.v4()`, `Uuid.v7()`, `Uuid.parse(s)`, `Uuid.isValid(s)`, `.toString()` |
| `core.shlex` | `split(cmdline)`, `quote(token)`, `join(argv)` |
| `core.string_utils` | `splitWhitespace`, `toCamelCase`, `toSnakeCase`, `padLeft`, `padRight`, `isDigits`, `isIdentifier`, `repeat` |
| `core.*` (other) | `complex`, `array` (n-d arrays), `fpenv`, `atomic`, `numeric`, `interchange`, `waiting` (polling helpers: `waitForItSync`, `WaitGate`, `WaitingScope`) |
| `data.csv` | `parse(text, delim): list[list[string]]`, `parseRecords(text, delim): list[dict[string, string]]`, `write(rows, delim)`, `escapeField` |
| `data.toml` | `parse(text): dict[string, Any]` (throws `TomlParseError`) |
| `data.ini` | `parse(text)`, `stringify(doc)`, `sections`, `hasSection`, `getSection`, `getValue(doc, section, key)`, `getValueOrDefault` |
| `data.yaml` | `parse(text): Any` (throws `YamlParseError`) |
| `data.xml` | `parse(text): Element`, `stringify(el)`; `Element.find(tag)`, `.findAll(tag)`, `.attribute(name)`, `.text()` |
| `data.query` | URL query strings: `parse`, `parseMulti`, `encode`, `encodeComponent`, `decodeComponent` |
| `net.http` | server only: `serve(host, port, handler)`, `parseRequest(raw)`, `Request` (`method`, `path`, `headers`, `body`), `Response`, `ok(body)`, `html(body)`, `json(body)`, `notFound()`, `status(code, body)`, `Headers`, `HttpStatus` |
| `net.tcp` | `connect(host, port): TcpSocket`, `listen(host, port): TcpListener` |
| `net.addressing` | IP address and URL types |
| `structures.*` | `priority_queue.PriorityQueue[T](compare)`, `ordered_set.OrderedSet`, `case_insensitive_dict.CaseInsensitiveDictionary` |
| `debug.assert` | `expect`, `expectEq`, `expectNeq`, `expectSome`, `expectContains`, `expectThrows`, `expectNear`, `AssertionError` |
| `debug.profiler` | profiling helpers |
| `testing` | `skipTest(reason)`, `runTest`, `TestResult` |
| `loup.log` | `getLogger(name)`, `Logger.trace/debug/info/warn/error`, `Level` (writes to stdout) |
| `lang.compiler` | compiler service wrapper |
| `native.atomic` | `.lphc` only: x86-64 barriers |
| `native.css` | the s390x channel subsystem (not CSS) |
| `debug.assert_fs`, `debug.freestanding`, `debug.recording` | freestanding only |

Notes:

- JSON is `system.json`; there is no `data.json`.
- `core.time` is the clock/duration module (`Instant`, `Duration`);
  `system.time` is a different, host-side module.
- **Import at most one of `data.toml`, `data.xml` and `data.yaml` per
  program.** Two of them in one program fail with
  ``type `_Cursor` is defined by more than one imported module``.
- `data.xml` prints a stray `warning: value is already Any` when used.
- Methods marked `modifier` in the stdlib (for example `Random.intRange`,
  `PriorityQueue.push`) must be called inside `safe { ... }`.

## JSON

```loup
@mode(host.scripted)

from system.json import (parse, stringifyIndented, getString, getArray);

let text = "{\"name\": \"loup\", \"tags\": [\"fast\", \"small\"], \"port\": 8080}";
match parse(text) {
    Ok(doc) => {
        println(getString(doc, "name").unwrap_or("?"));
        println(getArray(doc, "tags").unwrap().len());
        let obj = doc as dict[string, Any];
        let port = obj["port"] as int;
        println(port + 1);
    },
    Err(msg) => println(i"bad json: {$ msg $}"),
}

match parse("{oops") {
    Ok(doc) => println("parsed"),
    Err(msg) => println(i"bad json: {$ msg $}"),
}

let out: dict[string, Any] = {"ok": true, "count": 2};
println(stringifyIndented(out, 2));
```

```text
loup
2
8081
bad json: expected string key at position 1
{
  "ok": true,
  "count": 2
}
```

Parsed JSON is `Any`: cast objects to `dict[string, Any]`, arrays to
`list[Any]`, and leaves to their types, or use the `get*` helpers, which
return `Result`. A dict literal with mixed value types needs the
`dict[string, Any]` annotation.

## Files and paths

```loup
@mode(host.scripted)

from io.fs import (createDir, writeText, appendText, readLines, listDir, isFile, remove, removeDir);
from io.path import (join, basename, extname, dirname);

let dir = "notes_demo";
createDir(dir);
let file = join([dir, "todo.txt"]);
writeText(file, "buy milk\n");
appendText(file, "call bob\n");
println(readLines(file));
println(listDir(dir));
println(i"{$ isFile(file) $} {$ basename(file) $} {$ extname(file) $} {$ dirname(file) $}");
remove(file);
removeDir(dir);
println(exists(dir));

try {
    readText("missing.txt");
} catch (IoError as e) {
    println(i"cannot read: code {$ e.code $}");
}
```

```text
["buy milk", "call bob"]
["todo.txt"]
true todo.txt .txt notes_demo
false
cannot read: code 2
```

File functions throw `IoError` on failure. `readText("/dev/stdin")` reads
standard input on Unix. Paths are plain strings.

## Text and regex

```loup
@mode(host.scripted)

from system.text import (parseInt, parseFloat, padStart, count, replaceAll);
from system.regex import (Regex);

println(parseInt("42").unwrap() + 1);
println(parseInt("4x").is_err());
println(parseFloat("2.5").unwrap_or(0.0));
println(padStart("7", 3, "0"));
println(count("banana", "a"));
println(replaceAll("a-b-c", "-", "+"));

let email = Regex("([a-z]+)@([a-z.]+)");
let m = email.findFirst("mail ann@example.org today").unwrap();
println(m.value);
println(m.groupByIndex(1).unwrap());
println(email.isMatch("no address here"));
let digits = Regex("[0-9]+");
println(digits.findAll("a1 b22 c333").len());
println(digits.replace("a1 b22", "#"));
match Regex.compile("(unclosed") {
    Ok(re) => println("compiled"),
    Err(msg) => println(msg),
}
```

```text
43
true
2.5
007
3
a+b+c
ann@example.org
ann
false
3
a# b22
invalid regex: unclosed group at offset 9
```

## Collections

```loup
@mode(host.scripted)

from system.collections import (sortBy, groupBy, sum, zip, find, distinct, partition, chunk);

let words = ["pear", "fig", "apple", "fig"];
println(sortBy(words, func(w: string): int { return w.len(); }));
println(distinct(words));
println(groupBy(words, func(w: string): int { return w.len(); }));
println(find(words, func(w: string): bool { return w.startsWith("a"); }).unwrap_or("none"));
println(sum([1, 2, 3]));
println(zip([1, 2], ["a", "b"]));
println(partition([1, 2, 3, 4], func(n: int): bool { return n % 2 == 0; }));
println(chunk([1, 2, 3, 4, 5], 2));
```

```text
["fig", "fig", "pear", "apple"]
["pear", "fig", "apple"]
{4: ["pear"], 3: ["fig", "fig"], 5: ["apple"]}
apple
6
[(1, "a"), (2, "b")]
([2, 4], [1, 3])
[[1, 2], [3, 4], [5]]
```

The list methods (`xs.map`, `xs.filter`, `xs.reduce`, `xs.sort(cmp)`, ...)
cover most needs without an import; see [syntax.md](syntax.md#collections).

## Math, time, random, ids

```loup
@mode(host.scripted)

from core.math import (sqrt, floor, PI, maxInt);
from core.time import (Instant, Duration, sleep, timeIt);
from core.random import (Random);
from core.uuid import (Uuid);
from core.datetime import (Date);

println(sqrt(16.0));
println(floor(PI));
println(maxInt(3, 9));

let start = Instant.now();
sleep(Duration.ofMillis(5));
let elapsed = Instant.now() - start;
println(elapsed.toMillis() >= 5);
let took = timeIt(func(): void { sleep(Duration.ofMillis(1)); });
println(took.toMillis() >= 1);

var rng = Random(42);
var roll = 0;
safe { roll = rng.intRange(1, 6); }
println(roll >= 1 and roll <= 6);

println(Uuid.v4().toString().len());
let release = Date(2026, 10, 19);
println(release.addDays(14).isoformat());
```

```text
4
3
9
true
true
true
36
2026-11-02
```

`core.math` functions take and return `float` (use `absInt`, `minInt`,
`maxInt` for `int`).

## Processes and environment

```loup
@mode(host.scripted)

from io.proc import (run, output);
from system.env import (get, getOrDefault);

let r = run(["echo", "hello"]);
println(r.exit_code);
println(r.stdout.decode().trim());
println(output(["echo", "there"]).trim());
let failed = exec(["sh", "-c", "exit 3"]);
println(failed.exit_code);
println(execShell("true"));
println(getOrDefault("LOUP_DEMO_UNSET", "fallback"));
println(get("LOUP_DEMO_UNSET").is_none());
println(env("LOUP_DEMO_UNSET") ?? "none");
```

```text
0
hello
there
3
0
fallback
true
none
```

`exec`/`run` return a `ProcResult` with `exit_code`, `stdout` and `stderr`
(`bytes`; `.decode()` gives a string). A non-zero exit does not throw.

## Data formats

```loup
@mode(host.scripted)

from data.csv import (parse as parse_csv, parseRecords);
from data.toml import (parse as parse_toml);
from data.ini import (parse as parse_ini, getValue);
from data.query import (parse as parse_query);

println(parse_csv("name,qty\napple,3\n", ","));
let rows = parseRecords("name,qty\napple,3\npear,5\n", ",");
println(rows[1]["qty"]);

let cfg = parse_toml("title = \"demo\"\n[server]\nport = 8080\n");
println(cfg["title"]);
let server = cfg["server"] as dict[string, Any];
println(server["port"]);

let ini = parse_ini("[db]\nhost = localhost\n");
println(getValue(ini, "db", "host"));
println(parse_query("q=two%20words&page=2")["q"]);
```

```text
[["name", "qty"], ["apple", "3"]]
5
demo
8080
localhost
two words
```

## Logging and structures

```loup
@mode(host.scripted)

from loup.log import (getLogger);
from structures.priority_queue import (PriorityQueue);

let log = getLogger("app");
log.info("starting");
log.warn("disk almost full");

let jobs: PriorityQueue[int] = PriorityQueue(func(a: int, b: int): int { return a - b; });
safe {
    jobs.push(5);
    jobs.push(1);
    jobs.push(3);
}
var next = 0;
safe { next = jobs.pop(); }
println(next);
```

```text
INFO app - starting
WARN app - disk almost full
1
```

## HTTP and TCP

`net.http` is a small, serial HTTP/1.1 **server**. Write the handler as a
plain function so it can be tested without a socket:

```loup
@mode(host.scripted)

from net.http import (Request, Response, ok, notFound, parseRequest);

func route(req: Request): Response {
    if (req.method == "GET" and req.path == "/health") {
        return ok("up");
    }
    return notFound();
}

let req = parseRequest("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n");
let resp = route(req);
println(i"{$ req.method $} {$ req.path $} -> {$ resp.status $} {$ resp.body $}");
println(route(parseRequest("GET /nope HTTP/1.1\r\n\r\n")).status);
```

```text
GET /health -> 200 up
404
```

Serve it (blocks forever, one connection at a time; needs the net
capability):

```sh
# in server.lpscr add:  from net.http import (serve);  serve("127.0.0.1", 8080, route);
loup run --allow-net server.lpscr
```

There is no HTTP client, router, cookie support, TLS or async handler.
`net.tcp` offers `connect(host, port)` and `listen(host, port)`/`accept()`
for raw sockets.

## Absent modules

Do not import these; none has an implementation in 1.25.1:

| Area | Absent |
|---|---|
| CLI and config | `loup.cli`, `loup.config` |
| Reflection | `core.reflect`, `core.inspect`, `core.serialization` (and `typeof`) |
| Networking | `net.tls`, `net.dns`, `net.ws`, any HTTP client |
| Concurrency | every `sync.*` module (`thread`, `mutex`, `atomic`, `channel`, `semaphore`, `shared`) |
| App | `thisapp` |
| Browser and UI | every `web.*` (`dom`, `storage`, `workers`, `css`, components) and `ui.*` (`ui.web`, `ui.desktop`, `ui.fence`, `ui.animation`) |
| Native | `native.simd`, `native.ffi`, `native.mem`, `native.gpu`, `native.webgpu`, `native.hal`, `native.tpu`, `native.window`, `native.audio` |
| Language | `lang.interop.*`, `lang.macro` |
| ML | `loup.tensor`, `loup.autodiff`, `loup.tpu` |
| Debug | `debug.browser` |
| Packages | `loup.http`, `loup.schema`, `loup.cache`, `loup.ai`, `loup.queue` (stubs), `webworks` |

What you see when you try:

- `'core.reflect' is not a standard-library module (namespace 'core' is reserved for the standard library)`
- `unresolved package import 'loup/cli': searched package roots [...]`
- `` `sync.thread` is not available in the scripted runtime `` (in every mode)

Alternatives: parse `args()` / `runtime.args()` by hand instead of
`loup.cli`; read config with `data.toml`, `data.ini` or `system.json`; run
`curl` through `exec([...])` instead of an HTTP client; use processes
(`exec`) or `spawnBlocking` instead of threads.

The standard library owns the namespaces `core io data net sync concurrent
web ui native lang debug structures` and the `loup.` prefix. Do not create
your own modules under them.
