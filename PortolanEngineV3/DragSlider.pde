// DragSlider — a minimal horizontal slider that we fully control.
//
// Why this exists: ControlP5's Slider / Numberbox have awkward drag UX that
// we kept fighting with (no visible thumb, tiny hit target, or drag requiring
// an exact-hit on an invisible strip). Writing our own slider is <150 lines
// and gives us exactly the "grab the ball and drag it" behavior users expect.
//
// Usage: buildUI() creates DragSliders and stashes them in UI.pde's `sliders`
// map. PortolanEngineV3.pde's draw() calls s.draw(this) after card chrome is
// painted, and its mouse callbacks forward events to sliders *before* the
// PortolanApp so a click-on-slider never reaches the drawing canvas.
class DragSlider {
  // Name matches the ControlP5 W_* constant for the widget this replaces —
  // UI.pde switches on it in onSliderChange() to route value changes to the app.
  String name;

  // Geometry (top-left of the full row; track itself is inset).
  float x, y, w, h;

  // Value range and current value.
  float minV, maxV, value;
  int decimals;        // how many digits to display (0 for integers)
  boolean integerSnap; // true → value is rounded on every update

  // Display.
  String label;
  boolean visible = true;
  boolean dragging = false;

  // When true (default), onSliderChange fires on every drag tick so the
  // mesh/pattern update continuously while you scrub. When false, it fires
  // only on release — useful for sliders whose change triggers expensive
  // work (e.g. a full mesh.recompute after setGraph).
  boolean liveUpdate = true;

  DragSlider setLiveUpdate(boolean v) { this.liveUpdate = v; return this; }

  // Styling constants (matched to UI.pde's palette).
  final int TRACK_COLOR    = 0xffd0d4d8;
  final int FILL_COLOR     = 0xff4a90e2;
  final int THUMB_FILL     = 0xffffffff;
  final int THUMB_STROKE   = 0xff4a90e2;
  final int THUMB_R        = 8;
  final int HIT_PAD        = 6;   // extra vertical slop so the track is easy to grab

  DragSlider(String name, float x, float y, float w, float h,
             float minV, float maxV, float value,
             int decimals, boolean integerSnap, String label) {
    this.name = name;
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.minV = minV; this.maxV = maxV;
    this.decimals = decimals;
    this.integerSnap = integerSnap;
    this.label = label;
    this.value = clampAndSnap(value);
  }

  float clampAndSnap(float v) {
    float c = constrain(v, minV, maxV);
    if (integerSnap) c = round(c);
    return c;
  }

  void setValue(float v) { value = clampAndSnap(v); }

  // Is (mx,my) inside the clickable area for this slider? We include vertical
  // padding so the user doesn't have to hit the 2 px track exactly.
  boolean hit(float mx, float my) {
    if (!visible) return false;
    return mx >= x && mx <= x + w
        && my >= y - HIT_PAD && my <= y + h + HIT_PAD;
  }

  // Called by PortolanEngineV3.pde's mousePressed.
  // Returns true if this slider took ownership of the drag.
  boolean press(float mx, float my) {
    if (!hit(mx, my)) return false;
    dragging = true;
    return updateFromMouse(mx);
  }

  // Called while dragging.
  boolean drag(float mx, float my) {
    if (!dragging) return false;
    updateFromMouse(mx);
    return true;
  }

  // Called on mouse release. Returns true iff we were dragging.
  boolean release() {
    boolean was = dragging;
    dragging = false;
    return was;
  }

  // Returns true if the value actually changed.
  boolean updateFromMouse(float mx) {
    float t = constrain((mx - x) / w, 0, 1);
    float newV = clampAndSnap(lerp(minV, maxV, t));
    if (newV == value) return false;
    value = newV;
    return true;
  }

  // Render the slider. `p` is the sketch (PApplet).
  void draw(PApplet p) {
    if (!visible) return;

    float trackY = y + h / 2.0f;
    float t = (maxV == minV) ? 0 : (value - minV) / (maxV - minV);
    float tx = x + t * w;

    // Caption (label left, current value right) above the track.
    p.textSize(11);
    p.fill(UI_LABEL_COLOR);
    p.textAlign(p.LEFT, p.BASELINE);
    p.text(label, x, y - 4);
    p.textAlign(p.RIGHT, p.BASELINE);
    p.text(formatValue(), x + w, y - 4);

    // Track (full width, unfilled portion).
    p.strokeWeight(4);
    p.stroke(TRACK_COLOR);
    p.line(x, trackY, x + w, trackY);

    // Filled portion (from left up to thumb).
    p.stroke(FILL_COLOR);
    p.line(x, trackY, tx, trackY);

    // Thumb.
    p.strokeWeight(2);
    p.stroke(THUMB_STROKE);
    p.fill(THUMB_FILL);
    p.ellipse(tx, trackY, THUMB_R * 2, THUMB_R * 2);

    // Reset stroke weight so we don't leak into later drawing.
    p.strokeWeight(1);
    p.noStroke();
  }

  String formatValue() {
    if (integerSnap || decimals == 0) return str((int) value);
    // Use Java's String.format so we don't pull in Processing's locale.
    return String.format(java.util.Locale.US, "%." + decimals + "f", value);
  }
}
