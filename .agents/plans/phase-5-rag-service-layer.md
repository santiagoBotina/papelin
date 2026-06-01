# Plan: Phase 5 — Service Layer: RAG Pipeline

## 1. Goal

The query-time RAG pipeline — retrieval, generation, and orchestration — is
fully implemented and tested. This is the most critical path in the application.
Every service returns a `Result` struct. All OpenAI calls are stubbed
via `spec/support/openai_helpers.rb` (created in Phase 4). Phase 5 ends with
`bundle exec rspec spec/services/rag/` and
`bundle exec rubocop app/services/rag/ spec/services/rag/` both green.

No controllers, no jobs, no views, no routes touched. Phase 6 will build
background jobs that call these services.

## 2. Files affected

### [CREATE]

- `app/services/rag/retrieval_service.rb`
- `app/services/rag/generation_service.rb`
- `app/services/rag/query_service.rb`
- `spec/services/rag/retrieval_service_spec.rb`
- `spec/services/rag/generation_service_spec.rb`
- `spec/services/rag/query_service_spec.rb`

### [MODIFY]

None. The `openai_helpers.rb` created in Phase 4 already contains both
`stub_openai_embedding` and `stub_openai_chat` (per R7 of Phase 4 plan).
No `rails_helper.rb` changes needed — WebMock, OpenAIHelpers, and
FactoryBot are all already wired.

### [NO CHANGES]

- `app/services/documents/**` (Phase 4 complete)
- `app/services/application_service.rb` (Phase 4, base Result)
- `app/models/**`, `app/policies/**`
- `app/controllers/**`, `config/routes.rb`
- `app/jobs/**`
- `db/migrate/**`, `db/schema.rb`
- `Gemfile`

## 3. Spec files to write first (SDD red-step list)

| # | Spec file | Drives implementation of |
|---|-----------|--------------------------|
| 1 | `spec/services/rag/retrieval_service_spec.rb` | `app/services/rag/retrieval_service.rb` |
| 2 | `spec/services/rag/generation_service_spec.rb` | `app/services/rag/generation_service.rb` |
| 3 | `spec/services/rag/query_service_spec.rb` | `app/services/rag/query_service.rb` |

Order matters strictly. RetrievalService depends on DocumentChunk +
pgvector (need database setup). GenerationService depends on the system
prompt and chat API. QueryService depends on both RetrievalService and
GenerationService. Run them in order 1 → 2 → 3.

## 4. Database changes

**None.** RetrievalService queries existing `DocumentChunk` records via
pgvector's `nearest_neighbors`. No new migrations. Verify that the pgvector
extension and the IVFFlat index on `document_chunks.embedding` are present
(the index was created in Phase 1 schema).

## 5. External side effects

- **OpenAI embeddings API** is called by `Rag::QueryService`
  (via `Rag::EmbedService`, which was already tested in Phase 4).
- **OpenAI chat completions API** is called by `Rag::GenerationService`.
  In specs, stubbed via `stub_openai_chat`. In production, fires real
  HTTP requests to `https://api.openai.com/v1/chat/completions`.
- No jobs enqueued, no emails sent.

## 6. Risks and open questions

### R1 — pgvector `nearest_neighbors` in test

The `nearest_neighbors` method from the `neighbor` gem requires the pgvector
extension to be enabled and indexed. The spec must create `DocumentChunk`
records with valid embeddings (arrays of 1536 floats) and documents with
`status: :ready`. **Decision:** use the `DocumentChunk` factory (from
Phase 2) which sets `embedding` to a 1536-element array. Note that the
IVFFlat index may cause inconsistent results for small datasets in test;
use `reindex` or brute force in the test helper if needed. Per the
`neighbor` gem docs, the `.nearest_neighbors` method returns records in
approximate order even with small datasets — no special handling needed.

### R2 — `Rag::RetrievalService::SIMILARITY_THRESHOLD` value

AGENTS.md §7 sets `SIMILARITY_THRESHOLD = 0.75`. `neighbor_distance` is a
cosine distance, which ranges from 0 (identical) to 2 (opposite). A
threshold of 0.75 means the minimum cosine similarity is `1 - 0.75 = 0.25`.
**Decision:** keep the AGENTS.md §7 code verbatim:

```ruby
.select { |c| c.neighbor_distance <= (1 - SIMILARITY_THRESHOLD) }
```

This filters chunks where `distance <= 0.25` (i.e., similarity >= 0.75).

### R3 — `Rag::GenerationService::SYSTEM_PROMPT` language

AGENTS.md §6 says "the system prompt is written in the same language the
company uses (Spanish or English — confirm with team)." The master plan
($2) says end-user content is in Spanish. **Decision:** write the system
prompt in Spanish, matching the end-user persona. The prompt instructs the
model to answer in Spanish based on the provided context.

**Fallback phrase (Spanish):** "No tengo información suficiente sobre eso
en los documentos disponibles."

### R4 — `Rag::GenerationService` streaming

PROMPT.md §5.2 says "full spec and implementation" but the streaming
behavior (Turbo::StreamsChannel broadcast) is **not tested in the unit
spec** — it requires ActionCable integration. **Decision:** the unit spec
tests the content generation, token usage recording, and error handling.
Streaming is verified in Phase 7 (request specs) and Phase 8 (manual smoke
test). The `GenerationService` implementation includes the streaming hook
but the spec stubs the broadcast method.

### R5 — `Rag::QueryService` orchestration responsibility

QueryService calls: EmbedService → RetrievalService → GenerationService,
then persists the assistant message. The spec must cover all combinations
of failure at each step. **Decision:** stub each downstream service at the
`.call` level (not the HTTP level) for most examples. Cover OpenAI-level
failures in retrieval and generation specs; cover orchestration errors
(what happens when retrieval returns empty) in the query spec.

### R6 — Conversation history scope

AGENTS.md §6 says "last 10 messages (5 turns)." `GenerationService` calls
`conversation.context_messages` (a model method per the quick reference).
**Decision:** if `context_messages` does not exist on the model yet, add a
scope or method in Phase 2 or add it now. The spec must create a
conversation with messages and verify only the last 10 are included.

### R7 — `CertificateRequest` context

When a user asks about their certificate status, `GenerationService` adds
request data to the prompt. **Decision:** the service receives an optional
`certificate_requests` parameter. If present, it builds a context block.
The spec creates a user with a certificate request and verifies the block
appears in the prompt constructed for OpenAI.

## 7. Spec-first contract (SDD per AGENTS.md §19)

For each service, follow this strict cycle. **No implementation code is
written before the spec is red.**

```
1. UNDERSTAND  Read PROMPT.md §5.x, AGENTS.md §6-7, and master plan §6.
2. SPECIFY     Write the spec file covering the full matrix:
               - Happy path
               - All error paths
               - Boundary conditions (empty results, missing context, etc.)
3. RED         bundle exec rspec spec/services/rag/<file>_spec.rb
               → every example must fail.
4. IMPLEMENT   Write app/services/rag/<file>.rb.
5. GREEN       bundle exec rspec spec/services/rag/<file>_spec.rb → all green.
6. REFACTOR    Clean up. Re-run spec.
7. LINT        bundle exec rubocop app/services/rag/<file>.rb
                            spec/services/rag/<file>_spec.rb
                → zero offenses.
```

## 8. Execution order

### Step 1 — Rag::RetrievalService

- **1.1** Create `spec/services/rag/retrieval_service_spec.rb` with three
  `context` blocks:
  - `when matching chunks exist`: create ready document + chunk, embed query
    vector similar to the chunk's vector → result.success? true,
    result.chunks non-empty, result.chunks.first is the nearest chunk.
  - `when no chunks are above the similarity threshold`: create a chunk with
    an embedding very different from the query vector → result.success? true,
    result.chunks empty.
  - `when pgvector raises an error`: stub `DocumentChunk.nearest_neighbors`
    to raise `PG::Error` → result.success? false, result.error present.
- **1.2** Red-step: `bundle exec rspec spec/services/rag/retrieval_service_spec.rb`
  → must fail with `NameError: uninitialized constant Rag::RetrievalService`.
- **1.3** Create `app/services/rag/retrieval_service.rb` per AGENTS.md §7
  verbatim:
  - `TOP_K = 5`, `SIMILARITY_THRESHOLD = 0.75`.
  - `.call(query_embedding:)` → `Result`.
  - Uses `DocumentChunk.joins(:document).where(documents: { status: :ready })
    .nearest_neighbors(:embedding, @query_embedding, distance: "cosine")`.
- **1.4** Green-step → lint.

### Step 2 — Rag::GenerationService

- **2.1** Create `spec/services/rag/generation_service_spec.rb` covering:
  - Happy path with chunks, conversation history → success? true,
    content returned, metadata includes sources and token usage.
  - System prompt is always the first message in the OpenAI messages array.
  - Retrieved chunk content is included in the prompt.
  - Conversation history is included (last 10 messages).
  - Certificate request context is included when data is provided.
  - OpenAI call fails → success? false, error present.
  - Streaming: the content accumulator builds the full response (stub the
    broadcast method).
- **2.2** Red-step → fail.
- **2.3** Create `app/services/rag/generation_service.rb`:
  - `MODEL = "gpt-4o"` constant.
  - `SYSTEM_PROMPT` (Spanish, per R3).
  - `.call(conversation:, chunks:, user_message:, certificate_requests: nil)`
    → `Result`.
  - Builds prompt per AGENTS.md §7 prompt construction structure.
  - Calls `OpenAI::Client.new.chat(parameters: { model: MODEL, messages: prompt_messages, stream: ... })`.
  - Broadcasts tokens via `Turbo::StreamsChannel.broadcast_append_to`.
  - Records token usage in metadata.
- **2.4** Green-step → lint.

### Step 3 — Rag::QueryService

- **3.1** Create `spec/services/rag/query_service_spec.rb` covering all
  cases from AGENTS.md §19:
  - Happy path: question → retrieval → generation → persisted assistant
    message with status:completed.
  - No relevant chunks found → assistant message says so (not hallucination).
  - Embeddings API fails → assistant message status:failed.
  - Chat completion API fails → assistant message status:failed.
  - Conversation has prior messages → history is passed to GenerationService.
  - User has matching certificate request → request data included in context.
  - Assistant message status transitions (:pending → :completed or :failed).
- **3.2** Red-step → fail.
- **3.3** Create `app/services/rag/query_service.rb`:
  - `.call(conversation:, user_message:, user:)` → `Result`.
  - Orchestrates: embed query → retrieve chunks → generate response.
  - Updates assistant message: content, status, metadata.
- **3.4** Green-step → lint.

### Step 4 — Phase 5 verification gates (all must pass)

- **4.1** `bundle exec rspec spec/services/rag/` → 0 failures, 0 pending,
  0 errors.
- **4.2** `bundle exec rubocop app/services/rag/ spec/services/rag/`
  → 0 offenses.
- **4.3** `git diff --name-only` matches the [CREATE] list in §2.
- **4.4** Confirm no real HTTP calls leaked (WebMock check).
- **4.5** Confirm `bundle exec rspec` (full suite) still shows 0 failures.
- **4.6** Manual sanity: in `rails console` (if vectors exist):

  ```ruby
  Rag::QueryService.call(
    conversation: Conversation.first,
    user_message: "¿Qué necesito para un certificado de nómina?",
    user: User.first
  )
  ```

  This will try to call the real OpenAI API if WebMock is not active in
  the console — skip it or stub manually. Not a gate condition.

## 9. Definition of done

- [ ] All three RAG service files exist and pass their specs.
- [ ] `Rag::RetrievalService` returns chunks with cosine similarity above
      threshold; handles pgvector errors gracefully.
- [ ] `Rag::GenerationService` builds the correct prompt structure; includes
      system prompt first, chunks in context, conversation history, and
      certificate request context when available; handles streaming and
      token recording; returns Result with success/failure.
- [ ] `Rag::QueryService` orchestrates the full pipeline end-to-end;
      transitions assistant message status correctly; handles failure at
      every sub-service.
- [ ] `bundle exec rspec spec/services/rag/` → 0 failures, 0 errors.
- [ ] `bundle exec rubocop app/services/rag/ spec/services/rag/`
      → 0 offenses.
- [ ] No real HTTP calls made (WebMock verified).

## 10. Sub-agent delegation plan (per AGENTS.md §18)

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 1 | **RAG pipeline agent: Retrieval** | Create `rag/retrieval_service.rb`, spec | PROMPT.md §5.1, AGENTS.md §7, R1, R2; existing `document_chunk` factory | `rspec spec/services/rag/retrieval_service_spec.rb` green; rubocop clean |
| 2 | **RAG pipeline agent: Generation** | Create `rag/generation_service.rb`, spec | PROMPT.md §5.2, AGENTS.md §6-7, R3, R4, R6, R7; existing phase 4 services | `rspec spec/services/rag/generation_service_spec.rb` green; rubocop clean |
| 3 | **RAG pipeline agent: Query** | Create `rag/query_service.rb`, spec | PROMPT.md §5.3, AGENTS.md §19, R5; existing phase 4 + step 1-2 services | `rspec spec/services/rag/query_service_spec.rb` green; rubocop clean |
| 4 | **Main agent** | Phase verification gates | Full repo | All gates pass |

Steps 1, 2, 3 must run **serially** (each depends on the previous step's
service being present and tested).

## 11. Out of scope (explicitly NOT in Phase 5)

- Background jobs that call these services (Phase 6)
- Controllers that trigger queries via these services (Phase 7)
- Views / frontend for displaying responses (Phase 8)
- ActionCable / Turbo Stream integration beyond the `broadcast_append_to`
  call inside GenerationService (tested manually in Phase 8)
- Authentication/authorization of the query endpoint (Phase 7)
- Real OpenAI API integration testing (Phase 10 manual smoke test)
