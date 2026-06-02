# ADR-0009: Spec-Driven Development as a Process Requirement

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

The project is built by multiple AI agents working in parallel. Without a forcing function, agents may write untested code that appears to work but breaks under edge cases or when integrated with other agents' output. A formal process is needed to ensure code correctness and integration compatibility.

## Decision

Mandate spec-driven development: specs are written before implementation, verified red, then implementation is written to make them green. No implementation file is considered complete without a passing spec file. This applies to all agents and human developers equally.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Spec-driven development** (chosen) | Specs define correctness before code exists; prevents untested code; integration safety for multi-agent work | Slows initial implementation velocity; can feel bureaucratic for simple changes |
| TDD-optional | Faster initial velocity; flexible approach | No quality guarantee; agents skip testing; integration failures multiply |
| Post-implementation testing | Tests reflect actual implementation; easier to write when code exists | Tests are often skipped; biased toward happy path; missing edge cases |
| No formal requirement | Maximum velocity for solo development | Guaranteed quality degradation as the codebase grows; impossible to verify agent work |

## Consequences

**Positive:**
- Every implementation file has a corresponding spec file at the mirrored path
- The spec file is the authoritative definition of correct behavior — not the brief or the AGENTS.md
- Integration safety: when multiple agents work in parallel, specs act as contracts between components
- Specs serve as living documentation — a new developer can understand behavior by reading specs

**Negative / trade-offs:**
- Slows initial implementation velocity slightly (10–20% overhead)
- Prevents integration failures and regressions significantly
- Requires all agents to understand RSpec conventions
- Some specs may be fragile — changes to implementation details can break passing specs

## References
- https://en.wikipedia.org/wiki/Test-driven_development
- AGENTS.md §19 (Spec-Driven Development)
