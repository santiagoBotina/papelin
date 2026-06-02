# ADR-0003: OpenAI GPT-4o and text-embedding-3-small

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

The RAG pipeline requires two OpenAI capabilities: embedding documents and user queries into vectors for similarity search, and generating grounded natural-language responses from retrieved context. Multiple models are available for each task.

## Decision

Use `text-embedding-3-small` (1536 dimensions) for all embeddings and `gpt-4o` for chat completion. Both are consumed via the `ruby-openai` gem. The same embedding model is used for both document chunking and query embedding — they must never diverge.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **text-embedding-3-small + gpt-4o** (chosen) | Cost-optimal embedding; best reasoning in chat; structured outputs support; 1536 dims sufficient for retrieval quality | Primary operational cost is OpenAI API; no fallback if API is down |
| text-embedding-3-large + gpt-4o | Higher embedding quality (3072 dims) | 2x embedding cost; larger vector storage; marginal quality gain for internal document retrieval |
| text-embedding-ada-002 + gpt-4o | Well-known; battle-tested | Deprecated by OpenAI; same cost as 3-small with lower quality |
| text-embedding-3-small + gpt-4o-mini | Lower chat cost | Reduced reasoning capability; more hallucination on nuanced HR policy questions |
| Open-source models (BERT, all-MiniLM, Llama) via self-hosted | No API cost; data privacy; offline operation | Infrastructure cost (GPU); maintenance burden; lower quality than GPT-4o; embedding dimension mismatch with pgvector defaults |

## Consequences

**Positive:**
- Query embeddings and chunk embeddings always use the same model, ensuring consistent vector space
- `text-embedding-3-small` at 1536 dims is the cost-optimal choice for this document scale
- `gpt-4o` provides excellent reasoning for interpreting nuanced HR policy questions
- Streaming API enables token-by-token delivery to the chat UI

**Negative / trade-offs:**
- A model change requires full re-embedding of all stored chunks (noted in ADR-0002)
- `gpt-4o` cost is the primary operational expense — rate limiting via `rack-attack` is both a security and a cost-control measure
- No self-hosted or open-source model path exists without a significant architecture change
- OpenAI API availability is an external dependency — if OpenAI is down, the chat feature is unavailable

## References
- https://platform.openai.com/docs/models/gpt-4o
- https://platform.openai.com/docs/models/embeddings
- https://github.com/alexrudall/ruby-openai
