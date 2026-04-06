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
| Confluence/Notion wiki | Familiar UI | Decoupled from code, gets stale | Decisions should live with the code |
| PR descriptions only | No extra tooling | Not searchable, no canonical location | Too ephemeral |
| RFC process | Thorough | Heavy overhead for small decisions | Too slow for pace of development |

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
