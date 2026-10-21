# AGENTS.md

This repository is `nc`, netcat for TCP written in the Loup programming
language on the standard library's `net.tcp`, part of the loup-cmd series of
example applications. It recreates OpenBSD netcat's connect (`nc HOST
PORT`), listen (`-l`, `-k`) and scan (`-z`) modes. It is a `host.scripted`
program: the `.lpscr` script in `bin/`, run from source by
`loup-bootstrap run` with the `fs` and `net` capabilities, imports
`.lpscr` and `host.dual` modules from `lib/`. Nothing is compiled.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # manifest: name, version, toolchain, [build] entry (bin/nc.lpscr), [test] pattern
├── Makefile                     # run, check, test, e2e, ci, clean
├── bin/
│   └── nc.lpscr                 # entry script (host.scripted, executable): options, grant check, plan, stdin, mode
├── lib/
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, exit statuses, DEFAULT_SERVICES, SERVICES_ENV
│   ├── args.loup                # struct Options, ArgError, parse_args(), parse_seconds(), check_combination()
│   ├── usage.loup               # usage(), version_line()
│   ├── services.loup            # class ServiceTable, fields(), parse_services(), load_services()
│   ├── ports.loup               # parse_port(), parse_port_range(), parse_port_list(), service_label()
│   ├── plan.loup                # enum Mode, struct Plan, make_plan(), mode_name()
│   ├── text.loup                # to_crlf(), split_lines(), utf8_complete(), sequence_length(), concat()
│   ├── hexdump.loup             # hex(), shown(), dump_lines(): the -o format
│   ├── neterrors.loup           # failure_reason(), is_lookup_failure(), is_peer_gone()
│   ├── traffic.lpscr            # interface Transcript, NoTranscript, HexTranscript, open_transcript(), class Traffic
│   ├── connection.lpscr         # NcError, ConnectError, ListenError, Connection, open_connection(), open_listener(), SocketReader, SocketWriter, TextOutput
│   ├── session.lpscr            # SessionSettings, settings_from(), run_session(): the receiving thread, sending, -q
│   └── modes.lpscr              # Reporter (-v messages), connect_mode(), scan_ports(), listen_mode()
├── tests/
│   ├── *_test.lpscr             # unit tests: func test_*(): void (no sockets)
│   ├── e2e.sh                   # end-to-end: nc against nc on 127.0.0.1, command-line errors
│   └── fixtures/services        # a services(5) file for the unit tests
├── specs/nc/                    # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
└── .github/workflows/ci.yml     # installs Loup and runs `make ci`
```

## Check, run and test

Prerequisites: Loup 1.26.0 (`loup-bootstrap` on `PATH`), `make`, `bash` and
`python3` (the end-to-end tests use it to find free ports).

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run | `make run ARGS="-zv 127.0.0.1 20-25"` | `loup-bootstrap run --deny-all --allow-fs --allow-net bin/nc.lpscr -- ARGS` |
| Run directly | `./bin/nc.lpscr -zv 127.0.0.1 22` | the shebang grants the capabilities; long options only after `--` |
| Type-check | `make check` | `loup-bootstrap check FILE` for each `bin/*.lpscr` and its imports |
| Unit tests | `make test` | each `tests/*_test.lpscr` in turn, `--no-parallel` |
| One test file | `make test TESTS=tests/args_test.lpscr` | |
| Matching tests | `make test TEST_ARGS="--filter values"` | |
| End-to-end tests | `make e2e` | `tests/e2e.sh`: listeners on free ports, always killed |
| Everything CI runs | `make ci` | check, test, e2e, then `--version` |
| Clean | `make clean` | removes `build/` (test scratch files), `.temp/`, `.loup-cache/` |

Run `make ci` before reporting a change as done.

Toolchain facts this project depends on (Loup 1.26.0, Linux x86-64):

- `net.tcp` works only under Stage0 (`loup-bootstrap run`), and only with
  `--allow-net`; the self-hosted `loup run` has none. `runtime.has("net")`
  tells the program whether it was granted. The test runner
  (`loup-bootstrap test`) grants no network, so socket tests live in
  `tests/e2e.sh`.
- Stage0 runs a `Thread` for real, with a global lock that a thread gives up
  while it waits in a socket read, write or accept, in `sleepNs`, or in
  `join`. Reading a file (`readBytes("/dev/stdin")`) keeps the lock: that is
  why standard input is read before the session starts.
- Values captured by a `Thread.spawnWith` lambda must be `Sendable`; a class
  is `Sendable` when it says so and every field that changes is an `Atomic`
  (`Mutex`, `RwLock`). `Connection`, `Traffic` and the transcripts are.
- `TcpSocket.close()` throws when called twice (hence `Connection`'s atomic
  guard), `write()` may write only part of the data, and `read()` returns
  empty bytes once the peer has closed. A read clones the socket while it
  waits, so closing the socket from another thread takes effect only when
  that read returns.
- `TcpSocket` is not accepted where `io.streams` wants a `Readable` or
  `Writable`: wrap it (`SocketReader`, `SocketWriter`).
- `Closeable.close()` cannot be a `modifier` method: `with` calls it
  outside a `safe` context.
- Network errors are `IoError`s whose message ends with the system's reason
  (`... Connection refused (os error 111)`); `lib/neterrors.loup` reads it.
- `print` writes UTF-8 text and flushes at once; `writeBytes("/dev/stdout")`
  reopens and truncates a redirected file, so received data is printed as
  text.
- `loup-bootstrap test` with all files at once fails random tests with an
  empty `RuntimeError` on a busy machine; the Makefile runs one file at a
  time with `--no-parallel`.
- `attempt` is a reserved word (`attempt { }` blocks): do not name a
  function after it.

## Making a change

1. Update the spec in `specs/nc/` (see [specs/README.md](specs/README.md)).
2. Change the code: parsing and plans in the `host.dual` modules, sockets
   and threads in the `.lpscr` modules, start-up in `bin/nc.lpscr`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/nc/tasks.md`.

## Conventions

- `bin/nc.lpscr` is `@mode(host.scripted)` with the shebang
  `#!/usr/bin/env -S loup-bootstrap run --deny-all --allow-fs --allow-net`
  and the executable bit. Grant no more capabilities than it uses.
- `lib/*.loup` are `@mode(host.dual)` and touch no socket; `lib/*.lpscr`
  are `@mode(host.scripted)` and hold everything that uses `net.tcp` or
  threads.
- Imports are relative: `from ..lib.args import (...)` in `bin/` and
  `tests/`, `from .ports import (...)` inside `lib/`.
- Messages follow OpenBSD netcat: `nc: ...` on standard error, `-v` lines
  without the prefix (`Connection to HOST PORT port [tcp/*] succeeded!`).
- Only `bin/nc.lpscr`, `lib/modes.lpscr` and the receiving side of
  `lib/session.lpscr` print.
- The end-to-end tests never leave 127.0.0.1 and set `NC_SERVICES` to a
  file of their own.
- Keep `APP_VERSION` in `lib/appinfo.loup` and `version` in `package.lppkg`
  in step.
- The skill documents toolchain 1.25.1; this project targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
