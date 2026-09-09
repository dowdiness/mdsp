# Named patterns and groups

## Purpose and syntax

Define a phrase once and reuse it across sections. Editing the definition updates
all uses. Each use keeps its own transformations, placement, and source path.

```js
let motif = note("E4 G4 A4").slow(3);
let kick = s("bd").gain(0.46);
let groove = stack(motif, kick);
song(
  section("intro", 12, motif),
  section("main", 24, groove),
  part("a", "intro"),
  part("b", "main")
)
```

- Put `let name = expression;` before the final expression. The semicolon is required.
- Names start with an ASCII letter or `_`, followed by ASCII letters, digits, or `_`.
  The names `let`, `s`, `note`, `chord`, `stack`, and `song` are reserved.
- Definitions are immutable and take effect in order. Duplicate names, undefined
  names, and forward references are errors. This also rejects self and mutual references.
- A name is an expression: use it in `stack`, as a method target, or in a section.
  `groove.gain(0.2)` changes that use without changing the definition.
- Definitions work in pattern and song modes, including `$:` lines in pattern mode.
  Their scope is one input; names do not carry over to the next parse.
- Only patterns used by the final expression play. Unused definitions are still validated.

## Parsing and compilation

`mini/expression_syntax.mbt` owns the expression grammar. Calls, stacks,
references, methods, and callbacks are data with source spans. The syntax tree
contains no playback closures or `PatternDoc` values.

`resolve_mini_expr` is a pure function from syntax and the active definitions to
a resolved expression. Each reference points to an immutable definition. There
is no runtime name lookup. An undefined reference reports its use position in
the original input, measured in UTF-16 code units.

The runtime and document compilers consume the same resolved expressions.
They cache compiled definitions within each input so references can share them.
Local mutation builds these caches during preparation and does not touch playback
state. Strings use the existing sound, note, and chord mini-notation converters.
The document compiler keeps its ID-based random seeds; the runtime compiler
keeps its existing seed rules.

The UI uses the existing prepare/apply path and its layout and tempo rules for
updates during playback. A parse error preserves both the applied score and any
accepted pending update. References add no clocks: pattern periods and section
time rules still apply.

## References and source paths

`PatternDoc::reference(id~, definition~)` creates a node for one use and holds
the definition document. It shares the definition's nodes without copying them
into the caller's tree. Construction accepts only existing immutable documents,
so references cannot be rewired to create cycles.

`referenced_definition(id)` returns the target document for inspection.
Event source paths include both the use ID and the nodes inside the definition.
Two uses of the same definition still produce separate events.

Compilation returns playback and source-tracking views together for each node.
Both views use the same compiled children and share one cache. Playback queries
only the playback view; they do not build source arrays. The caller owns the
cache, and `clear` removes both views from it.

Source paths are relative to each node. A reference prepends its use ID.
Arbitrary transformation callbacks do not expose exact source mappings, so they
keep the existing rule of reporting reachable children as sources.

Cache keys include dependency tokens. A parent's ID or generation alone cannot
distinguish definitions whose children differ. Every node replacement gets a
new generation, so a matching dependency token allows reuse. Public revisions
serve edit notifications and comparisons; the cache does not check them again.

Node IDs are resolved within each document. Compiled results can be shared across
documents through dependency tokens, but traversal memos keyed only by node ID
stay within their document. Documents are immutable, so an old snapshot keeps
its meaning after an edit.

Reparsing and recompiling the whole input is allowed. Reusing individual nodes
inside named definitions across edits is not required for this feature.

## Validation

- Named and inline expressions produce the same event spans and values.
- Transforming one use leaves its definition and other uses unchanged.
- Editing a shared definition updates every section without changing the layout.
- Invalid names, references, recursion, and missing separators are rejected.
- Definitions remain inspectable, and source paths distinguish separate uses.
- Shared definitions compile once; caches keep divergent edits with the same IDs separate.
- Real AudioWorklet tests cover live updates and playback preservation on failure.
- [Light Orbit](../../examples/light-orbit.mini) matches the original 12-section,
  240-cycle score in half-cycle queries, including two cycles after the ending.

Bar syntax, quantized updates, game transitions, effects, and Worker migration
are outside this feature's scope.
