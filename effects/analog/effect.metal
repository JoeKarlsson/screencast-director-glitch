// Analog: a worn VHS/CRT signal. Chroma split and bleed, bloom that pushes warm highlights,
// scanlines, grain, a vignette, and a tape-tracking band that rolls through every 14 s.
// Sizes are in pixels at 1080p and scale with the layer's short side.

float4 effect(Layer src, float2 pos, Signals s, constant float *p) {
  float chroma = p[0], bleed = p[1], scan = p[2], grain = p[3], bloom = p[4], vig = p[5], tracking = p[6];
  float k = min(s.size.x, s.size.y) / 1080.0;

  // Tracking band: a 70 px strip that wobbles sideways and washes out as it rolls down.
  float bandY = (fract(s.time / 14.0) * 1.3 - 0.15) * s.size.y;
  float d = (pos.y - bandY) / (70.0 * k);
  float inBand = tracking * step(0.0, d) * step(d, 1.0);
  float2 q = pos;
  q.x += inBand * (18.0 * k * sin(d * 7.0) + (hash(float2(floor(pos.y), s.frame)) - 0.5) * 12.0 * k);

  // Chroma split: red from the left, blue from the right.
  float4 base = src.read(q);
  float3 col = float3(src.read(q - float2(chroma * k, 0)).r, base.g, src.read(q + float2(chroma * k, 0)).b);

  // Chroma bleed: keep this pixel's brightness, smear its color sideways.
  float y = luma(float4(col, 1));
  float3 smear = 0;
  for (int i = -3; i <= 3; i++) {
    float4 t = src.read(q + float2(float(i) * bleed * k / 3.0, 0));
    smear += t.rgb - luma(t);
  }
  col = y + mix(col - y, smear / 7.0, 0.7);

  // Bloom: highlights glow outward, warm, like the orange key light blowing out on tape.
  float3 glow = 0;
  for (int ring = 1; ring <= 2; ring++) {
    float r = 26.0 * k * float(ring);
    for (int a = 0; a < 8; a++) {
      float ang = float(a) * 0.785398 + float(ring) * 0.39;
      glow += max(src.read(pos + float2(cos(ang), sin(ang)) * r).rgb - 0.65, 0.0) * 2.5;
    }
  }
  col += glow / 16.0 * float3(0.55, 0.32, 0.12) * bloom;

  // Inside the band: washed out and noisy.
  col = mix(col, col * 0.85 + 0.12, inBand) + inBand * (hash(pos + s.frame) - 0.5) * 0.12;

  // Scanlines: two lit rows, two dim ones (at 1080p).
  col *= 1.0 - scan * step(2.0, fmod(floor(pos.y / k), 4.0));

  // Grain, then the vignette.
  col += (hash(pos * 0.73 + float2(s.frame * 13.1, s.frame * 7.7)) - 0.5) * grain * 2.0;
  float2 nd = (pos / s.size - 0.5) * 2.0;
  col *= 1.0 - vig * clamp(length(nd) - 0.55, 0.0, 1.0);
  return float4(clamp(col, 0.0, 1.0), 1.0);
}
