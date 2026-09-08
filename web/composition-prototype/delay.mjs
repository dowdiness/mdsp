// PROTOTYPE imperative DSP owner. Allocated once, independent of score revision.
export class SharedDelay {
  constructor(frames = 12000, feedback = 0.4, mix = 0.25) {
    this.left = new Float64Array(frames); this.right = new Float64Array(frames);
    this.cursor = 0; this.feedback = feedback; this.mix = mix;
  }
  process(left, right) {
    for (let i = 0; i < left.length; i++) {
      const dl = this.left[this.cursor], dr = this.right[this.cursor];
      this.left[this.cursor] = left[i] + this.feedback * dl;
      this.right[this.cursor] = right[i] + this.feedback * dr;
      left[i] += this.mix * dl; right[i] += this.mix * dr;
      this.cursor = (this.cursor + 1) % this.left.length;
    }
  }
}
