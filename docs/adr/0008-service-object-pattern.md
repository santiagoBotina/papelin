# ADR-0008: Service Object Pattern for Business Logic

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

Rails controllers and models can accumulate logic over time, making the codebase harder to test and understand. The RAG pipeline and document ingestion are multi-step operations that do not naturally belong to any single model. The codebase needs a consistent pattern for encapsulating business logic.

## Decision

Implement a service layer in `app/services/`. Every service inherits from `ApplicationService`, has a `.call` class method, takes keyword arguments, and returns a `Result` struct with `success?`, domain-specific data fields, and `error`. Services are organized by domain namespace (`Rag::`, `Documents::`).

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Service objects** (chosen) | Plain Ruby — easy to test in isolation; explicit Result pattern; RAII-like initialization with keyword arguments | Adds a file per operation; requires discipline to keep services focused |
| Interactors gem | Standardized lifecycle (`organized`, `around`); built-in error handling | Adds a gem dependency; more ceremony than needed; less flexible than plain services |
| dry-transaction | Functional composition; step adapters; clear error handling | Adds dry-rb dependency; learning curve for the functional style; overkill for this project's complexity |
| Concerns in models | Simple; Rails-native; no new folder | Concerns tend to grow into god-objects; hard to test in isolation; no clear boundary for multi-model operations |
| Controller methods | Fastest to write | Untestable in isolation; violates the thin-controller principle; logic scattered across actions |

## Consequences

**Positive:**
- Services are plain Ruby objects — no Rails magic, easy to unit test
- The `Result` struct pattern makes caller code explicit: `if result.success?`
- Nested namespaces (`Rag::`, `Documents::`) keep the service directory organized as it grows
- Services do not render, redirect, or call `render` — they are HTTP-agnostic
- `ApplicationService` provides a shared convention while allowing subclasses to define their own `Result` structs

**Negative / trade-offs:**
- The pattern adds a file per operation — this is intentional, not overhead
- Requires discipline to prevent services from growing too large
- No built-in orchestration pipeline (no `organized` like the interactors gem) — sequential steps are called explicitly in the service
- Services that coordinate other services (like `Rag::QueryService`) can become moderately complex

## References
- https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial
- https://github.com/serradura/service_objects_pattern
