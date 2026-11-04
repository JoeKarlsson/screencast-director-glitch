// Detector boxes: a thin outline around each thing Screencast Director finds (the face, each hand,
// the person, a held-up object; the pointer and clicks on the screen), with a small tag naming it
// and Vision's confidence. Nothing is drawn inside a box.

// 3x5 pixel glyphs, top row in the high bits, in this order: 0123456789 %ABCDEFHIJKLNOPRSTU
constant ushort trackGlyphs[30] = { 0x7B6F, 0x2C97, 0x73E7, 0x73CF, 0x5BC9, 0x79CF, 0x79EF, 0x7292, 0x7BEF, 0x7BCF, 0x0000, 0x52A5, 0x2BED, 0x6BAE, 0x3923, 0x6B6E, 0x79A7, 0x79A4, 0x5BED, 0x7497, 0x126A, 0x5BAD, 0x4927, 0x6B6D, 0x2B6A, 0x6BA4, 0x6BAD, 0x388E, 0x7492, 0x5B6F };
constant int trackSpace = 10, trackPercent = 11;
// Each kind's name as glyph indices: FACE, HAND, PERSON, OBJECT, CURSOR, CLICK.
constant int trackNames[6][6] = { {17, 12, 14, 16, 10, 10}, {18, 12, 23, 15, 10, 10}, {25, 16, 26, 27, 24, 23}, {24, 13, 20, 16, 14, 28}, {14, 29, 26, 27, 24, 26}, {14, 22, 19, 14, 21, 10} };

inline int trackNameRow(float kind) {
  int k = int(kind + 0.5);
  return k == 10 ? 4 : k == 11 ? 5 : clamp(k - 1, 0, 3);
}

// The tag's glyph at slot i: the name, a space, then the confidence as a percent.
inline int trackTagGlyph(int i, float kind, float confidence) {
  int row = trackNameRow(kind);
  int nameLength = 0;
  for (int j = 0; j < 6; j++) if (trackNames[row][j] != trackSpace) nameLength = j + 1;
  if (i < nameLength) return trackNames[row][i];
  int pct = clamp(int(confidence * 100 + 0.5), 0, 99);
  int j = i - nameLength;
  if (j == 0) return trackSpace;
  if (j == 1) return pct / 10;
  if (j == 2) return pct % 10;
  if (j == 3) return trackPercent;
  return -1;
}

inline int trackTagLength(float kind) {
  int row = trackNameRow(kind), n = 0;
  for (int j = 0; j < 6; j++) if (trackNames[row][j] != trackSpace) n = j + 1;
  return n + 4;
}

inline bool trackGlyphPixel(int g, int2 q) {
  if (g < 0 || q.x < 0 || q.x > 2 || q.y < 0 || q.y > 4) return false;
  return (trackGlyphs[g] >> (14 - (q.y * 3 + q.x))) & 1;
}

float4 effect(Layer src, float2 pos, Signals s, constant float *p) {
  float4 c = src.read(pos);
  int n = int(s.blobs);
  if (n == 0 || p[0] <= 0) return c;
  float px = max(1.0, round(s.size.y / 540));  // outline width
  float fpx = max(1.0, round(s.size.y / 300));  // the tag's font pixel
  float3 rgb = c.rgb;
  for (int i = 0; i < n; i++) {
    float4 b = src.blobs[i].box, info = src.blobs[i].info;
    int kind = int(info.x + 0.5);
    if (kind == 3 && p[3] <= 0) continue;
    if (kind == 4 && p[4] <= 0) continue;
    float2 lo = b.xy, hi = b.xy + b.zw;
    // The outline, inside the box's edge.
    bool inside = all(pos >= lo) && all(pos < hi);
    bool rim = inside && (pos.x < lo.x + px || pos.x >= hi.x - px || pos.y < lo.y + px || pos.y >= hi.y - px);
    if (rim) rgb = mix(rgb, float3(1), p[0]);
    // The tag sits on the box's top edge, outside it (inside when the box touches the top).
    if (p[1] > 0) {
      int len = trackTagLength(info.x);
      float2 tagSize = float2(len * 4 + 1, 7) * fpx;
      bool above = info.w < 0.5 && lo.y - tagSize.y >= 0;
      float2 tag = float2(lo.x, above ? lo.y - tagSize.y : lo.y);
      if (all(pos >= tag) && all(pos < tag + tagSize)) {
        int2 q = int2(floor((pos - tag) / fpx)) - int2(1, 1);
        bool ink = q.x >= 0 && trackGlyphPixel(trackTagGlyph(q.x / 4, info.x, info.y), int2(q.x % 4, q.y));
        rgb = mix(rgb, ink ? float3(0) : float3(1), p[0] * p[1]);
      }
    }
    // Lines joining each box's center to the next.
    if (p[2] > 0 && i + 1 < n) {
      float2 a = b.xy + b.zw / 2, e = src.blobs[i + 1].box.xy + src.blobs[i + 1].box.zw / 2;
      float2 ab = e - a;
      float k = clamp(dot(pos - a, ab) / max(dot(ab, ab), 1e-3), 0.0, 1.0);
      if (length(pos - a - ab * k) < px * 0.5) rgb = mix(rgb, float3(1), p[0] * p[2] * 0.6);
    }
  }
  return float4(rgb, c.a);
}
