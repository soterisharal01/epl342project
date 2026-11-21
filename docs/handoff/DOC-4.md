# Handoff: DOC-4 Separate document (contention, security, extension)

Lock: free

Branch: task/DOC-4-separate-doc
Doc: docs/15-concurrency.md, docs/16-security.md, docs/17-extensibility.md
Status: finished (in review)

## Next step
Coordinator review. PRF-4 fills the 10,000-request table in doc 15, section 8.

## Done so far
- 2026-11-21: docs 15, 16, 17 written from the real code (sql/create.sql, sql/procs_*.sql, sources/*.php). README status and tasks.md rows updated.

## Blockers / open questions
- 10,000-request numbers pending (PRF-4).
- Not verifiable in code: least-privilege GRANT login (recommended only), COMMAND_ATTEMPT.AttemptNo (no procedure writes it), the OBIS 5.8.0 worked example (derived from the joins, not run).

## How to test
Docs only: read them against sql/procs_*.sql and sources/*.php.
