// In-place 2D rotation for PVector (top-level so inner classes can call it directly).
void rotate2D(PVector v, float a) {
  float c = cos(a), s = sin(a);
  float nx = v.x * c - v.y * s;
  float ny = v.x * s + v.y * c;
  v.x = nx;
  v.y = ny;
}
