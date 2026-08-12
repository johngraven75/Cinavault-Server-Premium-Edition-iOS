# Repository Engineering Standard

Mandatory for all AI-assisted engineering. Before code, define product goal, target user, measurable success criteria, non-goals, assumptions, and missing requirements. Propose architecture first, covering platform constraints, security boundaries, dependency direction, public contracts, persistence, lifecycle, observability, backward compatibility, upgrades, signing/distribution implications, and rollback.

Organize implementation/reporting as **Frontend**, **Connector / integration**, and **Backend** where applicable. Break substantial work into small independently testable vertical slices suitable for isolated git worktrees/branches. For each slice define exact files, public interfaces/contracts, validation/error handling, logging/telemetry, security implications, and definition of done. Keep commits atomic and conventional; never merge around failing required checks.

Ship fresh, idiomatic, repository-specific production code following SOLID, DRY, explicit typing, immutable data where practical, dependency injection, narrow interfaces, secure defaults, input validation, null safety, cancellation/disposal, bounded resources, and clear separation of concerns. No TODOs, placeholders, mock data, fabricated integrations, credentials, signing secrets, or incomplete production paths. Preserve accepted functionality and backward compatibility unless an explicit migration is approved.

Every slice requires appropriate unit tests for edge/failure cases, real filesystem/OS integration tests, API/cross-layer contract tests, security tests, performance tests with measurable budgets, and manual QA for UI/install/upgrade/distribution flows. Run formatting, linting, static analysis, type checks, unit/integration/E2E, archive/package validation, and user-flow validation. Never weaken tests to obtain green CI.

Before completion, self-review normal and failure paths for races, deadlocks, leaks, disposal, cancellation, retries, lifecycle cleanup, permissions, interrupted operations, rollback, and compatibility; fix discovered issues first.

Production readiness requires a diff summary, changelog/release notes, migration/install notes, public API docs, environment/config docs, rollback plan, post-release monitoring plan, and test/checksum/signing evidence for distributable artifacts. Never claim completion/publication/signing/test success without evidence. Commit every change before building and rerun validation after each fix.
