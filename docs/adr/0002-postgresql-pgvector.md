# ADR-0002: PostgreSQL with pgvector for Vector Storage

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

The RAG pipeline requires storing and querying 1536-dimensional embedding vectors for semantic similarity search. Options range from adding a dedicated vector database to extending the existing PostgreSQL instance with the pgvector extension.

## Decision

Use PostgreSQL 16 with the pgvector extension as the sole data store for both relational data and vector embeddings. The `neighbor` gem provides ActiveRecord integration for nearest-neighbor queries.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **pgvector** (chosen) | Zero additional infrastructure — same DB for relational + vector data; ACID guarantees across both in the same transaction; familiar tooling for developers | IVFFlat index accuracy decreases at extreme scale; re-embedding all chunks required if embedding model changes |
| Pinecone | Fully managed vector DB; excellent performance at scale; no index tuning needed | Additional infrastructure cost; data sovereignty concerns; separate query API from ActiveRecord |
| Weaviate | Built-in chunking and embedding; hybrid search (vector + keyword); horizontal scaling | Extra service to manage; learning curve for GraphQL API; operational overhead for an internal tool |
| Qdrant | High-performance ANN; filtering with payload indexing; Rust-based performance | Same drawbacks as other external vector DBs — extra infra, separate API, operational cost |
| Chroma | Simple; local-first; Python-native | Not production-grade at the time of evaluation; limited query capabilities; Python-only for some features |

## Consequences

**Positive:**
- Zero additional infrastructure — same PostgreSQL DB handles all data
- ACID guarantees across relational and vector data in the same transaction
- `neighbor` gem provides idiomatic ActiveRecord integration (`has_neighbors`, `.nearest_neighbors`)
- IVFFlat index with cosine distance provides good ANN performance at company document scale (thousands to low millions of chunks)

**Negative / trade-offs:**
- At extreme scale (millions of chunks), a dedicated vector DB would outperform pgvector — this threshold is far beyond current requirements
- Re-embedding all chunks is required if the embedding model changes (noted in ADR-0003)
- IVFFlat index requires periodic re-indexing for optimal performance as data grows
- No pure keyword/BM25 fallback — if embedding quality degrades, there is no text-search backup

## References
- https://github.com/pgvector/pgvector
- https://github.com/ankane/neighbor
- https://www.pgvector.org/
