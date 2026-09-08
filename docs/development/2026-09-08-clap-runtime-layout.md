# CLAP builds with the split MoonBit runtime

The CLAP build scripts compile the generated MoonBit C payload and link it
into a shared library. With moon 0.1.20260907 (7aabba5), runtime sources reside
under `$MOON_HOME/lib/runtime/`; the scripts previously required
`$MOON_HOME/lib/runtime.c`.

Running the main-baseline build script from commit 737dbf1 with this toolchain
fails before building the payload: `MoonBit runtime.c not found`. Selecting
only the new `runtime/runtime.c` file allows linking a library but leaves
`moonbit_panic`, `moonbit_println`, `moonbit_rt_get_random` and
`moonbit_runtime_init` unresolved, so `dlopen` fails.

The scripts now compile the five runtime sources listed in the installed
runtime's `dune.auto`: runtime, backtrace, env, sync_io and utf. The legacy
single-source layout remains supported; a missing required source fails with
its exact path. Each invocation links only the objects selected for that
layout. Linux now rejects unresolved symbols at link time, as the Windows
script already did.

The C backend is explicitly selected because the bridge header and linker
consume its generated C payload. The setting is documented in the
[official MoonBit FFI documentation](https://docs.moonbitlang.com/en/latest/language/ffi.html).
MinGW runtime compilation defines `_CRT_RAND_S` to expose the declaration of
`rand_s`, which the split environment runtime uses.

Validation on Linux with moon 0.1.20260907:

- Linux build and `dlopen`/process smoke passed, including note and MIDI release.
- clap-validator 0.3.2: 21 tests, 13 passed, zero failed, 8 skipped, zero warnings.
- Windows MinGW cross-build passed with unresolved-symbol checking enabled.
  This is build evidence; Windows host loading was not tested here.
- Both build scripts pass `bash -n`.

These results validate the prototype build and CLAP checks, not DAW readiness
or audio-thread allocation safety. The old toolchain layout was not rebuilt
with an older compiler during this verification.
