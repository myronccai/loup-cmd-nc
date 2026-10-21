#!/usr/bin/env bash
# End-to-end tests for nc: the command-line errors first, then real
# connections on 127.0.0.1 only, nc against nc. A listener runs in the
# background with -v, and the tests read its port from its "Listening on"
# line (port 0 asks for a free one). Every nc run is wrapped in `timeout`,
# and an EXIT trap kills whatever is still running.
#
# usage: tests/e2e.sh [LOUP_BOOTSTRAP]     (run from the repository root)

set -u
LOUP=${1:-loup-bootstrap}
GRANTS=(run --deny-all --allow-fs --allow-net)
SCRIPT=bin/nc.lpscr
TMP=$(mktemp -d)
PIDS=()
pass=0
fail=0

cleanup() {
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2> /dev/null
    done
    wait 2> /dev/null
    rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Service names come from a file the tests write, never from the machine's
# /etc/services, so that a port is reported as [tcp/*] everywhere.
: > "$TMP/no-services"
export NC_SERVICES="$TMP/no-services"

# nc ARGS...: run the script once (stdin and outputs as redirected).
nc() {
    timeout 20 "$LOUP" "${GRANTS[@]}" "$SCRIPT" -- "$@"
}

# same NAME EXPECTED ACTUAL
same() {
    if [ "$2" == "$3" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1"
        diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | sed 's/^/    /' | head -20
    fi
}

# cli NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]: stdin is empty.
cli() {
    local name=$1 want_status=$2 want_out=$3 want_err=$4
    shift 4
    nc "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    same "$name: status" "$want_status" "$status"
    same "$name: stdout" "$want_out" "$(cat "$TMP/out")"
    same "$name: stderr" "$want_err" "$(cat "$TMP/err")"
}

# free_port: a port nothing listens on (bound and released at once).
free_port() {
    python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

# listener NAME [ARGS...]: start `nc -v ARGS` in the background with stdin
# from $LISTEN_IN (default /dev/null), stdout in $TMP/NAME.out and stderr
# in $TMP/NAME.err, and wait for its "Listening on ADDRESS PORT" line.
# Sets PORT and LPID.
listener() {
    local name=$1
    shift
    nc -v "$@" < "${LISTEN_IN:-/dev/null}" > "$TMP/$name.out" 2> "$TMP/$name.err" &
    LPID=$!
    PIDS+=("$LPID")
    PORT=""
    for _ in $(seq 1 100); do
        PORT=$(sed -n 's/^Listening on [^ ]* \([0-9][0-9]*\)$/\1/p' "$TMP/$name.err")
        if [ -n "$PORT" ]; then
            return 0
        fi
        kill -0 "$LPID" 2> /dev/null || break
        sleep 0.1
    done
    fail=$((fail + 1))
    echo "FAIL: $name: the listener did not start"
    sed 's/^/    /' "$TMP/$name.err"
    return 1
}

# finished: wait for the last listener to end by itself; status in LSTATUS.
finished() {
    wait "$LPID"
    LSTATUS=$?
}

# stop: end the last listener (one started with -k never ends by itself).
stop() {
    kill "$LPID" 2> /dev/null
    wait "$LPID" 2> /dev/null
}

# --- command line ---------------------------------------------------------------

HINT="Try 'nc --help' for more information."
cli "version"           0 "nc (loup-cmd-nc) 0.1.0" "" --version
nc --help < /dev/null > "$TMP/out" 2>&1
same "help"             "usage: nc [OPTION]... DESTINATION PORT..." "$(head -1 "$TMP/out")"
cli "-h"                0 "$(cat "$TMP/out")" "" -h
cli "invalid option"    1 "" "nc: invalid option -- 'Y'
$HINT" -Y 127.0.0.1 80
cli "missing value"     1 "" "nc: option requires an argument -- 'w'
$HINT" 127.0.0.1 80 -w
cli "long option"       1 "" "nc: unrecognized option '--udp'
$HINT" --udp 127.0.0.1 80
cli "no operands"       1 "" "nc: missing destination and port
$HINT"
cli "no port"           1 "" "nc: missing port number" 127.0.0.1
cli "port too large"    1 "" "nc: port number too large: 65536" 127.0.0.1 65536
cli "port too small"    1 "" "nc: port number too small: 0" -z 127.0.0.1 0
cli "port invalid"      1 "" "nc: port number invalid: x" -z 127.0.0.1 20-x
cli "timeout invalid"   1 "" "nc: timeout invalid: soon" -w soon 127.0.0.1 80
cli "quit invalid"      1 "" "nc: quit timer invalid: 1s" -q 1s 127.0.0.1 80
cli "interval invalid"  1 "" "nc: interval invalid: -1" -i -1 127.0.0.1 80
cli "-k without -l"     1 "" "nc: must use -l with -k" -k 127.0.0.1 80
cli "-z and -l"         1 "" "nc: cannot use -z and -l" -lz 80
cli "-p without -l"     1 "" "nc: -p needs -l: the local port of a connection cannot be chosen" -p 5000 127.0.0.1 80
cli "listen operands"   1 "" "nc: extra operand '9'
$HINT" -l 127.0.0.1 9 9000
cli "-n and a name"     1 "" 'nc: getaddrinfo for host "localhost" port 80: Name or service not known' -n localhost 80
cli "-o bad file"       1 "" "nc: $TMP/no/dump: No such file or directory" -o "$TMP/no/dump" -d 127.0.0.1 80

# Without the net capability nothing is read or opened.
timeout 20 "$LOUP" run --deny-all --allow-fs "$SCRIPT" -- 127.0.0.1 80 < /dev/null > "$TMP/out" 2> "$TMP/err"
same "no net grant: status" 1 $?
same "no net grant: stderr" "nc: network access is not granted: run nc with \`loup-bootstrap run --allow-net\`" "$(cat "$TMP/err")"

# --- connecting and scanning ----------------------------------------------------

CLOSED=$(free_port)
cli "refused"           1 "" "" 127.0.0.1 "$CLOSED"
cli "refused -v"        1 "" "nc: connect to 127.0.0.1 port $CLOSED (tcp) failed: Connection refused" -v 127.0.0.1 "$CLOSED"
cli "scan closed"       1 "" "nc: connect to 127.0.0.1 port $CLOSED (tcp) failed: Connection refused" -zv 127.0.0.1 "$CLOSED"

# A listener that keeps accepting (and sends nothing) for the scans.
listener sink -lk -d 127.0.0.1 0
OPEN=$PORT
cli "scan open"         0 "" "" -z 127.0.0.1 "$OPEN"
cli "scan open -v"      0 "" "Connection to 127.0.0.1 $OPEN port [tcp/*] succeeded!" -zv 127.0.0.1 "$OPEN"
cli "scan both"         0 "" "nc: connect to 127.0.0.1 port $CLOSED (tcp) failed: Connection refused
Connection to 127.0.0.1 $OPEN port [tcp/*] succeeded!" -zv 127.0.0.1 "$CLOSED" "$OPEN"
cli "scan a range"      0 "" "Connection to 127.0.0.1 $OPEN port [tcp/*] succeeded!" -zv 127.0.0.1 "$OPEN-$OPEN"
printf 'e2e-sink\t%s/tcp\t\tsink # the test listener\n' "$OPEN" > "$TMP/services"
NC_SERVICES="$TMP/services" nc -zv 127.0.0.1 e2e-sink < /dev/null > "$TMP/out" 2> "$TMP/err"
same "service name"     "Connection to 127.0.0.1 $OPEN port [tcp/e2e-sink] succeeded!" "$(cat "$TMP/err")"
NC_SERVICES="$TMP/services" nc -zvn 127.0.0.1 sink < /dev/null > "$TMP/out" 2> "$TMP/err"
same "-n: alias, no name" "Connection to 127.0.0.1 $OPEN port [tcp/*] succeeded!" "$(cat "$TMP/err")"
nc -l 127.0.0.1 "$OPEN" < /dev/null > "$TMP/out" 2> "$TMP/err"
same "port in use: status" 1 $?
same "port in use: stderr" "nc: Address already in use" "$(cat "$TMP/err")"
stop
same "sink got nothing"  "" "$(cat "$TMP/sink.out")"

# -w waits for a refused port until the time is up...
SECONDS=0
cli "scan -w closed"    1 "" "" -z -w 1 127.0.0.1 "$CLOSED"
same "scan -w waited"   yes "$([ "$SECONDS" -ge 1 ] && echo yes || echo no)"
# ... and connects as soon as a late listener is there.
LATE=$(free_port)
( sleep 1; printf 'late reply\n' | nc -l -q 0 127.0.0.1 "$LATE" > "$TMP/late.out" 2>&1 ) &
PIDS+=($!)
printf 'early\n' | nc -v -w 10 127.0.0.1 "$LATE" > "$TMP/out" 2> "$TMP/err"
same "-w late: status"  0 $?
same "-w late: stdout"  "late reply" "$(cat "$TMP/out")"
same "-w late: stderr"  "Connection to 127.0.0.1 $LATE port [tcp/*] succeeded!" "$(cat "$TMP/err")"
wait

# The first port that accepts is used.
printf 'second port\n' > "$TMP/reply"
LISTEN_IN="$TMP/reply" listener first -l -q 0 127.0.0.1 0
nc -v 127.0.0.1 "$CLOSED" "$PORT" < /dev/null > "$TMP/out" 2> "$TMP/err"
same "ports in turn: stdout" "second port" "$(cat "$TMP/out")"
same "ports in turn: stderr" "nc: connect to 127.0.0.1 port $CLOSED (tcp) failed: Connection refused
Connection to 127.0.0.1 $PORT port [tcp/*] succeeded!" "$(cat "$TMP/err")"
finished

# --- relaying -------------------------------------------------------------------

# A file goes through unchanged: 100 KB of UTF-8 in 16 KiB chunks, so that
# characters arrive cut in two, and no final newline.
for i in $(seq 1 2000); do printf 'line %d: café, 日本語, 😀 — ok\n' "$i"; done > "$TMP/big.txt"
printf 'the end' >> "$TMP/big.txt"
listener transfer -l 127.0.0.1 0
nc -q 0 127.0.0.1 "$PORT" < "$TMP/big.txt" > "$TMP/out" 2> "$TMP/err"
same "transfer: client status" 0 $?
finished
same "transfer: listener status" 0 "$LSTATUS"
cmp -s "$TMP/big.txt" "$TMP/transfer.out"
same "transfer: same bytes" 0 $?
same "transfer: listener stderr" "Listening on 127.0.0.1 $PORT
Connection received" "$(cat "$TMP/transfer.err")"

# Both ways: the listener answers with its stdin and quits a second after
# sending; the client sends its own and prints the answer.
printf 'hello from the listener\n' > "$TMP/reply"
LISTEN_IN="$TMP/reply" listener both -l -q 1 127.0.0.1 0
printf 'hello\nfrom the client\n' | nc -vv 127.0.0.1 "$PORT" > "$TMP/out" 2> "$TMP/err"
same "both ways: status" 0 $?
same "both ways: client got" "hello from the listener" "$(cat "$TMP/out")"
same "both ways: counts" "Connection to 127.0.0.1 $PORT port [tcp/*] succeeded!
Sent 22 bytes, received 24 bytes" "$(cat "$TMP/err")"
finished
same "both ways: listener got" "hello
from the client" "$(cat "$TMP/both.out")"

# -C sends CR LF, which the client's -o dump and the listener both show;
# the listener's own dump has the received side.
listener crlf -l -d -o "$TMP/listener.dump" 127.0.0.1 0
printf 'GET / HTTP/1.0\nHost: x\r\n\nend' | nc -C -q 0 -o "$TMP/client.dump" 127.0.0.1 "$PORT" > /dev/null 2>&1
finished
printf 'GET / HTTP/1.0\r\nHost: x\r\n\r\nend' > "$TMP/want"
cmp -s "$TMP/want" "$TMP/crlf.out"
same "-C: bytes on the wire" 0 $?
same "-C: client dump" "> 00000000 47 45 54 20 2f 20 48 54 54 50 2f 31 2e 30 0d 0a # GET / HTTP/1.0..
> 00000010 48 6f 73 74 3a 20 78 0d 0a 0d 0a 65 6e 64       # Host: x....end" "$(cat "$TMP/client.dump")"
same "-o: listener dump" "< 00000000 47 45 54 20 2f 20 48 54 54 50 2f 31 2e 30 0d 0a # GET / HTTP/1.0..
< 00000010 48 6f 73 74 3a 20 78 0d 0a 0d 0a 65 6e 64       # Host: x....end" "$(cat "$TMP/listener.dump")"

# Received bytes that are not UTF-8 are printed as U+FFFD; -o has them.
listener binary -l -d -o "$TMP/binary.dump" 127.0.0.1 0
printf 'A\377B\n' | nc -q 0 127.0.0.1 "$PORT" > /dev/null 2>&1
finished
same "not UTF-8: printed" "41 ef bf bd 42 0a" "$(od -An -tx1 "$TMP/binary.out" | xargs)"
same "not UTF-8: dump" "< 00000000 41 ff 42 0a                                     # A.B." "$(cat "$TMP/binary.dump")"

# -i: a line at a time both ways; CR LF and a missing last newline come out
# as LF lines.
listener lines -l -d -i 0.1 127.0.0.1 0
printf 'one\r\ntwo\nthree' | nc -i 0.1 -q 0 127.0.0.1 "$PORT" > /dev/null 2>&1
finished
same "-i: lines" "$(printf 'one\ntwo\nthree\n')" "$(cat "$TMP/lines.out")"

# -d: the client sends nothing, though it has input, and prints the reply.
printf 'from the listener\n' > "$TMP/reply"
LISTEN_IN="$TMP/reply" listener quiet -l -q 0 127.0.0.1 0
printf 'not sent\n' | nc -d 127.0.0.1 "$PORT" > "$TMP/out" 2> "$TMP/err"
same "-d: status" 0 $?
same "-d: client got" "from the listener" "$(cat "$TMP/out")"
finished
same "-d: listener got nothing" "" "$(cat "$TMP/quiet.out")"

# -k: one listener, a banner for each of three clients, and what each
# client sent on the listener's output. Each client quits half a second
# after sending; the listener (no -q) waits for that.
printf 'banner\n' > "$TMP/reply"
LISTEN_IN="$TMP/reply" listener keep -lk 127.0.0.1 0
for n in 1 2 3; do
    printf 'client %s\n' "$n" | nc -q 0.5 127.0.0.1 "$PORT" > "$TMP/client$n.out" 2>&1
    same "-k: client $n" "banner" "$(cat "$TMP/client$n.out")"
done
kill -0 "$LPID" 2> /dev/null
same "-k: still listening" 0 $?
stop
same "-k: listener got" "client 1
client 2
client 3" "$(cat "$TMP/keep.out")"
same "-k: three connections" "Listening on 127.0.0.1 $PORT
Connection received
Connection received
Connection received" "$(cat "$TMP/keep.err")"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
