# ─────────────────────────────────────────────────────────────
#  Papelin — Makefile
#  First-time setup:  make setup
#  Daily development: make dev
# ─────────────────────────────────────────────────────────────

.PHONY: setup install env start-db start-localstack start-redis \
        stop-db db-create db-migrate db-seed db-reset db-setup \
        start-server start-sidekiq start-tailwind dev \
        logs console seed lint test credentials

# ─── Primary entry point ────────────────────────────────────

setup: install env start-db db-setup
	@echo ""
	@echo "  ✓  Papelin is ready!"
	@echo "  ─────────────────────────────────────"
	@echo "  1. Run  make dev      to start all processes"
	@echo " 2. Open http://localhost:3000"
	@echo " 3. If you haven't yet, run:"
	@echo "       rails credentials:edit"
	@echo "     and add your OpenAI API key under:"
	@echo "       openai:"
	@echo "         api_key: sk-..."
	@echo ""

# ─── Dependencies ───────────────────────────────────────────

install:
	@echo "→ Installing Ruby dependencies..."
	@bundle install
	@echo "✓  bundle install complete"

env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓  Created .env from .env.example — edit OPENAI_API_KEY if needed."; \
	else \
		echo "✓  .env already exists"; \
	fi

# ─── Infrastructure (Docker) ────────────────────────────────

start-redis:
	@echo "→ Starting Redis..."
	@docker compose up -d redis
	@echo "✓  Redis ready on port 6379"

start-localstack:
	@echo "→ Starting LocalStack (S3 mock)..."
	@docker compose up -d localstack
	@echo "  Waiting for LocalStack to be healthy..."
	@for i in $$(seq 1 20); do \
		if curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1; then \
			echo "✓  LocalStack ready on port 4566"; \
			break; \
		fi; \
		sleep 2; \
	done

start-db: start-redis start-localstack
	@echo "→ Starting PostgreSQL..."
	@docker compose up -d postgres
	@echo "  Waiting for PostgreSQL to accept connections..."
	@for i in $$(seq 1 30); do \
		if docker compose exec postgres pg_isready -U postgres -d papelin_dev > /dev/null 2>&1; then \
			echo "✓  PostgreSQL ready on port 5432"; \
			break; \
		fi; \
		sleep 1; \
	done

stop-db:
	@echo "→ Stopping all Docker services..."
	@docker compose down
	@echo "✓  Services stopped"

# ─── Database ────────────────────────────────────────────────

db-create:
	@echo "→ Creating database..."
	@bin/rails db:create
	@echo "✓  Database created"

db-migrate:
	@echo "→ Running migrations..."
	@bin/rails db:migrate
	@echo "✓  Migrations complete"

db-seed:
	@echo "→ Seeding database..."
	@bin/rails db:seed
	@echo "✓  Database seeded"

db-setup: db-create db-migrate db-seed
	@echo "✓  Database ready"

db-reset:
	@echo "→ Resetting database..."
	@bin/rails db:drop db:create db:migrate db:seed
	@echo "✓  Database reset complete"

# ─── Development servers ────────────────────────────────────

start-server:
	@echo "→ Starting Rails server on http://localhost:3000..."
	@bin/rails server

start-sidekiq:
	@echo "→ Starting Sidekiq worker..."
	@bundle exec sidekiq

start-tailwind:
	@echo "→ Starting Tailwind CSS watcher..."
	@bin/rails tailwindcss:watch

# ─── Run everything ─────────────────────────────────────────

dev:
	@echo "  Starting Papelin development environment"
	@echo "  ───────────────────────────────────────────"
	@echo "  Rails:     http://localhost:3000"
	@echo "  Sidekiq:   http://localhost:3000/sidekiq"
	@echo "  PostgreSQL:  localhost:5432"
	@echo "  Redis:       localhost:6379"
	@echo "  LocalStack:  http://localhost:4566"
	@echo ""
	@trap 'kill 0' EXIT; \
		bundle exec sidekiq & \
		bin/rails tailwindcss:watch & \
		bin/rails server & \
		wait

# ─── Utilities ──────────────────────────────────────────────

logs:
	@docker compose logs -f

console:
	@bin/rails console

seed:
	@bin/rails db:seed

lint:
	@bundle exec rubocop

test:
	@bundle exec rspec

credentials:
	@bin/rails credentials:edit

# ─── Quick health check ─────────────────────────────────────

status:
	@echo "→ Checking services..."
	@echo ""
	@printf "  PostgreSQL:  "
	@docker compose exec postgres pg_isready -U postgres -d papelin_dev > /dev/null 2>&1 && \
		echo "running (port 5432)" || echo "NOT running"
	@printf "  Redis:       "
	@docker compose exec redis redis-cli ping > /dev/null 2>&1 && \
		echo "running (port 6379)" || echo "NOT running"
	@printf "  LocalStack:  "
	@curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1 && \
		echo "running (port 4566)" || echo "NOT running"
	@printf "  Rails:       "
	@curl -sf http://localhost:3000/up > /dev/null 2>&1 && \
		echo "running (port 3000)" || echo "NOT running"
	@echo ""
	@echo "  Run  make logs  to see container logs"
