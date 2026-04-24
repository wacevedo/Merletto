class BoundingBox {
  float width, height;
  GPoint center;
  BoundingBox() {
    width = height = 0;
    center = new GPoint(0, 0);
  }
  BoundingBox(float w, float h, GPoint c) {
    this.width = w;
    this.height = h;
    this.center = c;
  }
}
