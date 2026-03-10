# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mdsp** is a MoonBit DSP audio engine library (part of the "Salat Engine" project). Target: live-codable audio in browser via wasm-gc AudioWorklet, and native via CLAP plugins. Currently in Phase 0 — proving MoonBit wasm-gc can generate audio in AudioWorklet.

## MoonBit Language Notes

- `pub` vs `pub(all)` visibility modifiers have different semantics — check current docs before using
- `._` syntax is deprecated, use `.0` for tuple access
- `try?` does not catch `abort` — use explicit error handling
- `?` operator is not always supported — use explicit match/error handling when it fails
- `ref` is a reserved keyword — do not use as variable/field names
- Blackbox tests cannot construct internal structs — use whitebox tests or expose constructors
- For cross-target builds, use per-file conditional compilation rather than `supported-targets` in moon.pkg.json

## Build & Development Commands

```bash
moon check              # Type-check (also runs as pre-commit hook)
moon build              # Build the project
moon build --target wasm-gc  # Build for WebAssembly GC
moon run cmd/main       # Run the CLI entry point
moon fmt                # Format code
moon info               # Regenerate .mbti interface files
moon test               # Run all tests
moon test --update      # Refresh snapshot test expectations
moon coverage analyze   # Show uncovered code paths
```

**Pre-commit workflow:** `moon info && moon fmt` — then check `.mbti` diffs to verify interface changes are expected.

**Git hooks setup:** `chmod +x .githooks/pre-commit && git config core.hooksPath .githooks`

## Architecture

- **Root package** (`mdsp.mbt`): Core DSP library
- **`cmd/main/`**: Executable entry point (imports the root package)
- **`docs/`**: `salat-engine-blueprint.md` (full architecture vision) and `step0-instruction.md` (current phase spec)

Design principles from the blueprint:
- Finally Tagless two-layer architecture (traits for extensibility + enums for concrete ASTs)
- Incremental computation for memoized DSP graph updates
- No allocation in the audio thread; pre-allocated buffers
- Compile the graph, don't interpret it

Audio constants: 48000 Hz sample rate, 128 samples per buffer (~2.67ms).

## Package Map

| Package | Purpose |
|---------|---------|
| `/` (root) | Core DSP library (`mdsp.mbt`) |
| `cmd/main` | Executable entry point |

## Documentation

**Main docs:** [docs/](docs/)

- **Blueprint:** [docs/salat-engine-blueprint.md](docs/salat-engine-blueprint.md) — full architecture vision and 9-phase roadmap
- **Step 0:** [docs/step0-instruction.md](docs/step0-instruction.md) — current phase spec (wasm-gc AudioWorklet proof)

## MoonBit Conventions

- Code blocks are separated by `///|` markers; block order is irrelevant
- Test files: `*_test.mbt` (blackbox, uses `@mdsp` import), `*_wbtest.mbt` (whitebox, package-internal)
- Each directory with a `moon.pkg` is a package; `moon.mod.json` is the module manifest
- Prefer `assert_eq` for stable results; use snapshot tests for recording current behavior
- Keep deprecated code in `deprecated.mbt` files per directory
- **Trait impl:** `pub impl Trait for Type with method(self) { ... }` — one method per impl block
- **Arrow functions:** `() => expr`, `() => { stmts }`. Empty body: `() => ()` not `() => {}`

## Code Review Standards

- Never dismiss a review request — always do a thorough line-by-line review even if changes seem minor
- Check for: integer overflow, zero/negative inputs, boundary validation, generation wrap-around
- Do not suggest deleting public API types (Id structs, etc.) as 'unused' — they may be needed by downstream consumers
- Verify method names match actual API before writing tests (e.g., check if it's `insert` vs `add_local_op`)

## Development Workflow

1. Make edits
2. `moon check` — Lint
3. `moon test` — Run tests
4. `moon test --update` — Update snapshots (if behavior changed)
5. `moon info` — Update `.mbti` interfaces
6. Check `git diff *.mbti` — Verify API changes
7. `moon fmt` — Format

## Git Workflow

- Always check if git is initialized before running git commands
- After rebase operations, verify files are in the correct directories
- When asked to 'commit remaining files', interpret generously even if phrasing is unclear
