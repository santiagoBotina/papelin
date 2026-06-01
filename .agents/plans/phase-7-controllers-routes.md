# Plan: Phase 7 — Controllers, Routes & Request Specs

## 1. Goal

All HTTP endpoints defined in `config/routes.rb` exist as thin controller
actions with no business logic. Every request is authenticated, authorized
(via Pundit), and returns the correct HTTP status code and response shape.
Every action has a corresponding request spec covering at minimum:
authenticated success, unauthenticated redirect (401), and unauthorized
access (403). Phase 7 ends with
`bundle exec rspec spec/requests/` and
`bundle exec rubocop app/controllers/ spec/requests/` both green.

No views beyond minimal placeholders (empty templates or `render plain:`
responses). Phase 8 adds full views.

## 2. Files affected

### [CREATE]

- `app/controllers/application_controller.rb` — *may already exist from
  Phase 0; replace with full implementation per PROMPT.md §7.2.*
- `app/controllers/conversations_controller.rb`
- `app/controllers/messages_controller.rb`
- `app/controllers/documents_controller.rb`
- `app/controllers/certificate_requests_controller.rb`
- `app/controllers/admin/base_controller.rb`
- `app/controllers/admin/dashboard_controller.rb`
- `app/controllers/admin/documents_controller.rb`
- `app/controllers/admin/users_controller.rb`
- `app/controllers/users/sessions_controller.rb` (Devise override for
  redirect after sign-in)
- `spec/requests/conversations_spec.rb`
- `spec/requests/messages_spec.rb`
- `spec/requests/documents_spec.rb`
- `spec/requests/certificate_requests_spec.rb`
- `spec/requests/admin/dashboard_spec.rb`
- `spec/requests/admin/documents_spec.rb`
- `spec/requests/admin/users_spec.rb`

### [MODIFY]

- `config/routes.rb` — replace the scaffold route file with the full route
  set from PROMPT.md §7.1.
- `spec/rails_helper.rb` — add `config.include Devise::Test::IntegrationHelpers, type: :request`
  (may already exist from Phase 4; verify).

### [NO CHANGES]

- `app/models/**`
- `app/policies/**` (Phase 3 — controllers will call `authorize` and
  `policy_scope`)
- `app/services/**` (Phases 4 & 5)
- `app/jobs/**` (Phase 6)
- `Gemfile`

## 3. Spec files to write first (SDD red-step list)

| # | Spec file | Drives implementation of |
|---|-----------|--------------------------|
| 1 | `spec/requests/conversations_spec.rb` | `ConversationsController` |
| 2 | `spec/requests/messages_spec.rb` | `MessagesController` |
| 3 | `spec/requests/documents_spec.rb` | `DocumentsController` |
| 4 | `spec/requests/certificate_requests_spec.rb` | `CertificateRequestsController` |
| 5 | `spec/requests/admin/dashboard_spec.rb` | `Admin::DashboardController` |
| 6 | `spec/requests/admin/documents_spec.rb` | `Admin::DocumentsController` |
| 7 | `spec/requests/admin/users_spec.rb` | `Admin::UsersController` |

Order: `config/routes.rb` must be finalized first. Then controllers can be
implemented in any order (they share no dependencies at the controller
layer). Request specs must be written before their implementations.

## 4. Database changes

**None.** Controllers read/write through existing models and policies.

## 5. External side effects

- `DocumentsController#create` enqueues `Documents::IngestJob`.
- `MessagesController#create` enqueues `Rag::QueryJob`.
- All other actions are pure read/write through Pundit-authorized scopes.
- No OpenAI calls are made from controllers (delegated to jobs/services).
- No views rendered beyond `render plain:` or `redirect_to` (Phase 8 adds
  view templates).

## 6. Risks and open questions

### R1 — `ApplicationController` must include Pundit

PROMPT.md §7.2 specifies `include Pundit::Authorization`,
`after_action :verify_authorized`, `after_action :verify_policy_scoped`,
and `rescue_from Pundit::NotAuthorizedError`. **Decision:** if the
Phase 0-generated `ApplicationController` already has some of these,
replace it entirely with the PROMPT.md §7.2 version. The rescue block sets
a flash error and redirects.

### R2 — `Admin::BaseController` enforcement

All admin controllers inherit from `Admin::BaseController`, which checks
`current_user.admin?` and raises `Pundit::NotAuthorizedError`. The request
spec verifies an employee gets a 302 redirect with error flash.

**Decision:**

```ruby
class Admin::BaseController < ApplicationController
  before_action :authorize_admin

  private

  def authorize_admin
    raise Pundit::NotAuthorizedError unless current_user&.admin?
  end
end
```

### R3 — `MessagesController#create` Turbo Stream response

`MessagesController#create` must respond to Turbo Stream requests
(since the form is submitted via Turbo in Phase 8). For Phase 7, the
controller creates the user message, creates the pending assistant
message, enqueues the job, and returns:

```ruby
respond_to do |format|
  format.turbo_stream { render turbo_stream: turbo_stream.append(...) }
  format.html { redirect_to @conversation }
end
```

The request spec for Phase 7 should test both `Accept: text/html` and
`Accept: text/vnd.turbo-stream.html` content types. For simplicity, the
spec can test HTML only and verify the redirect. Turbo Stream behavior
is verified in Phase 8.

### R4 — `CertificateRequestsController` does not need CRUD

Per PROMPT.md §7.1 routes: `resources :certificate_requests, only: [:index, :show]`.
Users can view their requests but cannot create, update, or delete them
(that may be an admin or external process). The request spec covers:

- `GET /certificate_requests` → index shows user's own requests (via
  `policy_scope`).
- `GET /certificate_requests/:id` → show own request; 403 for another
  user's request.
- `GET /certificate_requests/:id` for non-existent → 404.

### R5 — `Admin::UsersController` full CRUD

PROMPT.md §7.1 adds `resources :users, only: [:index, :show, :new, :create, :edit, :update]`
under the `admin` namespace. The request spec covers:

- Admin can list, view, create, edit, update users.
- Employee gets 403 on any admin user action.

### R6 — `ConversationsController#destroy` soft or hard delete

PROMPT.md §7.1 uses `resources :conversations, only: [:index, :show, :create, :destroy]`.
The `destroy` action should call `conversation.destroy!` (hard delete) since
conversations are user-owned and deleting old chats is expected. The spec
verifies the record is removed and the user is redirected.

### R7 — `DocumentsController#create` file attachment

The spec for document upload must use `fixture_file_upload`:
```ruby
post documents_path, params: {
  document: {
    title: "Test doc",
    file: fixture_file_upload("spec/fixtures/files/sample.txt", "text/plain")
  }
}
```

The `ActiveStorage` attachment is validated by the model (Phase 2). The
spec should verify the document record is created, `Documents::IngestJob`
is enqueued (using `assert_enqueued_with`), and a redirect to the document
list occurs.

### R8 — Routes scope and `authenticated` block

PROMPT.md §7.1 uses an `authenticated :user` block for the root route.
Unathenticated users are redirected to sign in. The `devise_for` line uses
a custom sessions controller for sign-in redirect customization. The spec
must verify:

- `GET /` → redirects to `/conversations` when authenticated.
- `GET /` → redirects to `/users/sign_in` when unauthenticated.

### R9 — `Users::SessionsController` custom `after_sign_in_path`

PROMPT.md §7.2's `ApplicationController` defines
`after_sign_in_path_for(_resource)` → `authenticated_root_path`. If using
a custom sessions controller, override this method there instead.
**Decision:** keep it in `ApplicationController` per PROMPT.md — it is
simpler and works with Devise's default flow.

### R10 — No view templates yet

All controller actions that render views will fail in Phase 7 because the
view templates don't exist yet. **Decision:** for `index` and `show`
actions, render `render plain: "placeholder"` or
`head :ok` temporarily. Override with real views in Phase 8. Request specs
do not care about view content — they test status codes, redirects, auth
enforcement, and response headers. Use `render plain:` for the response
body.

## 7. Spec-first contract (SDD per AGENTS.md §19)

For each controller, follow this strict cycle. **No implementation code is
written before the spec is red.**

```
1. UNDERSTAND  Read PROMPT.md §7.x for the controller and the route
               definition.
2. SPECIFY     Write the request spec covering:
               - Unauthenticated: 302 redirect to sign-in
               - Authenticated + authorized: success (2xx)
               - Authenticated + unauthorized: 302 redirect with error flash
               - Invalid params: 422 or redirect with error (appropriate)
3. RED         bundle exec rspec spec/requests/<file>_spec.rb
               → every example must fail.
4. IMPLEMENT   Write app/controllers/<file>.rb (thin — authenticate,
               authorize, call service/model, respond).
5. GREEN       bundle exec rspec spec/requests/<file>_spec.rb → all green.
6. REFACTOR    Clean up. Re-run spec.
7. LINT        bundle exec rubocop app/controllers/<file>.rb
                            spec/requests/<file>_spec.rb
                → zero offenses.
```

## 8. Execution order

### Step 0 — Route file + ApplicationController (prerequisite)

- **0.1** Replace `config/routes.rb` with the full PROMPT.md §7.1 route
  definition (including Devise, authenticated root, admin namespace,
  ActionCable mount).
- **0.2** Replace `app/controllers/application_controller.rb` with
  PROMPT.md §7.2 implementation (includes Pundit, rescue blocks,
  `after_sign_in_path_for`).
- **0.3** Create `app/controllers/users/sessions_controller.rb` if needed
  (override Devise to customize after_sign_in).
- **0.4** Create `app/controllers/admin/base_controller.rb` per R2.
- **0.5** Run `bundle exec rubocop config/routes.rb app/controllers/`.

### Step 1 — ConversationsController

- **1.1** Create `spec/requests/conversations_spec.rb` covering:
  - `GET /conversations` → 200 (list user's conversations via policy_scope).
  - `GET /conversations/:id` → 200 if owner, 302 if not.
  - `POST /conversations` → 302 create + redirect.
  - `DELETE /conversations/:id` → 302 destroy + redirect; record removed.
  - Unauthenticated → 302 redirect to sign-in for all actions.
- **1.2** Red-step → fail.
- **1.3** Create `app/controllers/conversations_controller.rb` — thin, calls
  `authorize`, `policy_scope`.
- **1.4** Green-step → lint.

### Step 2 — MessagesController

- **2.1** Create `spec/requests/messages_spec.rb` covering:
  - `POST /conversations/:conversation_id/messages` → 302 create,
    enqueues `Rag::QueryJob`.
  - Unauthorized (not conversation owner) → 302 with error.
  - Invalid params (empty content) → 422 or redirect with error.
  - Unauthenticated → 302 redirect to sign-in.
- **2.2** Red-step → fail.
- **2.3** Create `app/controllers/messages_controller.rb`:
  - Creates user message, creates pending assistant message, enqueues job.
- **2.4** Green-step → lint.

### Step 3 — DocumentsController

- **3.1** Create `spec/requests/documents_spec.rb` covering:
  - `GET /documents` → 200 (list via policy_scope: ready docs for employee,
    all for admin).
  - `GET /documents/:id` → 200 for any ready doc; 302 for non-ready doc
    as employee.
  - `POST /documents` → admin: 302, enqueues `Documents::IngestJob`;
    employee: 302 with error.
  - `DELETE /documents/:id` → admin: 302; employee: 302 with error.
- **3.2** Red-step → fail.
- **3.3** Create `app/controllers/documents_controller.rb`:
  - `new`/`create` require admin per policy. File attached via ActiveStorage.
  - Enqueues `Documents::IngestJob`.
- **3.4** Green-step → lint.

### Step 4 — CertificateRequestsController

- **4.1** Create `spec/requests/certificate_requests_spec.rb` covering:
  - `GET /certificate_requests` → 200, lists user's own requests.
  - `GET /certificate_requests/:id` → 200 if owner; 302 if not.
- **4.2** Red-step → fail.
- **4.3** Create `app/controllers/certificate_requests_controller.rb`.
- **4.4** Green-step → lint.

### Step 5 — Admin::DashboardController

- **5.1** Create `spec/requests/admin/dashboard_spec.rb` covering:
  - `GET /admin` → 200 for admin; 302 for employee.
- **5.2** Red-step → fail.
- **5.3** Create `app/controllers/admin/dashboard_controller.rb`.
- **5.4** Green-step → lint.

### Step 6 — Admin::DocumentsController

- **6.1** Create `spec/requests/admin/documents_spec.rb` covering:
  - `GET /admin/documents` → 200 (all docs, including processing/failed).
  - `GET /admin/documents/:id` → 200.
  - `DELETE /admin/documents/:id` → 302, record removed.
  - Employee gets 302 on all.
- **6.2** Red-step → fail.
- **6.3** Create `app/controllers/admin/documents_controller.rb`.
- **6.4** Green-step → lint.

### Step 7 — Admin::UsersController

- **7.1** Create `spec/requests/admin/users_spec.rb` covering:
  - `GET /admin/users` → 200.
  - `GET /admin/users/:id` → 200.
  - `GET /admin/users/new` → 200.
  - `POST /admin/users` → 302, creates user.
  - `GET /admin/users/:id/edit` → 200.
  - `PUT /admin/users/:id` → 302, updates user.
  - Employee gets 302 on all.
- **7.2** Red-step → fail.
- **7.3** Create `app/controllers/admin/users_controller.rb`.
- **7.4** Green-step → lint.

### Step 8 — Phase 7 verification gates (all must pass)

- **8.1** `bundle exec rspec spec/requests/` → 0 failures, 0 pending,
  0 errors.
- **8.2** `bundle exec rubocop app/controllers/ spec/requests/ config/routes.rb`
  → 0 offenses.
- **8.3** `git diff --name-only` matches the [CREATE] + [MODIFY] list in §2.
- **8.4** Verify `Pundit::AuthorizationNotPerformedError` is never raised:
  every non-index action has `authorize`; every index action has
  `policy_scope`. This is checked by the `after_action` callbacks.
- **8.5** Confirm `bundle exec rspec` (full suite) still shows 0 failures.

## 9. Definition of done

- [ ] `config/routes.rb` matches PROMPT.md §7.1 exactly.
- [ ] `ApplicationController` has Pundit include, rescue blocks, and
      `after_sign_in_path_for`.
- [ ] `ConversationsController`: index, show, create, destroy — all
      authorized via ConversationPolicy.
- [ ] `MessagesController`: create — creates messages, enqueues job.
- [ ] `DocumentsController`: index, show, new, create, destroy — all
      authorized via DocumentPolicy.
- [ ] `CertificateRequestsController`: index, show — scoped to user.
- [ ] `Admin::BaseController` enforces admin-only access.
- [ ] `Admin::DashboardController`, `Admin::DocumentsController`,
      `Admin::UsersController` — admin-only CRUD.
- [ ] Every action has a request spec covering unauthenticated,
      authenticated-authorized, and authenticated-unauthorized paths.
- [ ] `bundle exec rspec spec/requests/` → 0 failures, 0 errors.
- [ ] `bundle exec rubocop app/controllers/ spec/requests/ config/routes.rb`
      → 0 offenses.

## 10. Sub-agent delegation plan (per AGENTS.md §18)

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent** | Replace `routes.rb`, `application_controller.rb`, create `users/sessions_controller.rb`, `admin/base_controller.rb`, create placeholder view templates for all routes | PROMPT.md §7.1-7.2, R2, R8-R10 | `rails routes` shows all expected routes; `rails server` boots |
| 1 | **Controller agent: Conversations** | Create `conversations_controller.rb`, `spec/requests/conversations_spec.rb` | PROMPT.md §7.3, existing `ConversationPolicy` | `rspec spec/requests/conversations_spec.rb` green; rubocop clean |
| 2 | **Controller agent: Messages** | Create `messages_controller.rb`, `spec/requests/messages_spec.rb` | PROMPT.md §7.4, R3, existing `ConversationPolicy` | `rspec spec/requests/messages_spec.rb` green; rubocop clean |
| 3 | **Controller agent: Documents** | Create `documents_controller.rb`, `spec/requests/documents_spec.rb` | PROMPT.md §7.5, R7, existing `DocumentPolicy` | `rspec spec/requests/documents_spec.rb` green; rubocop clean |
| 4 | **Controller agent: CertificateRequests** | Create `certificate_requests_controller.rb`, `spec/requests/certificate_requests_spec.rb` | PROMPT.md §7.1, existing `CertificateRequestPolicy` | `rspec spec/requests/certificate_requests_spec.rb` green; rubocop clean |
| 5 | **Controller agent: Admin dashboard** | Create `admin/dashboard_controller.rb`, `spec/requests/admin/dashboard_spec.rb` | PROMPT.md §7.6, existing `ApplicationController` | `rspec spec/requests/admin/dashboard_spec.rb` green; rubocop clean |
| 6 | **Controller agent: Admin documents** | Create `admin/documents_controller.rb`, `spec/requests/admin/documents_spec.rb` | PROMPT.md §7.6, existing `DocumentPolicy` | `rspec spec/requests/admin/documents_spec.rb` green; rubocop clean |
| 7 | **Controller agent: Admin users** | Create `admin/users_controller.rb`, `spec/requests/admin/users_spec.rb` | PROMPT.md §7.1, existing `User` model R4 | `rspec spec/requests/admin/users_spec.rb` green; rubocop clean |
| 8 | **Main agent** | Phase verification gates | Full repo | All gates pass |

Controller agents 1-7 are eligible for parallelism since each controller
is independent (they share the ApplicationController base and routes but
do not read each other's files). For determinism, run them in order.

## 11. Out of scope (explicitly NOT in Phase 7)

- View templates (`.html.erb`) for any controller (Phase 8)
- Stimulus controllers and JavaScript (Phase 8)
- Turbo Stream response format testing beyond basic HTML (Phase 8)
- Real file upload CSS/UX (Phase 8)
- Chat UI visual design (Phase 8)
- Admin dashboard analytics content (Phase 8)
- ActionCable channel configuration beyond mount in routes (Phase 8)
- Sidekiq web UI mount (Phase 10 ops)
