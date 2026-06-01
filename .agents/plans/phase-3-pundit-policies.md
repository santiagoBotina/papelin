# Plan: Phase 3 — Pundit Policies & Specs

## 1. Goal

Authorization layer is complete. Every domain resource exposed in `routes.rb`
has a Pundit policy. Every action on every policy has a "permitted" spec and a
"denied" spec. The `ApplicationPolicy` base class enforces a logged-in user
and provides a default-deny contract. Phase 3 ends with
`bundle exec rspec spec/policies/` and
`bundle exec rubocop app/policies/` both green.

No controllers, no services, no jobs, no views, no routes touched.

## 2. Files affected

### [CREATE]

- `app/policies/application_policy.rb`
- `app/policies/conversation_policy.rb`
- `app/policies/document_policy.rb`
- `app/policies/certificate_request_policy.rb`
- `spec/policies/application_policy_spec.rb`
- `spec/policies/conversation_policy_spec.rb`
- `spec/policies/document_policy_spec.rb`
- `spec/policies/certificate_request_policy_spec.rb`
- `spec/support/pundit_matchers.rb` (configures `pundit-matchers` if added) —
  *deferred; AGENTS.md does not require pundit-matchers. Use raw Pundit API
  in specs and assert with `permit`/`not_to permit` provided by Pundit's
  built-in matcher.*

### [MODIFY]

- `spec/rails_helper.rb` — add `require "pundit/rspec"` so the
  `permit`/`forbid` matchers are loaded. Confirm `Pundit::Authorization` is
  already included in `ApplicationController` (it is — Phase 0 bootstrap).
- `spec/factories/users.rb` — confirm `:admin` trait is exported (it must
  already exist from Phase 2; verify and add an `employee` trait alias if
  missing for clarity).

### [NO CHANGES]

- `app/controllers/**` (no controller changes in Phase 3)
- `config/routes.rb`
- `app/models/**`
- `app/services/**`
- `app/jobs/**`
- `db/migrate/**`, `db/schema.rb`
- `Gemfile` (pundit already present)

## 3. Spec files to write first (SDD red-step list)

| # | Spec file | Drives implementation of |
|---|-----------|--------------------------|
| 1 | `spec/policies/application_policy_spec.rb` | `app/policies/application_policy.rb` |
| 2 | `spec/policies/conversation_policy_spec.rb` | `app/policies/conversation_policy.rb` |
| 3 | `spec/policies/document_policy_spec.rb` | `app/policies/document_policy.rb` |
| 4 | `spec/policies/certificate_request_policy_spec.rb` | `app/policies/certificate_request_policy.rb` |

Order matters: `ApplicationPolicy` first (its behavior is the parent of
everything else), then domain policies in any order. `ConversationPolicy` and
`DocumentPolicy` are fully spec'd in PROMPT.md §3.2 and §3.3 — those specs
are authoritative. `CertificateRequestPolicy` is sketched in PROMPT.md §3.4
and must be elaborated per AGENTS.md §11 (employees see only their own;
admins see all and can update status).

## 4. Database changes

**None.** Policies are pure Ruby classes that wrap existing models.

## 5. External side effects

**None.** No HTTP, no OpenAI, no jobs, no emails.

## 6. Risks and open questions

### R1 — `pundit/rspec` matcher availability

The `permit(user, record)` matcher ships with `pundit-matchers` (a separate
gem) — not with `pundit` itself. PROMPT.md uses it, AGENTS.md §11 does not
mandate it. **Decision:** add the `pundit-matchers` gem only if it is not
already in the Gemfile from Phase 0. If absent, replace `permit` assertions
with raw `policy.new(user, record).show?` boolean checks. This is the
deterministic path; the matcher gem adds non-trivial dependencies and is
not necessary for correctness.

**Mitigation:** check `Gemfile` for `pundit-matchers`. If absent, write
specs with raw Pundit calls. If present, use the matcher.

### R2 — `ConversationPolicy#index?` returning `true`

PROMPT.md §3.2 sets `index? = true` for `ConversationPolicy`. The
`verify_authorized` after-action in `ApplicationController` exempts `:index`
in favor of `verify_policy_scoped`. **Mitigation:** the controller
(`ConversationsController#index`) must use `policy_scope(Conversation)` —
not `Conversation.all`. The policy spec does not need to test this contract;
it's enforced in Phase 7. The Phase 3 spec covers `index?` returning `true`
in isolation.

### R3 — `DocumentPolicy#show?` for employees

PROMPT.md §3.3 sets `show? = true` for all authenticated users. **Decision:
follow PROMPT.md.** Employees may read any ready document (they need to see
sources cited in assistant answers). Admin-only restriction applies to
`create?`, `update?`, `destroy?`.

### R4 — `CertificateRequestPolicy` is not in PROMPT.md verbatim

PROMPT.md §3.4 says "Spec and implementation follow the same pattern —
users see only their own requests; admins see all and can update status"
without showing the full code. **Decision:** write the policy per AGENTS.md
§11 (`CertificateRequestPolicy` not shown there either, so we extrapolate
from the pattern used in `ConversationPolicy`):

```ruby
class CertificateRequestPolicy < ApplicationPolicy
  def index?   = true
  def show?    = record.user == user || user.admin?
  def create?  = true
  def update?  = user.admin?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(user: user)
    end
  end
end
```

The spec covers all six cases plus the scope. Flag this design choice in
the report so the main agent can override if it conflicts with later
phases.

### R5 — `ApplicationPolicy` raises on `nil` user

PROMPT.md §3.1's initializer raises `Pundit::NotAuthorizedError` when `user`
is nil. **Implication:** the spec for `ApplicationPolicy` cannot use a nil
user with the `permit` matcher. The spec must call
`ApplicationPolicy.new(nil, record)` directly and expect a raise. **Mitigation:**
add an explicit `describe "when user is nil"` example that asserts
`Pundit::NotAuthorizedError`.

### R6 — Boolean return type (Rails 7.2 endless methods)

PROMPT.md uses endless method syntax (`def index? = false`). **Decision:**
match PROMPT.md verbatim. Confirm `rubocop` does not flag endless methods
under `Style/EndlessMethod` — it should not, since endless methods are
idiomatic for one-line returns in Rails 7.

### R7 — `Pundit::Authorization` already wired

`ApplicationController` already includes `Pundit::Authorization` (added in
Phase 0 / Phase 7 placeholder). Confirm via `grep` before writing the
`rails_helper` change; if it is not present yet, the spec wiring still
works (Pundit specs don't require the include).

## 7. Spec-first contract (SDD per AGENTS.md §19)

For each policy, follow this strict cycle. **No implementation code is
written before the spec is red.**

```
1. UNDERSTAND  Read PROMPT.md §3.x and AGENTS.md §11 for the policy.
2. SPECIFY     Write the spec file. Use raw Pundit assertions
               (policy.new(user, record).action?) unless pundit-matchers
               is already in the Gemfile.
3. RED         bundle exec rspec spec/policies/<file>_spec.rb
               → every example must fail.
4. IMPLEMENT   Write app/policies/<file>.rb.
5. GREEN       bundle exec rspec spec/policies/<file>_spec.rb → all green.
6. REFACTOR    Clean up. Re-run spec to confirm still green.
7. LINT        bundle exec rubocop app/policies/<file>.rb
                            spec/policies/<file>_spec.rb
                → zero offenses.
```

## 8. Execution order

### Step 0 — Test infrastructure prerequisites (one-time, before any policy work)

- **0.1** Modify `spec/rails_helper.rb` to add `require "pundit/rspec"`.
  This loads Pundit's `permit`/`forbid` matchers, which are part of the
  `pundit` gem itself (not the `pundit-matchers` gem). Verify by running
  `bundle exec rspec spec/policies/application_policy_spec.rb` (which
  doesn't exist yet — expect a load error or pending).
- **0.2** Confirm the `:admin` user trait exists in
  `spec/factories/users.rb`. If absent, add it:
  `trait(:admin) { role { :admin } }`. Apply R1's `permit` decision based
  on whether `pundit-matchers` is in the Gemfile.

### Step 1 — ApplicationPolicy

- **1.1** Create `spec/policies/application_policy_spec.rb` with:
  - `describe "when user is nil"` → expects `Pundit::NotAuthorizedError`
    from `ApplicationPolicy.new(nil, :any_record)`.
  - `describe "default permissions"` → instantiates with a real user and
    asserts `index?`, `show?`, `create?`, `update?`, `destroy?` all return
    `false`.
  - `describe "Scope"` → asserts `Scope#resolve` raises
    `NotImplementedError` when called directly on the base class, and
    raises `Pundit::NotAuthorizedError` when initialized with nil user.
- **1.2** Red-step: `bundle exec rspec spec/policies/application_policy_spec.rb`
  → must fail with `NameError: uninitialized constant ApplicationPolicy`.
- **1.3** Create `app/policies/application_policy.rb` per PROMPT.md §3.1
  verbatim.
- **1.4** Green-step: same rspec command → all green.
- **1.5** Lint: `bundle exec rubocop app/policies/application_policy.rb
  spec/policies/application_policy_spec.rb`.

### Step 2 — ConversationPolicy

- **2.1** Create `spec/policies/conversation_policy_spec.rb` per
  PROMPT.md §3.2 verbatim.
- **2.2** Red-step: `bundle exec rspec spec/policies/conversation_policy_spec.rb`
  → must fail.
- **2.3** Create `app/policies/conversation_policy.rb` per PROMPT.md §3.2
  verbatim.
- **2.4** Green-step → lint.

### Step 3 — DocumentPolicy

- **3.1** Create `spec/policies/document_policy_spec.rb` per PROMPT.md §3.3
  verbatim.
- **3.2** Red-step → must fail.
- **3.3** Create `app/policies/document_policy.rb` per PROMPT.md §3.3
  verbatim.
- **3.4** Green-step → lint.

### Step 4 — CertificateRequestPolicy

- **4.1** Create `spec/policies/certificate_request_policy_spec.rb` covering:
  - `permissions :index?` → permits both employee and admin.
  - `permissions :show?, :update?, :destroy?`:
    - permits the owner of the request.
    - permits an admin (admin sees all).
    - denies another employee (not the owner).
  - `permissions :create?` → permits any authenticated user.
  - `describe "Scope#resolve"`:
    - admin sees all requests.
    - employee sees only their own.
- **4.2** Red-step → must fail.
- **4.3** Create `app/policies/certificate_request_policy.rb` per R4
  decision.
- **4.4** Green-step → lint.

### Step 5 — Phase 3 verification gates (all must pass)

- **5.1** `bundle exec rspec spec/policies/` → 0 failures, 0 pending, 0
  errors.
- **5.2** `bundle exec rubocop app/policies/ spec/policies/ spec/rails_helper.rb`
  → 0 offenses.
- **5.3** `git diff --name-only` matches the [CREATE] + [MODIFY] list in §2.
  No surprises.
- **5.4** Confirm `bundle exec rspec` (full suite) still shows 0 failures.
- **5.5** Manual smoke: in `rails console`, run:

  ```ruby
  u = User.first || User.create!(email: "pol@test.com", password: "Password1!", employee_id: "EMP00002", first_name: "P", last_name: "O", role: :admin)
  conv = u.conversations.create!(title: "Policy smoke")
  Pundit.authorize(u, conv, :show?)  # → must not raise
  other = User.create!(email: "other@test.com", password: "Password1!", employee_id: "EMP00003", first_name: "O", last_name: "T")
  Pundit.authorize(other, conv, :show?)  # → must raise Pundit::NotAuthorizedError
  ```

  → confirm both calls behave as expected.

## 9. Definition of done

- [ ] All four policy spec files exist and pass.
- [ ] All four policy files exist and follow PROMPT.md §3.1–§3.4
      (with the R4 design decision for `CertificateRequestPolicy`
      documented in the report).
- [ ] `spec/rails_helper.rb` requires `pundit/rspec` (or pundit-matchers
      is wired if that gem is the chosen path).
- [ ] `bundle exec rspec spec/policies/` → 0 failures, 0 pending, 0 errors.
- [ ] `bundle exec rubocop app/policies/ spec/policies/ spec/rails_helper.rb`
      → 0 offenses.
- [ ] `git diff --name-only` matches the scope in §2.
- [ ] `tmp/pending_specs.md` is updated if R4 (CertificateRequestPolicy
      design choice) needs to be revisited when Phase 7 wires the
      controller.

## 10. Sub-agent delegation plan (per AGENTS.md §18)

The main agent will not write policy code itself. It will dispatch the
following sub-agents in strict order. Step 0 (rails_helper tweak) is done
by the main agent because it touches global test infrastructure.

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent (no delegation)** | Update `spec/rails_helper.rb` to require `pundit/rspec`; verify `User#admin?` trait and R1 matcher decision | Current `rails_helper.rb`, `Gemfile`, `spec/factories/users.rb` | `bundle exec rspec spec/policies/application_policy_spec.rb` (no file yet) raises load error as expected |
| 1 | **Policy agent: ApplicationPolicy** | Create `app/policies/application_policy.rb`, `spec/policies/application_policy_spec.rb` | PROMPT.md §3.1, AGENTS.md §11, R5, R6 | `rspec spec/policies/application_policy_spec.rb` green; rubocop scoped clean |
| 2 | **Policy agent: ConversationPolicy** | Create `app/policies/conversation_policy.rb`, `spec/policies/conversation_policy_spec.rb` | PROMPT.md §3.2 verbatim, AGENTS.md §11 | `rspec spec/policies/conversation_policy_spec.rb` green; rubocop scoped clean |
| 3 | **Policy agent: DocumentPolicy** | Create `app/policies/document_policy.rb`, `spec/policies/document_policy_spec.rb` | PROMPT.md §3.3 verbatim, AGENTS.md §11, R3 | `rspec spec/policies/document_policy_spec.rb` green; rubocop scoped clean |
| 4 | **Policy agent: CertificateRequestPolicy** | Create `app/policies/certificate_request_policy.rb`, `spec/policies/certificate_request_policy_spec.rb` | AGENTS.md §11, R4 design decision, existing user factory | `rspec spec/policies/certificate_request_policy_spec.rb` green; rubocop scoped clean |
| 5 | **Main agent** | Phase verification gates §8.5.1–§8.5.5 | Full repo | All gates pass |

Steps 2, 3, 4 are eligible for parallelism (no shared files, no ordering
dependency between them once their model factories exist). For
determinism, run them serially.

## 11. Out of scope (explicitly NOT in Phase 3)

- Controllers calling `authorize` / `policy_scope` (Phase 7)
- `Admin::BaseController` enforcement of `current_user.admin?` (Phase 7)
- `ApplicationController#after_action :verify_authorized` (Phase 7 — it's
  referenced in PROMPT.md §7.2 but already present from Phase 0
  bootstrap; Phase 3 only verifies the policy layer is correct)
- `CertificateRequest` model changes (already complete in Phase 2)
- Adding `pundit-matchers` gem (R1 decision)
- Service objects (Phases 4 & 5)
- Background jobs (Phase 6)
- Views, Stimulus controllers (Phase 8)
