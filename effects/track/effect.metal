// Blob tracking: a thin box on each followed point with its id and coordinates, the colors flipped
// inside it, and lines chaining the points together.

// 3x5 pixel glyphs, top row in the high bits: 0-9, then '.' (10) and ' ' (11).
constant ushort trackGlyphs[12] = {
  0x7B6F, 0x2C97, 0x73E7, 0x73CF, 0x5BC9, 0x79CF, 0x79EF, 0x7249, 0x7BEF, 0x7BCF, 0x0002, 0x0000
};

// Whether pixel `q` (relative to the text's top-left, in font pixels) lands on glyph `g`.
inline bool trackGlyphPixel(int g, int2 q) {
  if (q.x < 0 || q.x > 2 || q.y < 0 || q.y > 4) return false;
  return (trackGlyphs[g] >> (14 - (q.y * 3 + q.x))) & 1;
}

// The label "ID X.XXX Y.YYY" as glyph indices: two id digits, the point's position as 0-999.
inline int trackLabelGlyph(int i, float id, float2 at) {
  int x = clamp(int(at.x * 1000), 0, 999), y = clamp(int(at.y * 1000), 0, 999);
  int idn = int(id) % 100;
  switch (i) {
    case 0: return idn / 10;
    case 1: return idn % 10;
    case 2: return 11;
    case 3: return 10;
    case 4: return x / 100;
    case 5: return (x / 10) % 10;
    case 6: return x % 10;
    case 7: return 11;
    case 8: return 10;
    case 9: return y / 100;
    case 10: return (y / 10) % 10;
    case 11: return y % 10;
    default: return 11;
  }
}

inline float trackSegment(float2 p, float2 a, float2 b) {
  float2 ab = b - a;
  float k = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-3), 0.0, 1.0);
  return length(p - a - ab * k);
}

float4 effect(Layer src, float2 pos, Signals s, constant float *p) {
  float4 c = src.read(pos);
  int n = int(s.blobs);
  if (n == 0 || p[0] <= 0) return c;
  float px = max(1.0, round(s.size.y / 1080));  // line width and font pixel
  float ink = 0, flip = 0;
  for (int i = 0; i < n; i++) {
    float4 b = src.blobs[i];
    float radius = b.z * p[1] * 0.5;
    float2 d = abs(pos - b.xy);
    // Inside the box, and on its 1-pixel outline.
    if (d.x < radius && d.y < radius) flip = 1;
    float ring = max(d.x, d.y);
    if (ring < radius + px * 0.5 && ring > radius - px * 0.5) ink = 1;
    // The label sits over the box's top-left corner.
    if (p[3] > 0) {
      float2 origin = b.xy + float2(-radius, -radius - px * 7);
      int2 q = int2(floor((pos - origin) / px));
      if (q.y >= 0 && q.y < 5 && q.x >= 0 && q.x < 12 * 4) {
        int g = q.x / 4;
        if (trackGlyphPixel(trackLabelGlyph(g, b.w, b.xy / s.size), int2(q.x % 4, q.y))) ink = max(ink, p[3]);
      }
    }
    // Chain each point to the next, when it's near (a fifth of the layer's height).
    if (p[2] > 0 && i + 1 < n) {
      float2 a = b.xy, e = src.blobs[i + 1].xy;
      if (distance(a, e) < s.size.y * 0.2 && trackSegment(pos, a, e) < px * 0.5) ink = max(ink, p[2] * 0.6);
    }
  }
  float3 rgb = mix(c.rgb, 1 - c.rgb, flip * p[4] * p[0]);
  rgb = mix(rgb, float3(1), ink * p[0]);
  return float4(rgb, c.a);
}
