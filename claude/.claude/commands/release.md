---
argument-hint: "Bump version and update changelog"
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the command**.

```
/release — bump version and update changelog

  Bump the version and update the changelog based on changes in this
  branch. Analyzes git diff, bumps the semver PATCH in main.go (override
  for MINOR/MAJOR), and inserts a changelog entry matching the existing
  style. Read-only git — user handles all git operations.

  /release                       run version bump + changelog
  /release --help                show this help

  See also:
    /go-release        full Go quality checks + release
    /feature-release   feature dev + release pipeline
```

---

Bump the version and update the changelog based on changes in this branch.

## Git Commits

**GIT POLICY: Only use `git diff` and `git status` for analysis. NEVER create branches, commit, push, or modify git state. User handles all git operations.**

Share commit message this with the user in output at the end. Keep message to standard number of columns.

---

## Phase 1: Analyze Changes

Run `git diff main...HEAD` and `git log main..HEAD --oneline` to understand what changed on this branch.

---

## Phase 2: Version Bump

Version format is semver: `MAJOR.MINOR.PATCH` (e.g. `1.4.2`).

1. Read `cmd/api/main.go` and find the `version` const
2. Default: bump **PATCH** (e.g. `"1.4.2"` → `"1.4.3"`). User will specify if they want MINOR or MAJOR instead.
3. Update the const in `cmd/api/main.go`

---

## Phase 3: Changelog Update

1. Read `changelog.md` and match the existing style exactly:
   - Heading format: `## vX.Y.Z - YYYY-MM-DD`
   - New entries go directly below the `## Roadmap` section
   - Bullet points with backtick-wrapped code references
   - Nested bullets for sub-details
2. Generate a changelog entry summarizing the branch changes
3. Insert it below the Roadmap section, before the previous version entry

---

## Phase 4: Summary

Report what was done:

```
Version: MAJOR.MINOR.PATCH → MAJOR.MINOR.PATCH
Updated: cmd/api/main.go, changelog.md

Ready for review. User handles git operations.
```
