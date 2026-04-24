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
  // Side-panel backgrounds.
  noStroke();
  fill(236, 239, 241);
  rect(0, 0, LEFT_PANEL_W, CANVAS_H);
  rect(LEFT_PANEL_W + CANVAS_W, 0, RIGHT_PANEL_W, CANVAS_H);
  // Panel titles (ControlP5 labels overlay these — we still paint the header strip).
  fill(255);
  rect(0, 0, LEFT_PANEL_W, 40);
  rect(LEFT_PANEL_W + CANVAS_W, 0, RIGHT_PANEL_W, 40);
  fill(40);
  textSize(14);
  textAlign(LEFT, CENTER);
  text("Graphical Encoding", 16, 20);
  text("Decoded Pattern", LEFT_PANEL_W + CANVAS_W + 16, 20);

  if (app == null) {
    fill(200, 0, 0);
    textSize(16);
    text("app is NULL. setupError=" + setupError, 20, 60);
    return;
  }

  pushMatrix();
  translate(LEFT_PANEL_W, 0);
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
  popMatrix();
  // ControlP5 auto-renders after draw().
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
