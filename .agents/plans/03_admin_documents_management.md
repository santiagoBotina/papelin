# Plan: Admin Documents Management

## Goal

Give admins a complete document management interface: view all documents, update
metadata (title, description, doc type, cert type), re-upload the underlying
file to replace stale content, delete a document (purging its S3 blob and RAG
chunks), and manually trigger re-ingestion for a failed document.

---

## Current State

| What exists | Location |
|---|---|
| `Admin::DocumentsController` — `index`, `show`, `destroy` | `app/controllers/admin/documents_controller.rb` |
| `DocumentsController` (non-admin) — `index`, `show`, `new`, `create`, `destroy` | `app/controllers/documents_controller.rb` |
| `Document` model with `status` enum: `pending`, `processing`, `ready`, `failed` | `app/models/document.rb` |
| `Documents::IngestJob` — background RAG ingestion job | `app/jobs/documents/ingest_job.rb` |
| Admin documents index view (basic table) | `app/views/admin/documents/index.html.erb` |
| Admin document show view | `app/views/admin/documents/show.html.erb` |
| Routes: `GET/DELETE /admin/documents`, `GET /admin/documents/:id` | `config/routes.rb` |

**Gaps**

1. **No `edit` / `update`**: Admin cannot fix a wrong title, wrong `doc_type`,
   or missing `cert_type` without deleting and re-uploading the whole document.

2. **No file replacement**: Updating a document's content (e.g. new policy
   version) requires delete + re-upload, losing the document's history and ID.

3. **No re-ingest trigger**: If ingestion failed, admin has no button to retry
   — they must delete and recreate the record.

4. **`destroy` does not purge the S3 file**: `@document.destroy!` deletes the
   DB record and its `DocumentChunk` records (via `dependent: :destroy`) but
   Active Storage blob cleanup depends on the background `ActiveStorage::PurgeJob`.
   On LocalStack / S3 this means the file may linger. Should call
   `@document.file.purge` explicitly before destroying.

5. **Admin index shows no `cert_type`**: The cert_type column added in the
   previous session is not visible in the admin documents table.

---

## Implementation Steps

### 1. Expand admin routes

```ruby
# config/routes.rb — inside namespace :admin
resources :documents, only: %i[index show edit update destroy] do
  member do
    post :reingest
  end
end
```

### 2. Add `edit`, `update`, `reingest` to `Admin::DocumentsController`

```ruby
before_action :set_document, only: %i[show edit update destroy reingest]

def edit; end

def update
  if @document.update(document_params)
    if params[:document][:file].present?
      @document.chunks.destroy_all
      @document.update!(status: :pending)
      Documents::IngestJob.perform_later(@document.id)
      msg = 'Documento actualizado — reingesta en proceso.'
    else
      msg = 'Documento actualizado.'
    end
    redirect_to admin_document_path(@document), notice: msg
  else
    render :edit, status: :unprocessable_entity
  end
end

def reingest
  return redirect_to(admin_document_path(@document),
                     alert: 'Solo se pueden reingestar documentos fallidos.') unless @document.failed?

  @document.chunks.destroy_all
  @document.update!(status: :pending, processing_error: nil)
  Documents::IngestJob.perform_later(@document.id)
  redirect_to admin_document_path(@document), notice: 'Reingesta iniciada.'
end

def destroy
  @document.file.purge_later if @document.file.attached?
  @document.destroy!
  redirect_to admin_documents_path, notice: 'Documento eliminado.'
end

private

def set_document
  @document = Document.find(params[:id])
end

def document_params
  permitted = params.require(:document).permit(:title, :description, :doc_type, :cert_type, :file)
  permitted[:cert_type] = nil if permitted[:cert_type].blank?
  permitted
end
```

**Key decisions**:
- When the admin uploads a new file, chunks are wiped and ingestion re-runs.
  The document `status` is reset to `pending` so the employee-facing UI shows
  it as processing, not stale.
- `purge_later` is used in `destroy` so the HTTP request returns immediately;
  S3 deletion happens in a background job.

### 3. Create `edit.html.erb` view

`app/views/admin/documents/edit.html.erb`

Render a shared `_form.html.erb` partial (or inline the form). Fields:

| Field | Input | Notes |
|---|---|---|
| `title` | `text_field` | Required |
| `description` | `text_area` rows 3 | Optional |
| `doc_type` | `select` from `Document.doc_types.keys` | Required |
| `cert_type` | `select` with blank "— Ninguno —" option | Optional; drives employee requestable types |
| `file` | `file_field` accept `.pdf,.docx,.txt,.md` | Optional on edit — leave blank to keep current file |

Below the file field, show the current file info:
```erb
<% if @document.file.attached? %>
  <p>Archivo actual: <strong><%= @document.file.filename %></strong>
     (<%= number_to_human_size(@document.file.byte_size) %>)
  </p>
  <p style="font-size:12px; color:#a1a1aa;">
    Subir un nuevo archivo reemplazará el actual y disparará una nueva ingesta de RAG.
  </p>
<% end %>
```

Style: match existing `.card`, `.input`, `.btn.btn-violet` / `.btn-emerald` patterns.

### 4. Update `show.html.erb` — add Edit and Re-ingest actions

`app/views/admin/documents/show.html.erb`

- Add "Editar documento" button → `edit_admin_document_path(@document)`.
- If `@document.failed?`, show a prominent "Reintentar ingesta" button that
  POSTs to `reingest_admin_document_path(@document)`.
- Show `cert_type` in the details card (currently missing).
- Show `processing_error` message if status is `failed`.

### 5. Update `index.html.erb` — show cert_type column and edit link

`app/views/admin/documents/index.html.erb`

- Add a "Tipo cert." column showing the `cert_type` badge or "—" if nil.
- Replace the existing "Ver" link with "Ver" + "Editar" quick links per row.
- Show a re-ingest icon button for failed documents inline.

### 6. Fix `destroy` in non-admin `DocumentsController`

`app/controllers/documents_controller.rb`

Apply the same `purge_later` fix so user-initiated deletes also clean up S3:

```ruby
def destroy
  @document = Document.find(params[:id])
  authorize @document
  @document.file.purge_later if @document.file.attached?
  @document.destroy!
  redirect_to documents_path, notice: 'Document deleted.'
end
```

---

## RAG consistency considerations

When a document is re-ingested:
- All existing `DocumentChunk` records for that document are deleted first
  (`@document.chunks.destroy_all`).
- The `Rag::EmbedService` (called inside `Documents::IngestJob`) creates fresh
  chunks from the new file content.
- Any in-flight queries that reference the old chunks will get stale context
  for their current response only — the next query will use the updated chunks.

When a document is deleted:
- `DocumentChunk` records are removed via `dependent: :destroy` on the model.
- The pgvector embeddings table (`document_chunks`) is pruned automatically.
- The S3 blob is purged via `file.purge_later`.

---

## Files to create / modify

| Action | File |
|---|---|
| Modify | `config/routes.rb` |
| Modify | `app/controllers/admin/documents_controller.rb` |
| Modify | `app/controllers/documents_controller.rb` (purge_later fix) |
| Create | `app/views/admin/documents/edit.html.erb` |
| Modify | `app/views/admin/documents/show.html.erb` |
| Modify | `app/views/admin/documents/index.html.erb` |
