# Plan: Phase 6 — Background Jobs & Specs

## 1. Goal

Both async workers are implemented and tested: `Documents::IngestJob` (runs
the full ingestion pipeline from Phase 4) and `Rag::QueryJob` (runs the
query pipeline from Phase 5). Jobs are idempotent, handle retry/discard per
AGENTS.md §9, use the correct Sidekiq queues, and update record statuses on
success and failure. Phase 6 ends with
`bundle exec rspec spec/jobs/` and
`bundle exec rubocop app/jobs/ spec/jobs/` both green.

No controllers, no views, no routes touched.

## 2. Files affected

### [CREATE]

- `app/jobs/application_job.rb` (base job — may already exist from phase 0;
  ensure it sets `queue_as` and includes retry/discard logic)
- `app/jobs/documents/ingest_job.rb`
- `app/jobs/rag/query_job.rb`
- `spec/jobs/documents/ingest_job_spec.rb`
- `spec/jobs/rag/query_job_spec.rb`

### [MODIFY]

- `spec/support/active_job.rb` (configure ActiveJob test adapter globally
  or per-spec. Prefer per-spec with `ActiveJob::Base.queue_adapter = :test`.)

### [NO CHANGES]

- `app/services/**` (Phases 4 & 5)
- `app/models/**`, `app/policies/**`
- `app/controllers/**`, `config/routes.rb`
- `db/migrate/**`, `db/schema.rb`
- `Gemfile` (Sidekiq already present)

## 3. Spec files to write first (SDD red-step list)

| # | Spec file | Drives implementation of |
|---|-----------|--------------------------|
| 1 | `spec/jobs/documents/ingest_job_spec.rb` | `app/jobs/documents/ingest_job.rb` |
| 2 | `spec/jobs/rag/query_job_spec.rb` | `app/jobs/rag/query_job.rb` |

Order independent — the two jobs live in different namespaces and have no
shared files. They can be written in parallel or in either order.

## 4. Database changes

**None.** Jobs update status fields on existing records and create
`DocumentChunk` records via `insert_all`.

## 5. External side effects

- `Documents::IngestJob` calls:
  - `Documents::TextExtractorService.call(document:)`
  - `Documents::ChunkingService.call(text:, document:)`
  - `Documents::EmbedService.call(chunks:)`
  - `DocumentChunk.insert_all(...)`
  - `Document.update!(status: ..., chunks_count: ...)`
- `Rag::QueryJob` calls:
  - `Rag::QueryService.call(conversation:, user_message:, user:)`
  - `Turbo::StreamsChannel.broadcast_*` (stubbed in spec)
- Both jobs are enqueued by Sidekiq (`sidekiq` gem, adapter set in
  `config/application.rb`). In test, `queue_adapter = :test`.

## 6. Risks and open questions

### R1 — Sidekiq adapter in test

Rails' `ActiveJob::Base.queue_adapter` defaults to `:async` in development
and `:test` in test (via `config.active_job.queue_adapter` in
`config/application.rb`). **Decision:** for Phase 6 specs, use:

```ruby
ActiveJob::Base.queue_adapter = :test
```

This enqueues jobs to an in-memory array (`enqueued_jobs`) without
executing them. Use `perform_enqueued_jobs` to execute inline. Confirm
this is set in `spec/support/active_job.rb` or in `rails_helper.rb`.

### R2 — `Documents::IngestJob` idempotency

PROMPT.md §6.1 requires: "already-:ready document is skipped (not
re-processed)." **Implementation:** the job starts with a guard:

```ruby
def perform(document_id)
  document = Document.find(document_id)
  return if document.status == "ready"
  # ... pipeline
end
```

The spec tests this by calling `perform` twice — the second call must
not re-run the pipeline (e.g., verify the document's `chunks_count` does
not double).

### R3 — `Documents::IngestJob` cleanup on failure

PROMPT.md §6.1 requires: "Embedding failure: document status set to :failed,
chunks cleaned up." **Implementation:** wrap the per-chunk embedding loop
in a transaction and raise on failure:

```ruby
Document.transaction do
  chunks_with_embeddings = embed_service.call(chunks: raw_chunks)
  raise "Embedding failed" unless chunks_with_embeddings.success?
  DocumentChunk.insert_all(chunks_with_embeddings.data)
  document.update!(status: :ready, chunks_count: chunks_with_embeddings.data.count)
end
```

However, the `Result` pattern from Phase 4 already handles this. **Decision:**
the job checks each service's `Result#success?` and short-circuits on
failure. No explicit transaction needed because the job updates document
status at the end; if it fails mid-way, the document stays `:processing`
and the error message is stored. The spec verifies:
- Document status is `:failed` after an embedding failure.
- `processing_error` contains the error message.

### R4 — `Documents::IngestJob` queue name

PROMPT.md §6.1 and AGENTS.md §9 specify `queue_as :ingestion`.
**Implementation:** `Documents::IngestJob.queue_as :ingestion`.
`Rag::QueryJob.queue_as :default`.

### R5 — `Rag::QueryJob` broadcast on success

After `Rag::QueryService.call` succeeds, the job should broadcast a Turbo
Stream update to replace the assistant message loading state with the
completed content. **Implementation:** in the job, after the query service
returns:

```ruby
def perform(assistant_message_id, user_content)
  message = Message.find(assistant_message_id)
  result = Rag::QueryService.call(
    conversation: message.conversation,
    user_message: user_content,
    user: message.conversation.user
  )
  if result.success?
    Turbo::StreamsChannel.broadcast_replace_later_to(...)
  else
    message.update!(status: :failed, content: result.error)
  end
end
```

The spec stubs `Turbo::StreamsChannel` methods to avoid ActionCable setup.

### R6 — ActiveJob `discard_on`

`Documents::IngestJob` should discard `ActiveJob::DeserializationError`
(record not found). `Rag::QueryJob` should discard
`ActiveJob::DeserializationError` and retry `OpenAI::Error` twice.
Verify both in specs.

### R7 — `spec/support/active_job.rb` helper

If needed, create a support module that sets the test adapter:

```ruby
# spec/support/active_job.rb
RSpec.configure do |config|
  config.include ActiveJob::TestHelper

  config.before(:each, type: :job) do
    ActiveJob::Base.queue_adapter = :test
  end
end
```

**Decision:** this is simple enough to put inline in each job spec's
`before(:each)` block. Keep it small.

### R8 — `Documents::IngestJob` calls services serially

The job calls TextExtractorService → ChunkingService → EmbedService in
sequence. Each step's output feeds into the next. The spec must not test
the services themselves (already tested in Phase 4) — only that the job
calls them with the correct arguments and handles their results.

## 7. Spec-first contract (SDD per AGENTS.md §19)

For each job, follow this strict cycle. **No implementation code is written
before the spec is red.**

```
1. UNDERSTAND  Read PROMPT.md §6.x, AGENTS.md §9.
2. SPECIFY     Write the spec file covering:
               - Happy path
               - Error paths (service failure, record not found)
               - Idempotency (calling twice is safe)
               - Retry/discard behavior
3. RED         bundle exec rspec spec/jobs/<path>_spec.rb
               → every example must fail.
4. IMPLEMENT   Write app/jobs/<path>.rb.
5. GREEN       bundle exec rspec spec/jobs/<path>_spec.rb → all green.
6. REFACTOR    Clean up. Re-run spec.
7. LINT        bundle exec rubocop app/jobs/<path>.rb
                            spec/jobs/<path>_spec.rb
                → zero offenses.
```

## 8. Execution order

### Step 0 — Test infrastructure (one-time, before any job work)

- **0.1** If `spec/support/active_job.rb` does not exist, create it with
  `ActiveJob::TestHelper` inclusion and `queue_adapter = :test` config.
- **0.2** If `app/jobs/application_job.rb` does not exist (or is the
  Rails-generated scaffold), ensure it exists with proper config:

  ```ruby
  class ApplicationJob < ActiveJob::Base
    # Automatically retry jobs that encountered a deadlock
    retry_on ActiveRecord::Deadlocked
    # Most jobs are safe to ignore if the underlying records are no longer available
    discard_on ActiveJob::DeserializationError
  end
  ```

  This file is generated by `rails new` but may need retry_on/discard_on
  additions.

### Step 1 — Documents::IngestJob

- **1.1** Create `spec/jobs/documents/ingest_job_spec.rb` covering:
  - Happy path: document status goes `:pending` → `:processing` → `:ready`,
    chunks are created.
  - Idempotency: calling `perform` twice skips if already `:ready`.
  - Text extraction failure → document status `:failed`, error stored.
  - Embedding failure → document status `:failed`, error stored.
  - `retry_on` for `OpenAI::Error` (stub the embed service to raise it,
    verify the job is retried).
  - `discard_on` for `ActiveJob::DeserializationError` (non-existent
    document ID).
  - Queue name is `:ingestion`.
- **1.2** Red-step → fail.
- **1.3** Create `app/jobs/documents/ingest_job.rb` per PROMPT.md §6.1.
- **1.4** Green-step → lint.

### Step 2 — Rag::QueryJob

- **2.1** Create `spec/jobs/rag/query_job_spec.rb` covering:
  - Happy path: calls `Rag::QueryService` with correct arguments.
  - Service succeeds → assistant message status `:completed`.
  - Service fails → assistant message status `:failed`, content updated
    with error.
  - Record not found → `discard_on` does not raise.
  - Queue name is `:default`.
  - (Broadcast stubs: verify `Turbo::StreamsChannel` is called on success.)
- **2.2** Red-step → fail.
- **2.3** Create `app/jobs/rag/query_job.rb` per PROMPT.md §6.2.
- **2.4** Green-step → lint.

### Step 3 — Phase 6 verification gates (all must pass)

- **3.1** `bundle exec rspec spec/jobs/` → 0 failures, 0 pending, 0 errors.
- **3.2** `bundle exec rubocop app/jobs/ spec/jobs/ spec/support/`
  → 0 offenses.
- **3.3** `git diff --name-only` matches the [CREATE] + [MODIFY] list in §2.
- **3.4** Confirm `bundle exec rspec` (full suite) still shows 0 failures.

## 9. Definition of done

- [ ] `Documents::IngestJob` runs full pipeline: extraction, chunking,
      embedding, persistence. Skips ready docs. Sets failed status on error.
- [ ] `Rag::QueryJob` delegates to `Rag::QueryService`, updates message
      status, broadcasts via Turbo Streams.
- [ ] Both jobs use the correct queues (`:ingestion`, `:default`).
- [ ] Both jobs handle `ActiveJob::DeserializationError` gracefully.
- [ ] `bundle exec rspec spec/jobs/` → 0 failures, 0 errors.
- [ ] `bundle exec rubocop app/jobs/ spec/jobs/ spec/support/`
      → 0 offenses.

## 10. Sub-agent delegation plan (per AGENTS.md §18)

| Step | Sub-agent | Brief scope | Inputs allowed | Done when |
|------|-----------|-------------|----------------|-----------|
| 0 | **Main agent** | Ensure `application_job.rb` exists with retry_on/discard_on; create `spec/support/active_job.rb` if needed | Existing `app/jobs/application_job.rb` | Full suite green |
| 1 | **Job agent: Ingest** | Create `documents/ingest_job.rb`, spec | PROMPT.md §6.1, R2-R4, R8, existing Phase 4 services | `rspec spec/jobs/documents/ingest_job_spec.rb` green; rubocop clean |
| 2 | **Job agent: Query** | Create `rag/query_job.rb`, spec | PROMPT.md §6.2, R5-R6, existing Phase 5 services | `rspec spec/jobs/rag/query_job_spec.rb` green; rubocop clean |
| 3 | **Main agent** | Phase verification gates | Full repo | All gates pass |

Steps 1 and 2 are fully independent — they can run in parallel.

## 11. Out of scope (explicitly NOT in Phase 6)

- Controllers that enqueue these jobs (Phase 7)
- Views that display job status (Phase 8)
- Sidekiq web UI or monitoring (Phase 10 ops readiness)
- Real Sidekiq process testing (only ActiveJob::TestHelper used)
- ActionCable broadcast verification for Turbo Streams (Phase 8)
