# Specs

Each feature gets a directory under `specs/` holding three files:

| File | Contents |
|------|----------|
| `requirements.md` | Introduction, then numbered requirements. Each has a user story and numbered acceptance criteria written as `WHEN ... THE <component> SHALL ...`. |
| `design.md` | How the requirements are met: the modules under `source/` involved, data types, control flow, error handling, and the tests that cover it. |
| `tasks.md` | A checklist of implementation steps. Each task names the requirements it satisfies (`_Requirements: 1.2, 3.1_`) and is ticked when done. |

Name the directory after the feature in kebab-case, e.g. `specs/export-command/`.

Write or update the spec before changing behaviour, keep it in step with the
code, and tick tasks off as they land. [`command-line-interface/`](command-line-interface/)
is a worked example that describes the template's own argument parsing and
sample command.

## Starting a new spec

```markdown
# Requirements: <feature>

## Introduction

<What the feature is for and who uses it.>

## Requirements

### Requirement 1: <name>

**User Story:** As a <user>, I want <capability> so that <benefit>.

#### Acceptance Criteria

1. WHEN <condition>, THE <component> SHALL <behaviour>.
```

```markdown
# Design: <feature>

## Overview
## Modules
## Error handling
## Testing
```

```markdown
# Tasks: <feature>

- [ ] 1. <step>
  - _Requirements: 1.1_
```
