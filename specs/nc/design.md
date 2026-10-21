# Design: nc

## Overview

`bin/nc.lpscr` is a `host.scripted` script that Stage0 runs with the `net`
capability (`loup-bootstrap run --allow-net`). Its top-level statements
parse `args()` into `Options`, answer `--help` and `--version`, check
`runtime.has("net")`, load the services file, turn the operands into a
`Plan` (connect, listen or scan, with the host and the ports), read
standard input once, and hand the plan to one of three modes.

```text
args ─► parse_args ─► make_plan ─► scan_ports    (-z)
                                └► connect_mode  ─► open_connection ─┐
                                └► listen_mode   ─► accept ──────────┴► run_session
```

A session (one connection) runs two directions at once: a thread receives
(socket → standard output) while the main thread sends (payload →
socket), then waits for the peer according to `-q`.

## Modules

| Module | Contents |
|---|---|
| `bin/nc.lpscr` | top level: options, capability check, services, plan, standard input, mode dispatch, exit status |
| `lib/appinfo.loup` | name, version, exit statuses, default services path |
| `lib/args.loup` | `Options`, `parse_args` (getopt-style clusters, permuted operands), `parse_seconds`, `check_options` |
| `lib/usage.loup` | `usage()`, `version_line()` |
| `lib/services.loup` | `ServiceTable` from an `/etc/services` text: name → port, port → name (TCP only) |
| `lib/ports.loup` | `parse_port`, `parse_port_list` (numbers, names, ranges) with OpenBSD's messages |
| `lib/plan.loup` | `Plan`, `make_plan`: the mode, host and ports from the options and operands |
| `lib/text.loup` | `to_crlf`, `split_lines`, `utf8_complete` (where a chunk may be cut without splitting a character) |
| `lib/hexdump.loup` | `dump_lines`: traditional netcat `-o` lines |
| `lib/neterrors.loup` | `failure_reason`, `is_lookup_failure`, `is_peer_gone`: runtime `IoError` messages in netcat's words |
| `lib/traffic.lpscr` | `interface Transcript`, `NoTranscript`, `HexTranscript` (`-o FILE`), `Traffic` (atomic counters and flags shared with the receiving thread) |
| `lib/connection.lpscr` | `NcError`, `ConnectError`, `ListenError`; `Connection` (a `TcpSocket` that is `Closeable`, closed once); `open_connection` with `-n` and `-w`; `open_listener`; `SocketReader implements Readable`, `SocketWriter implements Writable`, `TextOutput implements Writable` |
| `lib/session.lpscr` | `SessionSettings`, `run_session`: the receiving thread, sending, the `-q` wait |
| `lib/modes.lpscr` | `Reporter` (the `-v` messages), `connect_mode`, `scan_ports`, `listen_mode` |

### Options and plan

`parse_args` walks the words once. A word starting with `-` (not `-` alone
or a negative number given as an option value) is a cluster of flags;
`i o p q s w` take a value, attached or the next word. Other words are
operands, so options may follow them; `--` ends the options. Errors use
OpenBSD's getopt wording. `check_options` then validates the times
(`parse_seconds`: whole or decimal seconds to milliseconds, negative only
for `-q`) and the combinations (`-k` needs `-l`, `-z` excludes `-l`, `-p`
and `-s` need `-l`).

`make_plan` reads the operands: listen mode takes `[ADDRESS] PORT` or
`-s`/`-p` (one port, 0 allowed); connect and scan modes take a destination
and one or more port operands, each a number, a service name or (any mode
but listen) a range `LOW-HIGH`, swapped when given high first.

### Connections

`open_connection(host, port, numeric = false, wait_ms = -1, poll_ms = 100)` checks `-n` with
`IpAddr.isValid`, then calls `net.tcp.connect`. Without `-w` it tries once;
with `-w` it polls with `core.waiting.waitForItSync`, retrying refused
connections until the time is up. A name-lookup failure is never retried.
Failures become a `ConnectError` carrying the host, port, reason and
whether it was a lookup failure, chained (`from`) to the runtime's
`IoError`.

`Connection` implements `Closeable`, so the modes hold it in `with`. Its
`close()` is guarded by an `Atomic` so that it closes the socket once,
whichever thread or scope gets there first (`TcpSocket.close()` throws the
second time). It cannot be a `modifier` method: `with` calls it outside a
`safe` context. `open_listener` turns a failed bind into a `ListenError`
carrying the reason; `listen_mode` closes the listener in `finally` and
accepts with `do { ... } while (o.keep_listening)`.

### Sessions

`run_session` starts a `Thread` that receives:

- bytes mode: `copyStream(SocketReader, TextOutput, 16384)`. `TextOutput`
  writes each chunk with `print`, holding back the bytes of a character
  cut at the end of a chunk (`utf8_complete`) until the next chunk;
- line mode (`-i`): `BufferedReader.new(SocketReader)`, `readLine()`,
  `println`, then a pause.

`SocketReader` and `SocketWriter` record every chunk in the `Traffic`
(counters and the `-o` transcript), so the dump holds the raw bytes in both
modes. The thread marks the `Traffic` when the peer closes.

The main thread sends the payload: `copyStream(ByteReader(payload),
SocketWriter, 16384)`, or line by line with pauses for `-i`. A peer that
has gone away (broken pipe, reset) ends the sending quietly. Then:

- `-q N` (N ≥ 0): `waitForItSync` polls the `Traffic` until the peer has
  closed or N seconds pass; then the session ends. The receiving thread may
  still be blocked in `read`, so the `Traffic` is marked abandoned and its
  `TextOutput` prints nothing more.
- otherwise: `join()` the receiving thread, i.e. wait for the peer to
  close.

## Error handling

- Option errors (`ArgError` with `hint`): `nc: MESSAGE` and `Try 'nc
  --help' for more information.`, status 1 (OpenBSD netcat uses 1 for usage
  errors too).
- Port and time errors, missing grant, unwritable `-o` file: `nc: MESSAGE`,
  status 1.
- Connect failures: silent unless `-v`, status 1; lookup failures always
  reported. Listen failures: `nc: REASON`, status 1.
- Read and write errors during a session (reset, broken pipe) end that
  direction; with `-v` they are reported.

## Testing

- Unit tests (`tests/*_test.lpscr`, no sockets: the Stage0 test runner
  does not grant `net`): options and their errors, times, the services
  parser on a fixture, ports and ranges, plans, CRLF and line splitting,
  UTF-8 cut points, hex dump lines, error-message mapping.
- `tests/e2e.sh`: command-line errors and the missing grant; then real
  connections on 127.0.0.1 only, nc against nc (a listener in the
  background, its port read from its `-v` output): file transfer, replies
  both ways, `-q`, `-C` and `-o` checked through the dump, `-i`, `-d`,
  `-k` with two clients, `-vv` counts, scans of open and closed ports,
  service names from a fixture services file, `-w` waiting for a listener
  that starts late, `-n`, and a port already in use.

## Differences from the original

- Standard input is read to its end before the connection starts (Loup
  1.26.0 has no non-blocking or line-at-a-time standard input), so nc is
  not interactive: type the whole input, then Ctrl-D.
- Received data is written as UTF-8 text; bytes that are not UTF-8 become
  U+FFFD (`-o` records them exactly).
- `-w` retries refused connections until it expires (OpenBSD fails at
  once); a single connection attempt cannot be bounded.
- `-p` and `-s` only apply to `-l`: a connection's source address and port
  cannot be chosen. `Connection received` names no client: `accept()` does
  not report the peer. Addresses are printed as IP addresses, without
  reverse lookups.
- No UDP, Unix sockets, proxies, `-4`/`-6`, `-N` (no half-close in
  `net.tcp`), `-t`, `-r` or socket options. `-o` comes from the
  traditional netcat. `-i` takes fractions of a second.
