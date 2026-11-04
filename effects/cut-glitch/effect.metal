// Cut glitch: a few motivated moments instead of a glitch on every cut.
//   jump back (back from a cold open)   a short VHS rewind with a VCR "<< REW", then "> PLAY" for a beat
//   new section (a chapter or slate)    the picture breaks up hard for a moment; the six kinds of
//                                       break-up take turns (blocks, slip, wave, melt, burst, comb)
//   everything else                     nothing: plain cuts stay clean, and B-roll gets the profile's
//                                       interlace transition from the app
// `window` is about how many seconds each side of a section change the break-up lasts; `amount`
// scales how hard it hits; `rewind` is how many seconds the rewind takes; `osd` 0 hides the VCR text.
// Sizes are in pixels at 1080p and scale with the layer's short side.

// VCR on-screen display: a blocky 5x7 font, just the glyphs "<< REW" and "> PLAY" need.
constant int GLYPHS[10][7] = {
  {1, 3, 7, 15, 7, 3, 1},         // left triangle
  {16, 24, 28, 30, 28, 24, 16},   // right triangle
  {0, 0, 0, 0, 0, 0, 0},          // space
  {30, 17, 17, 30, 20, 18, 17},   // R
  {31, 16, 16, 30, 16, 16, 31},   // E
  {17, 17, 17, 21, 21, 21, 10},   // W
  {30, 17, 17, 30, 16, 16, 16},   // P
  {16, 16, 16, 16, 16, 16, 31},   // L
  {14, 17, 17, 31, 17, 17, 17},   // A
  {17, 17, 10, 4, 4, 4, 4},       // Y
};
constant int REW_TEXT[6] = {0, 0, 2, 3, 4, 5};
constant int PLAY_TEXT[6] = {1, 2, 6, 7, 8, 9};

// Whether `pos` is inside a lit pixel of the text, drawn at the top left.
float osdText(float2 pos, float k, bool play) {
  float cell = 9.0 * k;
  float2 q = (pos - float2(80.0, 140.0) * k) / cell;
  if (q.x < 0.0 || q.y < 0.0 || q.y >= 7.0 || q.x >= 36.0) return 0.0;
  int ch = int(q.x / 6.0);
  int col = int(q.x) - ch * 6;
  if (col >= 5) return 0.0;
  int g = play ? PLAY_TEXT[ch] : REW_TEXT[ch];
  return float((GLYPHS[g][int(q.y)] >> (4 - col)) & 1);
}

float4 withOSD(float4 c, float2 pos, float k, bool play) {
  float shadow = osdText(pos - float2(5.0, 5.0) * k, k, play);
  float lit = osdText(pos, k, play);
  c.rgb = mix(c.rgb, c.rgb * 0.35, shadow);
  return float4(mix(c.rgb, float3(1.0), lit), 1.0);
}

// Tape rewinding: rows shear sideways, the picture rolls, static bars race down, color washes out.
float4 rewound(Layer src, float2 pos, Signals s, float g, float k) {
  float2 q = pos;
  q.x += g * (sin(pos.y / (23.0 * k) + s.time * 90.0) * 14.0 + sin(pos.y / (7.0 * k)) * 5.0) * k;
  q.y += g * 0.06 * s.size.y * (0.5 + 0.5 * sin(s.time * 31.0));
  float4 c = src.read(q);
  for (int i = 0; i < 3; i++) {
    float barY = fract(s.time * 2.7 + float(i) * 0.37) * s.size.y;
    float h = (10.0 + 14.0 * float(i)) * k;
    if (abs(pos.y - barY) < h) c.rgb = mix(c.rgb, float3(hash(pos + s.frame)), 0.7 * g);
  }
  c.rgb = mix(c.rgb, float3(luma(c)), 0.45 * g);
  return c;
}

// A hard break-up for a section change; the kinds take turns by `cutIndex`.
float4 breakup(Layer src, float2 pos, Signals s, float g, float k) {
  float id = s.cutTime * 7.31;
  float kind = fmod(s.cutIndex * 5.0, 6.0);
  float dir = hash(float2(id, 2.3)) < 0.5 ? -1.0 : 1.0;
  float seed = floor(s.time * 24.0) + id;
  float2 q = pos;
  float split = 0.0, crush = 0.0, flare = 0.0;
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
    return float4(src.read(c + (pos - c) * (1.0 - z)).r, src.read(pos).g, src.read(c + (pos - c) * (1.0 + z)).b, 1.0);
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

float4 effect(Layer src, float2 pos, Signals s, constant float *p) {
  float window = p[0], amount = p[1], rewind = p[2], osd = p[3];
  float k = min(s.size.x, s.size.y) / 1080.0;
  if (s.cutKind == 1.0) {
    // Seconds from the jump: a blink of rewinding before it, then the rewind settling onto the shot.
    float d = s.time - s.cutTime;
    if (d >= -0.06 && d < rewind) {
      float g = d < 0.0 ? 1.0 : 1.0 - smoothstep(0.0, rewind, d);
      float4 c = rewound(src, pos, s, g, k);
      return osd > 0.0 ? withOSD(c, pos, k, false) : c;
    }
    if (osd > 0.0 && d >= rewind && d < rewind + 0.5) return withOSD(src.read(pos), pos, k, true);
    return src.read(pos);
  }
  if (s.cutKind == 5.0) {
    float id = s.cutTime * 7.31;
    float len = window * mix(0.6, 1.5, hash(float2(id, 4.2)));
    float g = amount * mix(0.55, 1.25, hash(float2(id, 9.9))) * clamp(1.0 - s.toCut / len, 0.0, 1.0);
    if (g > 0.0) return breakup(src, pos, s, g, k);
  }
  return src.read(pos);
}
