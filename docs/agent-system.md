# Agent System

## Overview

Papelin is built by multiple AI agents working in parallel under the coordination of an Orchestrator agent. Each agent has a narrow scope and clear boundaries. The agent system exists to parallelize development while maintaining code quality, consistency, and integration safety through spec-driven development and strict context hygiene.

## Agent roster

| Agent | Phase | Files it owns | Files it must NOT touch |
|-------|-------|---------------|------------------------|
| Orchestrator | All | `AGENTS.md`, `tmp/plans/*.md` | Any implementation file |
| Schema Agent | Schema | `db/migrate/*`, `db/schema.rb` | Models, services, controllers |
| Model Agent | Model | `app/models/*.rb`, `spec/models/*_spec.rb` | Controllers, services, jobs, views |
| Service Agent | Service | `app/services/**/*.rb`, `spec/services/**/*_spec.rb` | Controllers, views, jobs |
| Policy Agent | Policy | `app/policies/*.rb`, `spec/policies/*_spec.rb` | Models, controllers, views |
| Job Agent | Job | `app/jobs/**/*.rb`, `spec/jobs/**/*_spec.rb` | Controllers, views, services |
| Controller Agent | Controller | `app/controllers/**/*.rb`, `config/routes.rb`, `spec/requests/**/*_spec.rb` | Models, services, views (except routes) |
| Frontend Agent | Frontend | `app/views/**/*`, `app/javascript/**/*`, `app/assets/**/*` | Ruby logic files (models, services, controllers) |
| Spec Agent | Spec | `spec/**/*_spec.rb` (new or expanded) | Implementation files |
| Documentation Agent | Docs | `README.md`, `docs/**/*.md` | Any application source file |

## Orchestration model

The Orchestrator follows a plan → brief → delegate → checkpoint → integrate cycle:

1. **Plan**: The Orchestrator produces a written plan (`tmp/plans/<task-slug>.md`) mapping out all files, specs, and execution steps.
2. **Brief**: Each sub-task is dispatched to a sub-agent with a precise written brief (scope, inputs, spec contract, definition of done).
3. **Delegate**: The sub-agent executes independently with a clean context, reading only files listed in its brief.
4. **Checkpoint**: After the sub-agent reports back, the Orchestrator runs integration checks (specs, rubocop, git diff).
5. **Integrate**: The Orchestrator validates the output and moves to the next step.

## Communication protocol

**Brief format** (Orchestrator → sub-agent):
- Context: where this fits in the larger feature
- Task: precise description with file paths, class names, method signatures
- Inputs available: files the sub-agent may read
- Spec contract: spec files that must pass
- Definition of done: checklist
- Do NOT do: explicit out-of-scope items
- Report back: what to report (summary, not file contents)

**Report format** (sub-agent → Orchestrator):
1. Files created or modified
2. Any spec that required a factory change
3. Any deviation from the brief and why
4. Any open question for the Orchestrator
Keep the report under 20 lines. No file contents.

## Context hygiene

- Each sub-agent starts with a clean context — it receives only the brief, relevant spec files, and specific source files listed as "Inputs available."
- A sub-agent reads **only the files listed in its brief**. If it needs something not listed, it flags it in its report rather than reading speculatively.
- A sub-agent runs only its own spec file(s) — never the full test suite.
- A sub-agent reports a summary — never raw file contents, never full test output.
- The main Orchestrator never accumulates tool output in context. It summarizes results after each step.

## Parallelism rules

| Pair | Safe to parallelize? | Condition |
|------|---------------------|-----------|
| Schema Agent + Spec Agent | Yes | Specs can be written while migration is being prepared |
| Model Agent + Frontend Agent | Yes | When the model interface is already known from the plan |
| Service Agent + Service Agent | Yes | When working on different namespaces (`Rag::` vs `Documents::`) |
| Controller Agent + Service Agent | Yes | When the service interface is specified in the plan |
| Any two agents writing to the same file | **Never** | Hard constraint — file conflicts are not acceptable |

## Planning mode

A plan is required before any non-trivial task. Non-trivial means: touches more than one file, introduces a new class, changes a database schema, or modifies a public interface.

**Plan template:**

```markdown
## Plan: [Short description]

### 1. Goal
One or two sentences on success from the user's perspective.

### 2. Files affected
List every file created, modified, or deleted. Mark as [CREATE], [MODIFY], or [DELETE].

### 3. Spec files to write first
List every spec file written before implementation.

### 4. Database changes
List migrations, column names, types, indexes.

### 5. External side effects
Jobs enqueued, emails sent, OpenAI calls made, ActiveStorage attachments.

### 6. Risks and open questions
Uncertainties, decisions needing confirmation, edge cases.

### 7. Execution order
Numbered list of atomic steps in exact order.
```

The plan is stored at `tmp/plans/<task-slug>.md` during execution and deleted when the task is merged.

## Spec-driven development in the agent context

Spec-driven development (SDD) is especially critical in a multi-agent system because:

1. **Specs are the contract** — when the Model Agent defines a scope and the Controller Agent uses it, the spec is the authoritative definition of that scope's behavior.
2. **Prevents regression** — when agents modify shared files (e.g., routes), the spec suite catches integration failures.
3. **Enables parallel work** — the Frontend Agent can work from the spec-defined interface without waiting for the Controller Agent.
4. **Verifies agent output** — a passing spec is the acceptance criterion for any agent's work.

The SDD cycle is: understand → specify → verify red → implement → verify green → refactor → lint.

Every implementation file must have a corresponding spec file at the mirrored path. No implementation is considered complete without a passing spec file.
