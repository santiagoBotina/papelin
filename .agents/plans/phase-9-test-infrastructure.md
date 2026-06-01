# Plan: Phase 9 — Test Infrastructure Hardening

## 1. Goal

All shared RSpec configuration, test support files, CI infrastructure, and
code quality tooling are in place and final. The `rails_helper.rb` is
complete. `rubocop.yml` is configured. A GitHub Actions CI workflow runs
tests, lint, and coverage on every push. SimpleCov enforces a minimum
coverage threshold. Phase 9 ends with `bundle exec rspec` (full suite) at
≥80% coverage and `bundle exec rubocop` (full scan) at 0 offenses.

No application feature code is added — only test and quality infrastructure.

## 2. Files affected

### [CREATE]

- `.github/workflows/ci.yml`
- `spec/support/simplecov.rb`

### [MODIFY / REPLACE]

- `spec/rails_helper.rb` — replace with the canonical version from
  PROMPT.md §9.1, ensuring all support files are loaded, WebMock is
  configured, and all helpers are included.
- `.rubocop.yml` — replace with the canonical version from PROMPT.md §9.2,
  ensuring all cops are enabled and excludes are correct.
- `spec/spec_helper.rb` — ensure SimpleCov configuration is loaded before
  anything else (PROMPT.md §9.1 pattern with `SimpleCov.start`).

### [REVIEW / VERIFY] — no changes unless missing

- `spec/support/openai_helpers.rb` (Phase 4 — confirm still complete)
- `spec/support/shoulda_matchers.rb` (Phase 2 — confirm still present)
- `spec/support/active_job.rb` (Phase 6 — confirm still present)
- `spec/support/pundit_matchers.rb` (Phase 3 — confirm present if used)
- All model, service, job, policy, controller spec files — confirm they
  pass with the hardened configuration.

### [NO CHANGES]

- `app/**` (any file under app/)
- `config/**`
- `db/**`
- `Gemfile` (all gems already present: `rubocop`, `rubocop-rails`,
  `rubocop-rspec`, `rubocop-performance`, `simplecov`, `rspec_junit_formatter`
  for CI output)

## 3. Coverage target

PROMPT.md §9 definition of done: ≥80% coverage reported by SimpleCov.

**Decision:** set the threshold in `spec/support/simplecov.rb`:
```ruby
SimpleCov.minimum_coverage 80
SimpleCov.refuse_coverage_drop
```
`refuse_coverage_drop` ensures coverage never decreases between runs.
If coverage drops below 80% during development, SimpleCov will fail the
spec run.

**Coverage groups for SimpleCov:**
- Models
- Services
- Policies
- Jobs
- Controllers
- Helpers
- (Exclude `app/javascript/`, `app/views/`, `app/assets/` from coverage
  since RSpec does not exercise them)

## 4. External side effects

- CI pipeline (GitHub Actions) will run on every push to any branch and on
  every PR. It requires:
  - A PostgreSQL service with pgvector extension (Docker image
    `pgvector/pgvector:pg16`).
  - A Redis service for Sidekiq (`redis:7-alpine`).
  - The `RAILS_MASTER_KEY` GitHub secret to decrypt credentials.
  - The `DATABASE_URL` environment variable pointing to the test database.
- No OpenAI calls are made in CI (all stubbed).
- No real file uploads to S3 (local ActiveStorage in test env).

## 5. Risks and open questions

### R1 — SimpleCov configuration location

PROMPT.md §9.1 includes `SimpleCov.start` at the very top of
`spec_helper.rb`, **before** anything else. The existing
`spec/spec_helper.rb` from Phase 0 may or may not have this. **Decision:**
move or add `SimpleCov.start` at the top of `spec_helper.rb`. Create
`spec/support/simplecov.rb` only if grouping or threshold configuration
is too verbose for `spec_helper.rb`. Otherwise, keep thresholds inline.

### R2 — Coverage exclusions

Files under `app/javascript/` are not covered by RSpec. `app/views/` is
not covered. `app/assets/` is not covered. Exclude them from SimpleCov:

```ruby
SimpleCov.start do
  add_filter "/app/javascript/"
  add_filter "/app/views/"
  add_filter "/app/assets/"
  add_filter "/app/channels/"
  add_filter "/app/mailers/"
end
```

This prevents SimpleCov from reporting artificially low coverage due to
untested ERB/JS/CSS files.

### R3 — CI database service requires pgvector

The `pgvector/pgvector:pg16` Docker image includes the pgvector extension.
The CI workflow's `db:create` / `db:migrate` steps must run after the
PostgreSQL service is healthy. Without pgvector, migration 1 (enabling
extension) will fail. **Decision:** use `pgvector/pgvector:pg16` explicitly
in the CI YAML for the PostgreSQL service.

### R4 — CI Redis service

The app uses Sidekiq which requires Redis. The CI workflow must start a
Redis service container. Even though specs use the `:test` queue adapter,
Rails will load the Sidekiq adapter configuration on boot. **Decision:**
include the Redis service in the CI workflow to prevent boot errors.

### R5 — CI `RAILS_MASTER_KEY` secret

The CI workflow needs `RAILS_MASTER_KEY` to decrypt
`config/credentials.yml.enc`. For open-source repos, this must be configured
as a GitHub Actions secret. For this internal project, add instructions in
the CI workflow comments. **Decision:** include `${{ secrets.RAILS_MASTER_KEY }}`
in the CI env block and document in `README.md` that this secret must be
configured in the repository.

### R6 — RuboCop `NewCops: enable`

PROMPT.md §9.2 uses `NewCops: enable` which means new cops from
`rubocop-rails`, `rubocop-rspec`, and `rubocop-performance` will be
automatically enforced after gem updates. **Risk:** an update could break
CI with new offenses. **Mitigation:** check `Gemfile.lock` for pinned
versions of the RuboCop gems. If unpinned, pin them:

```ruby
gem "rubocop", "~> 1.60"
gem "rubocop-rails", "~> 2.23"
gem "rubocop-rspec", "~> 2.26"
gem "rubocop-performance", "~> 1.20"
```

Pinning prevents surprise CI failures from new cops.

### R7 — RSpec `--format progress` for CI

PROMPT.md §9.3 CI configuration uses `--format progress` for CI and
`--format RspecJunitFormatter --out tmp/rspec.xml` for test result XML.
The `rspec_junit_formatter` gem may not be in the Gemfile from Phase 0.
**Decision:** add `gem "rspec_junit_formatter", require: false` to the
`:test` group in `Gemfile`. If the user prefers not to add a new gem,
remove the junit formatter step from the CI config.

### R8 — All `spec/support/**/*.rb` files must be loaded

PROMPT.md §9.1 uses `Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }`.
This is an authoritative pattern — use it and remove any ad-hoc `require`
calls for individual support files (except `shoulda-matchers` and
`webmock/rspec` which must be loaded before the directory traversal).

**Correct load order in `rails_helper.rb`:**
```ruby
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("...")
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

### R9 — CI step order

1. Checkout
2. Set up Ruby (with `bundler-cache: true` for faster runs)
3. Set up database (`db:create`, `db:migrate`)
4. RuboCop (`--parallel` for speed)
5. RSpec (with coverage)
6. Upload test results (always, even on failure)

### R10 — `bundle exec rubocop` must pass on full scan

Run `bundle exec rubocop` and fix any remaining offenses. If there are
many offenses from earlier phases (accumulated technical debt), address
them now. Common issues:
- `Rails/ActiveRecordCallbacksOrder` — fix callback ordering.
- `Rails/EnumHash` — confirm enum syntax matches RuboCop's expectations.
- `RSpec/LetSetup` — confirm `let!` usage is necessary.
- `Layout/LineLength` — check long lines in specs.
- `Style/FrozenStringLiteralComment` — some files may lack the
  `# frozen_string_literal: true` comment.

## 6. Execution order

### Step 0 — SimpleCov setup

- **0.1** Verify `spec/spec_helper.rb` has `SimpleCov.start` at the top
  (before any `require`).
- **0.2** Create `spec/support/simplecov.rb` with coverage groups,
  threshold, and exclusions.
- **0.3** Run a single spec file to verify SimpleCov runs and reports.

### Step 1 — Complete `spec/rails_helper.rb`

- **1.1** Replace the current `rails_helper.rb` with the canonical version
  from PROMPT.md §9.1, adjusting load order per R8.
- **1.2** Run `bundle exec rspec` — must pass with all existing specs.

### Step 2 — Complete `.rubocop.yml`

- **2.1** Replace the current `.rubocop.yml` with the canonical version
  from PROMPT.md §9.2.
- **2.2** Run `bundle exec rubocop` and fix any offenses:
  - Use `rubocop -a` for autocorrectable offenses.
  - For non-autocorrectable offenses, fix manually.
  - Document any necessary `rubocop:disable` comments with explanations.
- **2.3** Re-run `bundle exec rspec` after fixes to ensure nothing broke.

### Step 3 — Pin dependencies (optional but recommended)

- **3.1** If RuboCop gems are unpinned, add version constraints to
  `Gemfile`.
- **3.2** Add `gem "rspec_junit_formatter", require: false` if CI output
  format is desired (per R7).
- **3.3** Run `bundle install`.

### Step 4 — Create CI configuration

- **4.1** Create `.github/workflows/ci.yml` per PROMPT.md §9.3.
- **4.2** Verify YAML syntax: `ruby -ryaml -e "YAML.safe_load(File.read('.github/workflows/ci.yml'))"`.
- **4.3** Validate workflow structure against GitHub Actions schema (no
  syntax errors, valid `on`, `jobs`, `services`, `steps`).

### Step 5 — Phase 9 verification gates (all must pass)

- **5.1** `bundle exec rspec` → all green, ≥80% coverage
  (check the SimpleCov report in `coverage/index.html`).
- **5.2** `bundle exec rubocop` → 0 offenses.
- **5.3** `git diff --name-only` matches the [CREATE] + [MODIFY] list in §2.
- **5.4** CI YAML file is valid YAML (`ruby -ryaml -e "..."`).
- **5.5** Run a targeted dry-run of the CI workflow (push to a branch and
  verify it triggers; skip this if no GitHub remote is configured).

## 7. Definition of done

- [ ] `spec/rails_helper.rb` is canonical per PROMPT.md §9.1.
- [ ] `spec/spec_helper.rb` loads SimpleCov before all other code.
- [ ] SimpleCov coverage ≥80%, refuse coverage drop configured.
- [ ] `.rubocop.yml` is canonical per PROMPT.md §9.2.
- [ ] `bundle exec rubocop` → 0 offenses across the entire codebase.
- [ ] `bundle exec rspec` → 0 failures, ≥80% coverage.
- [ ] `.github/workflows/ci.yml` exists and is valid YAML.
- [ ] CI yml includes pgvector Postgres, Redis, RuboCop, RSpec with
      junit output, and artifact upload.
- [ ] `Gemfile` has RuboCop gems pinned (optional) and
      `rspec_junit_formatter` added (optional).

## 8. Out of scope (explicitly NOT in Phase 9)

- `README.md` updates (Phase 10)
- `tmp/pending_specs.md` cleanup (Phase 10)
- Devise `:lockable` / `:timeoutable` migration (Phase 10 or deferred)
- Real OpenAI integration testing (Phase 10 manual smoke test)
- System (/Capybara/a11y) test infrastructure (future)
- Vulnerability scanning / Brakeman (future)
