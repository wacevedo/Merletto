// Planar point (port of geometry.js Point, renamed to avoid awt)

class GPoint {
  float x, y;
  GPoint() {
    this(0, 0);
  }
  GPoint(float x, float y) {
    this.x = x;
    this.y = y;
  }
  float dot(GPoint p) {
    return x * p.x + y * p.y;
  }
  GPoint add(GPoint p) {
    return new GPoint(x + p.x, y + p.y);
  }
  GPoint sub(GPoint p) {
    return new GPoint(x - p.x, y - p.y);
  }
  GPoint scale(float s) {
    return new GPoint(x * s, y * s);
  }
  float sqDistanceTo(GPoint p) {
    float dx = x - p.x, dy = y - p.y;
    return dx * dx + dy * dy;
  }
  void copyFrom(GPoint p) {
    x = p.x;
    y = p.y;
  }
  String toStr() {
    return "(" + nf(x, 0, 3) + ", " + nf(y, 0, 3) + ")";
  }
}
