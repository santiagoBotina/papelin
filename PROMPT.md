# Certificate Assistant — Application Generation Prompt

You are a senior Ruby on Rails engineer bootstrapping a production-quality Rails 7.2 monolith
from scratch. Your output is a fully working, runnable codebase — not pseudocode, not stubs,
not placeholders. Every file you create must be complete and correct.

The authoritative specification for this project lives in `AGENTS.md`. Read it fully before
writing a single file. It overrides any default intuition you have about structure, naming,
or patterns. If there is a conflict between AGENTS.md and general Rails convention,
AGENTS.md wins.

---

## Your mandate

Generate the Certificate Assistant application: a Rails 7.2 monolith that lets company
employees ask natural-language questions about internal certificate processes (payroll
certificates, labor certificates, employment letters, etc.) and receive accurate,
context-grounded answers via a RAG architecture backed by OpenAI GPT-4o.

---

## Execution rules — read before starting

### Rule 1: Plan before every phase

Before writing any code, produce a written plan for that phase (see AGENTS.md §17).
The plan must list every file to be created or modified and the exact execution order.
Store each phase plan at `tmp/plans/<phase-name>.md`.

### Rule 2: Spec-driven development is mandatory

For every class you implement, you write the spec file first, verify it is red, then
write the implementation, then verify it is green, then lint. No implementation file
may be committed without a passing spec file. Follow AGENTS.md §19 exactly.

### Rule 3: Delegate to sub-agents by phase

Each phase below is a discrete sub-agent task. Treat each phase as an isolated brief
following the sub-agent brief format in AGENTS.md §18. A sub-agent for Phase 3 must
not read files created by Phase 5 and vice versa. Each phase ends with an integration
checkpoint: run its specs, run rubocop on changed files, run `git diff --name-only`
to confirm scope was respected.

### Rule 4: Never skip a phase

The phases are ordered by dependency. Do not reorder them. Do not merge two phases
into one to save time. The ordering exists because later phases depend on earlier ones
being correct and tested.

### Rule 5: Context hygiene

Each sub-agent reads only the files listed in its brief plus AGENTS.md. It does not
read the full conversation history. It reports back a summary of ≤20 lines — no file
contents, no full test output.

---

## Phase execution order

```
Phase 0  →  Project bootstrap & configuration
Phase 1  →  Database schema & migrations
Phase 2  →  Domain models & specs
Phase 3  →  Pundit policies & specs
Phase 4  →  Service layer — Documents pipeline
Phase 5  →  Service layer — RAG pipeline
Phase 6  →  Background jobs & specs
Phase 7  →  Controllers, routes & request specs
Phase 8  →  Views & Stimulus frontend
Phase 9  →  Test infrastructure & shared helpers
Phase 10 →  Smoke test & integration check
```

---

## Phase 0 — Project Bootstrap & Configuration

**Goal**: A bootable Rails 7.2 application with all gems installed, database created,
credentials configured, and infrastructure initializers in place. No models yet.

### 0.1 Generate the Rails app

```bash
rails new certificate_assistant \
  --database=postgresql \
  --skip-test \
  --css=tailwind \
  --javascript=importmap
cd certificate_assistant
```

### 0.2 Gemfile

Replace the generated Gemfile with the following. Every gem is required — do not omit any.

```ruby
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

gem "rails", "~> 7.2.0"
gem "pg", "~> 1.5"
gem "puma", "~> 6.0"

# Hotwire
gem "turbo-rails"
gem "stimulus-rails"

# Frontend
gem "tailwindcss-rails"
gem "importmap-rails"
gem "sprockets-rails"

# Auth
gem "devise"
gem "pundit"

# AI / Vector
gem "ruby-openai", "~> 7.0"
gem "neighbor"                      # pgvector ActiveRecord integration

# File uploads
gem "active_storage_validations"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron"
gem "redis"

# Document parsing
gem "pdf-reader"
gem "docx"

# Performance & security
gem "rack-attack"
gem "pagy"

# Markdown rendering (assistant output)
gem "redcarpet"

# Utilities
gem "bootsnap", require: false

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "webmock"
  gem "vcr"
  gem "simplecov", require: false
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
  gem "dotenv-rails"
end

group :development do
  gem "bullet"
  gem "rack-mini-profiler"
  gem "letter_opener"
  gem "web-console"
end
```

Run: `bundle install`

### 0.3 Install Rails components

```bash
rails action_text:install     # rich text support (may be used later)
rails active_storage:install  # file upload tables
rails turbo:install
rails stimulus:install
```

### 0.4 Database configuration

`config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: certificate_assistant_development

test:
  <<: *default
  database: certificate_assistant_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
```

Run:
```bash
rails db:create
```

### 0.5 Enable pgvector extension

Create `db/migrate/TIMESTAMP_enable_pgvector.rb`:
```ruby
class EnablePgvector < ActiveRecord::Migration[7.2]
  def change
    enable_extension "vector"
  end
end
```

Run: `rails db:migrate`

### 0.6 Credentials structure

Run `rails credentials:edit` and set up this skeleton (fill in real values before running):

```yaml
secret_key_base: GENERATED_BY_RAILS

openai:
  api_key: sk-YOUR_KEY_HERE

redis:
  url: redis://localhost:6379/0

active_storage:
  aws_access_key_id: YOUR_KEY
  aws_secret_access_key: YOUR_SECRET
  aws_bucket: your-bucket-name
  aws_region: us-east-1
```

### 0.7 Initializers

**`config/initializers/openai.rb`**:
```ruby
require "openai"

OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.openai[:api_key]
  config.log_errors = Rails.env.development?
end
```

**`config/initializers/sidekiq.rb`**:
```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: Rails.application.credentials.dig(:redis, :url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: Rails.application.credentials.dig(:redis, :url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
```

**`config/initializers/rack_attack.rb`**:
```ruby
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: Rails.application.credentials.dig(:redis, :url) || ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
)

# Throttle message creation: max 20 per user per minute
Rack::Attack.throttle("messages/user", limit: 20, period: 60) do |req|
  if req.path == "/messages" && req.post?
    req.env["warden"]&.user&.id
  end
end

Rack::Attack.throttled_responder = lambda do |_req|
  [429, { "Content-Type" => "application/json" },
   [{ error: "Rate limit exceeded. Please wait before sending another message." }.to_json]]
end
```

**`config/initializers/pagy.rb`**:
```ruby
require "pagy/extras/array"
require "pagy/extras/overflow"
Pagy::DEFAULT[:items] = 25
Pagy::DEFAULT[:overflow] = :last_page
```

### 0.8 Application job adapter

`config/application.rb` — add inside the `Application` class:
```ruby
config.active_job.queue_adapter = :sidekiq
config.filter_parameters += [:password, :password_confirmation, :token,
                              :secret, :authorization, :api_key]
```

### 0.9 Devise install

```bash
rails generate devise:install
rails generate devise User
```

Do not run the migration yet — it will be modified in Phase 1.

### 0.10 RSpec install

```bash
rails generate rspec:install
```

Add to `spec/rails_helper.rb` (after existing requires):
```ruby
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  minimum_coverage 80
end

require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
```

**Phase 0 definition of done:**
- `rails server` starts without errors
- `rails db:migrate` runs cleanly
- `bundle exec rspec` runs (0 examples, 0 failures)
- `bundle exec rubocop` exits 0 on all generated files

---

## Phase 1 — Database Schema & Migrations

**Goal**: All tables exist in the database with correct columns, constraints, indexes,
and foreign keys. No model logic yet — schema only.

Write each migration completely. Run `rails db:migrate` after each one.
Do not batch multiple schema changes into one migration.

### 1.1 Modify Devise User migration

Find the generated Devise migration and add these columns before `t.timestamps`:

```ruby
t.string  :first_name,   null: false, default: ""
t.string  :last_name,    null: false, default: ""
t.integer :role,         null: false, default: 0
t.string  :employee_id,  null: false, default: ""
```

Also add after `create_table`:
```ruby
add_index :users, :employee_id, unique: true
```

### 1.2 Conversations table

```ruby
class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations do |t|
      t.references :user,   null: false, foreign_key: true
      t.string  :title
      t.integer :status,    null: false, default: 0
      t.timestamps
    end
    add_index :conversations, [:user_id, :status]
    add_index :conversations, [:user_id, :created_at]
  end
end
```

### 1.3 Messages table

```ruby
class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :role,            null: false
      t.text    :content,         null: false, default: ""
      t.jsonb   :metadata,        null: false, default: {}
      t.integer :status,          null: false, default: 0
      t.timestamps
    end
    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, [:conversation_id, :role]
  end
end
```

### 1.4 Documents table

```ruby
class CreateDocuments < ActiveRecord::Migration[7.2]
  def change
    create_table :documents do |t|
      t.references :uploaded_by,      null: false, foreign_key: { to_table: :users }
      t.string  :title,               null: false
      t.text    :description
      t.integer :doc_type,            null: false
      t.integer :status,              null: false, default: 0
      t.text    :processing_error
      t.integer :chunks_count,        null: false, default: 0
      t.timestamps
    end
    add_index :documents, :status
    add_index :documents, :doc_type
    add_index :documents, [:uploaded_by_id, :created_at]
  end
end
```

### 1.5 DocumentChunks table

```ruby
class CreateDocumentChunks < ActiveRecord::Migration[7.2]
  def change
    create_table :document_chunks do |t|
      t.references :document,   null: false, foreign_key: true
      t.text       :content,    null: false
      t.integer    :chunk_index, null: false
      t.vector     :embedding,  limit: 1536
      t.jsonb      :metadata,   null: false, default: {}
      t.timestamps
    end

    add_index :document_chunks, [:document_id, :chunk_index], unique: true
    # IVFFlat index for approximate nearest-neighbor search
    # NOTE: The lists value (100) should be tuned once data volume is known.
    # Rule of thumb: sqrt(num_rows). Rebuild with REINDEX when data grows 10x.
    add_index :document_chunks, :embedding,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              name: "index_document_chunks_on_embedding_ivfflat"
  end
end
```

### 1.6 CertificateRequests table

```ruby
class CreateCertificateRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :certificate_requests do |t|
      t.references :user,              null: false, foreign_key: true
      t.integer    :cert_type,         null: false
      t.integer    :status,            null: false, default: 0
      t.date       :requested_at,      null: false
      t.date       :expected_ready_at
      t.date       :ready_at
      t.text       :notes
      t.string     :reference_number,  null: false
      t.timestamps
    end

    add_index :certificate_requests, :reference_number, unique: true
    add_index :certificate_requests, [:user_id, :status]
    add_index :certificate_requests, [:user_id, :cert_type]
    add_index :certificate_requests, :status
    add_foreign_key :certificate_requests, :users
  end
end
```

Run: `rails db:migrate`

**Phase 1 definition of done:**
- `rails db:migrate` exits 0
- `rails db:schema:dump` produces a `schema.rb` that matches all tables above
- `rails db:rollback STEP=6` works cleanly (all migrations are reversible)
- `rails db:migrate` again restores full schema

---

## Phase 2 — Domain Models & Specs

**Goal**: All ActiveRecord models with validations, associations, enums, scopes, and
instance methods. Every model has a passing spec file written before its implementation.

Follow AGENTS.md §19 (SDD cycle) for each model: spec first → red → implement → green → lint.

### 2.1 User model

**Write `spec/models/user_spec.rb` first:**

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:conversations).dependent(:destroy) }
    it { is_expected.to have_many(:certificate_requests).dependent(:nullify) }
    it { is_expected.to have_many(:documents).with_foreign_key(:uploaded_by_id) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:employee_id) }
    it { is_expected.to validate_uniqueness_of(:employee_id).case_insensitive }
    it { is_expected.to validate_inclusion_of(:role).in_array(User.roles.keys) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(employee: 0, admin: 1) }
  end

  describe "#display_name" do
    it "returns full name when both are present" do
      user = build(:user, first_name: "Jane", last_name: "Doe")
      expect(user.display_name).to eq("Jane Doe")
    end

    it "falls back to email when names are blank" do
      user = build(:user, first_name: "", last_name: "", email: "j@example.com")
      expect(user.display_name).to eq("j@example.com")
    end
  end

  describe "#active_certificate_requests" do
    let(:user) { create(:user) }

    it "returns only requests that are not delivered or rejected" do
      submitted = create(:certificate_request, user: user, status: :submitted)
      delivered = create(:certificate_request, user: user, status: :delivered)
      rejected  = create(:certificate_request, user: user, status: :rejected)

      result = user.active_certificate_requests
      expect(result).to include(submitted)
      expect(result).not_to include(delivered, rejected)
    end
  end
end
```

**Then implement `app/models/user.rb`:**

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :lockable, :timeoutable

  # Enums
  enum role: { employee: 0, admin: 1 }

  # Associations
  has_many :conversations,         dependent: :destroy
  has_many :certificate_requests,  dependent: :nullify
  has_many :documents, foreign_key: :uploaded_by_id, dependent: :nullify,
           inverse_of: :uploaded_by

  # Validations
  validates :first_name,   presence: true
  validates :last_name,    presence: true
  validates :employee_id,  presence: true,
                           uniqueness: { case_sensitive: false }
  validates :role,         inclusion: { in: roles.keys }

  # Scopes
  scope :admins,    -> { where(role: :admin) }
  scope :employees, -> { where(role: :employee) }

  # Instance methods
  def display_name
    full = "#{first_name} #{last_name}".strip
    full.presence || email
  end

  def active_certificate_requests
    certificate_requests.where.not(status: [:delivered, :rejected])
  end
end
```

### 2.2 Conversation model

**Spec first** — `spec/models/conversation_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Conversation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:messages).dependent(:destroy).order(:created_at) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:user) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(active: 0, archived: 1) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active conversations" do
        active   = create(:conversation, status: :active)
        archived = create(:conversation, status: :archived)
        expect(Conversation.active).to include(active)
        expect(Conversation.active).not_to include(archived)
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        older = create(:conversation, created_at: 2.days.ago)
        newer = create(:conversation, created_at: 1.hour.ago)
        expect(Conversation.recent.first).to eq(newer)
      end
    end
  end

  describe "#generate_title_from" do
    let(:conversation) { create(:conversation, title: nil) }

    it "sets title to the first 60 chars of the given text" do
      conversation.generate_title_from("What are the required documents for a payroll certificate?")
      expect(conversation.title).to eq("What are the required documents for a payroll certificate?")
    end

    it "truncates long text with ellipsis" do
      long_text = "a" * 100
      conversation.generate_title_from(long_text)
      expect(conversation.title.length).to be <= 63 # 60 chars + "..."
    end

    it "does not overwrite an existing title" do
      conversation.update!(title: "Existing Title")
      conversation.generate_title_from("New text")
      expect(conversation.reload.title).to eq("Existing Title")
    end
  end
end
```

**Implementation** — `app/models/conversation.rb`:

```ruby
class Conversation < ApplicationRecord
  TITLE_MAX_LENGTH = 60

  belongs_to :user
  has_many :messages, -> { order(:created_at) }, dependent: :destroy, inverse_of: :conversation

  enum status: { active: 0, archived: 1 }

  validates :user, presence: true

  scope :active,  -> { where(status: :active) }
  scope :recent,  -> { order(created_at: :desc) }

  def generate_title_from(text)
    return if title.present?
    update!(title: text.truncate(TITLE_MAX_LENGTH))
  end

  def context_messages(limit: 10)
    messages.where(role: [:user, :assistant]).last(limit)
  end
end
```

### 2.3 Message model

**Spec first** — `spec/models/message_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Message, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:conversation) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:conversation) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(user: 0, assistant: 1, system: 2) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, streaming: 1, completed: 2, failed: 3) }
  end

  describe "scopes" do
    describe ".completed" do
      it "returns only completed messages" do
        completed = create(:message, status: :completed)
        pending   = create(:message, status: :pending)
        expect(Message.completed).to include(completed)
        expect(Message.completed).not_to include(pending)
      end
    end
  end

  describe "#append_content!" do
    let(:message) { create(:message, :assistant, content: "Hello") }

    it "appends a token to the content" do
      message.append_content!(" world")
      expect(message.reload.content).to eq("Hello world")
    end
  end

  describe "#sources" do
    it "returns source documents from metadata" do
      message = build(:message, metadata: { "sources" => [{ "title" => "HR Manual" }] })
      expect(message.sources).to eq([{ "title" => "HR Manual" }])
    end

    it "returns empty array when no sources" do
      message = build(:message, metadata: {})
      expect(message.sources).to eq([])
    end
  end
end
```

**Implementation** — `app/models/message.rb`:

```ruby
class Message < ApplicationRecord
  belongs_to :conversation, touch: true

  enum role: { user: 0, assistant: 1, system: 2 }
  enum status: { pending: 0, streaming: 1, completed: 2, failed: 3 }

  validates :role,         presence: true
  validates :conversation, presence: true

  scope :completed, -> { where(status: :completed) }
  scope :visible,   -> { where(role: [:user, :assistant]) }

  def append_content!(token)
    # Uses SQL concatenation to avoid a full AR reload on every streaming token.
    # This is a hot path — called once per streamed token.
    self.class.where(id: id).update_all("content = content || #{self.class.connection.quote(token)}")
  end

  def sources
    metadata.fetch("sources", [])
  end

  def mark_failed!(error_message)
    update!(status: :failed, metadata: metadata.merge("error" => error_message))
  end
end
```

### 2.4 Document model

**Spec first** — `spec/models/document_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Document, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:uploaded_by).class_name("User") }
    it { is_expected.to have_many(:chunks).class_name("DocumentChunk").dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:doc_type) }
    it { is_expected.to validate_presence_of(:uploaded_by) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:doc_type)
        .with_values(policy: 0, procedure: 1, faq: 2, template: 3)
    }
    it {
      is_expected.to define_enum_for(:status)
        .with_values(pending: 0, processing: 1, ready: 2, failed: 3)
    }
  end

  describe "scopes" do
    describe ".ready" do
      it "returns only documents with status :ready" do
        ready      = create(:document, status: :ready)
        processing = create(:document, status: :processing)
        expect(Document.ready).to include(ready)
        expect(Document.ready).not_to include(processing)
      end
    end
  end

  describe "#processing_duration" do
    it "returns nil when not yet processed" do
      doc = build(:document, status: :pending)
      expect(doc.processing_duration).to be_nil
    end
  end
end
```

**Implementation** — `app/models/document.rb`:

```ruby
class Document < ApplicationRecord
  belongs_to :uploaded_by, class_name: "User"
  has_many :chunks, class_name: "DocumentChunk", dependent: :destroy

  has_one_attached :file

  enum doc_type: { policy: 0, procedure: 1, faq: 2, template: 3 }
  enum status: { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :title,       presence: true
  validates :doc_type,    presence: true
  validates :uploaded_by, presence: true
  validates :file, content_type: {
    in: %w[application/pdf
           application/vnd.openxmlformats-officedocument.wordprocessingml.document
           text/plain],
    message: "must be a PDF, Word document, or plain text file"
  }, size: { less_than: 20.megabytes, message: "must be less than 20MB" },
     if: -> { file.attached? }

  scope :ready,      -> { where(status: :ready) }
  scope :recent,     -> { order(created_at: :desc) }
  scope :by_type,    ->(type) { where(doc_type: type) }

  def processing_duration
    return nil unless ready? || failed?
    (updated_at - created_at).round
  end

  def fail!(error)
    update!(status: :failed, processing_error: error.to_s.truncate(2000))
  end
end
```

### 2.5 DocumentChunk model

**Spec first** — `spec/models/document_chunk_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DocumentChunk, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:document) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:chunk_index) }
    it { is_expected.to validate_numericality_of(:chunk_index).is_greater_than_or_equal_to(0) }
  end

  describe "neighbor configuration" do
    it "responds to nearest_neighbors" do
      expect(DocumentChunk).to respond_to(:nearest_neighbors)
    end
  end
end
```

**Implementation** — `app/models/document_chunk.rb`:

```ruby
class DocumentChunk < ApplicationRecord
  belongs_to :document

  has_neighbors :embedding

  validates :content,     presence: true
  validates :chunk_index, presence: true,
                          numericality: { greater_than_or_equal_to: 0 }

  scope :for_ready_documents, -> {
    joins(:document).where(documents: { status: Document.statuses[:ready] })
  }

  def source_title
    document.title
  end
end
```

### 2.6 CertificateRequest model

**Spec first** — `spec/models/certificate_request_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe CertificateRequest, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:cert_type) }
    it { is_expected.to validate_presence_of(:requested_at) }
    it { is_expected.to validate_presence_of(:reference_number) }
    it { is_expected.to validate_uniqueness_of(:reference_number) }
    it { is_expected.to validate_presence_of(:user) }
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:cert_type)
        .with_values(payroll: 0, labor: 1, employment: 2, other: 3)
    }
    it {
      is_expected.to define_enum_for(:status)
        .with_values(submitted: 0, in_review: 1, ready: 2, rejected: 3, delivered: 4)
    }
  end

  describe "scopes" do
    describe ".pending_for" do
      let(:user) { create(:user) }

      it "returns only active requests for the given user" do
        active  = create(:certificate_request, user: user, status: :submitted)
        other   = create(:certificate_request, status: :submitted)
        deliver = create(:certificate_request, user: user, status: :delivered)

        result = CertificateRequest.pending_for(user)
        expect(result).to include(active)
        expect(result).not_to include(other, deliver)
      end
    end
  end

  describe "#overdue?" do
    it "returns true when expected_ready_at is in the past and not ready" do
      req = build(:certificate_request,
                  status: :submitted,
                  expected_ready_at: 1.day.ago)
      expect(req.overdue?).to be true
    end

    it "returns false when already ready" do
      req = build(:certificate_request, status: :ready, expected_ready_at: 1.day.ago)
      expect(req.overdue?).to be false
    end
  end

  describe ".generate_reference" do
    it "returns a reference in the format CR-YEAR-NNNNN" do
      ref = CertificateRequest.generate_reference
      expect(ref).to match(/\ACR-\d{4}-\d{5}\z/)
    end
  end
end
```

**Implementation** — `app/models/certificate_request.rb`:

```ruby
class CertificateRequest < ApplicationRecord
  belongs_to :user

  has_one_attached :generated_file

  enum cert_type: { payroll: 0, labor: 1, employment: 2, other: 3 }
  enum status: { submitted: 0, in_review: 1, ready: 2, rejected: 3, delivered: 4 }

  validates :cert_type,        presence: true
  validates :requested_at,     presence: true
  validates :reference_number, presence: true, uniqueness: true
  validates :user,             presence: true

  before_validation :assign_reference_number, on: :create

  scope :pending_for, ->(user) {
    where(user: user).where.not(status: [:delivered, :rejected])
  }
  scope :recent, -> { order(created_at: :desc) }

  def self.generate_reference
    year    = Date.current.year
    counter = where("created_at >= ?", Date.current.beginning_of_year).count + 1
    format("CR-%d-%05d", year, counter)
  end

  def overdue?
    return false if ready? || delivered? || rejected?
    expected_ready_at.present? && expected_ready_at < Date.current
  end

  def human_status
    {
      "submitted"  => "Submitted — Under review",
      "in_review"  => "In Review",
      "ready"      => "Ready for download",
      "rejected"   => "Rejected",
      "delivered"  => "Delivered"
    }.fetch(status, status.humanize)
  end

  private

  def assign_reference_number
    self.reference_number ||= self.class.generate_reference
  end
end
```

### 2.7 Factories

Create `spec/factories/` for all models:

**`spec/factories/users.rb`**:
```ruby
FactoryBot.define do
  factory :user do
    sequence(:email)       { |n| "user#{n}@example.com" }
    sequence(:employee_id) { |n| "EMP#{n.to_s.rjust(5, "0")}" }
    password               { "Password1!" }
    first_name             { Faker::Name.first_name }
    last_name              { Faker::Name.last_name }
    role                   { :employee }

    trait :admin do
      role { :admin }
    end
  end
end
```

**`spec/factories/conversations.rb`**:
```ruby
FactoryBot.define do
  factory :conversation do
    association :user
    title  { Faker::Lorem.sentence(word_count: 5) }
    status { :active }
  end
end
```

**`spec/factories/messages.rb`**:
```ruby
FactoryBot.define do
  factory :message do
    association :conversation
    role    { :user }
    content { "What documents do I need for a payroll certificate?" }
    status  { :completed }
    metadata { {} }

    trait :assistant do
      role    { :assistant }
      content { "To obtain a payroll certificate you will need..." }
    end

    trait :pending do
      role    { :assistant }
      status  { :pending }
      content { "" }
    end

    trait :with_sources do
      metadata { { "sources" => [{ "title" => "HR Policy Manual", "chunk_id" => 1 }] } }
    end
  end
end
```

**`spec/factories/documents.rb`**:
```ruby
FactoryBot.define do
  factory :document do
    association :uploaded_by, factory: :user, strategy: :create
    title       { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    doc_type    { :policy }
    status      { :ready }

    trait :pending    do; status { :pending }    end
    trait :processing do; status { :processing } end
    trait :ready      do; status { :ready }      end
    trait :failed     do
      status { :failed }
      processing_error { "PDF parsing failed: unexpected EOF" }
    end
  end
end
```

**`spec/factories/document_chunks.rb`**:
```ruby
FactoryBot.define do
  factory :document_chunk do
    association :document
    sequence(:chunk_index)
    content   { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    embedding { Array.new(1536) { rand(-1.0..1.0) } }
    metadata  { {} }
  end
end
```

**`spec/factories/certificate_requests.rb`**:
```ruby
FactoryBot.define do
  factory :certificate_request do
    association :user
    cert_type        { :payroll }
    status           { :submitted }
    requested_at     { Date.current }
    expected_ready_at { 5.business_days.from_now }
    sequence(:reference_number) { |n| "CR-#{Date.current.year}-#{n.to_s.rjust(5, "0")}" }

    trait :ready do
      status    { :ready }
      ready_at  { Date.current }
    end

    trait :overdue do
      status            { :submitted }
      expected_ready_at { 3.days.ago }
    end
  end
end
```

**Phase 2 definition of done:**
- `bundle exec rspec spec/models/ --format documentation` → all green
- `bundle exec rubocop app/models/` → 0 offenses

---

## Phase 3 — Pundit Policies & Specs

**Goal**: Authorization layer. Every policy covers all actions. Every permission
has both a "permitted" and a "denied" spec.

### 3.1 Application policy base

`app/policies/application_policy.rb`:

```ruby
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user
    @user   = user
    @record = record
  end

  def index?  = false
  def show?   = false
  def create? = false
  def update? = false
  def destroy? = false

  class Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, "must be logged in" unless user
      @user  = user
      @scope = scope
    end

    def resolve = raise NotImplementedError, "#{self.class}#resolve has not been implemented"

    private

    attr_reader :user, :scope
  end
end
```

### 3.2 ConversationPolicy

**Spec first** — `spec/policies/conversation_policy_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe ConversationPolicy, type: :policy do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  subject(:policy) { described_class }

  permissions :show?, :update?, :destroy? do
    it "grants access to the owner" do
      conversation = create(:conversation, user: user)
      expect(policy).to permit(user, conversation)
    end

    it "denies access to a non-owner" do
      conversation = create(:conversation, user: other)
      expect(policy).not_to permit(user, conversation)
    end
  end

  permissions :create? do
    it "grants access to any authenticated user" do
      expect(policy).to permit(user, Conversation)
    end
  end

  describe "Scope#resolve" do
    it "returns only conversations belonging to the user" do
      own   = create(:conversation, user: user)
      other_conv = create(:conversation, user: other)

      scope = Pundit.policy_scope!(user, Conversation)
      expect(scope).to include(own)
      expect(scope).not_to include(other_conv)
    end
  end
end
```

**Implementation** — `app/policies/conversation_policy.rb`:

```ruby
class ConversationPolicy < ApplicationPolicy
  def index?   = true
  def show?    = record.user == user
  def create?  = true
  def update?  = record.user == user
  def destroy? = record.user == user

  class Scope < Scope
    def resolve = scope.where(user: user)
  end
end
```

### 3.3 DocumentPolicy

**Spec first** — `spec/policies/document_policy_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DocumentPolicy, type: :policy do
  let(:employee) { create(:user) }
  let(:admin)    { create(:user, :admin) }
  let(:document) { create(:document, :ready) }

  subject(:policy) { described_class }

  permissions :index?, :show? do
    it "permits employees"  do; expect(policy).to permit(employee, document); end
    it "permits admins"     do; expect(policy).to permit(admin, document); end
  end

  permissions :create?, :destroy? do
    it "permits admins"    do; expect(policy).to permit(admin, document); end
    it "denies employees"  do; expect(policy).not_to permit(employee, document); end
  end

  describe "Scope#resolve" do
    before do
      create(:document, :ready)
      create(:document, :processing)
    end

    it "returns all documents to admins" do
      scope = Pundit.policy_scope!(admin, Document)
      expect(scope.count).to eq(Document.count)
    end

    it "returns only ready documents to employees" do
      scope = Pundit.policy_scope!(employee, Document)
      expect(scope.pluck(:status).uniq).to eq(["ready"])
    end
  end
end
```

**Implementation** — `app/policies/document_policy.rb`:

```ruby
class DocumentPolicy < ApplicationPolicy
  def index?   = true
  def show?    = true
  def create?  = user.admin?
  def update?  = user.admin?
  def destroy? = user.admin?

  class Scope < Scope
    def resolve
      user.admin? ? scope.all : scope.where(status: :ready)
    end
  end
end
```

### 3.4 CertificateRequestPolicy

**Spec** and **implementation** follow the same pattern — users see only their own requests; admins see all and can update status.

**Phase 3 definition of done:**
- `bundle exec rspec spec/policies/` → all green
- `bundle exec rubocop app/policies/` → 0 offenses

---

## Phase 4 — Service Layer: Documents Pipeline

**Goal**: The full document ingestion pipeline — text extraction, chunking, and
embedding — each as a separate tested service object.

Write specs first for each service. Stub all OpenAI calls using `spec/support/openai_helpers.rb`.

### 4.1 Create `spec/support/openai_helpers.rb`

```ruby
module OpenAIHelpers
  FAKE_EMBEDDING = Array.new(1536) { 0.01 }.freeze

  def stub_openai_embedding(embedding: FAKE_EMBEDDING)
    stub_request(:post, "https://api.openai.com/v1/embeddings")
      .to_return(
        status: 200,
        body: {
          data: [{ embedding: embedding, index: 0, object: "embedding" }],
          model: "text-embedding-3-small",
          object: "list",
          usage: { prompt_tokens: 8, total_tokens: 8 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_openai_chat(content: "Mocked assistant response.", finish_reason: "stop")
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(
        status: 200,
        body: {
          id: "chatcmpl-test",
          object: "chat.completion",
          choices: [{
            index: 0,
            message: { role: "assistant", content: content },
            finish_reason: finish_reason
          }],
          usage: { prompt_tokens: 100, completion_tokens: 50, total_tokens: 150 }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_openai_error(status: 500, message: "Internal server error")
    stub_request(:post, "https://api.openai.com/v1/embeddings")
      .to_return(status: status, body: { error: { message: message } }.to_json)
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: status, body: { error: { message: message } }.to_json)
  end
end

RSpec.configure do |config|
  config.include OpenAIHelpers
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
end
```

### 4.2 Documents::TextExtractorService

Implement `app/services/documents/text_extractor_service.rb` with specs for PDF, DOCX, and TXT extraction. Handle unsupported types gracefully (return a Result with `success?: false`).

Key methods to test and implement:
- `.call(document:)` → `Result`
- Private `extract_pdf`, `extract_docx`, `extract_txt`
- Strips null bytes and control characters from extracted text

### 4.3 Documents::ChunkingService

Implement and test `app/services/documents/chunking_service.rb`:
- Splits text into chunks of `CHUNK_SIZE = 2000` chars with `CHUNK_OVERLAP = 200`
- Returns array of hashes `{ document_id:, content:, chunk_index:, metadata:, created_at:, updated_at: }`
- Empty text returns empty array (not an error)
- Very short text (< CHUNK_SIZE) returns a single chunk

### 4.4 Rag::EmbedService

Implement and test `app/services/rag/embed_service.rb`:
- Calls OpenAI embeddings API with model `text-embedding-3-small`
- Truncates input to 8000 chars before sending
- Returns `Result.new(success?: true, embedding: [...])` on success
- Returns `Result.new(success?: false, error: "...")` on network/API failure
- Stub all HTTP calls with `stub_openai_embedding`

### 4.5 Documents::EmbedService

Thin wrapper around `Rag::EmbedService` that processes an array of chunk hashes,
adds the `embedding:` key to each, and returns them ready for `DocumentChunk.insert_all`.

**Phase 4 definition of done:**
- `bundle exec rspec spec/services/documents/ spec/services/rag/embed_service_spec.rb` → all green
- Zero real HTTP calls made (WebMock will raise if any leak through)

---

## Phase 5 — Service Layer: RAG Pipeline

**Goal**: The query-time RAG pipeline — retrieval and generation — fully implemented
and tested. This is the most critical path in the application.

### 5.1 Rag::RetrievalService

Full spec and implementation as described in AGENTS.md §7 and §19.
Test all three contexts: chunks found, no chunks above threshold, pgvector error.

### 5.2 Rag::GenerationService

Full spec and implementation. Critical spec cases (from AGENTS.md §19):
- Always sends system prompt as the first message to OpenAI
- Includes retrieved chunk content in the prompt
- Includes conversation history (last 10 messages)
- Includes certificate request context when user has active requests
- Records token usage in metadata
- Returns `success?: false` when OpenAI call fails

### 5.3 Rag::QueryService

The orchestrator. Full spec covering all cases listed in AGENTS.md §19:
- Happy path: question → retrieval → generation → persisted assistant message
- No relevant chunks found → answer says so, does not hallucinate
- Embeddings API fails → assistant message marked :failed
- Chat completion API fails → assistant message marked :failed
- Conversation has prior messages → history is passed to GenerationService
- User has matching certificate request → request data included in context
- Assistant message status → :completed on success, :failed on error

**Phase 5 definition of done:**
- `bundle exec rspec spec/services/rag/` → all green
- System prompt test passes (verifies the actual messages array sent to OpenAI)

---

## Phase 6 — Background Jobs & Specs

### 6.1 Documents::IngestJob

Full implementation of the ingestion pipeline job. Spec must cover:
- Happy path: document goes from :pending → :processing → :ready
- Idempotency: already-:ready document is skipped (not re-processed)
- Text extraction failure: document status set to :failed
- Embedding failure: document status set to :failed, chunks cleaned up
- `retry_on` exceptions behave as configured

### 6.2 Rag::QueryJob

Job that runs the query pipeline asynchronously. Spec must cover:
- Calls `Rag::QueryService` with correct arguments
- Sets assistant message to :failed if the service fails
- Broadcasts result via Turbo Streams after completion

**Phase 6 definition of done:**
- `bundle exec rspec spec/jobs/` → all green
- Jobs use `:ingestion` and `:default` queues respectively

---

## Phase 7 — Controllers, Routes & Request Specs

**Goal**: All HTTP endpoints exist, are authorized, and respond with the correct
status codes and response shapes. Controllers are thin — no business logic.

### 7.1 Routes

`config/routes.rb`:

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  authenticated :user do
    root to: "conversations#index", as: :authenticated_root
  end

  root to: redirect("/users/sign_in")

  resources :conversations, only: [:index, :show, :create, :destroy] do
    resources :messages, only: [:create]
  end

  resources :documents, only: [:index, :show, :new, :create, :destroy]
  resources :certificate_requests, only: [:index, :show]

  namespace :admin do
    root to: "dashboard#show"
    resources :documents, only: [:index, :show, :destroy]
    resources :users, only: [:index, :show, :new, :create, :edit, :update]
  end

  # Turbo Stream channel mount
  mount ActionCable.server => "/cable"
end
```

### 7.2 ApplicationController

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  before_action :authenticate_user!

  after_action :verify_authorized,    except: :index,
               unless: :devise_controller?
  after_action :verify_policy_scoped, only: :index,
               unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  add_flash_types :info, :error

  private

  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  def not_found
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end

  def after_sign_in_path_for(_resource)
    authenticated_root_path
  end
end
```

### 7.3 ConversationsController

Thin controller. Request spec must cover: unauthenticated redirect, creating a conversation, viewing own conversation, cannot view other user's conversation (403).

### 7.4 MessagesController

The `create` action: creates user message, creates pending assistant message, enqueues `Rag::QueryJob`, returns Turbo Stream response. No inline RAG logic.

### 7.5 DocumentsController

`index`: lists ready docs (employees) or all docs (admins) via `policy_scope`.
`new`/`create`: admin only. File attached via ActiveStorage. Enqueues `Documents::IngestJob`.
`destroy`: admin only.

### 7.6 Admin controllers

`Admin::BaseController` enforces admin-only access. `Admin::DashboardController#show` shows ingestion stats.

**Phase 7 definition of done:**
- `bundle exec rspec spec/requests/` → all green
- Every action in routes.rb has a corresponding request spec
- `verify_authorized` fires on every non-index action without raising `Pundit::AuthorizationNotPerformedError`

---

## Phase 8 — Views & Stimulus Frontend

**Goal**: A working UI that a user can actually interact with. No business logic in views
or Stimulus controllers.

### 8.1 Application layout

`app/views/layouts/application.html.erb` — full page layout with:
- Tailwind CSS classes
- Flash message rendering via a `shared/_flash.html.erb` partial
- Navigation bar: logo, user email, sign out link
- `<%= yield %>`
- Turbo and Stimulus tags

### 8.2 Chat UI (conversations/show)

The main chat interface. Key elements:
- `turbo_frame_tag "messages"` wrapping the messages list with auto-scroll
- Message bubbles: user messages right-aligned, assistant messages left-aligned
- Markdown rendering for assistant content (use `redcarpet` helper)
- A form that submits via Turbo to `MessagesController#create`
- Loading indicator shown while assistant message status is `:pending`
- Stimulus `chat` controller: auto-scroll to bottom on new message, clear input after submit

### 8.3 Documents UI

- `documents/index.html.erb`: card grid of documents with status badges
- `documents/new.html.erb`: upload form with drag-and-drop area (Stimulus `upload` controller)
- Status badge color coding: pending=gray, processing=yellow, ready=green, failed=red

### 8.4 Stimulus controllers

`app/javascript/controllers/chat_controller.js`:
- Targets: `messages`, `input`, `submit`
- `connect()`: scroll to bottom
- `messagesTargetConnected()`: scroll to bottom when new message appended
- `clearInput()`: clear and refocus input after form submission

`app/javascript/controllers/upload_controller.js`:
- Drag-and-drop area highlight on dragover/drop
- Display selected filename before upload
- Show progress bar during upload

**Phase 8 definition of done:**
- `rails server` — app renders without ERB errors
- Can log in, start a conversation, type a message, see loading state, see assistant response
- Can upload a document (as admin), see it appear with "Processing" status

---

## Phase 9 — Test Infrastructure Hardening

**Goal**: Shared RSpec configuration, shared contexts, and CI-readiness.

### 9.1 Complete `spec/rails_helper.rb`

```ruby
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "rspec/rails"
require "shoulda/matchers"
require "webmock/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include OpenAIHelpers
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

### 9.2 `.rubocop.yml`

```yaml
require:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.3
  Exclude:
    - "db/schema.rb"
    - "db/migrate/**/*"
    - "bin/**/*"
    - "vendor/**/*"
    - "node_modules/**/*"

Rails:
  Enabled: true

RSpec:
  Enabled: true

Metrics/MethodLength:
  Max: 20

Metrics/ClassLength:
  Max: 200

Metrics/BlockLength:
  Exclude:
    - "spec/**/*"
    - "config/routes.rb"

Style/Documentation:
  Enabled: false

Rails/FilePath:
  EnforcedStyle: arguments
```

### 9.3 CI configuration (GitHub Actions)

`.github/workflows/ci.yml`:

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: certificate_assistant_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]

    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/certificate_assistant_test
      REDIS_URL: redis://localhost:6379/0
      RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Set up database
        run: |
          bin/rails db:create
          bin/rails db:migrate

      - name: Run RuboCop
        run: bundle exec rubocop --parallel

      - name: Run RSpec
        run: bundle exec rspec --format progress --format RspecJunitFormatter --out tmp/rspec.xml

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: rspec-results
          path: tmp/rspec.xml
```

**Phase 9 definition of done:**
- `bundle exec rspec` → all green, ≥80% coverage reported by SimpleCov
- `bundle exec rubocop` → 0 offenses
- CI configuration file is valid YAML

---

## Phase 10 — Smoke Test & Integration Check

**Goal**: End-to-end verification that all phases integrated correctly.

### 10.1 Full test suite

```bash
bundle exec rspec --format documentation
```

All examples must pass. No pending specs except those explicitly marked with a reason.

### 10.2 RuboCop full scan

```bash
bundle exec rubocop
```

Zero offenses.

### 10.3 Database integrity check

```bash
rails db:migrate:status
```

All migrations should show `up`. None pending.

### 10.4 Manual smoke test checklist

Start the server: `bundle exec rails server`
Start Sidekiq: `bundle exec sidekiq`

Walk through:
- [ ] Sign in as an employee user
- [ ] Start a new conversation
- [ ] Ask: "What documents do I need for a payroll certificate?"
- [ ] Observe: user message appears immediately, loading indicator shows, assistant responds
- [ ] Ask: "What is the status of my certificate request?"
- [ ] Observe: assistant reports actual status from database (or says none found)
- [ ] Sign out, sign in as admin user
- [ ] Navigate to Documents
- [ ] Upload a PDF document
- [ ] Observe: document appears with "Processing" status
- [ ] Wait for Sidekiq to process it → status changes to "Ready"
- [ ] Return to conversation and ask a question the document answers
- [ ] Observe: assistant cites the document by name in its response

### 10.5 Security checklist

- [ ] Employee cannot access `/admin/*` routes (redirected with error flash)
- [ ] Employee cannot view another user's conversation (Pundit raises, 302 with error flash)
- [ ] Unauthenticated request to `/conversations` redirects to sign-in
- [ ] Document upload with a `.exe` file is rejected with a validation error
- [ ] Document upload with a 25MB file is rejected with a validation error

---

## Completion criteria

The application is complete when:

1. `bundle exec rspec` passes with ≥80% coverage and zero failures
2. `bundle exec rubocop` exits 0
3. The manual smoke test checklist is 100% checked
4. The security checklist is 100% checked
5. `AGENTS.md` is present at the repository root
6. `README.md` documents: local setup, environment variables required, how to run tests, how to run Sidekiq

---

## Quick reference: key constants and decisions

| Constant / Decision | Value | Location |
|---------------------|-------|----------|
| Embedding model | `text-embedding-3-small` | `Rag::EmbedService::MODEL` |
| Embedding dimensions | 1536 | `Rag::EmbedService::DIMENSIONS` |
| Chat model | `gpt-4o` | `Rag::GenerationService::MODEL` |
| Retrieval top-K | 5 | `Rag::RetrievalService::TOP_K` |
| Similarity threshold | 0.75 cosine | `Rag::RetrievalService::SIMILARITY_THRESHOLD` |
| Chunk size | 2000 chars | `Documents::ChunkingService::CHUNK_SIZE` |
| Chunk overlap | 200 chars | `Documents::ChunkingService::CHUNK_OVERLAP` |
| Context window (messages) | Last 10 | `Conversation#context_messages` |
| Max file size | 20 MB | `Document` validation |
| Rate limit | 20 msgs/user/min | `config/initializers/rack_attack.rb` |
| Ingestion queue | `:ingestion` | `Documents::IngestJob` |
| Query queue | `:default` | `Rag::QueryJob` |

---

## What to do if you hit a blocker

1. **Spec fails and you cannot identify why**: re-read the spec's context block carefully.
   The spec defines correctness — do not modify the spec to make it pass. Fix the implementation.

2. **pgvector behaves unexpectedly in test**: check that `enable_extension "vector"` ran in the
   test database. Run `rails db:test:prepare` to reset the test schema.

3. **OpenAI calls leak through WebMock**: a service is calling the API without going through
   `Rag::EmbedService` or `Rag::GenerationService`. Find the raw HTTP call and route it through
   the service layer.

4. **Pundit raises `AuthorizationNotPerformedError`**: a controller action is missing an
   `authorize` call. Every non-index action needs one. Check the before/after_action stack.

5. **Turbo Stream does not update the UI**: verify the broadcast target ID matches the DOM id
   in the view. `dom_id(@message)` → `"message_42"`. Target must exist in the DOM before the
   broadcast fires.