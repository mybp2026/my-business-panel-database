# Contributing Guide

This document defines the mandatory workflow for contributing to the **database repository** of the livestock marketplace. The goal is to **protect data model integrity**, ensure change traceability, and maintain reproducible and auditable development.

Not following this workflow invalidates the contribution.

---

## Guiding Principles

1. The **database is a critical business component**.
2. No structural change is made without a migration.
3. No business flow is considered complete without tests.
4. No test is considered valid without documentation.
5. Each developer is responsible for not breaking existing rules.

---

## Mandatory Local Environment

Each developer **MUST** work with their **own local database**.

- No database sharing.
- No testing changes directly in shared environments.
- The developer must be able to:
  - destroy their DB
  - recreate it from `bootstrap.sql`
  - run seeds and tests without manual intervention

This guarantees independence, security, and reproducibility.

---

## Repository Structure (Responsibilities)

| Folder          | Responsibility                                         |
| --------------- | ------------------------------------------------------ |
| `schemas/`      | Table definitions (pure DDL). One table per file.      |
| `seeds/`        | Catalog data and initial data. No logic.               |
| `migrations/`   | Immutable history of structural changes.               |
| `sql/`          | Functions, views, triggers, and complex queries.       |
| `tests/`        | Complete flow test scripts.                            |
| `docs/`         | Documentation of flows, decisions, and business rules. |
| `bootstrap.sql` | Complete schema bootstrap. Not manually editable.      |

---

## Mandatory Development Workflow

### 1. Structural Development

- New tables or structural changes:
  - are defined in `schemas/` (single source of truth)
  - are registered through a **new migration** in `migrations/` (for versioning)

**Important:** Migrations in `migrations/` folder are for **historical record only**. They should:

- be numbered sequentially (001, 002, 003...)
- never be modified after being merged
- only contain DDL changes (CREATE, ALTER, DROP. TRUNCATE)
- NOT contain INSERT statements (use `seeds/` instead)

**The `bootstrap.sql` file:**

- Represents the **complete current state** of the database schema
- Is automatically generated from the combination of:
  - `schemas/` (table definitions)
  - `sql/` (functions, triggers, procedures, views)
  - `seeds/` (initial data)
- Must **never be edited manually**
- Serves as the single source for recreating a clean database from scratch

- Catalogs:
  - structure in `schemas/`
  - data in `seeds/`

- Database logic:
  - functions, stored procedures, views, or triggers in `sql/`

**Forbidden:**

- modifying existing migrations
- editing `bootstrap.sql` directly

---

### 2. Mandatory Tests

Any change that implements or modifies a **business process** must include a **test script** in `tests/`.

Process examples:

- user registration
- livestock posting
- sale closure
- reputation calculation
- commission charging

**Test Idempotency Requirement:**

All tests **MUST be idempotent** - they can be executed repeatedly without side effects. Each test must:

- **Clean up** any existing test data before execution
- **Create** fresh test data needed for the flow
- **Execute** the complete business flow
- **Validate** expected results

This ensures tests can be run multiple times on the same database without conflicts or failures.

If there's no test, the change is not complete.

Recommended document naming format:

```bash
/tests/test-<name>.md
```

---

### 3. Mandatory Documentation

Once the test script **executes successfully**, a document must be created in `docs/` describing the flow.

**What goes in `docs/`:**

- Business flow descriptions
- Multi-table process explanations
- Decision rationale (why we chose approach X over Y)
- Complex query explanations

**What stays in code comments:**

- Single table purpose
- Column meaning
- Constraint rationale

The document must include:

- flow objective
- tables involved
- applied business rules
- process steps
- key validations
- reference to the test script

Recommended document naming format:

```bash
/docs/flow-<name>.md
```

A test without documentation is technical debt.

---

## Version Control Workflow (Forks)

1. Each developer works on their **personal fork** of the repository.
2. All development is done on the `development` branch of the fork.
3. Before starting work:

```bash
git checkout development
git pull upstream development
```

4. Upon finishing work:

```bash
git add .
git commit -m "feat(db): clear description of the change"
git push origin development
```

5. A **Pull Request** is created from:

```bash
fork:development → upstream:development
```

6. The PR must include:

- change description
- migrations created (if applicable)
- tests added
- associated documentation

---

## Strict Rules

- Direct push to `development`, `staging`, or `master` of the original repository is forbidden.
- Every contribution goes through PR and review.
- A PR can be rejected if it:
  - breaks compatibility
  - has no tests
  - has no documentation
  - introduces undocumented implicit logic

---

## Final Objective

This workflow exists to:

- protect critical business rules
- avoid data corruption
- allow team scaling without losing control
- guarantee that every decision is recorded

This is not bureaucracy. This is technical discipline applied to a system that handles reputation, money, and trust.
