// PortolanEngineV3 — Processing port of constelation/ with ControlP5 side panels.
// Install the ControlP5 library once via Sketch → Import Library → Add Library
// (search "ControlP5" by Andreas Schlegel).

import controlP5.*;

PortolanApp app;
ControlP5 cp5;
String setupError = null;

void settings() {
  size(WINDOW_W, CANVAS_H);
  pixelDensity(PIXEL_DENSITY);
}

void setup() {
  try {
    app = new PortolanApp(this);
    app.xOff = LEFT_PANEL_W;
    cp5 = new ControlP5(this);
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
  // ControlP5 auto-renders after draw().
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

// Mouse events are forwarded to the app only when the cursor is inside the
// canvas strip. ControlP5 handles clicks on its own widgets.
boolean inCanvas() {
  return mouseX >= LEFT_PANEL_W
    && mouseX < LEFT_PANEL_W + CANVAS_W
    && mouseY >= 0
    && mouseY < CANVAS_H;
}

void mousePressed()  { if (app != null && inCanvas()) { app.mouseP(); redraw(); } }
void mouseDragged()  { if (app != null && inCanvas()) { app.mouseD(); redraw(); } }
void mouseReleased() { if (app != null)               { app.mouseR(); redraw(); } }
void keyPressed()    { if (app != null) { app.key(key); redraw(); } }
