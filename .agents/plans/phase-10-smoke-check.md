# Plan: Phase 10 — Smoke Test & Integration Check

## 1. Goal

End-to-end verification that all phases integrated correctly into a working,
secure application. No new code is written. This phase consists of running
verification commands, walking through manual smoke test checklists,
validating security constraints, updating `README.md`, and documenting any
remaining follow-ups. Phase 10 ends with the application declared
complete per the master plan's completion criteria.

## 2. Files affected

### [MODIFY]

- `README.md` — replace the scaffold Rails README with project-specific
  documentation covering:
  - Project description
  - Local setup (Ruby, PostgreSQL, Redis, pgvector)
  - Environment variables required
  - How to run the app (`rails server`, `sidekiq`)
  - How to run tests (`bundle exec rspec`)
  - How to run RuboCop (`bundle exec rubocop`)
  - How to manage credentials (`rails credentials:edit`)
  - Deployment notes (if applicable)

- `tmp/pending_specs.md` — update with final status of any outstanding
  items. Mark completed items as done, note any deferred items for future
  work.

### [NO CHANGES]

- All application code (`app/`, `config/`, `db/`, `spec/`, etc.)
- `.rubocop.yml`, `.github/workflows/ci.yml`
- `Gemfile`, `Gemfile.lock`

## 3. Spec files to run (no new specs)

All existing specs are executed. No new specs are written in Phase 10.

## 4. Database changes

**None.** Phase 10 verifies the existing schema is fully migrated.

## 5. External side effects

- **Manual smoke test** requires a running `rails server` and `sidekiq`
  process.
- **Real OpenAI API calls** are made during the manual smoke test (if the
  app is configured with a valid API key). The assistant conversation test
  step will consume API credits.
- No CI runs, no deployments.

## 6. Risks and open questions

### R1 — Real OpenAI API key required for smoke test

Steps 4-5 of the smoke test checklist involve asking questions and
receiving assistant responses. Without a valid `OPENAI_API_KEY` in
credentials, these steps will fail. **Decision:** the smoke test is
conditional on having the key configured. If the key is not available,
skip the assistant-response steps and verify only the UI/navigation flow.

### R2 — Sidekiq must be running for ingestion smoke test

STEP 3 of the checklist (uploading a document) enqueues
`Documents::IngestJob`. Without Sidekiq running, the document will remain
in "Processing" status. **Decision:** start Sidekiq in a separate terminal.
If Sidekiq is not available, verify only that the document upload form
works and the record is created with `status: :pending`.

### R3 — `README.md` scope

The `README.md` should be concise (not a full operations manual). Cover:
- What the app does (1 paragraph).
- Prerequisites (Ruby 3.3+, PostgreSQL with pgvector, Redis).
- Setup steps (clone, `bundle install`, `rails db:create db:migrate`,
  `rails credentials:edit` for OpenAI key).
- Running the app (`rails server` + `bundle exec sidekiq`).
- Running tests (`bundle exec rspec`).
- Running RuboCop (`bundle exec rubocop`).

**Do not** include: architecture diagrams, API documentation, changelogs,
or detailed development guidelines (those belong in `AGENTS.md`).

## 7. Execution order

### Step 0 — Full test suite (gate 1)

- **0.1** `bundle exec rspec --format documentation` — all examples must
  pass. No pending specs except those explicitly documented in
  `tmp/pending_specs.md`.
- **0.2** If any failure occurs, investigate and fix. If the fix requires
  code changes, follow the same SDD flow (plan → spec → implement).
- **0.3** Confirm SimpleCov reports ≥80% coverage.

### Step 1 — RuboCop full scan (gate 2)

- **1.1** `bundle exec rubocop` — zero offenses.
- **1.2** If offenses are found, fix them (autocorrect or manual).
- **1.3** Re-run specs after any rubocop fix to ensure nothing broke.

### Step 2 — Database integrity check (gate 3)

- **2.1** `rails db:migrate:status` — all migrations show `up`.
- **2.2** If any show `down`, run `rails db:migrate` to bring them up.
- **2.3** Run `rails db:test:prepare` to sync the test database schema.

### Step 3 — Manual smoke test (gate 4)

Follow the PROMPT.md §10.4 checklist:

- **3.1** Start the server: `bundle exec rails server`
- **3.2** Start Sidekiq: `bundle exec sidekiq` (in a separate terminal)
- **3.3** Complete the walkthrough:

  | # | Step | Expected result | Check |
  |---|------|-----------------|-------|
  | 1 | Sign in as an employee user | Dashboard/conversations index renders | [ ] |
  | 2 | Start a new conversation | New conversation created, redirected to show page | [ ] |
  | 3 | Ask: "What documents do I need for a payroll certificate?" | User message appears immediately, loading indicator shows, assistant responds | [ ] |
  | 4 | Ask: "What is the status of my certificate request?" | Assistant reports actual status from database (or says none found) | [ ] |
  | 5 | Sign out, sign in as admin user | Admin navbar shows Admin link | [ ] |
  | 6 | Navigate to Documents | Document list page renders | [ ] |
  | 7 | Upload a PDF document | Document appears with "Processing" status | [ ] |
  | 8 | Wait for Sidekiq to process it | Status changes to "Ready" | [ ] |
  | 9 | Return to conversation and ask a question the document answers | Assistant cites the document by name | [ ] |

### Step 4 — Security checklist (gate 5)

Execute the PROMPT.md §10.5 checklist:

  | # | Check | Verification | Pass |
  |---|-------|--------------|------|
  | 1 | Employee cannot access `/admin/*` routes | Access `/admin/` as employee → 302 redirect with error flash | [ ] |
  | 2 | Employee cannot view another user's conversation | Access `/conversations/:id` of another user → 302 redirect with error flash | [ ] |
  | 3 | Unauthenticated request redirects | Access `/conversations` while logged out → redirect to sign-in | [ ] |
  | 4 | `.exe` upload rejected | Upload file with `.exe` extension → validation error | [ ] |
  | 5 | 25MB upload rejected | Upload 25MB+ file → validation error | [ ] |

For checklist items 4-5, verify via the existing request spec or a
one-off manual test in the browser.

### Step 5 — README.md update (gate 6)

- **5.1** Replace the scaffold `README.md` with project-specific content
  per R3.
- **5.2** Include a `## Prerequisites` section listing required system
  dependencies.
- **5.3** Include `## Setup` section with step-by-step instructions.
- **5.4** Include `## Running the app` section.
- **5.5** Include `## Running tests` section.
- **5.6** Include `## Code quality` section referencing RuboCop.

### Step 6 — Update `tmp/pending_specs.md`

- **6.1** Review all open items in `tmp/pending_specs.md`.
- **6.2** Mark completed items as done.
- **6.3** Add any new items discovered during the smoke test.
- **6.4** If Devise `:lockable` / `:timeoutable` migration is still
  pending (from Phase 2 R8), confirm it is documented and note the
  decision not to block completion.

### Step 7 — Final verification (all 6 completion criteria)

Per the master plan §11, verify all 6 criteria are met:

1. [ ] `bundle exec rspec` passes with ≥80% coverage and zero failures.
2. [ ] `bundle exec rubocop` exits 0.
3. [ ] Manual smoke test checklist (Step 3) is 100% complete.
4. [ ] Security checklist (Step 4) is 100% complete.
5. [ ] `AGENTS.md` is present at the repository root.
6. [ ] `README.md` documents local setup, env vars, tests, and Sidekiq.

## 8. Definition of done (master plan §11 completion criteria)

- [ ] **C1:** `bundle exec rspec` → ≥80% coverage, 0 failures, 0 pending
  (except documented).
- [ ] **C2:** `bundle exec rubocop` → 0 offenses.
- [ ] **C3:** Migration status → all `up`.
- [ ] **C4:** Smoke test checklist → 100% checked.
- [ ] **C5:** Security checklist → 100% checked.
- [ ] **C6:** `README.md` → includes local setup, env vars, tests, Sidekiq.
- [ ] **C7:** `AGENTS.md` → present at root (should already exist).
- [ ] **C8:** `tmp/pending_specs.md` → updated with final status.

## 9. Sub-agent delegation plan

This phase is primarily verification, not implementation. The main agent
should execute Steps 0-2 directly (running commands). Step 3 (manual
smoke test) is inherently interactive — the developer or main agent
follows the checklist. Step 5 (README) is a writing task that a sub-agent
can handle.

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent** | Run `bundle exec rspec`, fix failures | Full repo | Suite green, ≥80% coverage |
| 1 | **Main agent** | Run `bundle exec rubocop`, fix offenses | Full repo | 0 offenses |
| 2 | **Main agent** | Run `rails db:migrate:status` | `config/database.yml` | All `up` |
| 3 | **Main agent** | Follow smoke + security checklists, document results | Full app running | All checkboxes filled |
| 4 | **Sub-agent: README** | Replace scaffold README with project docs | `AGENTS.md`, `PROMPT.md` §10, R3 | `README.md` complete and reviewed |
| 5 | **Main agent** | Update `tmp/pending_specs.md`, final verification | Full repo | All 6 completion criteria met |

## 10. Out of scope (explicitly NOT in Phase 10)

- Adding new features or fixing non-blocking bugs (create follow-up
  issues/tickets instead).
- System specs / Capybara browser tests (added later if needed).
- Performance or load testing.
- Security audit beyond the 5-point checklist.
- Production deployment configuration (Heroku, Fly.io, Docker, etc.).
- Adding Devise `:lockable` / `:timeoutable` (deferred — documented only).
- I18n locale extraction beyond hardcoded Spanish strings.
