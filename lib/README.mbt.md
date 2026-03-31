# dowdiness/mdsp

`mdsp` is a MoonBit digital signal processing playground and engine prototype.
The repository currently contains:

- Phase 1 DSP primitives such as oscillators, noise, ADSR, filters, delay,
  gain, mix, clip, pan, smoothing, and audio-buffer/context helpers
- a browser AudioWorklet prototype for manual sound verification
- an in-progress Phase 2 compiled graph runtime with mono and narrow stereo
  graph support

Good starting points:

- [`RESULTS.md`](RESULTS.md) for current project checkpoints
- [`docs/salat-engine-blueprint.md`](docs/salat-engine-blueprint.md) for the
  roadmap
- [`docs/salat-engine-technical-reference.md`](docs/salat-engine-technical-reference.md)
  for the detailed implementation reference
