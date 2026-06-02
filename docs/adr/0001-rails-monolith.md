# ADR-0001: Rails Monolith Architecture

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

Papelin is an internal HR tool for a single company. The team needs to move fast, the user base is bounded (hundreds of employees, not millions), and operational complexity should be minimal. A single developer should be able to understand the entire system.

## Decision

Build as a Rails 7.2 monolith — single process, single codebase, single deployment unit. No microservices, no separate API server, no frontend SPA.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Rails monolith** (chosen) | Single deployment, no inter-service calls, full-stack Rails conventions, one team owns everything | Vertical scaling limit; cannot scale frontend and API independently |
| Rails API + React SPA | Frontend and backend scale independently; better UX for complex interactions | Two codebases, two deployment pipelines, CORS complexity, JS framework overhead |
| Microservices (Rails API + auth service + ingestion service) | Independent scaling; fault isolation; team ownership boundaries | Distributed tracing, eventual consistency, network latency, operational complexity far beyond requirements |
| Next.js + Rails API | Modern frontend tooling; SSR out of the box | Duplicate auth logic, two rendering pipelines, added build complexity for an internal tool |

## Consequences

**Positive:**
- Deployment is a single `git push` to a single server
- No inter-service network calls, no distributed tracing needed
- Entire codebase understandable by one developer
- Full benefit of Rails conventions (convention over configuration)

**Negative / trade-offs:**
- Scaling requires vertical scale or multiple dynos of the same app — acceptable for internal tooling
- All features share the same database connection pool and background job queue
- Cannot independently scale the chat streaming infrastructure without scaling the whole app

## References
- https://m.signalvnoise.com/the-majestic-monolith/
- https://basecamp.com/gettingreal
