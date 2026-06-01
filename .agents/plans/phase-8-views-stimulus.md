# Plan: Phase 8 — Views & Stimulus Frontend

## 1. Goal

A working, styled Hotwire UI that a user can interact with in a browser.
All controller actions render real view templates (not placeholders). The
chat interface, document management screens, and admin dashboard are
implemented with Tailwind CSS and Stimulus. Turbo Stream responses handle
async updates. Phase 8 ends when `rails server` boots without ERB errors,
a user can log in and type a message, and an admin can upload a document.

No business logic in views or Stimulus controllers. No new Ruby backend
code beyond helpers and partials.

## 2. Files affected

### [CREATE]

**Layout:**
- `app/views/layouts/application.html.erb`
- `app/views/shared/_flash.html.erb`
- `app/views/shared/_navbar.html.erb`

**Chat (conversations):**
- `app/views/conversations/index.html.erb`
- `app/views/conversations/show.html.erb`
- `app/views/messages/_message.html.erb`
- `app/views/messages/_token.html.erb`
- `app/views/messages/_assistant_stream.html.erb`

**Documents:**
- `app/views/documents/index.html.erb`
- `app/views/documents/new.html.erb`
- `app/views/documents/_document.html.erb`
- `app/views/documents/_status_badge.html.erb`

**Certificate requests:**
- `app/views/certificate_requests/index.html.erb`
- `app/views/certificate_requests/show.html.erb`

**Admin:**
- `app/views/admin/dashboard/show.html.erb`
- `app/views/admin/documents/index.html.erb`
- `app/views/admin/documents/_document.html.erb`
- `app/views/admin/users/index.html.erb`
- `app/views/admin/users/show.html.erb`
- `app/views/admin/users/new.html.erb`
- `app/views/admin/users/edit.html.erb`
- `app/views/admin/users/_form.html.erb`

**Stimulus controllers:**
- `app/javascript/controllers/chat_controller.js`
- `app/javascript/controllers/upload_controller.js`

### [MODIFY]

- `app/helpers/messages_helper.rb` — add Markdown rendering helper
  (using `redcarpet` gem).
- `app/helpers/application_helper.rb` — add page title helper or other
  shared helpers.
- `app/assets/stylesheets/application.tailwind.css` — add any custom
  Tailwind layers if needed (most styling is done via utility classes).
- `app/controllers/application_controller.rb` — add `helper_method` for
  `current_user` name or `admin?` if needed (Devise already provides
  `current_user`).

### [REPLACE (from Phase 7 placeholders)]

- `app/views/conversations/index.html.erb` (replace plain-text)
- `app/views/conversations/show.html.erb` (replace plain-text)
- `app/views/documents/index.html.erb` (replace plain-text)
- `app/views/documents/new.html.erb` (replace plain-text)
- `app/views/certificate_requests/index.html.erb` (replace plain-text)
- `app/views/admin/dashboard/show.html.erb` (replace plain-text)
- `app/views/admin/documents/index.html.erb` (replace plain-text)
- `app/views/admin/users/*.html.erb` (replace plain-text)

### [NO CHANGES]

- `app/controllers/**` (logic stays; views are just templates)
- `app/models/**`, `app/policies/**`, `app/services/**`, `app/jobs/**`
- `config/routes.rb`
- `Gemfile` (Tailwind, Turbo, Stimulus already included via
  `tailwindcss-rails`, `turbo-rails`, `stimulus-rails`)
- `db/migrate/**`, `db/schema.rb`

## 3. Stimulus controllers to write

| Controller | File | Purpose |
|------------|------|---------|
| `chat` | `app/javascript/controllers/chat_controller.js` | Scroll to bottom, clear input on submit, focus |
| `upload` | `app/javascript/controllers/upload_controller.js` | Drag-and-drop highlight, filename display, progress |

## 4. Partial index

| Partial | Used in | Purpose |
|---------|---------|---------|
| `shared/_flash.html.erb` | Application layout | Renders flash messages styled by type (notice, alert, error, info) |
| `shared/_navbar.html.erb` | Application layout | Logo, "Nueva Conversación", user email, sign out; admin link if admin |
| `messages/_message.html.erb` | `conversations/show` | Single message bubble: user right-aligned, assistant left-aligned with Markdown |
| `messages/_token.html.erb` | Turbo stream append target | Single token rendered during streaming response |
| `messages/_assistant_stream.html.erb` | `conversations/show` | Container for streaming assistant message (loading state → content) |
| `documents/_document.html.erb` | `documents/index`, `admin/documents/index` | Document card with title, status badge, description |
| `documents/_status_badge.html.erb` | `_document.html.erb` | Color-coded status badge (pending=gray, processing=yellow, ready=green, failed=red) |
| `admin/users/_form.html.erb` | `admin/users/new`, `admin/users/edit` | User form fields (email, password, role, employee_id, first_name, last_name) |

## 5. Database changes

**None.** Views are read-only from existing data.

## 6. External side effects

- **Turbo Stream broadcasting** is triggered by `Rag::GenerationService`
  (Phase 5) and `Rag::QueryJob` (Phase 6). View templates must have the
  correct `dom_id` targets for these broadcasts.
- **OpenAI streaming tokens** are rendered one-by-one via the `_token`
  partial appended to the `assistant_message_content_<id>` target.
- No new enqueueing, no emails.

## 7. Risks and open questions

### R1 — `dom_id` convention consistency

Turbo Stream broadcasts in Phase 5/6 target `message_<id>_content` (e.g.,
`dom_id(@message, :content)`). The view must have an element with this ID:

```erb
<div id="<%= dom_id(@assistant_message, :content) %>">
  <!-- Streaming tokens are appended here -->
</div>
```

**Decision:** use `dom_id(message, :content)` in both the view and the
service layer's `broadcast_append_to` target. This ensures they match.

### R2 — Streaming architecture

The streaming flow:
1. User submits message form via Turbo.
2. `MessagesController#create` renders a Turbo Stream response that
   appends the user message bubble and a pending assistant message
   container (`_assistant_stream.html.erb`).
3. `Rag::QueryJob` runs the pipeline. `GenerationService` broadcasts
   tokens via `Turbo::StreamsChannel.broadcast_append_to`, each token
   appending to `<%= dom_id(message, :content) %>`.
4. When streaming completes, the job broadcasts a final update replacing
   the loading indicator with the full content.

**Decision:** for Phase 8 MVP, implement step 2 (Turbo Stream response)
and step 3 (token broadcast). Step 4 (loading indicator removal) is a
future refinement — the loading state fades naturally as tokens arrive.

### R3 — Markdown rendering

Assistant responses may contain Markdown (lists, bold, links, code
blocks). Use `redcarpet` to render them as HTML. Create a helper:

```ruby
# app/helpers/messages_helper.rb
def markdown(text)
  MarkdownRenderer.render(text).html_safe
end
```

The `MarkdownRenderer` is a `Redcarpet::Markdown` instance configured with
`Redcarpet::Render::HTML` (hard_wrap: true, filter_html: true for safety).

### R4 — Tailwind styling approach

All styling uses Tailwind utility classes directly in ERB. No custom CSS
files (except `application.tailwind.css` for `@tailwind base/components/utilities`).
Style decisions:
- Chat: messages list is a flexbox column, user messages right-aligned
  (blue), assistant messages left-aligned (gray/white).
- Navbar: fixed top bar with dark background, light text.
- Document cards: 2-3 column grid on desktop, single column on mobile.
- Admin tables: full-width, striped rows.
- All text in UI labels and messages is in Spanish (per master plan §2).

### R5 — Mobile responsiveness

The chat UI must work on mobile. Use responsive Tailwind classes:
`sm:`, `md:`, `lg:` breakpoints. The chat layout should have a max-width
container and occupy full viewport height on mobile.

### R6 — Auto-scroll behavior

Stimulus `chat` controller scrolls the messages container to the bottom
on `connect()` and whenever a new message element is connected
(`messagesTargetConnected()`). This handles both user messages (appended
via Turbo Stream) and assistant tokens (streamed one by one).

### R7 — Upload form drag-and-drop

The `upload` Stimulus controller handles:
- `dragover`/`dragleave` events to toggle a highlight class on the drop
  zone.
- `drop` event to read the file and submit the form.
- `change` event on the file input to show the selected filename.
- Progress bar using Turbo's built-in upload progress (Turbo 7.x fires
  `turbo:upload-start` and `turbo:upload-end` events).

### R8 — Admin dashboard content

`Admin::DashboardController#show` should display:
- Total documents count (by status).
- Total conversations count.
- Total users count.
- Recent ingestion jobs (last 5).

These metrics can be fetched in the controller or via a simple query
object. **Decision:** keep queries in the controller for simplicity.
The view renders them in summary cards.

### R9 — Locales and Spanish text

All hardcoded UI text must be in Spanish:
- Button labels: "Nueva Conversación", "Enviar", "Subir Documento"
- Placeholders: "Escribe tu mensaje...", "Buscar documentos..."
- Statuses: "Pendiente", "Procesando", "Listo", "Fallido"
- Flash messages: "Sesión iniciada", "Documento subido exitosamente"
- Navbar: "Documentos", "Certificados", "Admin", "Cerrar Sesión"

Using `I18n` locale files is preferred but not required for Phase 8 MVP.
Hardcoding Spanish strings in ERB is acceptable; extraction to locale
YAML files can be done later.

### R10 — No view specs

Phase 8 does not require view specs or system specs. The verification
method is `rails server` boot + manual browser interaction. View specs
can be added in Phase 10 hardening.

## 8. Execution order

### Step 0 — Layout and shared partials

- **0.1** Create `app/views/layouts/application.html.erb` with Tailwind
  classes, Turbo/Stimulus tags, navbar, flash, yield.
- **0.2** Create `app/views/shared/_navbar.html.erb` with logo/links/user.
- **0.3** Create `app/views/shared/_flash.html.erb` rendering flash
  messages with color-coded Tailwind alerts.
- **0.4** Create `app/helpers/messages_helper.rb` with `markdown` method
  (Redcarpet).

### Step 1 — Chat UI (conversations)

- **1.1** Create `app/views/conversations/index.html.erb` — list of user's
  conversations with "Nueva Conversación" button.
- **1.2** Create `app/views/conversations/show.html.erb` — main chat
  interface with Turbo Frame for messages, message form, loading
  container.
- **1.3** Create `app/views/messages/_message.html.erb` — message bubble
  partial (user vs assistant styling, Markdown for assistant).
- **1.4** Create `app/views/messages/_token.html.erb` — single streaming
  token span.
- **1.5** Create `app/views/messages/_assistant_stream.html.erb` —
  container for pending assistant message with loading indicator.

### Step 2 — Documents UI

- **2.1** Create `app/views/documents/index.html.erb` — grid of document
  cards with search/filter if needed.
- **2.2** Create `app/views/documents/new.html.erb` — upload form with
  drag-and-drop zone.
- **2.3** Create `app/views/documents/_document.html.erb` — card partial.
- **2.4** Create `app/views/documents/_status_badge.html.erb` — badge
  partial.

### Step 3 — Certificate requests UI

- **3.1** Create `app/views/certificate_requests/index.html.erb` — table
  of user's requests.
- **3.2** Create `app/views/certificate_requests/show.html.erb` — request
  detail with status timeline.

### Step 4 — Admin UI

- **4.1** Create `app/views/admin/dashboard/show.html.erb` — stats cards
  (docs, conversations, users).
- **4.2** Create `app/views/admin/documents/index.html.erb` — admin
  document list with status management.
- **4.3** Create `app/views/admin/users/index.html.erb` — users table.
- **4.4** Create `app/views/admin/users/show.html.erb` — user detail.
- **4.5** Create `app/views/admin/users/new.html.erb` — new user form.
- **4.6** Create `app/views/admin/users/edit.html.erb` — edit user form.
- **4.7** Create `app/views/admin/users/_form.html.erb` — shared form
  partial.

### Step 5 — Stimulus controllers

- **5.1** Create `app/javascript/controllers/chat_controller.js`:
  - Static targets: `input`, `messages`.
  - `connect()`: scroll to bottom.
  - `messagesTargetConnected()`: scroll to bottom on new message.
  - `clearInput()`: clear and refocus input.
  - Connect with `data-controller="chat"` on the messages container.
- **5.2** Create `app/javascript/controllers/upload_controller.js`:
  - Static targets: `input`, `dropzone`, `filename`, `progress`.
  - `dragover`/`dragleave`/`drop` handlers.
  - `change` handler for file input.
  - Progress bar on upload.

### Step 6 — Phase 8 verification gates (all must pass)

- **6.1** `rails server` boots without ERB compilation errors
  (`rails s -p 3001 &` and check `/` returns a page).
- **6.2** All previously passing specs still pass:
  `bundle exec rspec` → 0 failures.
- **6.3** RuboCop passes: `bundle exec rubocop app/views/ app/helpers/ app/javascript/`
  (check ERB with `rubocop -a` — run `bin/rails rubocop` if using the
  `rubocop-rails` extension for ERB).
- **6.4** `git diff --name-only` matches the [CREATE] + [MODIFY] + [REPLACE]
  list in §2.

## 9. Definition of done

- [ ] Application layout renders with navbar, flash, and yield.
- [ ] Chat UI renders conversations index and show pages.
- [ ] Message bubbles show user messages right-aligned, assistant messages
      left-aligned with Markdown.
- [ ] Message form submits via Turbo; stream container is ready for tokens.
- [ ] Document list page shows cards with status badges.
- [ ] Document upload form has drag-and-drop with Stimulus controller.
- [ ] Certificate requests index and show pages render.
- [ ] Admin dashboard shows stats.
- [ ] Admin documents list shows all docs.
- [ ] Admin users CRUD has full form and listing.
- [ ] Stimulus `chat` controller auto-scrolls and clears input.
- [ ] Stimulus `upload` controller handles drag-and-drop and filename.
- [ ] `rails server` boots without errors.
- [ ] All UI text is in Spanish.
- [ ] `bundle exec rspec` (full suite) → 0 failures, pre-existing specs
      unaffected.
- [ ] `bundle exec rubocop` → 0 offenses.

## 10. Sub-agent delegation plan (per AGENTS.md §18)

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent (no delegation)** | Layout + shared partials + messages helper | PROMPT.md §8.1, existing `application.html.erb` | `rails s` boots, page renders |
| 1 | **Frontend agent: Chat UI** | `conversations/index`, `conversations/show`, message partials, token partial, stream container | PROMPT.md §8.2, R1-R3, R6 | `rails s` shows chat pages without ERB errors |
| 2 | **Frontend agent: Documents UI** | `documents/index`, `documents/new`, `_document`, `_status_badge` | PROMPT.md §8.3, R4, R7 | `rails s` shows document pages without ERB errors |
| 3 | **Frontend agent: Cert requests UI** | `certificate_requests/index`, `certificate_requests/show` | PROMPT.md §7.1 routes, R9 (Spanish) | `rails s` shows certificate request pages |
| 4 | **Frontend agent: Admin UI** | `admin/dashboard/show`, `admin/documents/index`, `admin/users/*` | PROMPT.md §8.3 (admin), R8 | `rails s` shows admin pages |
| 5 | **Frontend agent: Stimulus** | `chat_controller.js`, `upload_controller.js` | PROMPT.md §8.4, AGENTS.md §10, R6-R7 | Controllers are functional (verified manually) |
| 6 | **Main agent** | Phase verification gates | Full repo | `bundle exec rspec` green; `rails s` boots; `rubocop` clean |

Steps 1, 2, 3, 4 are eligible for parallelism (independent view sets,
same layout context but no file sharing). Step 5 can run in parallel with
them. For determinism, run them in order.

## 11. Out of scope (explicitly NOT in Phase 8)

- System specs / browser tests (Phase 10 or not at all)
- View specs (added later if needed)
- I18n locale files (hardcoded Spanish in ERB is acceptable)
- Internationalization / English support
- Dark mode toggle
- Real-time connection status indicator (ActionCable)
- Chat history search
- Document preview (PDF inline viewer)
- Print stylesheets
- Keyboard shortcuts beyond basic form submission
