# ADR-0005: Sidekiq + Redis for Background Jobs

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

Document ingestion (text extraction → chunking → embedding) is too slow for the HTTP request/response cycle. Each OpenAI embedding call adds ~100ms; a 50-chunk document would block the web process for 5+ seconds. Additionally, the RAG query pipeline should not block the web process during OpenAI API calls.

## Decision

Use Sidekiq 7 with Redis as the background job adapter for ActiveJob. Two queues: `:default` (user-facing query jobs, normal priority) and `:ingestion` (document processing, low priority).

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Sidekiq + Redis** (chosen) | Battle-tested at scale; mature ecosystem; process-based concurrency (thread-safe); Web UI for monitoring | Redis is a new infrastructure dependency; at-least-once delivery (jobs can run twice) |
| GoodJob | PostgreSQL-backed — no Redis dependency; async jobs via advisory locks; built-in dashboard | Less battle-tested at scale; advisory locks add DB overhead; fewer community resources |
| Delayed::Job | Simple; PostgreSQL-backed; no extra dependencies | Polling-based (DB overhead); poor at scale; outdated ecosystem |
| Que | PostgreSQL-backed; job locking via Skip Locks; fast | Maturity concerns; smaller community; Mac M1 compatibility issues at evaluation time |
| SolidQueue (Rails 8) | Rails-native; PostgreSQL-backed; no Redis | Not available in Rails 7.2; would require Rails 8 upgrade; not yet battle-tested |

## Consequences

**Positive:**
- Sidekiq provides two queues: `:ingestion` (low priority) and `:default` (user-facing)
- Redis is a well-understood infrastructure component
- Sidekiq Web UI (`/sidekiq`) provides real-time monitoring of queue depth, retries, and failures
- `sidekiq-cron` enables scheduled jobs (e.g., periodic re-indexing of pgvector)

**Negative / trade-offs:**
- Redis is a new infrastructure dependency (PostgreSQL alone is not sufficient)
- GoodJob would have eliminated the Redis dependency but is less battle-tested at scale
- Jobs must be idempotent — Sidekiq's at-least-once delivery can trigger retries, so status guards are required
- Redis memory must be monitored — a backlog of failed jobs can fill Redis memory
- Redis is an additional service to back up and monitor in production

## References
- https://github.com/sidekiq/sidekiq
- https://github.com/bensheldon/good_job
- https://guides.rubyonrails.org/active_job_basics.html
