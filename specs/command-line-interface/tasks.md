# Tasks: command-line interface

- [x] 1. Define application identity and exit statuses in `source/appinfo.loup`
  - _Requirements: 2.2, 3.1, 3.2, 3.3_
- [x] 2. Implement `Options` and `parse_args` in `source/cli/args.loup`
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_
- [x] 3. Implement `usage()` and `version_line()` in `source/cli/usage.loup`
  - _Requirements: 2.1, 2.2, 2.4_
- [x] 4. Implement `run`, `dispatch` and `usage_error` in `source/cli/app.loup`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3_
- [x] 5. Implement the `hello` command in `source/commands/hello.loup`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
- [x] 6. Add tests in `tests/`
  - _Requirements: 1.1–1.8, 2.1, 2.2, 3.1, 3.3, 4.2, 4.4_
- [ ] 7. Test the exception path (`EXIT_FAILURE`) once a real command can throw
  - _Requirements: 3.2_
