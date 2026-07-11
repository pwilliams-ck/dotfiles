---
argument-hint: "Check git changes and run Go quality checks before release"
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the command**.

```
/go-release — check git changes and run Go quality checks before release

  Prepare for release by thoroughly analyzing changes and running Go
  quality checks. Deep-thinks through all changes for correctness, bugs,
  edge cases, security, observability, resilience, and production
  hardening. Runs go test, go vet, and golangci-lint. Presents a
  prioritized to-do list for your review before bumping version and
  changelog.

  /go-release                    run the full pipeline
  /go-release --help             show this help

  See also:
    /release           lightweight version bump (no Go checks)
    /feature-release   feature dev + release pipeline
```

---

ultrathink

Prepare for release by thoroughly analyzing changes and running Go quality checks:

1. First, use a subagent to gather all context needed for analysis:
   - Run `git diff` to get all changes
   - Run `git diff --name-only` to list all changed files
   - Read the full content of each changed file (not just the diff) for complete context
   - Identify any test files that correspond to changed files
   - Check if there's a Dockerfile, docker-compose.yml, or k8s manifests that might be affected

2. With all context gathered, FULLY analyze all changes with deep thinking. Treat me like an aspiring mid-to-senior engineer/architect who needs to be challenged:
   - Scrutinize every change for correctness and potential bugs
   - Point out edge cases I may have missed
   - Identify missing tests or test coverage gaps
   - Call out error handling issues (nil checks, error returns not checked, etc.)
   - Flag any concurrency issues (race conditions, deadlocks, improper mutex usage)
   - Highlight potential performance problems
   - Note any violations of Go idioms or best practices
   - Question whether abstractions are appropriate or over-engineered
   - Check for resource leaks (unclosed files, connections, channels)
   - Verify proper context propagation and cancellation handling
   - Be direct and constructive - don't sugarcoat issues

   Production hardening checklist:

   **Security:**
   - Are secrets hardcoded? (should use env vars, Vault, or K8s secrets)
   - Input validation on all external data (user input, API params, file uploads)
   - SQL injection, command injection, path traversal vulnerabilities
   - Are auth/authz checks in place and correct?
   - TLS configured properly? Certificates validated?

   **Observability:**
   - Structured logging (not fmt.Println) with appropriate log levels
   - Metrics exposed for Prometheus (request latency, error rates, saturation)
   - Distributed tracing spans for external calls
   - Health check endpoints (/healthz, /readyz) for K8s probes

   **Resilience:**
   - Timeouts on ALL external calls (HTTP clients, DB queries, gRPC)
   - Retries with exponential backoff for transient failures
   - Circuit breakers for downstream dependencies
   - Graceful shutdown handling (SIGTERM, drain connections)
   - Rate limiting on public endpoints

   **Long handler / orchestration smells:**
   - Handlers with 3+ sequential external calls - should these be async jobs?
   - What happens if step N of M fails? Can it resume or must restart from scratch?
   - Are steps idempotent? (safe to retry without side effects)
   - Is there handler-level retry logic, or only at the client level?
   - Should this be a saga pattern with compensating transactions?
   - Would a state machine help track progress through steps?
   - Are there natural breakpoints where work could be queued?
   - How long can this handler take? Will it hit HTTP timeouts?
   - If the server restarts mid-handler, is work lost?

   **Docker/Container readiness:**
   - Dockerfile uses multi-stage build with minimal final image (distroless/scratch)
   - Runs as non-root user
   - Proper signal handling (PID 1 problem solved)
   - No volume mounts for things that should be ephemeral
   - Resource requests/limits defined

   **Database:**
   - Connection pooling configured with sensible limits
   - Transactions used correctly (not held open too long)
   - Prepared statements or parameterized queries
   - Migrations versioned and reversible

   **API hygiene:**
   - Consistent error response format
   - Proper HTTP status codes (not 200 for everything)
   - Request/response validation
   - API versioning strategy if breaking changes possible

   **Dependency hygiene:**
   - Are dependencies up to date? Any known CVEs?
   - Is go.sum committed and verified?
   - Any unnecessary dependencies that bloat the binary?

3. After analyzing, ask me constructive questions about my design decisions:
   - Why did I choose this approach over alternatives?
   - Have I considered how this will run in Docker containers?
   - What containers would this need? Are any unnecessary?
   - Should this be a sidecar, init container, or part of the main container?
   - Are there services I'm including that should be separate containers?
   - How will this handle container restarts and orchestration?
   - Is the configuration 12-factor app friendly (env vars, no local state)?
   - Offer 2-3 concrete options to fix each issue you identify

4. Create a to-do list of all issues found, categorized by priority:

   **🔴 Critical** - Could cause outages, security breaches, or data loss. Should fix before release.
   **🟡 Important** - Will bite you eventually. Good to fix soon but won't break things today.
   **🟢 Nice-to-have** - Best practices and polish. Fix when you have time.

   Present the categorized list and ASK ME which items I want to tackle in this release. I may choose to:
   - Fix only critical items now
   - Fix critical + some important items
   - Defer everything and ship as-is (it works!)
   - Pick specific items regardless of category

   For each item I choose to fix:
   - Explain why it matters (in plain terms)
   - Show me how to fix it (or offer options)
   - Wait for my confirmation before marking it resolved

   Items I defer should be noted for future releases - remind me what technical debt I'm accepting.

5. Run the following quality checks in parallel using subagents:
   - `go test ./...` to ensure all tests pass
   - `go vet ./...` to check for Go issues
   - `golangci-lint run ./...` to check code quality

Stop if any of these steps fail and explain what needs to be fixed.

6. If all checks pass, run the following tasks in parallel using subagents:
   - Check the version in main.go const variable near the top of the file and bump it
   - Add to changelog.md following the existing patterns