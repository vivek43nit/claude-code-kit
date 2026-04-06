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
