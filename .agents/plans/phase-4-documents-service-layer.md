# Plan: Phase 4 — Service Layer: Documents Pipeline

## 1. Goal

The full document ingestion pipeline (text extraction, chunking, embedding) is
implemented as isolated, tested service objects under `app/services/`. Every
service returns a `Result` struct with `success?`, `data`, `error`. All OpenAI
calls are stubbed via `spec/support/openai_helpers.rb`. No real HTTP calls leak
through (verified by WebMock). Phase 4 ends with
`bundle exec rspec spec/services/documents/ spec/services/rag/embed_service_spec.rb`
and `bundle exec rubocop app/services/ spec/services/` both green.

No controllers, no jobs, no views, no routes touched. Phase 5 will build on
Phase 4's embed service.

## 2. Files affected

### [CREATE]

- `spec/support/openai_helpers.rb` (OpenAI stub helpers for all test phases)
- `app/services/application_service.rb` (base class with `Result` struct)
- `app/services/documents/text_extractor_service.rb`
- `app/services/documents/chunking_service.rb`
- `app/services/rag/embed_service.rb`
- `app/services/documents/embed_service.rb`
- `spec/services/documents/text_extractor_service_spec.rb`
- `spec/services/documents/chunking_service_spec.rb`
- `spec/services/rag/embed_service_spec.rb`
- `spec/services/documents/embed_service_spec.rb`

### [MODIFY]

- `spec/rails_helper.rb` — add `require "webmock/rspec"` and
  `WebMock.disable_net_connect!(allow_localhost: true)` along with
  `config.include OpenAIHelpers` and `Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }`.
  These may partially exist from Phase 0; ensure they are present and correct.

### [NO CHANGES]

- `app/models/**`, `app/policies/**`
- `app/controllers/**`, `config/routes.rb`
- `app/jobs/**`
- `db/migrate/**`, `db/schema.rb`
- `Gemfile` (all required gems already present: `ruby-openai`, `pdf-reader`, `docx`, `webmock`)

## 3. Spec files to write first (SDD red-step list)

| # | Spec file | Drives implementation of |
|---|-----------|--------------------------|
| 1 | `spec/services/documents/text_extractor_service_spec.rb` | `app/services/documents/text_extractor_service.rb` |
| 2 | `spec/services/documents/chunking_service_spec.rb` | `app/services/documents/chunking_service.rb` |
| 3 | `spec/services/rag/embed_service_spec.rb` | `app/services/rag/embed_service.rb` |
| 4 | `spec/services/documents/embed_service_spec.rb` | `app/services/documents/embed_service.rb` |

Order: `openai_helpers.rb` must exist before specs 3 or 4 run. Services 1, 2
can be written in any order (no Open AI dependency). Service 4 depends on 3
(at runtime, but the spec can stub the dependency).

## 4. Database changes

**None.** These services operate on plain Ruby objects and document text.
`DocumentChunk.insert_all` (called from `Documents::EmbedService`) does touch
the database, but no schema changes are needed in this phase.

## 5. External side effects

- **OpenAI embeddings API is called by `Rag::EmbedService`**. In spec, the
  call is stubbed with `stub_openai_embedding`. In development/production,
  this fires a real HTTP request to `https://api.openai.com/v1/embeddings`.
- No jobs enqueued. `Documents::IngestJob` (Phase 6) will call these services.
- `Documents::TextExtractorService` reads files via the `pdf-reader` and
  `docx` gems, which are local-only — no network calls.

## 6. Risks and open questions

### R1 — `Result` struct location

Every service returns `Result.new(success?: ..., data: ..., error: ...)`.
PROMPT.md §4 and AGENTS.md §5 both require this pattern. **Decision:** define
`Result` as a `Struct` inside `ApplicationService`:

```ruby
class ApplicationService
  Result = Struct.new(:success?, :data, :error, keyword_init: true)
end
```

Alternatively, define it at the top-level `ApplicationService::Result`. Stick
to one pattern — do not re-define it in every service.

### R2 — `Documents::TextExtractorService` file handling

The service receives a `Document` record (with attached file via ActiveStorage)
and must download the blob to a tempfile for `pdf-reader` and `docx`.
**Implementation approach:**

```ruby
def extract_pdf
  doc = PDF::Reader.new(tempfile_path(document.file))
  doc.pages.map(&:text).join("\n")
end
```

**Spec approach:** stub `document.file.download` to return a fixture binary
string. Avoid real file I/O in unit tests. Keep fixture files under
`spec/fixtures/files/` if needed.

### R3 — `Documents::TextExtractorService` control character stripping

PROMPT.md specifies "Strip null bytes and control characters from extracted
text." Use `text.gsub(/\p{Cc}/, "")` for Unicode-aware stripping. Verify
via a spec with a string that includes `\x00` and other control chars.

### R4 — `Documents::ChunkingService::CHUNK_SIZE` constant

AGENTS.md §8 sets `CHUNK_SIZE = 2000` characters and `CHUNK_OVERLAP = 200`.
PROMPT.md §4.3 confirms. Use character length, **not** token length. The
return value is an array of hashes, not ActiveRecord objects.

### R5 — `Documents::EmbedService` integration with chunking service

`Documents::EmbedService` receives the **output** of
`Documents::ChunkingService` (array of hashes) and adds an `:embedding` key
to each hash. It delegates to `Rag::EmbedService` for the actual embedding.

**Decision:** `Documents::EmbedService#call` accepts `chunks:` (array of
hashes from `ChunkingService`) and returns the same array with embeddings
appended. If all embeddings succeed, `success?` is true and `data` contains
the complete array. If any chunk fails, return `success?: false` with the
error.

### R6 — `Rag::EmbedService` MAX_INPUT_LENGTH

PROMPT.md §4.4 says "truncates input to 8000 chars" — use
`@text.strip.truncate(8000)`. This is below `text-embedding-3-small`'s
8192-token limit for a safety margin.

### R7 — `spec/support/openai_helpers.rb` shared with Phase 5

Phase 5 will need `stub_openai_chat` in addition to `stub_openai_embedding`.
Include both helpers now even though Phase 4 only uses the embedding stub.
This avoids re-opening the file in Phase 5.

### R8 — OpenAI API calls are **never** made in specs

WebMock is configured with `disable_net_connect!` and only localhost is
allowed. Any unintended real HTTP call will raise `WebMock::NetConnectNotAllowedError`
— catch this in the Phase 4 gate. All specs must use `stub_openai_embedding`
before calling any service that triggers an embedding.

## 7. Spec-first contract (SDD per AGENTS.md §19)

For each service, follow this strict cycle. **No implementation code is
written before the spec is red.**

```
1. UNDERSTAND  Read PROMPT.md §4.x and AGENTS.md §7/§8 for the service.
2. SPECIFY     Write the spec file covering:
               - Happy path (success? true, data expected shape)
               - All error paths (bad input, network failure, etc.)
               - Boundary conditions (empty text, very short text, etc.)
3. RED         bundle exec rspec spec/services/<path>_spec.rb
               → every example must fail (NameError, NoMethodError)
4. IMPLEMENT   Write app/services/<path>.rb.
5. GREEN       bundle exec rspec spec/services/<path>_spec.rb → all green.
6. REFACTOR    Clean up. Re-run spec.
7. LINT        bundle exec rubocop app/services/<path>.rb
                            spec/services/<path>_spec.rb
                → zero offenses.
```

## 8. Execution order

### Step 0 — Test infrastructure prerequisites (one-time, before any service work)

- **0.1** Create `app/services/application_service.rb` with the `Result`
  struct per R1.
- **0.2** Create `spec/support/openai_helpers.rb` per PROMPT.md §4.1.
- **0.3** Update `spec/rails_helper.rb`:
  - Add `require "webmock/rspec"` near the top.
  - Add `WebMock.disable_net_connect!(allow_localhost: true)`.
  - Add `Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }`.
  - Inside `RSpec.configure`: add `config.include OpenAIHelpers`.
  - Confirm `config.include FactoryBot::Syntax::Methods` is already present.
- **0.4** Run `bundle exec rspec` to confirm all existing specs still pass
  (Phase 1-3 specs).

### Step 1 — Documents::TextExtractorService

- **1.1** Create `spec/services/documents/text_extractor_service_spec.rb`
  covering:
  - Given a document with a PDF fixture → returns text string, success? true.
  - Given a document with a TXT fixture → returns text string, success? true.
  - Given an unsupported file type → success? false, error present.
  - Extracted text has no null bytes / control chars.
- **1.2** Create fixture files in `spec/fixtures/files/`:
  - `sample.txt` (plain text)
  - (Skip PDF/DOCX binary fixtures for unit speed; stub the reader gems.)
- **1.3** Red-step: `bundle exec rspec spec/services/documents/text_extractor_service_spec.rb`
  → must fail with `NameError: uninitialized constant Documents::TextExtractorService`.
- **1.4** Create `app/services/documents/text_extractor_service.rb`:
  - `.call(document:)` entry point → `Result`.
  - Private methods: `extract_pdf`, `extract_docx`, `extract_txt`.
  - Unsupported type → `Result.new(success?: false, error: "Unsupported file type")`.
  - Null-byte stripping via `gsub(/\p{Cc}/, "")`.
- **1.5** Green-step → lint.

### Step 2 — Documents::ChunkingService

- **2.1** Create `spec/services/documents/chunking_service_spec.rb` covering:
  - Text longer than CHUNK_SIZE → returns multiple chunks with correct
    overlap.
  - Text shorter than CHUNK_SIZE → returns single chunk.
  - Empty text → returns empty array (success? true).
  - Chunk hashes have correct keys (`document_id`, `content`, `chunk_index`,
    `metadata`, `created_at`, `updated_at`).
  - Chunk indices are sequential starting from 0.
- **2.2** Red-step: `bundle exec rspec spec/services/documents/chunking_service_spec.rb`
  → must fail.
- **2.3** Create `app/services/documents/chunking_service.rb`:
  - `CHUNK_SIZE = 2000`, `CHUNK_OVERLAP = 200` constants.
  - `.call(text:, document:)` → array of chunk hashes.
  - Uses sliding window algorithm per AGENTS.md §8.
- **2.4** Green-step → lint.

### Step 3 — Rag::EmbedService

- **3.1** Create `spec/services/rag/embed_service_spec.rb` covering:
  - Successful embedding → success? true, embedding is Array of 1536 floats.
  - Input truncated to 8000 chars if longer.
  - OpenAI API failure → success? false, error present.
  - Uses `stub_openai_embedding` for stubs.
- **3.2** Red-step → must fail.
- **3.3** Create `app/services/rag/embed_service.rb`:
  - `MODEL = "text-embedding-3-small"`, `DIMENSIONS = 1536`.
  - `.call(text:)` → `Result`.
  - Initializer truncates input with `@text.strip.truncate(8000)`.
  - Calls `OpenAI::Client.new.embeddings(...)`.
- **3.4** Green-step → lint.

### Step 4 — Documents::EmbedService

- **4.1** Create `spec/services/documents/embed_service_spec.rb` covering:
  - Given array of chunk hashes → returns same array with `:embedding` key
    added to each hash.
  - All embeddings succeed → success? true, data is complete array.
  - Embedding service fails for one chunk → success? false, error present.
  - Delegates to `Rag::EmbedService` (not to `OpenAI::Client` directly).
- **4.2** Red-step → must fail.
- **4.3** Create `app/services/documents/embed_service.rb`:
  - `.call(chunks:)` → `Result`.
  - Iterates over chunks, calls `Rag::EmbedService.call(text: chunk[:content])`.
  - Appends `embedding:` to each chunk hash.
- **4.4** Green-step → lint.

### Step 5 — Phase 4 verification gates (all must pass)

- **5.1** `bundle exec rspec spec/services/documents/ spec/services/rag/embed_service_spec.rb`
  → 0 failures, 0 pending, 0 errors.
- **5.2** `bundle exec rubocop app/services/ spec/services/ spec/support/`
  → 0 offenses.
- **5.3** `git diff --name-only` matches the [CREATE] + [MODIFY] list in §2.
- **5.4** Confirm no real HTTP calls leaked: grep the output of 5.1 for
  `WebMock::NetConnectNotAllowedError` — it must not appear.
- **5.5** Confirm `bundle exec rspec` (full suite) still shows 0 failures.

## 9. Definition of done

- [ ] `spec/support/openai_helpers.rb` exists with embedding/chat stubs.
- [ ] `app/services/application_service.rb` exists with `Result` struct.
- [ ] `Documents::TextExtractorService` extracts PDF, DOCX, TXT; strips
      control characters; handles unsupported types gracefully.
- [ ] `Documents::ChunkingService` splits text into fixed-size overlapping
      chunks; handles empty and very short text.
- [ ] `Rag::EmbedService` calls OpenAI embeddings API, returns 1536-dim
      vector; handles truncation and API failures.
- [ ] `Documents::EmbedService` processes chunk arrays, delegates embedding
      work, returns enriched hashes.
- [ ] All four service specs pass; all four service files lint clean.
- [ ] `bundle exec rspec spec/services/documents/ spec/services/rag/embed_service_spec.rb`
      → 0 failures.
- [ ] `bundle exec rubocop app/services/ spec/services/ spec/support/`
      → 0 offenses.
- [ ] No real HTTP calls made (verified by WebMock).

## 10. Sub-agent delegation plan (per AGENTS.md §18)

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent (no delegation)** | Create `application_service.rb`, `openai_helpers.rb`, update `rails_helper.rb` | Existing `rails_helper.rb`, PROMPT.md §4.1 | Full suite green |
| 1 | **Service agent: TextExtractor** | Create `text_extractor_service.rb`, spec | PROMPT.md §4.2, R2, R3 | Spec green; rubocop clean |
| 2 | **Service agent: Chunking** | Create `chunking_service.rb`, spec | PROMPT.md §4.3, R4 | Spec green; rubocop clean |
| 3 | **Service agent: Rag::Embed** | Create `rag/embed_service.rb`, spec | PROMPT.md §4.4, R6, existing `openai_helpers.rb` | Spec green; rubocop clean |
| 4 | **Service agent: Documents::Embed** | Create `documents/embed_service.rb`, spec | PROMPT.md §4.5, R5, existing `rag/embed_service.rb`, existing `openai_helpers.rb` | Spec green; rubocop clean |
| 5 | **Main agent** | Phase verification gates §8.5.1–§8.5.5 | Full repo | All gates pass |

Steps 1, 2 are eligible for parallelism (no shared files). Step 3 must run
before step 4 (`Documents::EmbedService` depends on `Rag::EmbedService`);
run them serially.

## 11. Out of scope (explicitly NOT in Phase 4)

- `Documents::IngestJob` (Phase 6 — the job that calls these services)
- `Rag::RetrievalService`, `Rag::GenerationService`, `Rag::QueryService` (Phase 5)
- Controllers that trigger ingestion (Phase 7)
- Any view or frontend code (Phase 8)
- Pundit policies — already complete (Phase 3)
- Any background job infrastructure beyond what was set up in Phase 0
