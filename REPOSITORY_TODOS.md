# Repository TODOs

A checklist for turning a repository created from this template into your own
application. Work through it, then delete this file.

## Name and identity

- [ ] Pick the application's name (the examples below use `newname`).
- [ ] `package.lppkg`: set `name`.
- [ ] `source/appinfo.loup`: set `APP_NAME` and `APP_SUMMARY`.
- [ ] `Makefile`: set `APP` (it names the binary `build/<APP>`).
- [ ] `.github/workflows/ci.yml`: update the artifact `name` and `path`
      (`build/myapp`).
- [ ] `README.md`: replace the title, description, help output and
      `build/myapp` examples.
- [ ] `AGENTS.md`: replace the opening description with one of this project.
- [ ] Search for leftovers: `grep -rn "myapp" --exclude-dir=build .`

## Version and toolchain

- [ ] Set the starting version in both `package.lppkg` (`version`) and
      `source/appinfo.loup` (`APP_VERSION`). They must match: the program cannot
      read the manifest.
- [ ] Choose the Loup toolchain version and set it in `package.lppkg`
      (`loup`), `.github/workflows/ci.yml` (`LOUP_VERSION`) and the pinned
      install command in `README.md` ("Installing Loup Lite").
- [ ] If the toolchain is newer than the one `skills/loup-programmer/`
      describes (1.25.1), copy a newer skill from the Loup repository's
      `skills/` directory if one exists.

## Ownership and licensing

- [ ] `package.lppkg`: fill in `authors`.
- [ ] `LICENSE` is the MIT license, copyright 2026 Code Craft AI LLC. If this
      project needs another holder or license, change it and the README's
      License section.
- [ ] On GitHub: set the repository description and topics, and leave
      **Template repository** unchecked under Settings → General unless this
      repository is itself meant to be a template.

## Application code

- [ ] Replace the sample `hello` command:
  - [ ] delete or rewrite `source/commands/hello.loup` and `tests/hello_test.loup`;
  - [ ] update `dispatch` in `source/cli/app.loup`;
  - [ ] update the command list in `usage()` in `source/cli/usage.loup`.
- [ ] Replace the sample options (`--greeting`, `--shout`) in `Options` and
      `parse_args` (`source/cli/args.loup`) with the application's own options,
      and update `tests/args_test.loup` to match.
- [ ] Keep or drop the global `--verbose` flag.
- [ ] Review the exit statuses in `source/appinfo.loup` (`0` ok, `1` failure,
      `2` usage error) and add any the application needs.
- [ ] Update `tests/app_test.loup` for the new commands.
- [ ] Rewrite `specs/command-line-interface/` to describe the application's
      real commands and options, and add a spec under `specs/` for each new
      feature (see `specs/README.md`).

## Build and CI

- [ ] Run `make ci` locally and confirm it passes.
- [ ] Decide which platforms to build for. CI builds Linux x86-64 only; native
      builds also work on Linux arm64 and are a preview on macOS and Windows.
      Add jobs or a matrix if you need those binaries.
- [ ] Decide how releases are published (for example a workflow that attaches
      `build/<APP>` to a GitHub release on a tag).
- [ ] Set up branch protection on `main` and require the CI check.

## Agents

- [ ] Keep `AGENTS.md` up to date as conventions change.
- [ ] Optional: to make the skill load automatically in Claude Code, link it
      into `.claude/skills/`:
      `mkdir -p .claude/skills && ln -s ../../skills/loup-programmer .claude/skills/loup-programmer`

## Finish

- [ ] Delete `REPOSITORY_TODOS.md`.
