# loup-cmd-nc

`nc` (netcat) for TCP written as a [Loup](https://code-craft.ai/references/loup)
script on the standard library's `net.tcp`: connect to a port and relay
standard input and output over the connection, wait for a connection with
`-l` (and keep waiting with `-k`), or check which ports are open with `-z`.
The command line is OpenBSD netcat's, the `nc` of Debian and Ubuntu.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is a `host.scripted` program: a thin `.lpscr` entry script in
`bin/` over `.lpscr` and `host.dual` modules in `lib/`, run from source by
Stage0 with the network capability granted.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later (`loup-bootstrap` on `PATH`); see [Installing Loup Lite](#installing-loup-lite).
- `make`, `bash` and `python3` for the tests (python3 finds free ports).
  Nothing is built.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
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
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
./bin/nc.lpscr -zv 127.0.0.1 20-25                               # the shebang grants fs and net
loup-bootstrap run --allow-net bin/nc.lpscr -- -zv 127.0.0.1 22   # the same, by hand
make run ARGS="-zv 127.0.0.1 20-25"
make ci                                                          # check, unit tests, end-to-end tests
```

**Which runner.** nc runs under Stage0, `loup-bootstrap run`. On Linux
x86-64 `loup run` is the self-hosted driver, which has no `net.tcp` in
1.26.0; on macOS, Windows and Linux arm64 `loup` is Stage0 too, so
`loup run --allow-net bin/nc.lpscr -- ...` works there. The shebang line,
`#!/usr/bin/env -S loup-bootstrap run --deny-all --allow-fs --allow-net`,
grants the file system (standard input, the services file, `-o`) and the
network and nothing else. Stage0 takes options it does not know before
`--` as its own, so the shebang form takes nc's short options directly
(`./bin/nc.lpscr -lv 9000`) and `--version` only after `--`
(`./bin/nc.lpscr -- --version`). Without `--allow-net`:

```text
$ loup-bootstrap run bin/nc.lpscr -- -z 127.0.0.1 8765; echo "status $?"
nc: network access is not granted: run nc with `loup-bootstrap run --allow-net`
status 1
```

Talking HTTP to a local server (`python3 -m http.server 8765`):

```text
$ printf "GET / HTTP/1.0\r\nHost: localhost\r\n\r\n" | ./bin/nc.lpscr 127.0.0.1 8765
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.13.7
Date: Wed, 21 Oct 2026 05:57:42 GMT
Content-type: text/html
Content-Length: 15
Last-Modified: Wed, 21 Oct 2026 05:57:41 GMT

<h1>hello</h1>
```

Which ports are open, and waiting for a server that is still starting
(`-w` keeps retrying a refused port):

```text
$ ./bin/nc.lpscr -zv 127.0.0.1 8764-8766
nc: connect to 127.0.0.1 port 8764 (tcp) failed: Connection refused
Connection to 127.0.0.1 8765 port [tcp/*] succeeded!
nc: connect to 127.0.0.1 port 8766 (tcp) failed: Connection refused
$ ./bin/nc.lpscr -zv -w 30 127.0.0.1 9091 && echo "up after $SECONDS s"
Connection to 127.0.0.1 9091 port [tcp/*] succeeded!
up after 2 s
```

Two nc's talking: a listener that answers with its standard input and
quits a second after sending (`-q 1`), and a client that counts the bytes
(`-vv`):

```text
$ printf 'Hello from the listener\n' | ./bin/nc.lpscr -lv -q 1 127.0.0.1 9090
Listening on 127.0.0.1 9090
Connection received
Hi, listener
```

```text
$ printf 'Hi, listener\n' | ./bin/nc.lpscr -vv 127.0.0.1 9090
Connection to 127.0.0.1 9090 port [tcp/*] succeeded!
Hello from the listener
Sent 13 bytes, received 24 bytes
```

Sending a file (`-q 0`: close as soon as it is sent) to a receiving
listener: `./bin/nc.lpscr -l -d 9000 > copy.txt` on one side,
`./bin/nc.lpscr -q 0 HOST 9000 < file.txt` on the other.

The `-o` hex dump of an exchange, with `-C` turning the request's line
feeds into CR LF:

```text
$ printf 'GET /index.html HTTP/1.0\n\n' | ./bin/nc.lpscr -C -o http.dump 127.0.0.1 8765 > /dev/null
$ head -5 http.dump
> 00000000 47 45 54 20 2f 69 6e 64 65 78 2e 68 74 6d 6c 20 # GET /index.html 
> 00000010 48 54 54 50 2f 31 2e 30 0d 0a 0d 0a             # HTTP/1.0....
< 00000000 48 54 54 50 2f 31 2e 30 20 32 30 30 20 4f 4b 0d # HTTP/1.0 200 OK.
< 00000010 0a 53 65 72 76 65 72 3a 20 53 69 6d 70 6c 65 48 # .Server: SimpleH
< 00000020 54 54 50 2f 30 2e 36 20 50 79 74 68 6f 6e 2f 33 # TTP/0.6 Python/3
```

### Options

| Option | Meaning |
|---|---|
| `-l` | listen for a connection on `[ADDRESS] PORT` (default address `0.0.0.0`; port 0 picks a free one) |
| `-k` | with `-l`: after a client leaves, wait for the next; each gets the same input |
| `-p PORT`, `-s ADDRESS` | with `-l`: the port and the address to listen on |
| `-z` | scan: connect to each port and close at once, sending nothing |
| `-v` | report connections on standard error; `-vv` also `Sent N bytes, received M bytes` |
| `-w SECONDS` | retry a refused connection for up to SECONDS (every 0.1 s) |
| `-q SECONDS` | after sending, wait at most SECONDS for the peer to close, then quit (`0`: at once; negative: wait as long as it takes, the default) |
| `-i SECONDS` | send and print one line at a time, pausing SECONDS after each; with `-z`, pause between ports |
| `-d` | do not read standard input; send nothing |
| `-C` | send CR LF line endings (a lone LF becomes CR LF) |
| `-n` | the destination must be a numeric IP address (no name lookup, `[tcp/*]` in messages) |
| `-o FILE` | write a hex dump of the traffic to FILE (`>` sent, `<` received) |
| `-h`, `--help` / `--version` | help text / `nc (loup-cmd-nc) 0.1.0` |

PORT is a number or a service name, looked up in `$NC_SERVICES` if set,
else `/etc/services`; for connections and scans also a range `LOW-HIGH`,
and several PORT operands are tried in turn. Times take fractions
(`-w 2.5`). Options may follow the operands; `--` ends them.

### Exit status

`0` when a connection was made (with `-z`: when any port accepted), `1`
when none was, and for every error, usage errors included (as in OpenBSD
netcat). A listener with `-k` runs until it is stopped.

## Differences from the original

- **Standard input is read to its end before the connection starts.**
  Loup 1.26.0 reads standard input only whole, so nc is not interactive:
  what you type is sent after Ctrl-D. Pipes and files work as usual. With
  `-k`, every client gets the same input, which makes
  `nc -lk -q 0 9000 < reply` a fixed-answer server.
- **Received data is written as UTF-8 text.** A character cut in two by the
  network is put back together, but bytes that are not UTF-8 become U+FFFD
  (`print` takes a string, and `writeBytes("/dev/stdout")` would truncate a
  redirected file). `-o` records the exact bytes.
- **`-w` retries.** OpenBSD gives up on a refused connection at once and
  uses `-w` as a time limit per attempt; here a single attempt cannot be
  limited, so `-w` keeps retrying until it expires, which is what scripts
  waiting for a server want.
- **`-q` and the peer.** `net.tcp` has no half-close (`shutdown`), and a
  read that is waiting cannot be interrupted: when `-q` expires while the
  receiving thread waits in a read, the socket stays open until that read
  returns, at the latest when the program exits. With `-k`, a client that
  then neither sends nor closes keeps its connection until it does.
- **`-p` and `-s` belong to `-l`.** A connection's own address and port
  cannot be chosen. `Connection received` names no client (`accept()` does
  not report the peer), and addresses are printed as IP addresses, without
  reverse lookups (`Listening on 0.0.0.0 9000`, not `localhost`).
- **Left out:** UDP (`-u`), Unix sockets (`-U`), proxies (`-x`, `-X`),
  `-4`/`-6`, `-N`, `-t`, `-r`, `-b`, `-D` and the socket-option flags. `-o`
  comes from the traditional netcat (OpenBSD has none), `-i` takes fractions
  of a second, and option errors add a `Try 'nc --help'` line instead of
  printing the whole usage.

## How it is built

- **`net.tcp`**: `connect`, `listen`, `accept` and `addr()` (port 0 asks
  for a free port), and `runtime.has("net")` to explain a missing grant
  before anything is read.
- **`io.streams` over a socket.** A `TcpSocket` is not itself an
  `io.streams` source, so `lib/connection.lpscr` has `SocketReader
  implements Readable`, `SocketWriter implements Writable` (it loops, as
  `write` may take part of the data) and `TextOutput implements Writable`
  (standard output, holding back a cut UTF-8 character). Sending is
  `copyStream(ByteReader(payload), writer, 16384)`, receiving
  `copyStream(reader, output, 16384)`, and `-i` reads lines with
  `BufferedReader.new(reader).readLine()`.
- **Two directions at once.** The receiving side runs in a `Thread`; Stage0
  lets it run while the other thread waits on the socket. The classes the
  threads share are `Sendable`: every field that changes is an `Atomic`
  (byte counts, "peer closed", "given up", "closed once").
- **`core.waiting.waitForItSync`** polls for `-w` (retry the connection) and
  `-q` (wait for the peer), and its `TimeoutError` ends the wait.
- **Interfaces implemented by classes**: `Transcript` (`NoTranscript`,
  `HexTranscript` for `-o`), and the built-in `Closeable`, so every
  connection lives in `with (conn = ...) { ... }`; the listener is closed
  in `try`/`finally`.
- **Errors**: `ConnectError` and `ListenError` extend `NcError` and are
  thrown `from` the runtime's `IoError`, whose message
  (`tcp_connect failed on '127.0.0.1:9': Connection refused (os error 111)`)
  `lib/neterrors.loup` turns into netcat's wording.
- The pure parts (options, ports and `/etc/services`, plans, CRLF, UTF-8
  cut points, the hex dump) are `host.dual` modules with unit tests; the
  end-to-end tests run nc against nc on 127.0.0.1.

## Layout

```text
bin/nc.lpscr                # the program (host.scripted entry script)
lib/appinfo.loup            # name, version, exit statuses, services path
lib/args.loup               # option parsing, times
lib/usage.loup              # --help and --version text
lib/services.loup           # /etc/services: names and ports
lib/ports.loup              # port operands: numbers, names, ranges
lib/plan.loup               # connect, listen or scan; host and ports
lib/text.loup               # CR LF, lines, UTF-8 cut points
lib/hexdump.loup            # the -o dump lines
lib/neterrors.loup          # runtime error messages in netcat's words
lib/traffic.lpscr           # byte counts, transcripts, shared flags
lib/connection.lpscr        # connections, listeners, stream adapters
lib/session.lpscr           # relaying over one connection
lib/modes.lpscr             # connect, listen and scan; -v messages
tests/*_test.lpscr          # unit tests, no sockets (make test)
tests/e2e.sh                # nc against nc on 127.0.0.1 (make e2e)
tests/fixtures/services     # a services file for the unit tests
specs/nc/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every check and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
