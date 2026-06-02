# Document Ingestion Pipeline

## Overview

When an admin uploads a document, it goes through an asynchronous pipeline: text extraction → chunking → embedding → persistence. The pipeline runs inside `Documents::IngestJob` on the `:ingestion` Sidekiq queue. A document progresses through states: `pending` → `processing` → `ready` (or `failed`).

## Pipeline stages

### 1. Upload and validation

| Property | Value |
|----------|-------|
| Controller | `DocumentsController#create` |
| Model validation | Content type (PDF/DOCX/TXT/Markdown), size (< 20MB), title presence |
| Initial status | `pending` |
| Job enqueued | `Documents::IngestJob.perform_later(document.id)` |

The controller creates a `Document` record with `status: :pending`, attaches the file via ActiveStorage, and enqueues the ingestion job. The UI immediately shows the document as "Processing..."

### 2. Text extraction

| Property | Value |
|----------|-------|
| Service | `Documents::TextExtractorService` |
| Input | `Document` with attached file |
| Output | Plain text string |

Supported formats and extraction methods:

| Format | MIME type | Extraction method |
|--------|-----------|-------------------|
| PDF | `application/pdf` | `pdf-reader` gem — concatenates all pages |
| DOCX | `application/vnd.openxmlformats-officedocument.wordprocessingml.document` | `docx` gem — concatenates all paragraphs |
| TXT | `text/plain` | Raw download, force UTF-8 encoding |
| Markdown | `text/markdown` | Raw download, force UTF-8 encoding |

Extracted text is sanitized: null bytes (`\x00`) and control characters (except `\n`, `\r`, `\t`) are stripped.

**Failure mode:** Returns `success?: false` if no file is attached, the content type is unsupported, or extraction encounters an error (malformed PDF, etc.).

### 3. Chunking

| Property | Value |
|----------|-------|
| Service | `Documents::ChunkingService` |
| Input | Plain text string + `Document` record |
| Output | Array of chunk hashes |
| `CHUNK_SIZE` | 2000 characters |
| `CHUNK_OVERLAP` | 200 characters |

Uses a fixed-size sliding window. Text is split into segments of ~2000 characters with a 200-character overlap between consecutive chunks. This approximates ~500 tokens per chunk with ~50 tokens of overlap.

The overlap ensures that sentence boundaries near the cut point have a high chance of being captured in at least one chunk, preserving semantic continuity.

Each chunk hash includes:
```ruby
{
  document_id: @document.id,
  content: chunk_text,
  chunk_index: position_in_document,
  metadata: { char_start: N, char_end: M, source: document.title }.to_json,
  created_at: Time.current,
  updated_at: Time.current
}
```

**Failure mode:** Returns an empty array if the text is blank.

### 4. Embedding

| Property | Value |
|----------|-------|
| Service | `Documents::EmbedService` |
| Input | Array of chunk hashes (from `ChunkingService`) |
| Output | Array of chunk hashes enriched with `:embedding` key |
| Model | `text-embedding-3-small` (via `Rag::EmbedService`) |
| Dimensions | 1536 |

Each chunk's content is sent to `Rag::EmbedService.call(text: chunk_content)`. The returned 1536-dim embedding vector is merged into the chunk hash. Embedding is sequential (one API call per chunk) — no batching.

**Failure mode:** If any single chunk fails to embed, the entire ingestion fails (no partial results). An `EmbeddingFailedError` is raised internally and caught, returning `success?: false`.

### 5. Persistence

| Property | Value |
|----------|-------|
| Method | `DocumentChunk.insert_all` |
| Document status | Updated to `:ready` with `chunks_count` |

All chunks (with embeddings) are bulk-inserted via `DocumentChunk.insert_all`, bypassing ActiveRecord callbacks for performance. DB-level constraints (foreign keys, NOT NULL) ensure integrity.

If `embed_result.chunks` is empty (document produced no chunks after extraction), the document is still marked as `:ready` with `chunks_count: 0`.

## Chunking strategy

```
Document text:
[--- 2000 chars ---][--- 2000 chars ---][--- 2000 chars ---]
                    ^ 200 overlap       ^ 200 overlap
Chunk 1: [--- 2000 chars ---]
Chunk 2:          [--- 2000 chars ---]
Chunk 3:                           [--- 2000 chars ---]
```

Character count (~2000 chars) approximates token count (~500 tokens) for Spanish/English text. This is a heuristic — exact token counting would require a tokenizer. The approximation is sufficient for this use case; chunk quality is validated by retrieval performance.

## Accepted file types

| MIME type | Extension | Library | Notes |
|-----------|-----------|---------|-------|
| `application/pdf` | `.pdf` | `pdf-reader` | Handles scanned PDFs poorly (no OCR) |
| `application/vnd.openxmlformats-officedocument.wordprocessingml.document` | `.docx` | `docx` | Modern Word format only (not `.doc`) |
| `text/plain` | `.txt` | — | UTF-8 encoded |
| `text/markdown` | `.md` | — | UTF-8 encoded |

## Status lifecycle

```
                 ┌──────────┐
                 │  pending  │
                 └─────┬─────┘
                       │ Documents::IngestJob starts
                       ▼
                 ┌────────────┐
          ┌──────│ processing │──────┐
          │      └────────────┘      │
          │  success                 │ error
          ▼                          ▼
     ┌─────────┐              ┌──────────┐
     │  ready   │              │  failed  │
     └─────────┘              └──────────┘
```

Transitions:
- `pending` → `processing`: when `IngestJob` begins execution
- `processing` → `ready`: when all chunks are successfully embedded and persisted
- `processing` → `failed`: when any stage of the pipeline errors

A document in `ready` or `failed` status is skipped by the idempotency guard in `IngestJob`.

## Re-ingestion

To re-ingest a document (e.g., after file update or embedding model change):

1. Admin navigates to the document in the admin panel
2. Clicks "Re-ingest" (triggers `Admin::DocumentsController#reingest`)
3. Existing chunks are deleted
4. A new `Documents::IngestJob` is enqueued
5. The document is processed from scratch

This is also required if the embedding model is ever changed from `text-embedding-3-small` — all documents must be re-ingested to produce vectors in the new embedding space.

## Monitoring

In the admin dashboard and Sidekiq Web UI:

| What to check | Where | Healthy state |
|---------------|-------|---------------|
| Queue depth | Sidekiq Web UI → Queues | `ingestion` queue is near empty |
| Failed jobs | Sidekiq Web UI → Retries / Dead | Zero failed ingestion jobs |
| Document status | `Admin::Dashboard#show` | All documents are `:ready` |
| Processing errors | Document show page in admin | `processing_error` is nil for `:ready` documents |
| Chunks count | Document show page in admin | Non-zero for non-empty documents |
