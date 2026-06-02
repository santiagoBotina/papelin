# Plan: Admin Certificate Types Management

## Goal

Give admins a full CRUD interface for `CertificateType` records, replacing the
current read-only toggle-only index. Admins must be able to create new types,
edit existing ones, and activate/deactivate them. Deactivating a type hides it
from employees but does not delete historical requests.

---

## Current State

| What exists | Location |
|---|---|
| `certificate_types` table | `db/migrate/20260602152625_create_certificate_types.rb` |
| `CertificateType` model (key, label, description, active) | `app/models/certificate_type.rb` |
| Admin controller — `index` + `update` (toggle only) | `app/controllers/admin/certificate_types_controller.rb` |
| Admin index view (toggle buttons only) | `app/views/admin/certificate_types/index.html.erb` |
| Route: `GET /admin/certificate_types`, `PATCH /admin/certificate_types/:id` | `config/routes.rb` |

**Gaps**
- No `new` / `create` actions → admin cannot add types beyond the 4 seeded ones.
- No `edit` / `update` (full) → admin cannot rename a label or change description.
- No `destroy` action (with guard to block deletes that have associated requests).
- The `update` action only handles the `active` toggle, not arbitrary attribute changes.

---

## Implementation Steps

### 1. Expand routes

```ruby
# config/routes.rb — inside namespace :admin
resources :certificate_types, only: %i[index new create edit update destroy]
```

### 2. Add `new`, `create`, `edit`, `update` (full), `destroy` to controller

File: `app/controllers/admin/certificate_types_controller.rb`

```ruby
before_action :set_certificate_type, only: %i[edit update destroy]

def new
  @certificate_type = CertificateType.new
end

def create
  @certificate_type = CertificateType.new(certificate_type_params)
  if @certificate_type.save
    redirect_to admin_certificate_types_path, notice: "Tipo \"#{@certificate_type.label}\" creado."
  else
    render :new, status: :unprocessable_entity
  end
end

def edit; end

def update
  if @certificate_type.update(certificate_type_params)
    redirect_to admin_certificate_types_path, notice: "Tipo \"#{@certificate_type.label}\" actualizado."
  else
    render :edit, status: :unprocessable_entity
  end
end

def destroy
  if @certificate_type.certificate_requests.exists?
    redirect_to admin_certificate_types_path,
                alert: "No se puede eliminar — hay solicitudes asociadas a este tipo."
  else
    @certificate_type.destroy!
    redirect_to admin_certificate_types_path, notice: "Tipo eliminado."
  end
end

private

def certificate_type_params
  params.require(:certificate_type).permit(:key, :label, :description, :active)
end
```

**Note**: The `active` toggle `update` action (the old boolean-only PATCH) can be
removed and consolidated into the full `update` action — the index view simply
sends `{ certificate_type: { active: true/false } }` via the same PATCH route.

### 3. `CertificateType` model — add association guard

```ruby
# app/models/certificate_type.rb
has_many :certificate_requests, foreign_key: :cert_type, primary_key: :key
```

**Important**: `CertificateRequest.cert_type` is a Rails enum stored as an integer.
The association cannot be a real FK join. Instead, add a model validation:

```ruby
validate :not_destroyable_with_requests, on: :destroy_check

def has_associated_requests?
  CertificateRequest.where(cert_type: CertificateRequest.cert_types[key]).exists?
end
```

Use this helper in the controller `destroy` action (see step 2).

### 4. Add `new.html.erb` and `edit.html.erb` views

Location: `app/views/admin/certificate_types/`

Both views render a shared `_form.html.erb` partial. Fields:

| Field | Input type | Notes |
|---|---|---|
| `key` | `text_field` | Lowercase, no spaces (hint: "e.g. payroll"). Readonly on edit since existing requests reference it. |
| `label` | `text_field` | Display name shown to employees |
| `description` | `text_area` rows 2 | Shown in the employee request form |
| `active` | `check_box` | Employees can request this type when checked |

Styling: match existing card + `.input` + `.btn.btn-violet` patterns from the app.

Make `key` field `readonly` (and visually muted) on the `edit` form, since
changing the key would orphan existing `CertificateRequest` enum values.

### 5. Update index view

`app/views/admin/certificate_types/index.html.erb`

- Replace the single "Habilitar/Deshabilitar" button column with two action
  links: "Editar" → `edit_admin_certificate_type_path(ct)` and a toggle form.
- Add a "Nuevo tipo" button in the page header → `new_admin_certificate_type_path`.
- Add a "Eliminar" button that is disabled (greyed out with tooltip) when
  `has_associated_requests?` returns true.

---

## Validations to enforce

| Rule | Where |
|---|---|
| `key` uniqueness (case-insensitive) | Model validation |
| `key` format: lowercase letters + underscores only | Model: `format: { with: /\A[a-z_]+\z/ }` |
| `label` presence | Already exists |
| `key` readonly after creation | Controller: strip `key` from `certificate_type_params` on update |

---

## Edge cases

- **Deactivating a type that has in-progress requests**: Allowed — deactivation
  only blocks *new* requests. Existing ones continue through their lifecycle.
- **Deleting a type with no requests**: Allowed.
- **Deleting a type with requests**: Blocked with a clear flash message.
- **Key collision**: Uniqueness validation on model + DB unique index already present.

---

## Files to create / modify

| Action | File |
|---|---|
| Modify | `config/routes.rb` |
| Modify | `app/controllers/admin/certificate_types_controller.rb` |
| Modify | `app/models/certificate_type.rb` |
| Create | `app/views/admin/certificate_types/_form.html.erb` |
| Create | `app/views/admin/certificate_types/new.html.erb` |
| Create | `app/views/admin/certificate_types/edit.html.erb` |
| Modify | `app/views/admin/certificate_types/index.html.erb` |
