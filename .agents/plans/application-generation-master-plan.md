## Plan: Generate Certificate Assistant Rails Monolith

### 1. Goal
Build a production-quality Rails 7.2 monolith in this repository that implements the Certificate Assistant end-to-end (auth, RAG, ingestion, jobs, policies, UI, tests, CI), following `AGENTS.md` and `PROMPT.md` strictly.

### 2. Agreed constraints
- Development artifacts in English (code/specs/technical docs).
- End-user app content in Spanish (UI text, assistant prompt/persona, user-facing messages).
- Generate the Rails app directly in the current repo root.

### 3. Phase order (must not change)
1. Phase 0 - Project bootstrap & configuration
2. Phase 1 - Database schema & migrations
3. Phase 2 - Domain models & specs
4. Phase 3 - Pundit policies & specs
5. Phase 4 - Service layer: Documents pipeline
6. Phase 5 - Service layer: RAG pipeline
7. Phase 6 - Background jobs & specs
8. Phase 7 - Controllers, routes & request specs
9. Phase 8 - Views & Stimulus frontend
10. Phase 9 - Test infrastructure hardening
11. Phase 10 - Smoke test & integration check

### 4. Files affected
- [CREATE] Rails app structure in repository root.
- [CREATE] `tmp/plans/phase-0-bootstrap.md` through `tmp/plans/phase-10-smoke-check.md`.
- [MODIFY] Generated config/framework files per prompt requirements.
- [CREATE/MODIFY] migrations, models, services, jobs, policies, controllers, views, JS controllers, specs, factories.
- [CREATE] `.rubocop.yml`
- [CREATE] `.github/workflows/ci.yml`
- [MODIFY/CREATE] `README.md` with setup/run/test/Sidekiq instructions.

### 5. Spec-first contract
For every new class/module:
1. Write spec first.
2. Verify red.
3. Implement minimal code.
4. Verify green.
5. Run RuboCop on changed files.
No implementation is complete without passing specs.

### 6. Database changes planned
- Enable `vector` extension.
- Devise user migration updates: `first_name`, `last_name`, `role`, `employee_id` + unique index.
- Create: `conversations`, `messages`, `documents`, `document_chunks`, `certificate_requests`.
- Include required ActionText and ActiveStorage migrations.
- Validate reversibility and schema consistency.

### 7. External side effects to implement
- OpenAI calls via service layer only (`Rag::EmbedService`, `Rag::GenerationService`).
- Sidekiq queues: `default` and `ingestion`.
- ActiveStorage attachments for documents/certificates.
- Redis-backed Rack::Attack throttle for messages.
- Turbo Stream broadcasting for assistant output.

### 8. Language implementation rule
- Technical/internal layer in English.
- User-facing content in Spanish:
  - system prompt persona and fallback phrase
  - flash/validation/user guidance text
  - UI labels/actions/help text

### 9. Risks and controls
- Risk: prompt language mismatch, controlled by explicit bilingual split above.
- Risk: secret leakage, credentials placeholders only and no real keys in repo.
- Risk: phase scope drift, after each phase run scoped checks + file scope diff.
- Risk: accidental real API calls in tests, WebMock blocking + OpenAI helper stubs.

### 10. Per-phase quality gates
For each phase:
- Required scoped specs pass.
- Required scoped RuboCop passes.
- `git diff --name-only` matches planned scope.
- No unauthorized architectural deviations from `AGENTS.md`/`PROMPT.md`.

### 11. Completion criteria
- `bundle exec rspec` passes with required coverage threshold.
- `bundle exec rubocop` passes with zero offenses.
- Migration status fully `up`.
- Smoke test checklist complete.
- Security checklist complete.
- `README.md` includes local setup, env vars, tests, and Sidekiq.
