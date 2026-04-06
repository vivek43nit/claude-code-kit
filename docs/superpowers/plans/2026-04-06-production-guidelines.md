# Production Guidelines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the 10 missing production-grade guideline files that cover observability, database safety, API design, testing pyramid, branching/release, dependency management, ADRs, feature flags, incident management, and accessibility — then wire them all into CLAUDE.md.

**Architecture:** Each gap becomes a focused `guidelines/<topic>.md` file. Universal guidelines (apply to every project) are imported directly in `CLAUDE.md`. The one context-specific guideline (accessibility) is wired into `detect-languages.sh` so it only activates for TypeScript/JavaScript projects. The CLAUDE.md decision table is updated to reference security-guidance for the new sensitive areas.

**Tech Stack:** Bash, Markdown, existing hook infrastructure

---

## File Map

| File | Type | Purpose |
|------|------|---------|
| `guidelines/observability.md` | Universal | Structured logging, metrics (RED), distributed tracing, what never to log |
| `guidelines/database.md` | Universal | Zero-downtime migrations, N+1 prevention, connection pooling, rollback procedures |
| `guidelines/api-design.md` | Universal | REST versioning, error format, pagination, OpenAPI requirements, status codes |
| `guidelines/testing.md` | Universal | Testing pyramid (unit/integration/e2e/perf/contract), ratios, tooling per layer |
| `guidelines/branching.md` | Universal | Trunk-based dev, branch naming, semantic versioning, changelog, release tags |
| `guidelines/dependencies.md` | Universal | Renovate/Dependabot policy, license compliance, no-GPL rule, audit in CI |
| `guidelines/adr.md` | Universal | When to write ADRs, template, location (`docs/adr/`), numbering scheme |
| `guidelines/feature-flags.md` | Universal | When to use, stale flag policy, default-off rule, tooling |
| `guidelines/incidents.md` | Universal | Severity levels, post-mortem template, on-call handoff, runbook standards |
| `guidelines/accessibility.md` | Frontend-only | WCAG 2.1 AA, semantic HTML, ARIA, contrast, keyboard nav, screen reader |
| `CLAUDE.md` | Modify | Import all 9 universal guidelines; add accessibility to frontend decision table |
| `.claude/hooks/detect-languages.sh` | Modify | Add accessibility.md injection when TypeScript or JavaScript detected |

---

## Task 1: Observability Guidelines (P0)

**Files:**
- Create: `guidelines/observability.md`

- [ ] **Step 1: Define verification checklist**

The file must cover: structured logging format, required log fields, log levels with definitions, what never to log, RED metrics pattern, distributed tracing context propagation, per-language tooling.

- [ ] **Step 2: Create `guidelines/observability.md`**

```markdown
# Observability Guidelines

Good observability means you can answer "what is the system doing right now and why?" without SSH-ing into a server.

## Structured Logging

Always emit logs as JSON (or your platform's structured format). Never plain-text strings in production.

**Required fields on every log line:**

```json
{
  "timestamp": "2026-04-06T10:23:01.123Z",
  "level": "info",
  "service": "user-service",
  "version": "1.4.2",
  "trace_id": "abc123",
  "span_id": "def456",
  "message": "User login succeeded",
  "user_id": "u_789"
}
```

**Log levels — use precisely:**

| Level | When to use | Action required |
|-------|-------------|-----------------|
| `ERROR` | Operation failed, data may be lost or corrupt | Page on-call immediately |
| `WARN` | Unexpected state but operation succeeded | Investigate within 24h |
| `INFO` | Key business events (login, payment, order) | No action — for audit trail |
| `DEBUG` | Detailed execution flow | Dev/staging only, never prod |

**Never log:**
- Passwords, tokens, API keys, session IDs
- Full credit card numbers or CVVs
- Government IDs, SSNs, passport numbers
- Full request/response bodies (log shape only, not values)
- Stack traces at INFO level (ERROR only)

**Do log:**
- User ID (not email/name) for traceability
- Request ID / trace ID on every log line
- Timing information for slow operations
- External service call outcomes (success/fail + duration)

## Metrics — RED Pattern

For every service endpoint, track:

- **R**ate: requests per second
- **E**rrors: error rate (%)
- **D**uration: latency percentiles (p50, p95, p99)

For background jobs / queues, also track:
- Queue depth
- Processing lag (time between enqueue and start)
- Dead-letter queue size

**Naming convention:** `<service>_<operation>_<unit>`
Examples: `user_login_duration_ms`, `payment_requests_total`, `order_errors_total`

## Distributed Tracing

- Propagate trace context on every outbound call (HTTP headers: `traceparent`, `X-Trace-ID`)
- Every service entry point must extract and continue the trace
- Every external DB/cache/queue call must be a child span
- Instrument: use OpenTelemetry — it's vendor-neutral

**Minimum span attributes:**
- `service.name`
- `http.method` + `http.url` (for HTTP spans)
- `db.system` + `db.statement` (for DB spans, redact values)
- `error` = true + `error.message` (on failure spans)

## Health Endpoints

Every service must expose:

```
GET /health/live   → 200 if process is running (liveness)
GET /health/ready  → 200 if service can handle traffic (readiness: DB connected, cache reachable)
```

Never return 500 from `/health/live`. It will restart your pod.

## Per-Language Tooling

| Language | Logger | Metrics | Tracing |
|----------|--------|---------|---------|
| Python | `structlog` | `prometheus-client` | `opentelemetry-sdk` |
| TypeScript | `pino` | `prom-client` | `@opentelemetry/sdk-node` |
| Go | `zerolog` or `zap` | `prometheus/client_golang` | `go.opentelemetry.io/otel` |
| Java | `logback` + `SLF4J` | `micrometer` | `opentelemetry-java` |
| Kotlin | `logback` + `SLF4J` | `micrometer` | `opentelemetry-java` |
| Rust | `tracing` crate | `metrics` crate | `opentelemetry` crate |
```

- [ ] **Step 3: Verify checklist**

Read the file and confirm all items are present: JSON format, required fields, 4 log levels defined, 5+ "never log" items, RED metrics, trace propagation, OpenTelemetry, health endpoints, per-language tooling table.

- [ ] **Step 4: Commit**

```bash
git add guidelines/observability.md
git commit -m "feat: add observability guidelines (logging, metrics, tracing)"
```

---

## Task 2: Database Safety Guidelines (P0)

**Files:**
- Create: `guidelines/database.md`

- [ ] **Step 1: Define verification checklist**

Must cover: zero-downtime migration steps, column removal two-step process, index-before-FK rule, N+1 prevention, connection pooling rules, rollback procedure, per-language tooling.

- [ ] **Step 2: Create `guidelines/database.md`**

```markdown
# Database Guidelines

One bad migration can take down production. One missing index can collapse under load. These rules exist because someone learned them the hard way.

## Migration Safety (Zero-Downtime)

**The cardinal rule:** Every migration must be deployable without stopping the application.

**Safe operations (can do any time):**
- Add a nullable column
- Add an index (`CONCURRENTLY` in Postgres)
- Add a new table
- Add a new foreign key to a new column

**Dangerous operations (require two-step deploy):**

| Operation | Safe approach |
|-----------|--------------|
| Remove a column | Step 1: deploy code that ignores the column. Step 2 (next release): drop the column. |
| Rename a column | Step 1: add new column + backfill + dual-write. Step 2: migrate reads. Step 3: drop old column. |
| Change column type | Step 1: add new column. Step 2: backfill + dual-write. Step 3: swap. Step 4: drop old. |
| Add NOT NULL constraint | Step 1: add as nullable + backfill nulls. Step 2: add constraint with `NOT VALID`. Step 3: `VALIDATE CONSTRAINT` (non-blocking). |
| Add index | Always use `CREATE INDEX CONCURRENTLY` (Postgres). Never plain `CREATE INDEX` on live tables. |

**Before every migration:**
- [ ] Test on a copy of production data (row counts matter — 10M rows ≠ 10 rows)
- [ ] Estimate lock duration — anything > 1s needs a plan
- [ ] Write the rollback migration before writing the forward migration
- [ ] Review with a second engineer if the table has > 1M rows

## N+1 Query Prevention

N+1 kills production under load. Never load related records inside a loop.

```python
# BAD — N+1: 1 query for orders + N queries for users
orders = Order.objects.all()
for order in orders:
    print(order.user.email)  # separate query each time

# GOOD — 2 queries total
orders = Order.objects.select_related('user').all()
for order in orders:
    print(order.user.email)
```

**Rule:** Any code that accesses a relationship inside a loop must use eager loading / JOIN / batch fetch. Add this to your code review checklist.

## Connection Pooling

- Never open a raw database connection per request in a web handler
- Always use a connection pool (PgBouncer, HikariCP, SQLAlchemy pool, pgxpool)
- Pool size formula: `(num_cores * 2) + num_disk_spindles` — start with `10` if unsure
- Set `connection_timeout` and `pool_timeout` — never let a request hang forever waiting for a connection
- Monitor pool exhaustion — it presents as sudden latency spikes, not errors

## Query Guidelines

- Always add an index before adding a foreign key constraint
- Queries that appear in hot paths (>10 req/s) must have `EXPLAIN ANALYZE` reviewed
- Avoid `SELECT *` — select only columns you use
- Use pagination on all list queries — never return unbounded result sets
- Parameterised queries only. No string interpolation. Ever.

## Rollback Procedure

Every migration deployment must have a written rollback plan documented in the PR:

```
Rollback steps:
1. Run: `<tool> db downgrade <version>`
2. Verify: `<tool> db current` shows previous version
3. Check: application health endpoint returns 200
4. Confirm: no error spike in logs
```

If the migration is irreversible (e.g. data transformation), document the data recovery procedure instead.

## Per-Language Tooling

| Language | Migration tool | ORM / Query builder |
|----------|---------------|---------------------|
| Python | Alembic (SQLAlchemy) | SQLAlchemy, Django ORM |
| TypeScript | Prisma Migrate, TypeORM | Prisma, TypeORM, Drizzle |
| Go | `golang-migrate` | sqlc, GORM, sqlx |
| Java | Flyway or Liquibase | Hibernate, jOOQ |
| Kotlin | Flyway or Liquibase | Exposed, Hibernate |
| Rust | `sqlx` migrations | sqlx, Diesel |
```

- [ ] **Step 3: Verify checklist**

Confirm: zero-downtime table, 2-step column removal, index CONCURRENTLY, N+1 example, pooling rules, rollback template, per-language tooling.

- [ ] **Step 4: Commit**

```bash
git add guidelines/database.md
git commit -m "feat: add database safety guidelines (migrations, N+1, pooling)"
```

---

## Task 3: API Design Standards (P1)

**Files:**
- Create: `guidelines/api-design.md`

- [ ] **Step 1: Create `guidelines/api-design.md`**

```markdown
# API Design Standards

Consistent APIs reduce cognitive load across teams. These rules apply to all HTTP APIs exposed internally or externally.

## REST URL Design

- Use plural nouns: `/users`, `/orders`, `/products`
- No verbs in URLs: ✗ `/getUser`, ✗ `/createOrder`
- Nested resources for ownership: `/users/{id}/orders`
- Max 2 levels of nesting — deeper = design smell, use query params instead
- Lowercase, hyphenated: `/payment-methods`, not `/paymentMethods`

## Versioning

- URL versioning: `/v1/users`, `/v2/users`
- Increment major version on breaking changes only
- Maintain previous version for minimum 6 months after deprecation notice
- Add `Deprecation` and `Sunset` headers on deprecated endpoints:
  ```
  Deprecation: true
  Sunset: Sat, 01 Jan 2027 00:00:00 GMT
  ```

## HTTP Methods

| Method | Use for | Idempotent | Body |
|--------|---------|-----------|------|
| GET | Read | Yes | No |
| POST | Create | No | Yes |
| PUT | Full replace | Yes | Yes |
| PATCH | Partial update | No | Yes |
| DELETE | Delete | Yes | No |

## Status Codes — Use Precisely

| Code | Meaning | When |
|------|---------|------|
| 200 | OK | Successful GET, PUT, PATCH, DELETE |
| 201 | Created | Successful POST that creates a resource |
| 204 | No Content | Successful DELETE with no response body |
| 400 | Bad Request | Client sent invalid data (validation error) |
| 401 | Unauthorised | Not authenticated — missing/invalid token |
| 403 | Forbidden | Authenticated but lacks permission |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate resource, optimistic lock failure |
| 422 | Unprocessable | Semantically invalid (field values fail business rules) |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Unexpected server failure |
| 503 | Service Unavailable | Downstream dependency down |

Never return 200 with an error body. Never return 500 for client errors.

## Error Response Format

All error responses must use this structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid fields.",
    "request_id": "req_abc123",
    "details": [
      {
        "field": "email",
        "code": "INVALID_FORMAT",
        "message": "Must be a valid email address."
      }
    ]
  }
}
```

- `code`: machine-readable, SCREAMING_SNAKE_CASE, stable across versions
- `message`: human-readable, safe to display
- `request_id`: always include for support traceability
- `details`: array, only present for validation errors

## Pagination

Use cursor-based pagination for large or frequently-updated datasets:

```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTAwfQ==",
    "has_more": true,
    "limit": 20
  }
}
```

Never return unbounded lists. Default page size: 20. Max: 100.

Offset pagination is acceptable for admin UIs and small datasets (< 10K rows).

## Request / Response Conventions

- Dates: ISO 8601 UTC — `"2026-04-06T10:23:01Z"`
- IDs: strings (not integers — allows migration to UUIDs without breaking clients)
- Monetary values: integers in smallest unit (cents) — `"amount": 1999` = $19.99
- Booleans: never `0`/`1`, always `true`/`false`
- Nulls: omit optional absent fields rather than sending `null`

## Documentation

- Every endpoint must have an OpenAPI 3.0 spec
- Spec must live in the repo, not a wiki
- Generated from code annotations where possible (FastAPI, SpringDoc, tsoa)
- Include: request/response schemas, example values, error codes, authentication requirements

## Rate Limiting

- Every public endpoint must have rate limits
- Return `429` with `Retry-After` header
- Document limits in the API spec
```

- [ ] **Step 2: Commit**

```bash
git add guidelines/api-design.md
git commit -m "feat: add API design standards (REST, errors, pagination, OpenAPI)"
```

---

## Task 4: Testing Pyramid Guidelines (P1)

**Files:**
- Create: `guidelines/testing.md`

- [ ] **Step 1: Create `guidelines/testing.md`**

```markdown
# Testing Guidelines — The Testing Pyramid

Unit tests alone are not enough. Production failures happen at integration points, not inside isolated functions.

## The Pyramid

```
        /\
       /E2E\        10% — Critical user journeys only
      /------\
     /  Integ  \    20% — Service boundaries, real DB/cache
    /------------\
   /     Unit     \  70% — Business logic, fast, isolated
  /----------------\
```

**Rule:** If your test suite is >90% unit tests, you're testing implementation, not behaviour.

## Unit Tests (70%)

- Scope: a single function, method, or class in isolation
- Speed: < 10ms each, no I/O
- Mocking: mock at system boundaries only (DB, HTTP, filesystem, clock)
- What to test: business logic, edge cases, error paths, validation
- What NOT to unit test: framework glue code, simple getters/setters, generated code

```python
# Good unit test — tests logic, mocks boundary
def test_order_total_applies_discount_when_customer_is_vip():
    customer = Customer(tier="vip")
    items = [Item(price=100), Item(price=50)]
    total = calculate_order_total(items, customer)
    assert total == 135.0  # 10% VIP discount

# Bad — testing the ORM, not your logic
def test_save_user():
    user = User(email="a@b.com")
    db.save(user)
    assert db.get(user.id) is not None
```

## Integration Tests (20%)

- Scope: one service + its real infrastructure (DB, cache, message queue)
- Speed: < 2s each, uses real connections
- Use a test DB that is reset between test suites (not between each test)
- Test: data persistence, query correctness, transaction behaviour, migration correctness
- Do NOT mock the database in integration tests

```python
# Good integration test — real DB, tests actual persistence
def test_create_user_persists_to_database(db_session):
    user_service.create(db_session, email="a@b.com", name="Alice")
    result = db_session.query(User).filter_by(email="a@b.com").first()
    assert result is not None
    assert result.name == "Alice"
```

## End-to-End Tests (10%)

- Scope: full system through the public API or UI
- Speed: can be slow (seconds), run in CI on PR to main only
- Cover: critical user journeys ONLY (login → checkout → confirmation)
- Do NOT duplicate unit/integration coverage in E2E
- Max 20 E2E tests for a typical service — if you have more, convert to integration tests

## Contract Tests (for microservices)

When service A calls service B, both must agree on the contract.

- Use Pact or similar consumer-driven contract testing
- Consumer (service A) defines the contract
- Provider (service B) verifies it in CI
- Prevents "it works in isolation but breaks when deployed" failures

## Performance Tests

- Run before every production release on staging
- Baseline: capture p50/p95/p99 latency at expected load
- Gate: p99 must not exceed 2x the baseline from the previous release
- Tools: k6, Locust, Gatling, JMeter
- Minimum scenario: 10 min ramp-up → 30 min sustained load at peak → 5 min ramp-down

## Test Data Management

- Never use production data in tests
- Use factories/builders to create test data — not hand-crafted fixtures
- Reset state between test suites (not between tests — too slow)
- Seed scripts for E2E environments must be idempotent

## CI Test Strategy

| Stage | Tests run | Gate |
|-------|-----------|------|
| Pre-commit hook | Unit tests for changed files | Must pass |
| PR | Unit + Integration + Contract | Must pass, 80% coverage |
| Merge to main | All above + E2E | Must pass |
| Pre-release | All above + Performance | p99 ≤ 2x baseline |
```

- [ ] **Step 2: Commit**

```bash
git add guidelines/testing.md
git commit -m "feat: add testing pyramid guidelines (unit/integration/e2e/perf/contract)"
```

---

## Task 5: Branching & Release Strategy (P1)

**Files:**
- Create: `guidelines/branching.md`

- [ ] **Step 1: Create `guidelines/branching.md`**

```markdown
# Branching & Release Strategy

## Branching Model — Trunk-Based Development (Default)

All developers commit to `main` (trunk) at least once per day. Long-lived feature branches are a symptom of integration fear, not a solution to it.

**Rules:**
- `main` is always deployable
- Feature branches live < 2 days — if longer, use a feature flag
- No direct commits to `main` — always via PR
- PRs require 1 approval minimum (2 for security/payment/infra changes)
- Delete branches after merge

**Branch naming:**

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/<ticket>-<short-desc>` | `feat/PROJ-123-add-checkout` |
| Bug fix | `fix/<ticket>-<short-desc>` | `fix/PROJ-456-cart-total` |
| Hotfix | `hotfix/<ticket>-<short-desc>` | `hotfix/PROJ-789-payment-crash` |
| Chore | `chore/<short-desc>` | `chore/update-dependencies` |
| Release | `release/v<semver>` | `release/v2.3.0` |

## Semantic Versioning

Format: `MAJOR.MINOR.PATCH` — e.g. `v2.3.1`

| Increment | When |
|-----------|------|
| MAJOR | Breaking API change — clients must update |
| MINOR | New feature, backward-compatible |
| PATCH | Bug fix, backward-compatible |

Pre-release: `v2.3.0-beta.1`, `v2.3.0-rc.1`

## Release Process

1. Create `release/vX.Y.Z` branch from `main`
2. Bump version in manifest file (`package.json`, `pyproject.toml`, `go.mod`, etc.)
3. Generate changelog: `git-cliff` or `conventional-changelog`
4. PR → merge to `main`
5. Tag: `git tag -s vX.Y.Z -m "Release vX.Y.Z"`
6. Push tag — CI builds and publishes the release artifact
7. Create GitHub/GitLab Release with the changelog

## Changelog

Use conventional commits to auto-generate changelogs. Every release must have a `CHANGELOG.md` entry.

Format:
```markdown
## [2.3.0] - 2026-04-06

### Added
- feat(auth): add OAuth2 PKCE flow

### Fixed
- fix(cart): prevent duplicate item on rapid double-click

### Security
- fix(auth): rotate session token on privilege escalation
```

Tool: `git-cliff` — configure in `cliff.toml` at repo root.

## Hotfix Process

For P0/P1 production incidents:

1. Branch from the release tag: `git checkout -b hotfix/PROJ-789 v2.3.0`
2. Fix, test, commit
3. PR → merge to `main`
4. Cherry-pick to current release branch if needed
5. Tag: `v2.3.1`

Never hotfix directly on `main` without a branch + PR.

## Environment Promotion

```
developer machine → staging → production
```

- `main` auto-deploys to staging
- Production deploys are manually triggered (or on release tag push)
- No code skips staging
```

- [ ] **Step 2: Commit**

```bash
git add guidelines/branching.md
git commit -m "feat: add branching and release strategy guidelines"
```

---

## Task 6: Dependency Management Policy (P2)

**Files:**
- Create: `guidelines/dependencies.md`

- [ ] **Step 1: Create `guidelines/dependencies.md`**

```markdown
# Dependency Management Policy

Dependencies are attack surface. Every dependency you add is code you didn't write and can't fully control.

## Adding New Dependencies

Before adding any dependency, ask:
1. Is this functionality already available in the standard library?
2. Is this dependency actively maintained (commits in last 6 months)?
3. What is its license? (see License Policy below)
4. How many transitive dependencies does it add?
5. Has it had critical CVEs in the last 12 months?

**Rule:** Any new production dependency requires a brief justification comment in the PR.

## Automated Updates — Renovate (Required)

Every repo must have a `renovate.json` at root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:base"],
  "schedule": ["every weekend"],
  "automerge": false,
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": true,
      "matchPackagePatterns": ["*"]
    },
    {
      "matchUpdateTypes": ["minor", "major"],
      "automerge": false,
      "reviewers": ["team:backend"]
    }
  ]
}
```

- Patch updates: auto-merge if CI passes
- Minor updates: require 1 approval
- Major updates: require team discussion

## Lock Files

- Lock files (`package-lock.json`, `poetry.lock`, `go.sum`, `Cargo.lock`) must be committed
- Never run CI without a lock file
- Never use `--no-lockfile` in production builds

## License Policy

| License | Commercial use | Action |
|---------|---------------|--------|
| MIT, Apache 2.0, BSD | ✅ Allowed | No action needed |
| ISC, Unlicense | ✅ Allowed | No action needed |
| LGPL | ⚠️ Check | Allowed if dynamically linked — verify |
| GPL, AGPL | ❌ Blocked | Do not use in commercial products |
| Commercial / proprietary | ⚠️ Approve | Requires legal + finance approval |

Run `license-checker` (Node) or `pip-licenses` (Python) or `cargo-license` (Rust) in CI to catch violations automatically.

## Vulnerability Scanning

- CI must run a vulnerability scan on every PR (Trivy, already configured in quality-gates.yml)
- HIGH and CRITICAL CVEs block merge
- MEDIUM CVEs: create a tracking ticket and fix within 30 days
- LOW CVEs: fix in next scheduled dependency update cycle

## Dependency Review on PRs

GitHub's Dependency Review Action (add to quality-gates.yml):

```yaml
dependency-review:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/dependency-review-action@v4
      with:
        fail-on-severity: high
        deny-licenses: GPL-2.0, GPL-3.0, AGPL-3.0
```
```

- [ ] **Step 2: Commit**

```bash
git add guidelines/dependencies.md
git commit -m "feat: add dependency management policy (Renovate, license, vulnerability)"
```

---

## Task 7: Architecture Decision Records (P2)

**Files:**
- Create: `guidelines/adr.md`
- Create: `docs/adr/0001-use-adrs-for-architectural-decisions.md`

- [ ] **Step 1: Create `guidelines/adr.md`**

```markdown
# Architecture Decision Records (ADRs)

An ADR documents a significant architectural decision: what was decided, why, and what the trade-offs are. The goal is to make future engineers (including yourself in 6 months) understand the *why*, not just the *what*.

## When to Write an ADR

Write an ADR when:
- The decision is hard to reverse (database choice, auth approach, event vs REST)
- The decision affects more than one team or service
- Reasonable engineers could disagree on the right choice
- You find yourself explaining the same decision in multiple PR reviews
- The decision has significant security, performance, or cost implications

Do NOT write an ADR for:
- Library version bumps
- Code style preferences (covered by guidelines)
- Reversible implementation details

## Location & Numbering

Store in: `docs/adr/<NNNN>-<short-title>.md`

Number sequentially starting from `0001`. Never reuse or delete numbers — if a decision is superseded, mark the old ADR as superseded and write a new one.

Examples:
- `docs/adr/0001-use-adrs-for-architectural-decisions.md`
- `docs/adr/0002-use-postgresql-as-primary-database.md`
- `docs/adr/0003-use-jwt-for-api-authentication.md`

## ADR Template

```markdown
# <NNNN>. <Title>

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Deprecated | Superseded by [NNNN](./NNNN-title.md)
**Deciders:** @person1, @person2

## Context

What is the situation that forced this decision? What constraints exist?
Include: team size, traffic volume, existing systems, time pressure, non-functional requirements.

## Decision

What was decided? State it clearly in one paragraph.

## Alternatives Considered

| Option | Pros | Cons | Reason rejected |
|--------|------|------|-----------------|
| Option A | ... | ... | ... |
| Option B | ... | ... | ... |

## Consequences

**Positive:**
- ...

**Negative / trade-offs:**
- ...

**Risks:**
- ...

## Follow-up Actions

- [ ] Action item with owner @person
```

## Review Process

- ADR is written as part of the design phase, before implementation
- Reviewed in the design PR (not the implementation PR)
- Must be approved by at least one senior engineer
- Link the ADR from the implementation PR description
```

- [ ] **Step 2: Create the bootstrap ADR `docs/adr/0001-use-adrs-for-architectural-decisions.md`**

```markdown
# 0001. Use ADRs for Architectural Decisions

**Date:** 2026-04-06
**Status:** Accepted
**Deciders:** Platform team

## Context

As the codebase grows, important architectural decisions get made verbally, in Slack, or buried in PR comments. New engineers have no way to understand why the system is structured the way it is, leading to repeated debates and inconsistent patterns across teams.

## Decision

We will use Architecture Decision Records (ADRs) stored in `docs/adr/` to document significant architectural decisions. The format follows the template in `guidelines/adr.md`.

## Alternatives Considered

| Option | Pros | Cons | Reason rejected |
|--------|------|------|-----------------|
| Confluence/Notion wiki | Familiar UI | Decoupled from code, gets stale | Rejected — decisions should live with the code |
| PR descriptions only | No extra tooling | Not searchable, no canonical location | Rejected — too ephemeral |
| RFC process | Thorough | Heavy overhead for small decisions | Rejected — too slow for pace of development |

## Consequences

**Positive:**
- New engineers can understand the reasoning behind system design
- Reduces repeated debates about already-decided topics
- Creates a lightweight audit trail for compliance

**Negative / trade-offs:**
- Requires discipline to write ADRs before implementing
- Small overhead per significant decision

**Risks:**
- ADRs go stale if not updated when decisions are superseded — mitigate by linking superseded ADRs

## Follow-up Actions

- [ ] Add ADR writing to PR template checklist for architectural changes @platform-team
```

- [ ] **Step 3: Commit**

```bash
git add guidelines/adr.md docs/adr/0001-use-adrs-for-architectural-decisions.md
git commit -m "feat: add ADR guidelines and bootstrap first ADR"
```

---

## Task 8: Feature Flags & Safe Deployments (P3)

**Files:**
- Create: `guidelines/feature-flags.md`

- [ ] **Step 1: Create `guidelines/feature-flags.md`**

```markdown
# Feature Flags & Safe Deployments

Deploy code independently of releasing features. This is the single most effective way to reduce deployment risk.

## When to Use a Feature Flag

| Situation | Use flag? |
|-----------|-----------|
| Risky feature going to 100% of users at once | ✅ Yes |
| Feature that needs A/B testing | ✅ Yes |
| Feature touching auth, payments, or DB schema | ✅ Yes |
| Large refactor that can't be done atomically | ✅ Yes |
| Simple bug fix with clear rollback via revert | ❌ No |
| UI copy change | ❌ No |
| Internal tool or admin-only feature | ❌ Optional |

## Flag Types

| Type | Description | Example |
|------|-------------|---------|
| Release flag | Gates a new feature, removed after full rollout | `new-checkout-flow` |
| Experiment flag | A/B test with metrics | `checkout-cta-text-v2` |
| Ops flag | Kill switch for a feature under load | `disable-recommendations` |
| Permission flag | Feature for specific users/plans | `enterprise-sso` |

## Rules

1. **Default OFF** — new flags must default to `false`/disabled
2. **Short-lived** — release flags must be removed within 30 days of full rollout
3. **One owner** — every flag has a named owner responsible for cleanup
4. **Review stale flags** — sprint retro checklist includes "any flags older than 30 days?"
5. **Never nest flags** — `if flagA && flagB` is a maintenance nightmare

## Gradual Rollout Pattern

```
1%  → monitor error rate and latency
10% → monitor for 24h
50% → monitor for 24h
100% → remove flag in next sprint
```

## Tooling Options

| Tool | Self-hosted | Cost | Best for |
|------|-------------|------|----------|
| **Unleash** | ✅ Yes | Free (self-hosted) | Teams wanting control |
| **LaunchDarkly** | ❌ No | Paid | Enterprise, complex targeting |
| **Flagsmith** | ✅ Yes | Free tier | Simpler setups |
| **Env vars** | ✅ Yes | Free | Simple on/off per environment |

For simple on/off per environment, an env var is sufficient:
```python
ENABLE_NEW_CHECKOUT = os.getenv("ENABLE_NEW_CHECKOUT", "false").lower() == "true"
```

## Cleanup Checklist (before removing a flag)

- [ ] Flag is at 100% for all environments
- [ ] No errors or anomalies in the past 7 days at 100%
- [ ] Remove flag from code AND flag management tool
- [ ] Remove any fallback/old code paths
- [ ] PR description links to the original flag creation PR
```

- [ ] **Step 2: Commit**

```bash
git add guidelines/feature-flags.md
git commit -m "feat: add feature flags and safe deployment guidelines"
```

---

## Task 9: Incident Management (P3)

**Files:**
- Create: `guidelines/incidents.md`
- Create: `docs/templates/postmortem.md`
- Create: `docs/templates/runbook.md`

- [ ] **Step 1: Create `guidelines/incidents.md`**

```markdown
# Incident Management

How you respond to incidents defines your team's reliability culture. Clear process reduces MTTR (Mean Time To Recover).

## Severity Levels

| Severity | Definition | Response time | Examples |
|----------|------------|--------------|---------|
| **P0** | Total outage — service is down for all users | Immediate (< 5 min) | Site down, all payments failing, data loss |
| **P1** | Major degradation — core feature broken for many users | < 30 min | Login broken, checkout errors > 5%, API p99 > 10s |
| **P2** | Minor degradation — feature broken for some users | < 4h | Slow search, broken filter, partial API errors |
| **P3** | Cosmetic / low impact | Next business day | UI misalignment, typo, non-critical feature broken |

## Incident Response Process

**1. Detect** — alert fires or user report received
**2. Acknowledge** — on-call acknowledges within SLA
**3. Communicate** — post in incident channel: `🔴 [P0] Checkout service down — investigating`
**4. Investigate** — use runbook if available; check logs, metrics, recent deploys
**5. Mitigate** — restore service (rollback, feature flag off, scale up) — imperfect is fine
**6. Resolve** — confirm service restored; update status page
**7. Post-mortem** — required for P0/P1 within 48h of resolution

## Communication Template

Post in incident channel at each stage:

```
🔴 INCIDENT [P0] - [Short title]
Status: Investigating | Mitigating | Resolved
Impact: [Who is affected and how]
Start time: [HH:MM UTC]
On-call: @person
Next update in: 15 minutes
```

## On-Call Handoff Checklist

When handing off an ongoing incident:
- [ ] Current status and what has been tried
- [ ] All relevant runbooks / docs links
- [ ] Active monitoring dashboards
- [ ] Last known-good deployment SHA
- [ ] Any temporary mitigations in place (feature flags, rate limits)
- [ ] Stakeholders who have been notified

## Post-Mortem Requirements

- Required for: all P0 and P1 incidents
- Due: within 48 hours of resolution
- Format: see `docs/templates/postmortem.md`
- Blameless — focus on systems and processes, not individuals
- Action items must have owners and due dates

## Runbooks

Every critical service path must have a runbook. Store in `docs/runbooks/`.
Format: see `docs/templates/runbook.md`
```

- [ ] **Step 2: Create `docs/templates/postmortem.md`**

```markdown
# Post-Mortem: [Incident Title]

**Date:** YYYY-MM-DD
**Severity:** P0 / P1
**Duration:** X hours Y minutes
**Author:** @person
**Reviewers:** @person1, @person2
**Status:** Draft | In Review | Final

---

## Summary

One paragraph: what happened, who was affected, how it was resolved.

## Timeline

| Time (UTC) | Event |
|------------|-------|
| HH:MM | Alert fired / first user report |
| HH:MM | On-call acknowledged |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Service restored |
| HH:MM | Incident closed |

## Root Cause

What was the underlying cause? Be specific — "the database was slow" is not a root cause. "Query X acquired a table lock due to missing index on column Y, causing connection pool exhaustion under load" is a root cause.

## Contributing Factors

What conditions allowed this to happen or made it worse?

- ...
- ...

## Impact

- Users affected: [number or %]
- Duration: [X hours Y minutes]
- Revenue impact: [if known]
- Data impact: [any data loss or corruption?]

## What Went Well

- ...

## What Went Poorly

- ...

## Action Items

| Action | Owner | Due date | Issue link |
|--------|-------|----------|------------|
| Add index on column Y | @person | YYYY-MM-DD | #123 |
| Add alert for connection pool > 80% | @person | YYYY-MM-DD | #124 |
| Write runbook for DB pool exhaustion | @person | YYYY-MM-DD | #125 |
```

- [ ] **Step 3: Create `docs/templates/runbook.md`**

```markdown
# Runbook: [Service / Feature Name]

**Owner:** @team
**Last updated:** YYYY-MM-DD
**Escalation:** @senior-engineer or #oncall-channel

---

## Overview

What does this service do? Who uses it? What breaks if it's down?

## Monitoring

- Dashboard: [link]
- Alert: [link]
- Logs: [link or query]
- Key metrics to watch: [list]

## Common Failure Modes

### [Failure Mode 1: e.g. High Error Rate]

**Symptoms:** Error rate > 1%, alerts firing on X dashboard

**Investigation steps:**
1. Check logs: `[exact query or command]`
2. Check recent deploys: `[command]`
3. Check downstream dependencies: `[list]`

**Resolution:**
- If caused by bad deploy: `[rollback command]`
- If caused by downstream: `[mitigation step]`

**Escalate if:** Error rate > 5% after mitigation, or data loss suspected

---

### [Failure Mode 2: e.g. Slow Response Times]

...

## Deployment

- Deploy command: `[exact command]`
- Rollback command: `[exact command]`
- Feature flags: `[list with names and effects]`
- Config that affects this service: `[env vars list]`

## Dependencies

| Dependency | Type | Impact if down |
|------------|------|---------------|
| PostgreSQL | Hard | Complete outage |
| Redis | Soft | Degraded (cache miss) |
| Payment service | Hard | Checkout broken |
```

- [ ] **Step 4: Commit**

```bash
git add guidelines/incidents.md docs/templates/postmortem.md docs/templates/runbook.md
git commit -m "feat: add incident management guidelines, post-mortem and runbook templates"
```

---

## Task 10: Accessibility Guidelines (P3 — Frontend Only)

**Files:**
- Create: `guidelines/accessibility.md`

- [ ] **Step 1: Create `guidelines/accessibility.md`**

```markdown
# Accessibility Guidelines

**Standard:** WCAG 2.1 Level AA (minimum). This is also the legal requirement in the EU (EN 301 549), UK (PSBAR), and US (Section 508).

## Core Principles (POUR)

- **Perceivable** — users can perceive all content (alt text, captions, contrast)
- **Operable** — users can operate all UI (keyboard nav, no seizure-triggering content)
- **Understandable** — users can understand content and UI (clear labels, predictable behaviour)
- **Robust** — content works with current and future assistive technologies

## Required Checks Before Every PR

- [ ] All images have descriptive `alt` text (`alt=""` for decorative images)
- [ ] All form inputs have associated `<label>` elements
- [ ] Color is never the only way to convey information
- [ ] Focus order is logical and visible (never `outline: none` without a custom focus style)
- [ ] All interactive elements are keyboard accessible (Tab, Enter, Space, Arrow keys)
- [ ] Page has a single `<h1>`, headings are hierarchical (h1 → h2 → h3)
- [ ] All interactive elements have accessible names (visible label or `aria-label`)

## Color Contrast

| Context | Minimum ratio |
|---------|--------------|
| Normal text (< 18px) | 4.5:1 |
| Large text (≥ 18px or ≥ 14px bold) | 3:1 |
| UI components (borders, icons) | 3:1 |
| Decorative elements | None required |

Check with: [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) or browser DevTools.

## Semantic HTML First

Use the right element before reaching for ARIA. ARIA supplements HTML — it doesn't replace it.

```html
<!-- Bad — div soup with ARIA bolted on -->
<div role="button" tabindex="0" aria-label="Submit" onclick="submit()">Submit</div>

<!-- Good — semantic HTML, accessible by default -->
<button type="submit">Submit</button>
```

Use `<nav>`, `<main>`, `<aside>`, `<header>`, `<footer>`, `<article>`, `<section>` as landmarks.

## ARIA — When to Use

Use ARIA only when HTML semantics are insufficient:

```html
<!-- Indicating loading state -->
<div aria-live="polite" aria-atomic="true">
  <span aria-busy="true">Loading results...</span>
</div>

<!-- Custom combobox (when <select> doesn't meet design requirements) -->
<div role="combobox" aria-expanded="true" aria-haspopup="listbox">...</div>
```

**Never use:** `role="presentation"` on interactive elements, ARIA that conflicts with native semantics.

## Keyboard Navigation

All interactive functionality must be operable by keyboard alone:

- `Tab` / `Shift+Tab` — navigate between focusable elements
- `Enter` / `Space` — activate buttons and links
- `Arrow keys` — navigate within composite widgets (menus, tabs, listboxes)
- `Escape` — close modals, menus, tooltips

Modal dialogs must trap focus within the modal while open and return focus to the trigger on close.

## Testing

**Automated (add to CI):**
- `axe-core` (via `@axe-core/react`, `jest-axe`, or Playwright)
- Catches ~30-40% of WCAG issues automatically

```typescript
// jest-axe example
import { axe, toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);

test('CheckoutForm has no accessibility violations', async () => {
  const { container } = render(<CheckoutForm />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

**Manual (before each release):**
- Keyboard-only navigation of all critical flows
- Screen reader test with VoiceOver (Mac) or NVDA (Windows) on at least one flow
- Zoom to 200% — layout must not break or lose content
```

- [ ] **Step 2: Commit**

```bash
git add guidelines/accessibility.md
git commit -m "feat: add accessibility guidelines (WCAG 2.1 AA, keyboard, ARIA, testing)"
```

---

## Task 11: Wire All Guidelines into CLAUDE.md and detect-languages.sh

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.claude/hooks/detect-languages.sh`

- [ ] **Step 1: Read current CLAUDE.md**

```bash
cat /Users/vivek/personal/code/claude-base-setup/CLAUDE.md
```

- [ ] **Step 2: Add universal guideline imports to CLAUDE.md**

In the `## Universal Guidelines` section (after `@guidelines/base.md`), add imports for all 9 universal guidelines:

```markdown
## Universal Guidelines

@guidelines/base.md
@guidelines/observability.md
@guidelines/database.md
@guidelines/api-design.md
@guidelines/testing.md
@guidelines/branching.md
@guidelines/dependencies.md
@guidelines/adr.md
@guidelines/feature-flags.md
@guidelines/incidents.md
```

- [ ] **Step 3: Add accessibility to the plan mode decision table**

Add this row to the decision table in `## When to Use Plan Mode vs Respond Directly`:

```markdown
| Any UI component or frontend feature | **Plan + Accessibility** | Use `superpowers:writing-plans`; run axe-core check after implementation |
```

- [ ] **Step 4: Add accessibility to the Security Review section's area table**

Add to the Areas table in `## Security Review`:

```markdown
| Frontend UI (forms, inputs) | Login forms, payment forms, any user-facing form |
```

With note: Run `jest-axe` / `axe-core` — accessibility violations in forms are also a security concern (screen reader leaking hidden field values).

- [ ] **Step 5: Read current detect-languages.sh**

```bash
cat /Users/vivek/personal/code/claude-base-setup/.claude/hooks/detect-languages.sh
```

- [ ] **Step 6: Add accessibility guideline injection to detect-languages.sh**

After the existing language detection loop that writes language guides, add an accessibility injection block. After the line `for lang in "${DETECTED[@]}"; do` block ends, before the closing `}` of the output block, add:

```bash
# Accessibility guidelines — inject for frontend languages
for lang in "${DETECTED[@]}"; do
    if [ "$lang" = "typescript" ] || [ "$lang" = "javascript" ]; then
        guide="$GUIDELINES_DIR/accessibility.md"
        if [ -f "$guide" ]; then
            echo "---"
            echo ""
            cat "$guide"
            echo ""
        fi
        break  # Only inject once even if both TS and JS detected
    fi
done
```

- [ ] **Step 7: Run detect-languages tests — all 7 must still pass**

```bash
bash .claude/hooks/test-detect-languages.sh
```

Expected: 7 passed, 0 failed

- [ ] **Step 8: Verify accessibility injects for a TS project**

```bash
TMPDIR=$(mktemp -d)
touch "$TMPDIR/tsconfig.json"
mkdir -p "$TMPDIR/guidelines"
bash .claude/hooks/detect-languages.sh "$TMPDIR"
grep -c "WCAG" "$TMPDIR/guidelines/active.md" && echo "Accessibility injected"
rm -rf "$TMPDIR"
```

Expected: `Accessibility injected`

- [ ] **Step 9: Commit**

```bash
git add CLAUDE.md .claude/hooks/detect-languages.sh
git commit -m "feat: wire all production guidelines into CLAUDE.md and detect-languages hook"
```

---

## Self-Review

**Spec coverage:**
- [x] Observability (logging, metrics, tracing) — Task 1
- [x] Database safety (migrations, N+1, pooling) — Task 2
- [x] API design standards — Task 3
- [x] Testing pyramid (unit/integration/e2e/perf/contract) — Task 4
- [x] Branching & release strategy — Task 5
- [x] Dependency management + license compliance — Task 6
- [x] ADRs with template — Task 7
- [x] Feature flags & safe deployments — Task 8
- [x] Incident management + templates — Task 9
- [x] Accessibility (frontend-only, auto-activated) — Task 10
- [x] All wired into CLAUDE.md and detect-languages.sh — Task 11

**Placeholder scan:** No TBDs or TODOs. All templates have actual content.

**Consistency:** All guidelines use the same format: intro paragraph, rules/tables, code examples where needed, per-language tooling where applicable.
