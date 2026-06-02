# Plan: Admin Certificate Requests Management

## Goal

When an admin views a certificate request detail page they should be able to:
1. Change the request status through its full lifecycle.
2. Upload (or replace) the generated certificate file for the employee to download.
3. See a clear audit of the current state, the attached file, and the employee.

Both operations (status update and file upload) must work independently — the
admin should not be forced to upload a file in order to change a status, and
vice versa.

---

## Current State

| What exists | Location |
|---|---|
| `Admin::CertificateRequestsController` with `index`, `show`, `update` | `app/controllers/admin/certificate_requests_controller.rb` |
| `update` handles file attach + status change in a single PATCH | same file |
| `show.html.erb` — combined file-upload + status-change form | `app/views/admin/certificate_requests/show.html.erb` |
| `has_one_attached :generated_file` on `CertificateRequest` | `app/models/certificate_request.rb` |
| Status enum: `submitted`, `in_review`, `ready`, `rejected`, `delivered` | same model |

**Gaps / issues with current implementation**

1. **Single combined form**: One `<form multipart: true>` sends both the file
   and the status together. If admin only wants to change status without
   touching the file, the file field is empty and the file is not replaced —
   this works, but the UX is confusing (no visual separation of concerns).

2. **No `expected_ready_at` field**: Admin cannot set the estimated ready date
   from the UI — employees see "TBD" in their requests list.

3. **No notes/feedback field**: Admin cannot leave a rejection reason or
   internal note visible to the employee.

4. **File replacement UX**: Attaching a new file silently replaces the old one
   with no confirmation. If S3 is the storage backend, the old blob is not
   purged automatically (it stays in the bucket until `ActiveStorage::Blob`
   cleanup runs).

5. **No flash notice styling**: The current show view uses raw Tailwind utility
   classes inconsistent with the rest of the app's card/badge/btn CSS patterns.

---

## Implementation Steps

### 1. Split the show view into two dedicated sections

`app/views/admin/certificate_requests/show.html.erb`

**Section A — Request info** (read-only details card):
- Reference number, employee name (linked to admin user page), cert type
- Status badge, requested date, expected date, notes

**Section B — Update status** (separate small form, `PATCH`):
- Status select (`CertificateRequest.statuses.keys`)
- `expected_ready_at` date field
- Optional `admin_notes` textarea (rejection reason, etc.)
- Submit: "Actualizar estado"

**Section C — Certificate file** (separate `multipart: true` form, `PATCH`):
- If file attached: show filename, size, download link + "Reemplazar" toggle
- File input (always visible or behind a toggle)
- Auto-set status to `ready` checkbox ("Marcar como listo al subir")
- Submit: "Subir certificado"

Each section posts to `admin_certificate_request_path` via PATCH but can be
identified by a hidden `_action` param or split into separate controller actions.
**Recommendation**: Use a hidden `update_action` param (`status_update` vs
`file_upload`) — keeps a single `update` route, avoids adding member routes.

### 2. Update the controller `update` action

```ruby
def update
  case params[:update_action]
  when 'file_upload'
    handle_file_upload
  when 'status_update'
    handle_status_update
  else
    head :bad_request
  end
end

private

def handle_file_upload
  file = params.dig(:certificate_request, :generated_file)
  return redirect_to(admin_certificate_request_path(@certificate_request),
                     alert: 'No se seleccionó ningún archivo.') unless file.present?

  @certificate_request.generated_file.attach(file)

  if params[:mark_ready] == 'true'
    @certificate_request.update!(status: :ready)
  end

  redirect_to admin_certificate_request_path(@certificate_request),
              notice: 'Archivo subido correctamente.'
end

def handle_status_update
  attrs = status_update_params
  if @certificate_request.update(attrs)
    redirect_to admin_certificate_request_path(@certificate_request),
                notice: 'Estado actualizado.'
  else
    render :show, status: :unprocessable_entity
  end
end

def status_update_params
  params.require(:certificate_request)
        .permit(:status, :expected_ready_at, :admin_notes)
end
```

### 3. Add `admin_notes` and `expected_ready_at` to the model (if not present)

Check `db/schema.rb` — if `expected_ready_at` and `admin_notes` columns do not
exist, generate a migration:

```ruby
add_column :certificate_requests, :admin_notes, :text
# expected_ready_at may already exist — verify before adding
```

Add to model:
```ruby
validates :admin_notes, length: { maximum: 1000 }, allow_blank: true
```

### 4. Show `admin_notes` to the employee on their show page

`app/views/certificate_requests/show.html.erb` — add a conditional block:

```erb
<% if @certificate_request.admin_notes.present? %>
  <div style="...informational card...">
    <p>Nota de RRHH: <%= @certificate_request.admin_notes %></p>
  </div>
<% end %>
```

### 5. Purge old blob when file is replaced

In `handle_file_upload`, before attaching the new file:

```ruby
@certificate_request.generated_file.purge if @certificate_request.generated_file.attached?
```

`purge` removes both the `ActiveStorage::Blob` record and the file from S3,
avoiding orphaned objects in the bucket.

---

## Status lifecycle reference

```
submitted → in_review → ready → delivered
              ↓
           rejected
```

Admin should be able to move to any status (no enforced transitions in the
controller — RRHH may need to revert). Validation of sensible transitions is
a UX concern, not a hard constraint.

---

## Files to create / modify

| Action | File |
|---|---|
| Modify | `app/controllers/admin/certificate_requests_controller.rb` |
| Modify | `app/views/admin/certificate_requests/show.html.erb` |
| Modify | `app/views/certificate_requests/show.html.erb` (show admin_notes to employee) |
| Migration (if needed) | `add_admin_notes_to_certificate_requests` |
| Modify (if migration added) | `app/models/certificate_request.rb` |
