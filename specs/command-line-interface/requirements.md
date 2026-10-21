# Requirements: command-line interface

## Introduction

The application is invoked as `myapp [OPTIONS] COMMAND [ARGS...]`. This spec
covers how arguments are parsed, how commands are selected, the help and
version output, exit statuses, and the sample `hello` command. Loup 1.26 has no
CLI library, so parsing is implemented in the application.

## Requirements

### Requirement 1: Argument grammar

**User Story:** As a user, I want conventional option syntax so that the tool
behaves like other command-line programs.

#### Acceptance Criteria

1. THE parser SHALL treat the first argument that does not start with `-` as the command and every later such argument as an operand.
2. THE parser SHALL accept options before, between and after the command and its operands.
3. WHEN the parser meets `--`, THE parser SHALL treat every remaining argument as an operand.
4. THE parser SHALL treat a lone `-` as an operand.
5. THE parser SHALL accept a value option as `--name VALUE`, `-n VALUE` or `--name=VALUE`, splitting `--name=VALUE` on the first `=` only.
6. WHEN a value option is last and has no value, THE parser SHALL fail with `option '<name>' requires a value`.
7. WHEN a flag is given an inline value (`--flag=x`), THE parser SHALL fail with `option '<name>' does not take a value`.
8. WHEN an option is not recognised, THE parser SHALL fail with `unknown option '<name>'`.

### Requirement 2: Global options

**User Story:** As a user, I want help and version options so that I can learn
how to use the tool and which version I have.

#### Acceptance Criteria

1. WHEN `-h` or `--help` is given, THE application SHALL print the usage text to stdout and exit 0 without running a command.
2. WHEN `-V` or `--version` is given, THE application SHALL print `<name> <version>` to stdout and exit 0 without running a command.
3. WHEN `-v` or `--verbose` is given, THE application SHALL print the selected command and its operands to stderr before running it.
4. THE `help` command SHALL print the same usage text as `--help`.

### Requirement 3: Errors and exit statuses

**User Story:** As a script author, I want distinct exit statuses so that I can
tell misuse from failure.

#### Acceptance Criteria

1. WHEN a command succeeds, THE application SHALL exit 0.
2. WHEN a command throws an uncaught exception, THE application SHALL print `<name>: error: <message>` to stderr and exit 1.
3. WHEN parsing fails, no command is given, or the command is unknown, THE application SHALL print `<name>: <message>` and `Try '<name> --help' for more information.` to stderr and exit 2.

### Requirement 4: The hello command

**User Story:** As a developer evaluating the template, I want a small working
command so that I can see how commands receive options and report results.

#### Acceptance Criteria

1. WHEN `hello` is run with no operand, THE command SHALL print `Hello, world!`.
2. WHEN `hello NAME` is run, THE command SHALL print `<greeting>, NAME!`.
3. WHEN `-g TEXT` or `--greeting TEXT` is given, THE command SHALL use TEXT as the greeting; the default is `Hello`.
4. WHEN `--shout` is given, THE command SHALL print the message in upper case.
5. WHEN more than one operand is given, THE command SHALL print `<name>: hello takes at most one NAME` to stderr and exit 2.
