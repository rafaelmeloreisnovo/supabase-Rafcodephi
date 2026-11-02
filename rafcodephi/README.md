# RAFCODE-Φ — fork-specific governance overlay

This directory separates project-directed material from the upstream [Supabase monorepo](https://github.com/supabase/supabase). Maintainer context: **Rafael Melo Reis / RAFCODE-Φ**. It does **not** claim ownership of the upstream repository or relicense its components.

## Boundaries and routing

- `../README.md`, `../AGENTS.md` and `../LICENSE` retain the upstream project identity, conventions and Apache-2.0 license. The root README/AGENTS contain only small additive pointers to this overlay.
- `AGENTS.md` states scoped engineering, data, authorship and evidence gates. It augments rather than replaces the upstream agent contract.
- `LICENSE.md` documents what the license does and does not cover in the fork, including third-party exceptions and original-work attribution.
- `PROVENANCE.json` records the exact fork baseline and verified identity of a few upstream files. It is **not** an audit of the entire monorepo.

## Data and operational work

Public GitHub contains specifications, code, tests and sanitized receipts, **not private data or production secrets**. Connected Supabase projects or databases are separate assets and must be identified by exact project ID and explicit write authority before any SQL, migration, RLS, credential or deployment action. Google Drive holds authorized private longitudinal memory and records; an external source must be read in its own authority context before being used.

The project-specific scientific/technical ideas, contributions and claims must be distinguished from implemented and tested software. Prefer a small, independently testable module or documentation change over a sweeping relicense or refactor. Freestanding C/ASM and multi-ABI are design options only for workloads where interfaces, platform constraints and tests justify them; they are not substitutes for PostgreSQL, Supabase Auth, or other required runtime components.

## Completion gate

`SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM`. Treat `TOKEN_VAZIO` as an explicit unknown rather than zero or false. Record before/after, test, observed result, rollback and next reversible action. `IMPLEMENTED_UNTESTED != PASS` and `claim_allowed=false` until a concrete evidence gate passes. No automatic merge or provider write.

Baseline and scope: [PROVENANCE.json](PROVENANCE.json). Licenses: [LICENSE.md](LICENSE.md). Agent behavior: [AGENTS.md](AGENTS.md).
