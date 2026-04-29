// Geometry helpers — top-level functions (live on the sketch class, callable from
// any .pde tab and from inner classes without qualification). In Processing, each
// .pde tab is compiled as part of the main PApplet class (classes inside tabs
// become non-static inner classes). Top-level `static` methods aren't allowed
// inside inner classes, so we keep helpers as plain top-level functions.

// Output abstraction so the same drawing code can target either Processing's
// PApplet OR an SVG StringBuilder. Drawing primitives (lines and circles) are
// emitted via a Renderer; concrete subclasses translate them to PApplet calls
// for live rendering, or to SVG <line>/<circle> elements for export.
//
// This is what makes "Export Pattern SVG" / "Export Full SVG" produce the
// exact same Rosone 1 / Rosone 2 figure the canvas shows — drawAll() and
// patternToSvg() both call drawRosone1OnPolygon / drawRosone2OnPolygon, just
// with different Renderer implementations.
interface Renderer {
  void line(float x1, float y1, float x2, float y2);
  void circle(float cx, float cy, float diameter);
  // Set the active stroke color and weight. PARenderer translates this
  // to pa.stroke / pa.strokeWeight; SVGRenderer closes the current
  // <g> and opens a new one with the new attrs so each color/weight
  // run becomes its own SVG group, preserving the multi-color look
  // that drawRosone3 (gray construction guides + red main rosette)
  // and drawRosone1 (teal tile + red star) need on export.
  void setStroke(int r, int g, int b, float weight);
}

class PARenderer implements Renderer {
  PApplet pa;
  PARenderer(PApplet pa) { this.pa = pa; }
  public void line(float x1, float y1, float x2, float y2) { pa.line(x1, y1, x2, y2); }
  public void circle(float cx, float cy, float d) { pa.ellipse(cx, cy, d, d); }
  public void setStroke(int r, int g, int b, float weight) {
    pa.stroke(r, g, b);
    pa.strokeWeight(weight);
  }
}

class SVGRenderer implements Renderer {
  StringBuilder sb;
  String prefix;
  // Track the currently-open <g> so setStroke can close+reopen on
  // every color/weight change. Calling setStroke before any line/circle
  // is the normal case; if a caller draws without ever setting stroke
  // first, we lazily open a default group on the first primitive.
  boolean groupOpen = false;
  int curR = 0, curG = 0, curB = 0;
  float curWeight = 1.0f;

  SVGRenderer(StringBuilder sb, String prefix) {
    this.sb = sb;
    this.prefix = prefix;
  }

  public void line(float x1, float y1, float x2, float y2) {
    ensureGroup();
    sb.append(prefix).append("  ").append(String.format(java.util.Locale.US,
      "<line x1=\"%.3f\" y1=\"%.3f\" x2=\"%.3f\" y2=\"%.3f\"/>\n",
      x1, y1, x2, y2));
  }
  public void circle(float cx, float cy, float d) {
    ensureGroup();
    sb.append(prefix).append("  ").append(String.format(java.util.Locale.US,
      "<circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\"/>\n",
      cx, cy, d / 2.0f));
  }
  public void setStroke(int r, int g, int b, float weight) {
    if (groupOpen && r == curR && g == curG && b == curB && abs(weight - curWeight) < 1e-3f) {
      return; // No-op when color/weight haven't actually changed.
    }
    closeGroup();
    curR = r; curG = g; curB = b; curWeight = weight;
    String hex = String.format("#%02x%02x%02x", r, g, b);
    sb.append(prefix).append(String.format(java.util.Locale.US,
      "<g stroke=\"%s\" stroke-width=\"%.3f\" fill=\"none\">\n", hex, weight));
    groupOpen = true;
  }
  // Caller invokes this after the last draw to flush the trailing group.
  void close() { closeGroup(); }

  void ensureGroup() {
    if (!groupOpen) {
      // Default style if nobody called setStroke: red @ 1.0px to match
      // the legacy single-group export look.
      setStroke(0xdd, 0x5c, 0x50, 1.0f);
    }
  }
  void closeGroup() {
    if (groupOpen) {
      sb.append(prefix).append("</g>\n");
      groupOpen = false;
    }
  }
}

// Render a closed polygon outline as a sequence of line segments. Works with
// any Renderer — SVG path data is composed of <line> elements and PApplet
// would just call line() in sequence.
void renderPolygonClosed(Renderer r, GPoint[] pts) {
  int n = pts.length;
  if (n < 2) return;
  for (int i = 0; i < n; ++i) {
    GPoint p1 = pts[i];
    GPoint p2 = pts[(i + 1) % n];
    r.line(p1.x, p1.y, p2.x, p2.y);
  }
}

float cross(GPoint vec0, GPoint vec1) {
  return vec0.x * vec1.y - vec0.y * vec1.x;
}

GPoint[] edgePair(GPoint a, GPoint b) {
  return new GPoint[] { a, b };
}

float getPointOrientation(GPoint[] edge, GPoint p) {
  GPoint e01 = edge[1].sub(edge[0]);
  GPoint e0p = p.sub(edge[0]);
  return cross(e01, e0p);
}

boolean isEdgeIntersecting(GPoint[] edgeA, GPoint[] edgeB) {
  GPoint vecA0A1 = edgeA[1].sub(edgeA[0]);
  GPoint vecA0B0 = edgeB[0].sub(edgeA[0]);
  GPoint vecA0B1 = edgeB[1].sub(edgeA[0]);
  float AxB0 = cross(vecA0A1, vecA0B0);
  float AxB1 = cross(vecA0A1, vecA0B1);
  if ((AxB0 > 0 && AxB1 > 0) || (AxB0 < 0 && AxB1 < 0)) return false;
  GPoint vecB0B1 = edgeB[1].sub(edgeB[0]);
  GPoint vecB0A0 = edgeA[0].sub(edgeB[0]);
  GPoint vecB0A1 = edgeA[1].sub(edgeB[0]);
  float BxA0 = cross(vecB0B1, vecB0A0);
  float BxA1 = cross(vecB0B1, vecB0A1);
  if ((BxA0 > 0 && BxA1 > 0) || (BxA0 < 0 && BxA1 < 0)) return false;
  if (abs(AxB0) < 1e-14f && abs(AxB1) < 1e-14f) {
    if ((max(edgeB[0].x, edgeB[1].x) < min(edgeA[0].x, edgeA[1].x)) ||
        (min(edgeB[0].x, edgeB[1].x) > max(edgeA[0].x, edgeA[1].x))) return false;
    if ((max(edgeB[0].y, edgeB[1].y) < min(edgeA[0].y, edgeA[1].y)) ||
        (min(edgeB[0].y, edgeB[1].y) > max(edgeA[0].y, edgeA[1].y))) return false;
  }
  return true;
}

boolean isQuadConvex(GPoint p0, GPoint p1, GPoint p2, GPoint p3) {
  GPoint[] diag0 = { p0, p2 };
  GPoint[] diag1 = { p1, p3 };
  return isEdgeIntersecting(diag0, diag1);
}

boolean isSameEdge(int[] e0, int[] e1) {
  return (e0[0] == e1[0] && e0[1] == e1[1]) || (e0[1] == e1[0] && e0[0] == e1[1]);
}

GPoint getCircumcenter(GPoint p0, GPoint p1, GPoint p2) {
  float d = 2 * (p0.x * (p1.y - p2.y) + p1.x * (p2.y - p0.y) + p2.x * (p0.y - p1.y));
  float m0 = p0.x * p0.x + p0.y * p0.y;
  float m1 = p1.x * p1.x + p1.y * p1.y;
  float m2 = p2.x * p2.x + p2.y * p2.y;
  float xc = (m0 * (p1.y - p2.y) + m1 * (p2.y - p0.y) + m2 * (p0.y - p1.y)) / d;
  float yc = (m0 * (p2.x - p1.x) + m1 * (p0.x - p2.x) + m2 * (p1.x - p0.x)) / d;
  return new GPoint(xc, yc);
}

GPoint intersectLines(GPoint p1, GPoint p2, GPoint q1, GPoint q2) {
  float num = (q2.x - q1.x) * (p1.y - q1.y) - (q2.y - q1.y) * (p1.x - q1.x);
  float den = (q2.y - q1.y) * (p2.x - p1.x) - (q2.x - q1.x) * (p2.y - p1.y);
  float ua = num / den;
  return new GPoint(p1.x + ua * (p2.x - p1.x), p1.y + ua * (p2.y - p1.y));
}

// Sort points in-place counterclockwise by angle around (cx, cy)
void sortGPointsByAngle(java.util.ArrayList<GPoint> pts, final float cx, final float cy) {
  pts.sort(new java.util.Comparator<GPoint>() {
    public int compare(GPoint a, GPoint b) {
      float aa = atan2(a.y - cy, a.x - cx);
      float bb = atan2(b.y - cy, b.x - cx);
      return Float.compare(aa, bb);
    }
  });
}

// Convex hull via Andrew's monotone chain (O(n log n)). Returns hull vertices
// in CCW order. Used by Rosone 2 to find the outer boundary of the pattern.
java.util.ArrayList<GPoint> convexHullPoints(java.util.ArrayList<GPoint> in) {
  int n = in.size();
  if (n < 3) return new java.util.ArrayList<GPoint>(in);
  java.util.ArrayList<GPoint> sorted = new java.util.ArrayList<GPoint>(in);
  sorted.sort(new java.util.Comparator<GPoint>() {
    public int compare(GPoint a, GPoint b) {
      int c = Float.compare(a.x, b.x);
      return c != 0 ? c : Float.compare(a.y, b.y);
    }
  });
  java.util.ArrayList<GPoint> lower = new java.util.ArrayList<GPoint>();
  for (GPoint p : sorted) {
    while (lower.size() >= 2 && hullCross(lower.get(lower.size() - 2), lower.get(lower.size() - 1), p) <= 0) {
      lower.remove(lower.size() - 1);
    }
    lower.add(p);
  }
  java.util.ArrayList<GPoint> upper = new java.util.ArrayList<GPoint>();
  for (int i = sorted.size() - 1; i >= 0; --i) {
    GPoint p = sorted.get(i);
    while (upper.size() >= 2 && hullCross(upper.get(upper.size() - 2), upper.get(upper.size() - 1), p) <= 0) {
      upper.remove(upper.size() - 1);
    }
    upper.add(p);
  }
  // Drop the last point of each list (same as first point of the other).
  lower.remove(lower.size() - 1);
  upper.remove(upper.size() - 1);
  lower.addAll(upper);
  return lower;
}

float hullCross(GPoint o, GPoint a, GPoint b) {
  return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
}

// Render a circular arc from p1 → p2 that bows outward away from `inside`
// by `bulge` pixels (the sagitta). The arc is approximated with line
// segments emitted through a Renderer, which lets the same code drive both
// the Processing canvas and SVG export.
//
// Geometry: given chord length L and sagitta h, the arc's circle radius is
//   r = h/2 + L^2/(8h)
// and the circle center sits on the chord-perpendicular line on the side
// opposite the bulge, at distance (r - h) from the chord midpoint.
void drawArcBulge(Renderer r, GPoint p1, GPoint p2, GPoint inside, float bulge, int segments) {
  float dx = p2.x - p1.x, dy = p2.y - p1.y;
  float L = sqrt(dx * dx + dy * dy);
  if (L < 1e-4f || bulge < 1e-4f) {
    r.line(p1.x, p1.y, p2.x, p2.y);
    return;
  }
  float mx = (p1.x + p2.x) / 2, my = (p1.y + p2.y) / 2;
  // Unit perpendicular to the chord. Pick the side facing AWAY from `inside`.
  float nx = -dy / L, ny = dx / L;
  if ((inside.x - mx) * nx + (inside.y - my) * ny > 0) { nx = -nx; ny = -ny; }
  float rad = bulge / 2 + (L * L) / (8 * bulge);
  float d = rad - bulge;
  // Arc center sits on the inside half (negate the outward normal).
  float cx = mx - nx * d, cy = my - ny * d;
  float a1 = atan2(p1.y - cy, p1.x - cx);
  float a2 = atan2(p2.y - cy, p2.x - cx);
  // Sweep the short way around: if the difference exceeds π, normalize.
  float da = a2 - a1;
  while (da >  PI) da -= TWO_PI;
  while (da < -PI) da += TWO_PI;
  GPoint prev = p1;
  for (int i = 1; i <= segments; ++i) {
    float t = (float) i / segments;
    float ang = a1 + da * t;
    GPoint cur = new GPoint(cx + rad * cos(ang), cy + rad * sin(ang));
    r.line(prev.x, prev.y, cur.x, cur.y);
    prev = cur;
  }
}

BoundingBox computeBoundingBox(Mesh m) {
  float left = 0, right = 0, top = 0, bottom = 0;
  for (int idx = 0; idx < m.numPoints(); idx++) {
    VertProperty vp = m.vertProps.get(idx);
    if (vp.center == null) continue;
    if (vp.boundary) {
      GPoint c = vp.center;
      float r = vp.radius;
      left = min(c.x - r, left);
      right = max(c.x + r, right);
      top = min(c.y - r, top);
      bottom = max(c.y + r, bottom);
    }
  }
  float w = right - left, h = bottom - top;
  return new BoundingBox(w, h, new GPoint(left + w / 2, top + h / 2));
}
