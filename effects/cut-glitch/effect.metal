// Cut glitch: the signal breaks up for a moment around every visible change (a cut, B-roll or an
// animation coming or going, a layout change, a punch-in), hardest right on it. Each change gets its
// own kind of damage (the six take turns) and its own length, strength and direction (picked from
// when it happens), so back-to-back cuts don't repeat, and a video renders the same every time:
//   blocks   macroblocks jump or smear their top row down, color crushed
//   slip     the picture slips up or down and wraps, with a hot tear line at the seam
//   wave     rows ripple sideways like a bent tape
//   melt     columns drip down from one line, like data smearing
//   burst    red, green and blue pull apart from the center at different sizes
//   comb     interlaced line groups pull apart sideways
// `window` is the average seconds each side of the change; `amount` scales how hard it hits.
// Sizes are in pixels at 1080p and scale with the layer's short side.

float4 effect(Layer src, float2 pos, Signals s, constant float *p) {
  float window = p[0], amount = p[1];
  if (s.cutTime < 0.0) return src.read(pos);
  float id = s.cutTime * 7.31;
  // The kinds take turns, so no two changes in a row break up the same way.
  float kind = fmod(s.cutIndex * 5.0, 6.0);
  float len = window * mix(0.6, 1.5, hash(float2(id, 4.2)));
  float g = amount * mix(0.55, 1.25, hash(float2(id, 9.9))) * clamp(1.0 - s.toCut / len, 0.0, 1.0);
  if (g <= 0.0) return src.read(pos);
  float k = min(s.size.x, s.size.y) / 1080.0;
  float dir = hash(float2(id, 2.3)) < 0.5 ? -1.0 : 1.0;
  // The damage changes 24 times a second, chunky like a decoder losing its place.
  float seed = floor(s.time * 24.0) + id;
  float2 q = pos;
  float split = 0.0;
  float crush = 0.0;
  float flare = 0.0;

  if (kind == 0.0) {
    float bs = mix(24.0, 72.0, hash(float2(id, 6.1))) * k;
    float2 block = floor(pos / bs);
    float r = hash(block + seed * 1.37);
    if (r < 0.45 * g) {
      q += (float2(hash(block + seed + 3.1), hash(block + seed + 7.3)) - 0.5) * float2(260.0, 90.0) * k * g;
    } else if (r < 0.65 * g) {
      q.y = block.y * bs;
    }
    crush = r < 0.65 * g ? 1.0 : 0.0;
    float row = floor(pos.y / (10.0 * k));
    if (hash(float2(row, seed * 2.11)) < 0.3 * g) q.x += (hash(float2(row + 5.0, seed)) - 0.5) * 320.0 * k * g;
    split = 22.0 * k * g;
  } else if (kind == 1.0) {
    float off = g * min(0.15 * s.size.y, 640.0) * dir;
    q.y = fmod(pos.y + off + s.size.y, s.size.y);
    float seam = fmod(s.size.y - off + s.size.y, s.size.y);
    flare = clamp(1.0 - abs(pos.y - seam) / (16.0 * k), 0.0, 1.0) * g;
    q.x += flare * (hash(float2(floor(pos.y), seed)) - 0.5) * 60.0 * k;
    split = 10.0 * k * g;
  } else if (kind == 2.0) {
    float row = floor(pos.y / (6.0 * k));
    q.x += sin(pos.y / (38.0 * k) + s.time * 40.0 * dir) * 70.0 * k * g + (hash(float2(row, seed)) - 0.5) * 20.0 * k * g;
    split = 14.0 * k * g;
  } else if (kind == 3.0) {
    float lineY = mix(0.2, 0.7, hash(float2(id, 5.5))) * s.size.y;
    float drip = hash(float2(floor(pos.x / (6.0 * k)), id)) * 420.0 * k * g;
    bool melted = pos.y > lineY && pos.y < lineY + drip;
    if (melted) q.y = lineY;
    crush = melted ? 0.6 : 0.0;
    split = 6.0 * k * g;
  } else if (kind == 4.0) {
    float2 c = s.size * 0.5;
    float z = 0.06 * g;
    float3 col = float3(src.read(c + (pos - c) * (1.0 - z)).r, src.read(pos).g, src.read(c + (pos - c) * (1.0 + z)).b);
    return float4(col, 1.0);
  } else {
    float band = floor(pos.y / (3.0 * k));
    q.x += (fmod(band, 2.0) == 0.0 ? 1.0 : -1.0) * 40.0 * k * g * dir;
    crush = g > 0.5 ? 1.0 : 0.0;
    split = 8.0 * k * g;
  }

  float3 col = float3(src.read(q - float2(split, 0)).r, src.read(q).g, src.read(q + float2(split, 0)).b);
  if (crush > 0.0) col = mix(col, floor(col * 6.0) / 6.0, crush);
  col += flare * 0.6;
  return float4(clamp(col, 0.0, 1.0), 1.0);
}
