// Cut glitch: the signal breaks up for a moment around every visible change (a cut, B-roll or an
// animation coming or going, a layout change, a punch-in), hardest right on it. Macroblocks jump or
// smear, thin rows tear sideways, the color splits and crushes. `window` is how many seconds each
// side of the change it lasts; `amount` scales how hard it hits.
// Sizes are in pixels at 1080p and scale with the layer's short side.

float4 effect(Layer src, float2 pos, Signals s, constant float *p) {
  float window = p[0], amount = p[1];
  float g = amount * clamp(1.0 - s.toCut / window, 0.0, 1.0);
  if (g <= 0.0) return src.read(pos);
  float k = min(s.size.x, s.size.y) / 1080.0;
  // The damage changes 24 times a second, chunky like a decoder losing its place.
  float seed = floor(s.time * 24.0);
  float2 q = pos;

  // Macroblocks: some show pixels from somewhere else, some smear their top row down.
  float bs = 48.0 * k;
  float2 block = floor(pos / bs);
  float r = hash(block + seed * 1.37);
  bool broken = r < 0.65 * g;
  if (r < 0.45 * g) {
    q += (float2(hash(block + seed + 3.1), hash(block + seed + 7.3)) - 0.5) * float2(260.0, 90.0) * k * g;
  } else if (broken) {
    q.y = block.y * bs;
  }

  // Row tears: thin bands slide sideways.
  float row = floor(pos.y / (10.0 * k));
  if (hash(float2(row, seed * 2.11)) < 0.3 * g) q.x += (hash(float2(row + 5.0, seed)) - 0.5) * 320.0 * k * g;

  // RGB split, wider the harder it hits, and crushed color in the broken blocks.
  float split = 22.0 * k * g;
  float3 col = float3(src.read(q - float2(split, 0)).r, src.read(q).g, src.read(q + float2(split, 0)).b);
  if (broken) col = floor(col * 6.0) / 6.0;
  return float4(col, 1.0);
}
