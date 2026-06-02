# Architecture

## Overview

Papelin is a Rails 7.2 monolith that answers employee questions about internal certificate processes using RAG (Retrieval-Augmented Generation). Users ask natural-language questions via a chat interface; the system embeds the query, retrieves relevant document chunks from pgvector, and sends them as context to GPT-4o for a grounded response. Document ingestion (upload → text extraction → chunking → embedding) runs asynchronously via Sidekiq.

The target scale is a single company with hundreds of employees and thousands to tens of thousands of document chunks.

## System diagram

```
                         ┌─────────────────────────────────────────────┐
                         │                Browser                      │
                         │     (Hotwire: Turbo + Stimulus)             │
                         └──────────────┬──────────────────────────────┘
                                        │ HTTP / SSE
                                        ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Rails 7.2 Monolith                              │
│                                                                        │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐ │
│  │  Controllers     │    │   Views (ERB)    │    │   Stimulus JS    │ │
│  │  (thin: auth →   │───▶│  + Turbo Streams │◀───│  (UI behavior)   │ │
│  │   authorize →    │    │  + Tailwind CSS  │    │                  │ │
│  │   call service)  │    │                  │    │                  │ │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘ │
│           │                                                           │
│           ▼                                                           │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    Service Layer                              │    │
│  │                                                               │    │
│  │  ┌────────────────────┐    ┌────────────────────────────┐     │    │
│  │  │  Rag::QueryService │───▶│  Rag::EmbedService         │     │    │
│  │  │  (orchestrator)    │    │  (text-embedding-3-small)  │     │    │
│  │  │                    │───▶│  Rag::RetrievalService     │     │    │
│  │  │                    │    │  (pgvector cosine search)  │     │    │
│  │  │                    │───▶│  Rag::GenerationService    │     │    │
│  │  │                    │    │  (GPT-4o chat completion)  │     │    │
│  │  └────────────────────┘    └────────────────────────────┘     │    │
│  │                                                               │    │
│  │  ┌────────────────────────────┐                              │    │
│  │  │  Documents::IngestJob      │                              │    │
│  │  │  TextExtractor→Chunking→   │                              │    │
│  │  │  Embedding→Persist         │                              │    │
│  │  └────────────────────────────┘                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│           │                                                           │
└───────────┼───────────────────────────────────────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────────────────────────────────┐
│                       Infrastructure                                  │
│                                                                       │
│  ┌──────────────┐  ┌──────────────────┐  ┌────────────────────────┐  │
│  │  PostgreSQL  │  │  Redis           │  │  OpenAI API            │  │
│  │  + pgvector  │  │  (Sidekiq queue) │  │  (embeddings + chat)   │  │
│  │  + Active    │  │  + ActionCable   │  │  ruby-openai gem       │  │
│  │  Storage     │  │                  │  │                        │  │
│  └──────────────┘  └──────────────────┘  └────────────────────────┘  │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐      │
│  │  ActiveStorage (local disk dev / S3 production)            │      │
│  └────────────────────────────────────────────────────────────┘      │
└───────────────────────────────────────────────────────────────────────┘
```

## Layers

### HTTP Layer (Controllers)

Controllers are thin. Each action follows the same pattern: authenticate (`authenticate_user!` via Devise) → authorize (`authorize` or `policy_scope` via Pundit) → parse params → call one service or model method → respond (Turbo Stream or redirect).

- `ConversationsController` — chat session CRUD
- `MessagesController` — receives user messages, enqueues `Rag::QueryJob`
- `DocumentsController` — file upload and management
- `CertificateRequestsController` — certificate request listing
- `Admin::*` — admin-only management endpoints

### Business Layer (Services)

All non-trivial business logic lives in `app/services/`. Services are organized by domain:

- `Rag::QueryService` — orchestrates the RAG pipeline
- `Rag::EmbedService` — wraps OpenAI embeddings API
- `Rag::RetrievalService` — pgvector cosine similarity search
- `Rag::GenerationService` — prompt construction + GPT-4o call
- `Documents::TextExtractorService` — extracts text from PDF/DOCX/TXT
- `Documents::ChunkingService` — fixed-size sliding window chunking
- `Documents::EmbedService` — batch embedding of chunks (delegates to `Rag::EmbedService`)

Every service has a `.call` class method and returns a `Result` struct (`success?`, domain fields, `error`).

### Domain Layer (Models)

Models own validations, associations, scopes, and business-rule instance methods. They do not call OpenAI, enqueue jobs, or touch external services directly.

- `User` — Devise-managed user with employee/admin roles
- `Conversation` — chat session containing messages
- `Message` — individual turn (user or assistant) with status and metadata
- `Document` — uploaded source document with lifecycle status
- `DocumentChunk` — text fragment with embedding vector
- `CertificateRequest` — actual certificate request record
- `CertificateType` — admin-managed certificate type definitions

### Infrastructure Layer (Jobs, External APIs)

Background jobs use ActiveJob with the Sidekiq adapter:

- `Rag::QueryJob` — executes the RAG pipeline in the background (`:default` queue)
- `Documents::IngestJob` — runs the ingestion pipeline (`:ingestion` queue)

External API calls are isolated in services: `Rag::EmbedService` and `Rag::GenerationService` call OpenAI via the `ruby-openai` gem.

## Data flow: answering a question

1. User types a message and submits the form
2. `MessagesController#create` creates a `Message(role: :user)` and a `Message(role: :assistant, status: :pending)`
3. Both messages are broadcast via Turbo Streams to the UI
4. `Rag::QueryJob.perform_later` is enqueued
5. `Rag::QueryJob` calls `Rag::QueryService.call`
6. `Rag::QueryService`:
   a. Calls `Rag::EmbedService` to embed the user's text → 1536-dim vector
   b. Calls `Rag::RetrievalService` to find top-5 similar chunks via pgvector
   c. Calls `Rag::GenerationService` with chunks + conversation history + user query
7. `Rag::GenerationService` builds the prompt (system prompt → context → history → question) and calls GPT-4o
8. The assistant `Message` is updated with the response content and source metadata

## Data flow: ingesting a document

1. Admin uploads a file via `DocumentsController#create`
2. A `Document` record is created with `status: :pending`
3. `Documents::IngestJob.perform_later` is enqueued
4. `Documents::IngestJob` runs:
   a. Updates document to `status: :processing`
   b. `TextExtractorService` extracts plain text
   c. `ChunkingService` splits text into overlapping chunks
   d. `Documents::EmbedService` calls `Rag::EmbedService` per chunk
   e. Chunks are bulk-inserted via `DocumentChunk.insert_all`
   f. Document updated to `status: :ready` with `chunks_count`
5. On any error, document is set to `status: :failed` with error message

## Technology stack

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| Web framework | Rails | 7.2 | Full-stack monolith, convention over configuration |
| Ruby | Ruby | 3.3.0 | Latest stable with YJIT |
| Database | PostgreSQL | 16+ | pgvector support, ACID, reliable |
| Vector extension | pgvector | — | Vector similarity search in same DB |
| Frontend | Hotwire (Turbo + Stimulus) | — | No separate frontend codebase |
| CSS | Tailwind CSS | — | Utility-first, rapid UI development |
| Background jobs | Sidekiq | 7.x | Battle-tested, process-based concurrency |
| Job queue | Redis | 7+ | Required by Sidekiq and ActionCable |
| Chat model | GPT-4o | — | Best reasoning for HR policy questions |
| Embedding model | text-embedding-3-small | — | Cost-optimal 1536-dim embeddings |
| Auth | Devise | — | Standard Rails authentication |
| Authz | Pundit | — | Plain-Ruby policy objects |
| File storage | ActiveStorage | — | Local dev, S3 production |
| Document parsing | pdf-reader + docx | — | Text extraction from PDF and DOCX |
| Rate limiting | rack-attack | — | Prevent abuse and control OpenAI costs |
| Pagination | Pagy | 6.5 | Fast, memory-efficient pagination |
| Markdown | Redcarpet | — | Render assistant responses |

## Key constraints

- **No microservices** — everything lives in one Rails app. Single deployment unit.
- **No SPA framework** — Hotwire only. No React, Vue, or separate frontend.
- **No public API** — no `/api/v1/` namespaces. All endpoints are consumed by Turbo.
- **No self-hosted LLMs** — OpenAI is the only AI provider. No fallback path exists.
- **No real-time WebSockets beyond Turbo Streams** — ActionCable is used only for streaming token delivery.
- **No fine-tuning** — RAG is the retrieval strategy. Fine-tuning was rejected because documents change frequently.
- **No external vector DB** — pgvector is the only vector store. Pinecone, Weaviate, Qdrant are not options.
- **No user self-registration in production** — admins create accounts. Devise's `registerable` is restricted.
