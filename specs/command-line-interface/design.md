# Design: command-line interface

## Overview

`source/main.loup` calls `run(runtime.args())` and returns its result as the
exit status. `run` parses the arguments into an `Options` value, handles
`--help` and `--version`, then dispatches to a command function. Each command
takes the `Options` and returns an exit status, so the whole program can be
tested by calling `run` with an argument list.

```text
main() ──► run(argv) ──► parse_args(argv) ──► Result[Options, string]
                │
                ├── Err(msg)       ──► usage_error(msg)            exit 2
                ├── opts.help      ──► print usage()               exit 0
                ├── opts.version   ──► print version_line()        exit 0
                └── dispatch(opts) ──► run_hello(opts) / ...       exit 0, 1 or 2
```

## Modules

| Module | Contents |
|--------|----------|
| `source/appinfo.loup` | `APP_NAME`, `APP_VERSION`, `APP_SUMMARY`; `EXIT_OK` (0), `EXIT_FAILURE` (1), `EXIT_USAGE` (2) |
| `source/cli/args.loup` | `struct Options` and `parse_args(argv): Result[Options, string]` (Requirement 1) |
| `source/cli/usage.loup` | `usage()` and `version_line()` (Requirement 2) |
| `source/cli/app.loup` | `run(argv)`, `dispatch(opts)`, `usage_error(msg)` (Requirements 2, 3) |
| `source/commands/hello.loup` | `greeting_message(...)` and `run_hello(opts)` (Requirement 4) |

`Options` is a struct, so it is copied by value and needs no ownership verbs.
Its fields are `pub` because commands in other modules read them.

## Error handling

- Parse errors are values: `parse_args` returns `Err(message)` and `run`
  turns it into a usage error.
- Commands report misuse by printing to stderr and returning `EXIT_USAGE`.
- Any exception that escapes a command is caught in `run`
  (`catch (Exception as e)`), printed, and turned into `EXIT_FAILURE`.

## Testing

| Test file | Covers |
|-----------|--------|
| `tests/args_test.loup` | Requirement 1 and the flags of Requirement 2 |
| `tests/app_test.loup` | exit statuses of Requirement 3 |
| `tests/hello_test.loup` | message formatting of Requirement 4 |
