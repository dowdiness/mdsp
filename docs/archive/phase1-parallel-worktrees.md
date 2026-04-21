# Phase 1 Parallel Worktrees

This note records the current parallel execution setup for Phase 1 long-stretch
tasks.

## Active Worktrees

- `phase1-filter` at `/tmp/mdsp-phase1-filter`
- `phase1-clip` at `/tmp/mdsp-phase1-clip`
- `phase1-smoother` at `/tmp/mdsp-phase1-smoother`

Each worktree starts from commit `cec45b7` on its own branch.

## Assigned Briefs

- `phase1-filter` uses `phase1-filter-long-stretch.md`
- `phase1-clip` uses `phase1-clip-long-stretch.md`
- `phase1-smoother` uses `phase1-smoother-long-stretch.md`

## Why These Three First

- They are high-value Phase 1 primitives
- They can be developed mostly independently
- They minimize shared-file overlap compared with starting envelope, delay, and
  waveform expansion at the same time

## Expected Collision Points

These branches are isolated, but merges back into `main` will still need care
around:

- `mdsp_test.mbt`
- `mdsp_wbtest.mbt`
- `pkg.generated.mbti`

Every primitive slice is expected to touch at least those files.

## Suggested Merge Order

1. `phase1-clip`
2. `phase1-smoother`
3. `phase1-filter`

Reason:

- `Clip` is the smallest and least likely to conflict semantically
- `Smoother` adds a utility layer that may be reused later
- `Filter` is the heaviest change and is most likely to need rebasing

## Verification Rule

Each branch should independently pass:

- `moon fmt`
- `moon check`
- `moon test`
- `moon info`
- `moon build --target wasm-gc --release`

Optional:

- `moon build --target js`
- `moon test --target js`
