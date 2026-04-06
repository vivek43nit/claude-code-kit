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

**Symptoms:** p99 latency > 2s, users reporting slow page loads

**Investigation steps:**
1. Check DB query times: `[query or dashboard link]`
2. Check connection pool saturation: `[metric]`
3. Check for recent traffic spike: `[dashboard]`

**Resolution:**
- If DB slow: check for missing index or long-running query, kill if necessary
- If traffic spike: scale horizontally or enable rate limiting

**Escalate if:** Latency > 10s p99 or pool exhaustion confirmed

---

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
