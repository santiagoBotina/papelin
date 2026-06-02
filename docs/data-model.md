# Data Model

## Entity overview

Papelin has 7 main entities: `User`, `Conversation`, `Message`, `Document`, `DocumentChunk`, `CertificateRequest`, and `CertificateType`. Users own conversations and certificate requests. Documents are uploaded by admin users and broken into chunks with embedding vectors for semantic search.

## Entity reference

### users

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `email` | `string` | NOT NULL, unique | Devise auth column |
| `encrypted_password` | `string` | NOT NULL | Devise auth column |
| `reset_password_token` | `string` | Unique | Devise recoverable |
| `first_name` | `string` | NOT NULL | |
| `last_name` | `string` | NOT NULL | |
| `role` | `integer` | NOT NULL, default: 0 | Enum: `employee` (0), `admin` (1) |
| `employee_id` | `string` | NOT NULL, unique | Internal company ID |

**Associations:**
- `has_many :conversations` (dependent: :destroy)
- `has_many :documents` (foreign_key: :uploaded_by_id, dependent: :nullify)
- `has_many :certificate_requests` (dependent: :nullify)

**Indexes:** `email` (unique), `employee_id` (unique), `reset_password_token` (unique)

### conversations

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `user_id` | `bigint` | NOT NULL, FK → users | |
| `title` | `string` | | Auto-generated from first message |
| `status` | `integer` | NOT NULL, default: 0 | Enum: `active` (0), `archived` (1) |

**Associations:**
- `belongs_to :user`
- `has_many :messages` (dependent: :destroy, ordered by `created_at`)

**Indexes:** `[user_id, created_at]`, `[user_id, status]`, `user_id`

### messages

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `conversation_id` | `bigint` | NOT NULL, FK → conversations | |
| `role` | `integer` | NOT NULL | Enum: `user` (0), `assistant` (1), `system` (2) |
| `content` | `text` | NOT NULL, default: "" | User message or assistant response |
| `metadata` | `jsonb` | NOT NULL, default: {} | Sources cited, token usage, error info |
| `status` | `integer` | NOT NULL, default: 0 | Enum: `pending` (0), `streaming` (1), `completed` (2), `failed` (3) |

**Associations:**
- `belongs_to :conversation` (touch: true)

**Indexes:** `[conversation_id, created_at]`, `[conversation_id, role]`, `conversation_id`

**Notable methods:**
- `append_content!(token)` — SQL-concatenation hot path for streaming tokens
- `sources` — extracts source titles from metadata
- `mark_failed!(error)` — sets status to `:failed` with error in metadata

### documents

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `uploaded_by_id` | `bigint` | NOT NULL, FK → users | Admin who uploaded |
| `title` | `string` | NOT NULL | Display name |
| `description` | `text` | | Optional description |
| `doc_type` | `integer` | NOT NULL | Enum: `policy` (0), `procedure` (1), `faq` (2), `template` (3) |
| `status` | `integer` | NOT NULL, default: 0 | Enum: `pending` (0), `processing` (1), `ready` (2), `failed` (3) |
| `processing_error` | `text` | | Error message if `failed` |
| `chunks_count` | `integer` | NOT NULL, default: 0 | Counter cache |
| `cert_type` | `integer` | Nullable | Enum: `payroll` (0), `labor` (1), `employment` (2), `other` (3) |

**Attachments:** `has_one_attached :file`

**Associations:**
- `belongs_to :uploaded_by` (class_name: 'User')
- `has_many :chunks` (class_name: 'DocumentChunk', dependent: :destroy)

**Indexes:** `uploaded_by_id`, `[uploaded_by_id, created_at]`, `doc_type`, `status`, `cert_type`

**Validations:** file content type in ALLOWED list, file size < 20MB, title presence, doc_type presence

### document_chunks

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `document_id` | `bigint` | NOT NULL, FK → documents | |
| `content` | `text` | NOT NULL | Raw chunk text (used in prompt) |
| `chunk_index` | `integer` | NOT NULL | Position within document (0-based) |
| `embedding` | `vector(1536)` | | pgvector column, text-embedding-3-small |
| `metadata` | `jsonb` | NOT NULL, default: {} | `char_start`, `char_end`, `source` |

**Associations:**
- `belongs_to :document`
- `has_neighbors :embedding` (from the `neighbor` gem)

**Indexes:** `document_id`, `[document_id, chunk_index]` (unique), IVFFlat on `embedding` with cosine ops

**Notable methods:**
- `source_title` — delegates to `document.title`
- `for_ready_documents` scope — joins to documents with `status: :ready`

### certificate_requests

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `user_id` | `bigint` | NOT NULL, FK → users | |
| `cert_type` | `integer` | NOT NULL | Enum: `payroll` (0), `labor` (1), `employment` (2), `other` (3) |
| `status` | `integer` | NOT NULL, default: 0 | Enum: `submitted` (0), `in_review` (1), `ready` (2), `rejected` (3), `delivered` (4) |
| `requested_at` | `date` | NOT NULL | |
| `expected_ready_at` | `date` | | |
| `ready_at` | `date` | | |
| `notes` | `text` | | Employee notes |
| `admin_notes` | `text` | | Admin notes (max 1000 chars) |
| `reference_number` | `string` | NOT NULL, unique | Format: `CR-YYYY-NNNNN` |

**Attachments:** `has_one_attached :generated_file`

**Associations:**
- `belongs_to :user`

**Indexes:** `user_id`, `[user_id, status]`, `[user_id, cert_type]`, `status`, `reference_number` (unique)

**Notable methods:**
- `overdue?` — true if not delivered/rejected and expected date is past
- `human_status` — human-readable status string (ready → "Ready for download")
- `self.generate_reference` — generates `CR-YYYY-COUNTER` format
- `available_cert_types` — returns active certificate type keys from `CertificateType`

### certificate_types

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `key` | `string` | NOT NULL, unique | Machine name (e.g., `payroll`) |
| `label` | `string` | NOT NULL | Display name (e.g., "Certificado de Nómina") |
| `description` | `text` | | Optional description |
| `active` | `boolean` | NOT NULL, default: false | Controls availability to employees |

**Indexes:** `key` (unique), `active`

**Seed data:** 4 default types: payroll, labor, employment, other

## Key relationships

```
User ──has_many──▶ Conversation ──has_many──▶ Message
  │                    │
  │                    │
  │                    ▼
  │              (messages ordered by created_at)
  │
  ├──has_many──▶ CertificateRequest
  │                 │
  │                 └──has_one_attached :generated_file
  │
  └──has_many──▶ Document (as uploaded_by)
                    │
                    └──has_many──▶ DocumentChunk
                                    │
                                    └──vector:embedding (pgvector)
```

## Notable design decisions

- **Money is not stored** — certificate amounts are handled as free text in document content, not as structured data. The app answers questions about processes, not financial transactions.
- **Metadata is JSONB** — on `messages` (sources, token usage) and `document_chunks` (char positions, source). JSONB provides flexibility without schema migrations for evolving metadata needs.
- **Reference number is app-generated** (`CR-YYYY-NNNNN`) — not a DB sequence. This gives human-readable IDs that can be referenced in conversations. Format: `CR` prefix + year + zero-padded counter.
- **Role is an integer enum** — not a string. ActiveRecord enums with integer backing are more performant and use less storage than strings. The mapping is explicit in the model.
- **CertificateType is a separate table** — not a hardcoded enum. Admins can activate/deactivate certificate types without code changes. The 4 seed types match the `certificate_requests.cert_type` enum values.

## Vector column

The `embedding` column on `document_chunks` uses the `vector` type from pgvector with a limit of 1536 dimensions (matching `text-embedding-3-small`).

Index: `index_document_chunks_on_embedding_ivfflat` using IVFFlat (Inverted File with Flat Compression) with `vector_cosine_ops` — optimized for cosine distance queries.

The `neighbor` gem provides the `nearest_neighbors` scope that queries this index:
```ruby
DocumentChunk.nearest_neighbors(:embedding, query_vector, distance: 'cosine').first(5)
```

Cosine distance is used because it measures semantic similarity regardless of vector magnitude — appropriate for comparing text embeddings where absolute magnitude is not meaningful.
