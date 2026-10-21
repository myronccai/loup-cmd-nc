# Requirements: nc

## Introduction

`nc` is netcat for TCP: it opens a connection to a host and port (or waits
for one with `-l`) and relays bytes between the connection and its
standard input and output. With `-z` it only checks which ports accept a
connection, which scripts use to wait for a server to come up. The command
line follows OpenBSD netcat (the `nc` of Debian and Ubuntu), plus the
traditional netcat's `-o` hex dump.

It is a `host.scripted` project of the loup-cmd series, run by Stage0
(`loup-bootstrap run --allow-net`): the standard library's `net.tcp` works
only there. It shows `net.tcp` (`listen`, `connect`, `accept`),
`io.streams` (`BufferedReader`, `ByteReader`, `copyStream`) over a socket
wrapped as a `Readable`, `core.waiting.waitForItSync` for connection
retries and the quit timer, `runtime.has("net")`, interfaces implemented
by classes, `with` over `Closeable` connections, and `try`/`finally`.

## Requirements

### Requirement 1: Connecting

**User Story:** As a user, I want to send data to a TCP service and see its
answer so that I can talk to text protocols (HTTP, SMTP, Redis) by hand or
from a script.

#### Acceptance Criteria

1. WHEN nc is given `DESTINATION PORT...`, THE program SHALL connect to the
   first port that accepts the connection, send its standard input, and
   write what the peer sends to standard output.
2. WHEN no port accepts, THE program SHALL exit with status 1; with `-v` it
   SHALL print `nc: connect to HOST port PORT (tcp) failed: REASON` for
   each port.
3. WHEN the connection is made and `-v` is given, THE program SHALL print
   `Connection to HOST PORT port [tcp/SERVICE] succeeded!` on standard
   error, SERVICE being the port's name in the services file or `*`.
4. WHEN DESTINATION cannot be resolved, or `-n` is given and DESTINATION
   is not a numeric IP address, THE program SHALL print
   `nc: getaddrinfo for host "HOST" port PORT: Name or service not known`
   and exit with status 1.
5. WHEN `-w SECONDS` is given, THE program SHALL retry a refused
   connection until SECONDS have passed before it gives up on the port.

### Requirement 2: Listening

**User Story:** As a user, I want nc to wait for a connection so that I can
receive a file, answer a client with a fixed reply, or watch what a client
sends.

#### Acceptance Criteria

1. WHEN `-l` is given, THE program SHALL listen on `[ADDRESS] PORT` (or
   `-s ADDRESS` and `-p PORT`; ADDRESS defaults to `0.0.0.0`; port 0
   picks a free port), accept one connection and relay it like a client
   connection.
2. WHEN `-v` is given, THE program SHALL print `Listening on IP PORT` (the
   bound address and port) and `Connection received` for each client.
3. WHEN `-k` is given with `-l`, THE program SHALL accept the next client
   after each one leaves, sending each the same standard input, until it
   is stopped.
4. WHEN the address cannot be bound, THE program SHALL print `nc: REASON`
   (for example `nc: Address already in use`) and exit with status 1.

### Requirement 3: Relaying

**User Story:** As a user, I want control over what is sent and when the
program stops so that nc fits pipelines and scripts.

#### Acceptance Criteria

1. THE program SHALL read standard input to its end before the connection
   starts, and send it exactly as read (unless `-C`).
2. WHILE it sends, THE program SHALL also receive, so that a peer that
   answers while the input is still being sent does not block it.
3. WHEN `-d` is given, THE program SHALL not read standard input.
4. WHEN `-C` is given, THE program SHALL send every line feed that is not
   already preceded by a carriage return as CR LF.
5. WHEN `-q SECONDS` is given, THE program SHALL, after sending, wait at
   most SECONDS for the peer to close, then end the connection (`0`: at
   once; a negative value: wait as long as needed, the default).
6. WHEN `-i SECONDS` is given, THE program SHALL send the input one line at
   a time and print received data one line at a time, pausing SECONDS
   after each line (and between the ports of a scan).
7. THE program SHALL write received data to standard output as UTF-8
   text, never splitting a character that arrives in two pieces.
8. WHEN `-o FILE` is given, THE program SHALL write a hex dump of the
   traffic to FILE: `>` lines for sent and `<` lines for received data,
   each with its own running offset, 16 bytes per line in hexadecimal and
   then as text.
9. WHEN `-v` is given twice, THE program SHALL print
   `Sent N bytes, received M bytes` when each connection ends.

### Requirement 4: Scanning

**User Story:** As a script author, I want to know whether a port is open,
or wait until it is, so that I can start a client only once its server
runs.

#### Acceptance Criteria

1. WHEN `-z` is given, THE program SHALL connect to each port of
   `PORT`, `LOW-HIGH` (in either order) and service-name operands, close
   each connection at once and send nothing.
2. WHEN at least one port accepted, THE program SHALL exit with status 0,
   else 1. With `-v` it SHALL report each port as in Requirement 1.
3. WHEN `-w SECONDS` is given, THE program SHALL keep retrying each port
   for up to SECONDS, so that `nc -z -w 30 HOST PORT` waits for a server.

### Requirement 5: Command line

**User Story:** As a user, I want the options and messages of the netcat I
know so that my habits and scripts carry over.

#### Acceptance Criteria

1. THE parser SHALL accept clustered short options (`-lvk`), values
   attached or separate (`-w5`, `-w 5`), options after operands, and `--`
   to end the options.
2. WHEN an option is unknown or lacks its value, THE program SHALL print
   `nc: invalid option -- 'X'` or `nc: option requires an argument -- 'X'`
   and `Try 'nc --help' for more information.` and exit with status 1.
3. WHEN a port is missing or bad, THE program SHALL print `nc: missing port
   number`, `nc: port number invalid: X`, `nc: port number too small: N`
   or `nc: port number too large: N` and exit with status 1.
4. WHEN a time is bad, THE program SHALL print `nc: timeout invalid: X`
   (`-w`), `nc: quit timer invalid: X` (`-q`) or `nc: interval invalid: X`
   (`-i`) and exit with status 1.
5. WHEN options conflict, THE program SHALL print `nc: must use -l with
   -k`, `nc: cannot use -z and -l`, or say that `-p` and `-s` need `-l`,
   and exit with status 1.
6. THE program SHALL look service names up in `$NC_SERVICES`, else
   `/etc/services`.
7. WHEN the `net` capability is not granted, THE program SHALL say so and
   exit with status 1 before it reads any input.
8. `-h` and `--help` SHALL print the usage, `--version` SHALL print
   `nc (loup-cmd-nc) 0.1.0`, both with status 0.
