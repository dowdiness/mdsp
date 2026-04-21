# `dowdiness/mdsp/lib`

Internal re-export facade. `lib/` consolidates `@dsp`, `@graph`, and `@voice`
into one surface so existing consumers keep working without changing their
imports.

External consumers should import the module's public facade (`@mdsp.X`) rather
than `@mdsp.lib.X`. See the top-level landing page and docs index for where to
start.

- Package landing page: [`../README.mbt.md`](../README.mbt.md)
- Docs index: [`../docs/README.md`](../docs/README.md)
- Authoritative runtime/control reference:
  [`../docs/salat-engine-technical-reference.md`](../docs/salat-engine-technical-reference.md)
