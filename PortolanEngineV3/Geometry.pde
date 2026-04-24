// Geometry helpers — top-level functions (live on the sketch class, callable from
// any .pde tab and from inner classes without qualification). In Processing, each
// .pde tab is compiled as part of the main PApplet class (classes inside tabs
// become non-static inner classes). Top-level `static` methods aren't allowed
// inside inner classes, so we keep helpers as plain top-level functions.

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
