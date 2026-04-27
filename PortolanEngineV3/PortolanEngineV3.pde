// PortolanEngineV3 — Processing port of constelation/ with ControlP5 side panels.
// Install the ControlP5 library once via Sketch → Import Library → Add Library
// (search "ControlP5" by Andreas Schlegel).

import controlP5.*;

PortolanApp app;
ControlP5 cp5;
String setupError = null;

void settings() {
  size(WINDOW_W, CANVAS_H);
  // Use the display's native density (2 on Retina, 1 otherwise). pixelDensity
  // silently caps at whatever the device supports, so asking for the actual
  // display density gives us the crispest output without surprises.
  pixelDensity(displayDensity());
  // smooth(N): N = samples per pixel for MSAA. 2 is the Processing default;
  // 8 is the max and gives the nicest edges on strokes and glyphs.
  smooth(8);
}

void setup() {
  try {
    // Real TTF font for the sketch. Processing's default (a tiny bitmap
    // "Lucida Sans") pixelates badly once you scale it. createFont loads a
    // system TrueType font which is then rendered through the vector path,
    // so glyph edges get antialiased together with the rest of the scene.
    PFont uiFont = createFont("Helvetica", 14, true);
    textFont(uiFont);

    app = new PortolanApp(this);
    app.xOff = LEFT_PANEL_W;
    cp5 = new ControlP5(this);
    // Apply the same font to every ControlP5 widget caption / value label so
    // slider labels, button titles, and numberbox values are crisp too.
    cp5.setFont(uiFont, 11);
    buildUI(cp5, app);
    app.runSetup();
    syncUIFromApp(cp5, app);
    noLoop();
  } catch (Throwable t) {
    setupError = t.getClass().getSimpleName() + ": " + t.getMessage();
    println("[ERR] setup() threw:");
    t.printStackTrace();
  }
}

void draw() {
  background(245);

  // Right control column background.
  noStroke();
  fill(247);
  rect(CANVAS_W, 0, RIGHT_PANEL_W, CANVAS_H);

  // Two cards ("Graphical Encoding" + "Decoded Pattern"). Coordinates must
  // stay in sync with UI.pde's layout constants below.
  drawPanelCard(CANVAS_W + 12, 12, RIGHT_PANEL_W - 24, UI_ENC_H, "Graphical Encoding");
  drawPanelCard(CANVAS_W + 12, UI_ENC_Y2 + 12, RIGHT_PANEL_W - 24, UI_DEC_H, "Decoded Pattern");

  if (app == null) {
    fill(200, 0, 0);
    textSize(16);
    text("app is NULL. setupError=" + setupError, 20, 60);
    return;
  }

  try {
    app.drawAll();
  } catch (Throwable t) {
    println("[ERR] drawAll() threw:");
    t.printStackTrace();
    fill(255);
    rect(0, 0, CANVAS_W, CANVAS_H);
    fill(200, 0, 0);
    textSize(14);
    textAlign(LEFT, BASELINE);
    text("drawAll() error: " + t.getClass().getSimpleName() + " — " + t.getMessage(), 20, 30);
  }

  // Our custom sliders are painted after the canvas drawing but before
  // ControlP5's auto-render so they end up below the dropdown's expanded
  // list. ControlP5 auto-renders its own widgets after draw() returns.
  drawSliders(this);
}

// Draw a single card: rounded-ish rectangle with a section title at the top.
void drawPanelCard(int x, int y, int w, int h, String title) {
  noStroke();
  fill(255);
  rect(x, y, w, h, 6);
  stroke(222);
  noFill();
  rect(x, y, w, h, 6);
  noStroke();
  fill(40);
  textSize(13);
  textAlign(LEFT, CENTER);
  text(title, x + 14, y + 20);
  stroke(232);
  line(x + 10, y + 36, x + w - 10, y + 36);
  noStroke();
}

// Mouse dispatch order on every event:
//   1. DragSliders get first crack (they live in the right panel).
//   2. If no slider consumed it, and the click is inside the drawing canvas,
//      forward to PortolanApp.
//   3. ControlP5 handles clicks on its own widgets through its own listener
//      registration — we don't forward to it manually.
boolean inCanvas() {
  return mouseX >= LEFT_PANEL_W
    && mouseX < LEFT_PANEL_W + CANVAS_W
    && mouseY >= 0
    && mouseY < CANVAS_H;
}

void mousePressed() {
  if (slidersMousePressed(mouseX, mouseY)) { redraw(); return; }
  if (app != null && inCanvas()) { app.mouseP(); redraw(); }
}

void mouseDragged() {
  if (slidersMouseDragged(mouseX, mouseY)) { redraw(); return; }
  if (app != null && inCanvas()) { app.mouseD(); redraw(); }
}

void mouseReleased() {
  boolean wasSlider = slidersMouseReleased();
  if (wasSlider) { redraw(); return; }
  if (app != null) { app.mouseR(); redraw(); }
}

void keyPressed() { if (app != null) { app.key(key); redraw(); } }

// Mouse wheel over the right half of the canvas zooms the pattern in/out
// (1.10x per wheel notch), keeping app.rightZoom in sync with the Zoom
// slider so both controls always agree. Wheel events outside the right
// canvas (the left graph editor or the right control column) are ignored.
void mouseWheel(MouseEvent event) {
  if (app == null) return;
  int rightX0 = LEFT_PANEL_W + CANVAS_W / 2;
  int rightX1 = LEFT_PANEL_W + CANVAS_W;
  if (mouseX < rightX0 || mouseX >= rightX1) return;
  if (mouseY < 0 || mouseY >= CANVAS_H) return;
  float delta = event.getCount();
  float factor = (delta < 0) ? 1.10f : 1.0f / 1.10f;
  float newZoom = constrain(app.rightZoom * factor, 0.5f, 4.0f);
  if (newZoom == app.rightZoom) return;
  app.rightZoom = newZoom;
  DragSlider zs = sliders.get(W_ZOOM);
  if (zs != null) zs.setValue(newZoom);
  redraw();
}
