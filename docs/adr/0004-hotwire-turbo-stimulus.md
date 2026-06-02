# ADR-0004: Hotwire (Turbo + Stimulus) for Frontend

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

The chat UI requires real-time token streaming and dynamic updates without a full page reload. The team wants to avoid maintaining a separate frontend codebase. The choice of frontend technology affects development velocity, deployment complexity, and the team's ability to iterate quickly.

## Decision

Use Hotwire (Turbo + Stimulus) exclusively via `turbo-rails` and `stimulus-rails` gems. No React, Vue, or SPA framework. JavaScript is managed via Importmap (Rails 7 default).

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Hotwire (Turbo + Stimulus)** (chosen) | No separate frontend build pipeline; server-rendered HTML; native Rails 7 integration; Turbo Streams handle real-time updates | Limited interactivity for complex UI components; requires a server round-trip for most updates |
| React + Rails API | Rich interactive components; large ecosystem; familiar to many developers | Two codebases, two deployment pipelines; CORS complexity; build tooling overhead (Webpack/esbuild) |
| Vue + Rails API | Similar to React but lighter learning curve | Same dual-codebase drawbacks; Vue ecosystem churn |
| LiveView (Phoenix) | True real-time without client JS | Not available in Rails; would require rewriting the entire app in Elixir/Phoenix |
| Plain ERB with jQuery | No framework overhead | jQuery is legacy; poor developer experience for real-time features |

## Consequences

**Positive:**
- No separate frontend build pipeline — asset pipeline stays simple with Importmap
- Turbo Streams handle streaming token delivery via ActionCable
- Stimulus controllers are intentionally thin — UI behavior only, no business logic
- Server-rendered HTML means SEO works out of the box (not critical for internal app but eliminates surprises)
- Single deployment unit — one `git push` deploys everything

**Negative / trade-offs:**
- Adding a rich interactive component (drag-and-drop file tree, charts) would require either a Stimulus controller or a web component
- Full-page Turbo Drive navigation can cause edge cases with third-party scripts or complex form state
- Real-time features depend on ActionCable (Redis-backed), adding one more moving part
- Developer pool is smaller for Hotwire than React, though Rails developers can learn it quickly

## References
- https://hotwired.dev/
- https://turbo.hotwired.dev/
- https://stimulus.hotwired.dev/
- https://github.com/hotwired/turbo-rails
