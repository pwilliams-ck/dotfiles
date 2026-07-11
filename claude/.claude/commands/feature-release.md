---
argument-hint: "Feature dev then version bump and changelog"
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the command**.

```
/feature-release — run feature dev then version bump and changelog

  Run /feature-dev:feature-dev to completion first, then run /release to
  bump the version and update the changelog.

  /feature-release               run the full pipeline
  /feature-release --help        show this help

  Invokes:
    /feature-dev:feature-dev     guided feature development
    /release                     version bump + changelog

  See also:
    /go-release    Go quality checks + release pipeline
```

---

Run /feature-dev:feature-dev to completion first.

Then when feature-dev is fully complete, run /release to bump the version and update the changelog.
