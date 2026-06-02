# Papelin — Certificate Assistant

Papelin is an internal HR assistant that lets employees ask natural-language questions about certificate requests (payroll, labor, employment letters) and get answers grounded in company documents via RAG.

```text
Browser → Rails (Hotwire) → Service Layer → OpenAI API
                          ↘ PostgreSQL + pgvector
                          ↘ Sidekiq + Redis
```

## Requirements

| Dependency | Version | Notes |
|------------|---------|-------|
| Ruby | 3.3.0 | Use rbenv or asdf |
| Rails | 7.2 | |
| PostgreSQL | 16+ | With pgvector extension |
| Redis | 7+ | For Sidekiq |
| Node.js | 18+ | For asset compilation |

## Quick Start

1. Clone and install dependencies:
   ```bash
   git clone https://github.com/your-org/papelin.git
   cd papelin
   bundle install
   ```

2. Start infrastructure services:
   ```bash
   docker compose up -d
   ```
   This starts PostgreSQL (with pgvector), Redis, and LocalStack (S3 mock).

3. Set up credentials:
   ```bash
   cp .env.example .env
   # Edit .env with your OpenAI API key
   rails credentials:edit
   ```
   Add your OpenAI key to credentials:
   ```yaml
   openai:
     api_key: sk-your-key-here
   ```

4. Set up the database:
   ```bash
   rails db:create db:migrate db:seed
   ```

5. Start the application:
   ```bash
   # Terminal 1 — Rails server
   bin/rails server

   # Terminal 2 — Sidekiq worker
   bundle exec sidekiq

   # Terminal 3 — Tailwind watcher (development)
   bin/rails tailwindcss:watch
   ```

6. Open http://localhost:3000 and sign in with the seeded admin account:
   ```
   Email:    admin@papelin.internal
   Password: (set in db/seeds.rb)
   ```

## Environment Variables

Copy `.env.example` to `.env` and fill in the values. Never commit `.env`.

### Secrets — stored in Rails encrypted credentials

Edit with `rails credentials:edit`:

| Key path | Description |
|----------|-------------|
| `openai.api_key` | OpenAI API key (`sk-...`) |
| `redis.url` | Redis connection URL |
| `active_storage.aws_access_key_id` | S3 credentials (production only) |
| `active_storage.aws_secret_access_key` | S3 credentials (production only) |
| `active_storage.aws_bucket` | S3 bucket name (production only) |
| `active_storage.aws_region` | S3 region (production only) |

### Runtime configuration — stored in `.env`

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_HOST` | `localhost` | PostgreSQL host |
| `DATABASE_PORT` | `5432` | PostgreSQL port |
| `DATABASE_USER` | `postgres` | PostgreSQL user |
| `DATABASE_PASSWORD` | `postgres` | PostgreSQL password |
| `DATABASE_NAME` | `papelin_dev` | PostgreSQL database name |
| `REDIS_URL` | `redis://localhost:6379/0` | Redis connection string |
| `OPENAI_API_KEY` | `sk-replace-me` | OpenAI API key (or use credentials) |
| `RAILS_MAX_THREADS` | `5` | Puma thread count |
| `WEB_CONCURRENCY` | `2` | Puma worker count (production) |

## Running Tests

```bash
# Full suite with coverage report
bundle exec rspec

# Single spec file
bundle exec rspec spec/services/rag/query_service_spec.rb

# With documentation formatter
bundle exec rspec --format documentation

# Lint
bundle exec rubocop

# Lint with auto-fix
bundle exec rubocop -A
```

Coverage is measured by SimpleCov. After running the suite, open `coverage/index.html`.
Target: ≥80% overall, ≥90% in `app/services/` and `app/models/`.

## Architecture

Papelin is a Rails 7.2 monolith with a service layer. User messages are answered by a RAG pipeline: the query is embedded, relevant document chunks are retrieved via pgvector, and GPT-4o generates a grounded response. Document ingestion runs asynchronously via Sidekiq.

See [docs/architecture.md](docs/architecture.md) for the full system design.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System design, layers, and data flow |
| [RAG Pipeline](docs/rag-pipeline.md) | How queries are answered |
| [Ingestion Pipeline](docs/ingestion-pipeline.md) | How documents are processed |
| [Data Model](docs/data-model.md) | Database schema and relationships |
| [Agent System](docs/agent-system.md) | AI agent roles and responsibilities |
| [ADR Index](docs/adr/) | Architecture decision records |

