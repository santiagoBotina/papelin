# ADR-0007: RAG Architecture for Grounded Responses

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

An LLM answering questions about company-specific certificate processes without access to internal documents would hallucinate procedures, timelines, and requirements. Users need accurate, trustworthy answers grounded in authoritative company documents.

## Decision

Implement Retrieval-Augmented Generation (RAG): embed all company documents, retrieve the most relevant chunks at query time via cosine similarity search on pgvector, and inject them into the prompt as context. The system prompt explicitly instructs the model to answer only from provided context and to decline answering when context is insufficient.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **RAG with pgvector** (chosen) | Grounded in actual company documents; no retraining needed when documents change; retrieved chunks can be cited as sources | Requires a retrieval pipeline; answer quality depends on chunk quality; adds latency |
| Fine-tuning GPT-4o on company documents | No retrieval step at inference time; model internalizes the knowledge | Expensive retraining on each document update; cannot cite specific sources; model may still hallucinate on edge cases |
| Function calling to a structured database | Deterministic answers for structured data; no hallucination risk | Cannot answer open-ended questions about unstructured documents; requires rigorous schema design |
| Prompt-only (no RAG) | Simplest implementation; no vector store needed | Completely unreliable for company-specific information; hallucination rate unacceptable |
| Hybrid RAG (vector + keyword search) | Better recall; handles edge cases where embedding fails | More complex retrieval pipeline; two retrieval systems to maintain |

## Consequences

**Positive:**
- The system prompt rule ("answer ONLY from context") is a safety invariant, not a suggestion — it prevents hallucination
- When no relevant chunks exist, the model is instructed to say so — not guess
- Retrieved chunks are cited as sources, providing transparency and auditability
- Document updates take effect after re-ingestion — no retraining needed
- Each retrieved chunk includes its source document title, enabling the model to cite sources

**Negative / trade-offs:**
- Document updates take effect after re-ingestion — not immediately
- Fine-tuning was rejected: it is expensive, requires retraining on each document update, and cannot be versioned as easily as the document store
- `TOP_K = 5` and `SIMILARITY_THRESHOLD = 0.65` are tunable constants — their values affect both answer quality and prompt token cost
- RAG adds 200–500ms of latency per query for the retrieval step
- Chunking quality directly affects retrieval quality — poorly chunked content produces poor answers
- The system prompt and retrieved context must fit within the model's context window (currently capped at 6000 tokens for context)

## References
- https://arxiv.org/abs/2005.11401 (RAG paper)
- https://www.promptingguide.ai/techniques/rag
