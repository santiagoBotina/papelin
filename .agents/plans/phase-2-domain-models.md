# Plan: Phase 2 — Domain Models & Specs

## 1. Goal

All ActiveRecord models for the Certificate Assistant domain exist with full
validations, associations, enums, scopes, instance methods, and ActiveStorage
attachments. Every model has a passing spec file written **before** its
implementation (SDD per AGENTS.md §19). All factories exist and produce valid
records. Phase 2 ends with `bundle exec rspec spec/models/` and
`bundle exec rubocop app/models/ spec/models/ spec/factories/` both green.

No controllers, no policies, no services, no jobs — strictly the model layer.

## 2. Files affected

### [CREATE]

- `spec/support/shoulda_matchers.rb` (configure shoulda-matchers)
- `spec/models/conversation_spec.rb`
- `spec/models/message_spec.rb`
- `spec/models/document_spec.rb`
- `spec/models/document_chunk_spec.rb`
- `spec/models/certificate_request_spec.rb`
- `spec/factories/conversations.rb`
- `spec/factories/messages.rb`
- `spec/factories/documents.rb`
- `spec/factories/document_chunks.rb`
- `spec/factories/certificate_requests.rb`
- `app/models/conversation.rb`
- `app/models/message.rb`
- `app/models/document.rb`
- `app/models/document_chunk.rb`
- `app/models/certificate_request.rb`

### [MODIFY / REPLACE]

- `app/models/user.rb` (replace Devise-only scaffold with full Phase 2
  implementation: enums, associations, validations, instance methods)
- `spec/models/user_spec.rb` (replace `pending` placeholder with full spec)
- `spec/factories/users.rb` (replace empty factory with full Phase 2 factory)
- `spec/rails_helper.rb` (minimal additions: `require 'shoulda/matchers'`,
  `config.include FactoryBot::Syntax::Methods`,
  `config.infer_spec_type_from_file_location!`, load `spec/support/**/*.rb`)

### [NO CHANGES]

- `db/migrate/**/*` (Phase 1 is complete)
- `db/schema.rb`
- `Gemfile` / `Gemfile.lock` (all gems already present: `shoulda-matchers`,
  `factory_bot_rails`, `faker`, `active_storage_validations`, `neighbor`)
- `app/models/application_record.rb`
- `config/initializers/devise.rb`
- Any controller, view, policy, service, or job

## 3. Spec files to write first (SDD red-step list)

| # | Spec file | Drives implementation of |
|---|-----------|--------------------------|
| 1 | `spec/models/user_spec.rb` | `app/models/user.rb` |
| 2 | `spec/models/conversation_spec.rb` | `app/models/conversation.rb` |
| 3 | `spec/models/message_spec.rb` | `app/models/message.rb` |
| 4 | `spec/models/document_spec.rb` | `app/models/document.rb` |
| 5 | `spec/models/document_chunk_spec.rb` | `app/models/document_chunk.rb` |
| 6 | `spec/models/certificate_request_spec.rb` | `app/models/certificate_request.rb` |

Each spec covers: associations, validations, enums, scopes, every public
instance method, and edge cases per PROMPT.md §2.1–§2.6.

## 4. Database changes

**None.** Phase 1 completed all schema work. Models map onto the existing
tables in `db/schema.rb`. Any mismatch discovered during this phase indicates a
Phase 1 bug — stop and escalate, do not patch via migration in Phase 2.

## 5. External side effects

- **None at runtime.** No OpenAI calls, no jobs enqueued, no emails sent.
- ActiveStorage attachments are *declared*
  (`has_one_attached :file`, `has_one_attached :generated_file`) but no files
  are actually uploaded in this phase.
- No new gems installed.

## 6. Risks and open questions

### R1 — `belongs_to` implicit presence

Rails 5+ adds an implicit presence validation on `belongs_to`. The PROMPT.md
specs use `is_expected.to validate_presence_of(:user)` etc. shoulda-matchers
7.x supports this. **Mitigation:** verify by running spec after
`require 'shoulda/matchers'` wiring is added.

### R2 — Enum keyword syntax (Rails 7.2)

Rails 7.2 supports both positional (`enum role: { ... }`) and keyword
(`enum :role, { ... }`) enum syntax. PROMPT.md uses positional.
**Mitigation:** match PROMPT.md exactly (positional), confirm no rubocop
`Rails/EnumHash` cop violation; if cop fires, switch to keyword form across
all six enum declarations consistently.

### R3 — `Conversation` `has_many :messages` ordering scope

PROMPT.md uses
`has_many :messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :conversation`.
The spec says
`it { is_expected.to have_many(:messages).dependent(:destroy).order(:created_at) }`.
The `.order(:created_at)` matcher requires shoulda-matchers' association
matcher with `.order` — supported in 7.x. **Mitigation:** confirm matcher
behavior; if not supported in 7.x, drop the chained `.order` assertion and add
a separate `describe "message ordering"` that creates two messages and asserts
`conversation.messages.first` is the older one.

### R4 — `Message#append_content!` raw SQL safety

The method uses `update_all("content = content || #{quote(token)}")`. The
`quote` call protects against SQL injection. **Mitigation:** the spec already
covers correctness; no additional sanitization needed.

### R5 — `CertificateRequest.generate_reference` counter collisions

The counter
`where("created_at >= ?", Date.current.beginning_of_year).count + 1` resets per
test transaction, so two specs creating records via the model callback (not
via factory's `sequence`) would both produce `CR-YYYY-00001` and the second
`INSERT` would violate the unique index. **Mitigation:** the factory **always**
sets `reference_number` explicitly via `sequence`, so the callback's `||=`
no-op fires. The only model-driven generation happens in the dedicated
`.generate_reference` describe block, which calls the class method in
isolation. Document this in the spec with a comment explaining why we don't
`create` two records back-to-back without the factory.

### R6 — `business_days` not available

**Resolved.** Per user direction, use `5.days.from_now` in the
certificate_requests factory instead of `5.business_days.from_now`. Document
the deviation as a comment in the factory.

### R7 — `User#active_certificate_requests` requires factory

The user spec uses `create(:certificate_request, ...)`. The
certificate_requests factory must therefore exist before the user spec can run
green. **Mitigation:** create all factories in step 6.1 *before* running specs
in step 7.2.

### R8 — Devise `:lockable` and `:timeoutable` columns

PROMPT.md User model declares `:lockable` and `:timeoutable`. Schema
(`db/schema.rb` line 127-142) does **not** include `failed_attempts`,
`unlock_token`, or `locked_at` columns. Devise will raise on boot if
`:lockable` is declared without those columns. **Mitigation:** for Phase 2,
only declare the Devise modules that match the current schema:
`:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`.
Lockable/timeoutable migration is added in Phase 11 (security hardening) or
as an addendum — flag in the plan but **do not** add now to keep Phase 2
schema-clean. Mention this as a known follow-up in `tmp/pending_specs.md`.

### R9 — Scope `.recent` collision

Several models define `scope :recent, -> { order(created_at: :desc) }`.
Pure scope per-model — no collision. Confirmed safe.

## 7. Spec-first contract (SDD per AGENTS.md §19)

For each of the six models, follow this strict cycle. **No implementation code
is written before the spec is red.**

```
1. UNDERSTAND  Read PROMPT.md §2.x for the model.
2. SPECIFY     Write the spec file verbatim from PROMPT.md (with R-flagged
               adjustments documented inline as comments).
3. RED         bundle exec rspec spec/models/<file>_spec.rb
               → every example must fail (NameError, NoMethodError, or
                 assertion failure).
4. IMPLEMENT   Write app/models/<file>.rb following PROMPT.md §2.x verbatim
               (with R-flagged adjustments).
5. GREEN       bundle exec rspec spec/models/<file>_spec.rb → all green.
6. REFACTOR    Clean up duplication. Re-run spec to confirm still green.
7. LINT        bundle exec rubocop app/models/<file>.rb
                              spec/models/<file>_spec.rb
               → zero offenses.
```

## 8. Execution order

### Step 0 — Test infrastructure prerequisites (one-time, before any model work)

- **0.1** Create `spec/support/shoulda_matchers.rb` with the standard
  `Shoulda::Matchers.configure` block (`with.test_framework :rspec`,
  `with.library :rails`).
- **0.2** Modify `spec/rails_helper.rb` to add:
  - `require 'shoulda/matchers'`
  - `Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }`
    (replaces the commented-out line)
  - Inside `RSpec.configure`: `config.include FactoryBot::Syntax::Methods` and
    `config.infer_spec_type_from_file_location!`
- **0.3** Run `bundle exec rspec spec/models/user_spec.rb` — expect 1 pending
  example, 0 failures. This confirms wiring is correct.

### Step 1 — User model (replace scaffold)

- **1.1** Replace `spec/models/user_spec.rb` with PROMPT.md §2.1 spec (will
  reference `:certificate_request` factory — defer green-step until factory
  exists).
- **1.2** Replace `spec/factories/users.rb` with PROMPT.md §2.7 factory.
- **1.3** Defer red-step verification until step 6 (CertificateRequest factory
  exists). For now, run only the validation/enum/association/`#display_name`
  examples by tagging or filtering.
  - **Alternative (cleaner):** Implement steps 1.1–1.2 → step 6
    (CertificateRequest) → then close the loop by running the full user spec.
- **1.4** Replace `app/models/user.rb` with PROMPT.md §2.1 implementation.
  **Apply R8 adjustment:** keep current Devise modules only
  (`:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`).
- **1.5** Lint:
  `bundle exec rubocop app/models/user.rb spec/models/user_spec.rb spec/factories/users.rb`.

### Step 2 — Conversation model

- **2.1** Create `spec/models/conversation_spec.rb` per PROMPT.md §2.2. Apply
  R3 adjustment if needed.
- **2.2** Create `spec/factories/conversations.rb` per PROMPT.md §2.7.
- **2.3** Red-step: `bundle exec rspec spec/models/conversation_spec.rb` — must
  fail with `NameError: uninitialized constant Conversation`.
- **2.4** Create `app/models/conversation.rb` per PROMPT.md §2.2.
- **2.5** Green-step: same rspec command → all green.
- **2.6** Lint scope.

### Step 3 — Message model

- **3.1** Create `spec/models/message_spec.rb` per PROMPT.md §2.3.
- **3.2** Create `spec/factories/messages.rb` per PROMPT.md §2.7.
- **3.3** Red → implement `app/models/message.rb` per PROMPT.md §2.3 → green
  → lint.
  - Verify `Message#append_content!` updates content via direct SQL and that
    the spec passes.
  - Verify `belongs_to :conversation, touch: true` — the spec doesn't assert
    `touch`, but PROMPT.md specifies it. Keep it.

### Step 4 — Document model

- **4.1** Create `spec/models/document_spec.rb` per PROMPT.md §2.4.
- **4.2** Create `spec/factories/documents.rb` per PROMPT.md §2.7.
- **4.3** Red → implement `app/models/document.rb` per PROMPT.md §2.4
  (includes `has_one_attached :file` + `active_storage_validations`).
  - Confirm the conditional validation `if: -> { file.attached? }` doesn't
    fire in factory-created records (which don't attach a file by default).
- **4.4** Green → lint.

### Step 5 — DocumentChunk model

- **5.1** Create `spec/models/document_chunk_spec.rb` per PROMPT.md §2.5.
- **5.2** Create `spec/factories/document_chunks.rb` per PROMPT.md §2.7. Note:
  factory must produce a 1536-element embedding array.
- **5.3** Red → implement `app/models/document_chunk.rb` per PROMPT.md §2.5
  (declares `has_neighbors :embedding` via `neighbor` gem).
- **5.4** Green → lint.

### Step 6 — CertificateRequest model

- **6.1** Create `spec/models/certificate_request_spec.rb` per PROMPT.md §2.6.
- **6.2** Create `spec/factories/certificate_requests.rb` per PROMPT.md §2.7.
  **Apply R6:** substitute `5.business_days.from_now` → `5.days.from_now`
  with a comment explaining the substitution.
- **6.3** Red → implement `app/models/certificate_request.rb` per
  PROMPT.md §2.6.
- **6.4** Green → lint.

### Step 7 — Close the loop on User spec

- **7.1** With CertificateRequest now present, run the full
  `spec/models/user_spec.rb` (including `#active_certificate_requests`
  example) → must be green.

### Step 8 — Phase 2 verification gates (all must pass before declaring phase complete)

- **8.1** `bundle exec rspec spec/models/` → all green, no pending, no
  skipped.
- **8.2**
  `bundle exec rubocop app/models/ spec/models/ spec/factories/ spec/support/shoulda_matchers.rb spec/rails_helper.rb`
  → 0 offenses.
- **8.3** `git diff --name-only` matches the [CREATE] + [MODIFY] list in §2.
  No surprises.
- **8.4** Manual smoke: in `rails console`, run:
  ```ruby
  u = User.create!(email: "smoke@test.com", password: "Password1!", employee_id: "EMP00001", first_name: "S", last_name: "T")
  c = u.conversations.create!(title: "Smoke test")
  c.messages.create!(role: :user, content: "hello")
  ```
  → must succeed without raising. (Optional — fast confidence check, not a
  gate.)
- **8.5** Confirm `bundle exec rspec` (full suite) still shows 0 failures.

### Step 9 — Document follow-ups

- **9.1** Create or append `tmp/pending_specs.md` with two items:
  - "Add Devise `:lockable` migration (failed_attempts, locked_at,
    unlock_token) and re-enable in `User`. Scheduled for Phase 11."
  - "Add Devise `:timeoutable` (no schema change required, only
    `config.timeout_in`). Scheduled for Phase 11."
- **9.2** (Optional) Update `tmp/plans/` index or notes if such a convention
  exists. Not required.

## 9. Definition of done

- [ ] All six model spec files exist and pass.
- [ ] All six factory files exist and produce valid records (verified by
      their use in the specs).
- [ ] All six model files exist and follow PROMPT.md §2.1–§2.6 (with
      documented R-flagged deviations only).
- [ ] `spec/rails_helper.rb` minimally wired for shoulda-matchers +
      FactoryBot.
- [ ] `spec/support/shoulda_matchers.rb` configures shoulda-matchers.
- [ ] `bundle exec rspec spec/models/` → 0 failures, 0 pending, 0 errors.
- [ ] `bundle exec rubocop app/models/ spec/models/ spec/factories/
      spec/support/ spec/rails_helper.rb` → 0 offenses.
- [ ] `git diff --name-only` matches the scope in §2.
- [ ] `tmp/pending_specs.md` records the Devise lockable/timeoutable
      follow-up.

## 10. Sub-agent delegation plan (per AGENTS.md §18)

The main agent will not write model code itself. It will dispatch the
following sub-agents in strict order. The Step 0 work (rails_helper +
shoulda_matchers support file) is done by the main agent because it touches
global test infrastructure.

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent (no delegation)** | Update `spec/rails_helper.rb`, create `spec/support/shoulda_matchers.rb` | Current `rails_helper.rb`, PROMPT.md §9.1 | `bundle exec rspec spec/models/user_spec.rb` returns 1 pending, 0 failures |
| 1 | **Model agent: User** | Replace `app/models/user.rb`, `spec/models/user_spec.rb`, `spec/factories/users.rb` | PROMPT.md §2.1, §2.7; `db/schema.rb`; R8 note | User spec passes (deferred — gated by Step 6) |
| 2 | **Model agent: Conversation** | Create model, spec, factory | PROMPT.md §2.2, §2.7; existing user factory | `rspec spec/models/conversation_spec.rb` green; rubocop scoped clean |
| 3 | **Model agent: Message** | Create model, spec, factory | PROMPT.md §2.3, §2.7; existing conversation factory | `rspec spec/models/message_spec.rb` green; rubocop scoped clean |
| 4 | **Model agent: Document** | Create model, spec, factory | PROMPT.md §2.4, §2.7; existing user factory | `rspec spec/models/document_spec.rb` green; rubocop scoped clean |
| 5 | **Model agent: DocumentChunk** | Create model, spec, factory | PROMPT.md §2.5, §2.7; existing document factory | `rspec spec/models/document_chunk_spec.rb` green; rubocop scoped clean |
| 6 | **Model agent: CertificateRequest** | Create model, spec, factory | PROMPT.md §2.6, §2.7; existing user factory; R6 note | `rspec spec/models/certificate_request_spec.rb` green; rubocop scoped clean; full user spec also green |
| 7 | **Main agent** | Phase verification gates §8.1–§8.5 | Full repo | All gates pass |

Steps 2, 4, 5 are eligible for parallelism (no shared files, no ordering
dependency between them once their respective factory dependencies — user,
conversation, document — exist). For determinism, run them serially.

## 11. Out of scope (explicitly NOT in Phase 2)

- Pundit policies (Phase 3)
- Service objects under `app/services/` (Phases 4 & 5)
- Background jobs (Phase 6)
- Controllers, routes, request specs (Phase 7)
- Views, Stimulus controllers, frontend assets (Phase 8)
- Devise lockable/timeoutable migration (deferred to Phase 11 per R8)
- Full `rails_helper.rb` hardening (`Devise::Test::IntegrationHelpers`,
  `OpenAIHelpers`, etc. — all Phase 9)
- CI workflow, RuboCop strictening, coverage gates (Phase 9)
- Any model concerns, query objects, or auxiliary modules not specified in
  PROMPT.md §2
