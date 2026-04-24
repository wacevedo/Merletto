// Hybrid UI for the Processing port.
//
// Numeric inputs (triSize, tau, lambda, etc.) use our own DragSlider class —
// see DragSlider.pde. ControlP5's Slider/Numberbox drag UX was unintuitive
// enough that we replaced it with a custom widget. Everything else (buttons,
// toggles, the graph-type dropdown) still uses ControlP5 where it works well.
//
// Layout: one right-hand control column split into two cards:
//   • "Graphical Encoding": graph-type dropdown, per-type size slider(s),
//     Clear / Export JSON / Export SVG / Import JSON buttons.
//   • "Decoded Pattern":   τ slider, λ slider, Show Packing / Show Tiling
//     toggles, Export Pattern SVG / Export Full SVG buttons.

import java.io.File;
import java.io.FileReader;
import java.io.BufferedReader;
import java.io.FileNotFoundException;

// ControlP5 widget names (must match across buildUI / controlEvent / sync).
final String W_GRAPH_TYPE = "graphType";
final String W_TRI_SIZE   = "triSize";
final String W_KING_SIZE  = "kingSize";
final String W_SPI_LAYERS = "spiderLayers";
final String W_SPI_POINTS = "spiderPoints";
final String W_RAND_PTS   = "randomPoints";
final String W_CLEAR      = "clearGraph";
final String W_EXP_JSON   = "exportGraphJson";
final String W_EXP_GSVG   = "exportGraphSvg";
final String W_IMP_JSON   = "importGraphJson";

final String W_TAU        = "tau";
final String W_LAMBDA     = "lambda";
final String W_SHOW_PACK  = "showPacking";
final String W_SHOW_TILE  = "showTiling";
final String W_EXP_PAT    = "exportPatternSvg";
final String W_EXP_FULL   = "exportFullSvg";

// Dark text color for widget captions so they're legible on the light
// grey panel background. ControlP5's default caption color is white.
final int UI_LABEL_COLOR = 0xff222222;

// Labels shown in the "Graph Type" dropdown. Order must match the indices
// used by PortolanApp.setGraph()/graphKind (0=triangular, 1=king, 2=spider,
// 3=random). Stored as a field so controlEvent() can look up the current
// selection's display name when refreshing the dropdown's bar caption.
final String[] GRAPH_TYPE_LABELS = {
  "Triangular Grid Graph",
  "King's Graph",
  "Triangulated Spider Graph",
  "Random Delaunay Triangulation"
};

// ===== Layout constants (referenced by PortolanEngineV3.pde's card-drawing) =====
// The right column is 340px wide. Each card is inset 12px on each side.
final int UI_CARD_X  = CANVAS_W + 12;
final int UI_CARD_W  = RIGHT_PANEL_W - 24;       // 316
final int UI_ENC_Y1  = 12;                       // top of "Graphical Encoding" card
final int UI_ENC_H   = 340;                      // height of encoding card
final int UI_ENC_Y2  = UI_ENC_Y1 + UI_ENC_H;     // bottom (start of gap) → 352
final int UI_DEC_H   = 288;                      // height of decoded-pattern card

// Inner padding inside each card (text/widgets kept off the rounded border).
final int UI_CARD_PAD_X = 14;
final int UI_CARD_PAD_Y_TOP = 46; // leaves room for the title bar + separator

// All DragSliders live here so PortolanEngineV3.pde can iterate them for
// drawing and mouse dispatch, and syncUIFromApp() can toggle visibility.
HashMap<String, DragSlider> sliders = new HashMap<String, DragSlider>();

// Create a DragSlider, register it in `sliders`, and return it for chaining.
DragSlider addSlider(String name, int x, int y, int w,
                     float min, float max, float value,
                     int decimals, boolean integerSnap, String label) {
  DragSlider s = new DragSlider(name, x, y, w, 22,
    min, max, value, decimals, integerSnap, label);
  sliders.put(name, s);
  return s;
}

void styleCaption(Controller c) {
  if (c == null) return;
  c.getCaptionLabel()
    .align(ControlP5.LEFT, ControlP5.TOP_OUTSIDE)
    .setPaddingX(0)
    .setColor(UI_LABEL_COLOR);
}

void buildUI(ControlP5 cp, PortolanApp a) {
  int rowH = 22;
  int btnH = 26;
  int gap  = 8;

  int colX = UI_CARD_X + UI_CARD_PAD_X;
  int colW = UI_CARD_W - UI_CARD_PAD_X * 2;

  // ===================================================================
  // Card 1 — "Graphical Encoding"
  // ===================================================================
  int y = UI_ENC_Y1 + UI_CARD_PAD_Y_TOP;

  // Static label for the dropdown (ControlP5 Label renders as text only).
  cp.addLabel("lbl_graphType")
    .setText("Graph Type")
    .setPosition(colX, y)
    .setColorValue(UI_LABEL_COLOR);
  y += 16;

  java.util.List<String> graphItems = java.util.Arrays.asList(GRAPH_TYPE_LABELS);
  cp.addScrollableList(W_GRAPH_TYPE)
    .setPosition(colX, y)
    .setSize(colW, 110)
    .setBarHeight(24)
    .setItemHeight(22)
    .addItems(graphItems)
    .setType(ControlP5.LIST)
    .setOpen(false)
    .close()
    .setValue(a.graphKind);
  // ScrollableList uses the caption label as the text shown on the collapsed
  // bar, not the selected item. Seed it with the initial graph-type name;
  // controlEvent() updates it whenever the user picks a new option.
  setGraphTypeBarLabel(cp, a.graphKind);
  y += 24 + 22; // bar height + spacing for slider caption above

  // Per-type parameter sliders. Only one (or one pair) is visible at a time;
  // syncUIFromApp() toggles `visible` based on the selected graph kind. All
  // four int sliders share the same slot, and the spider-graph adds a
  // second row below for "Points per Layer".
  //
  // setLiveUpdate(false): changing graph topology runs mesh.recompute()
  // (CDT + circle packing, which iterates up to 2000 times). We don't want
  // to pay that cost on every pixel of drag, so these commit only when the
  // user lets go of the thumb. The slider number still updates live as you
  // drag so you see exactly where you'll land.
  addSlider(W_TRI_SIZE,   colX, y, colW, 5, 15,  a.triSz, 0, true, "Size").setLiveUpdate(false);
  addSlider(W_KING_SIZE,  colX, y, colW, 5, 12,  a.kSz,   0, true, "Size").setLiveUpdate(false);
  addSlider(W_SPI_LAYERS, colX, y, colW, 3, 8,   a.sLay,  0, true, "Layers").setLiveUpdate(false);
  addSlider(W_SPI_POINTS, colX, y + rowH + 20, colW, 8, 20, a.sPt, 0, true, "Points per Layer").setLiveUpdate(false);
  addSlider(W_RAND_PTS,   colX, y, colW, 10, 100, a.rN,   0, true, "Number of Points").setLiveUpdate(false);
  // Reserve space for two slider rows regardless of graph kind so the Clear
  // button below never moves when switching between graph types.
  y += rowH + 20 + rowH + 14;

  // Graph buttons
  cp.addButton(W_CLEAR)   .setPosition(colX, y).setSize(colW, btnH).setCaptionLabel("Clear Graph");
  y += btnH + gap;
  cp.addButton(W_EXP_JSON).setPosition(colX, y).setSize(colW, btnH).setCaptionLabel("Export Graph  (JSON)");
  y += btnH + gap;
  cp.addButton(W_EXP_GSVG).setPosition(colX, y).setSize(colW, btnH).setCaptionLabel("Export Graph  (SVG)");
  y += btnH + gap;
  cp.addButton(W_IMP_JSON).setPosition(colX, y).setSize(colW, btnH).setCaptionLabel("Import Graph  (JSON)");

  // ===================================================================
  // Card 2 — "Decoded Pattern"
  // ===================================================================
  y = UI_ENC_Y2 + 12 + UI_CARD_PAD_Y_TOP;

  // Float sliders — 2 decimal places, no integer snap.
  addSlider(W_TAU,    colX, y, colW, 0.7f, 0.9f, a.tau,    2, false, "tau (star size)");
  y += rowH + 22;
  addSlider(W_LAMBDA, colX, y, colW, 0.3f, 0.5f, a.lambda, 2, false, "lambda (sharpness)");
  y += rowH + 18;

  Toggle togPack = cp.addToggle(W_SHOW_PACK)
    .setPosition(colX, y).setSize(18, 18)
    .setValue(a.shPack).setMode(ControlP5.DEFAULT)
    .setCaptionLabel("Show Packing");
  togPack.getCaptionLabel()
    .align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
    .setPaddingX(8)
    .setColor(UI_LABEL_COLOR);
  y += 28;
  Toggle togTile = cp.addToggle(W_SHOW_TILE)
    .setPosition(colX, y).setSize(18, 18)
    .setValue(a.shTile).setMode(ControlP5.DEFAULT)
    .setCaptionLabel("Show Tiling");
  togTile.getCaptionLabel()
    .align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER)
    .setPaddingX(8)
    .setColor(UI_LABEL_COLOR);
  y += 36;

  cp.addButton(W_EXP_PAT) .setPosition(colX, y).setSize(colW, btnH).setCaptionLabel("Export Pattern  (SVG)");
  y += btnH + gap;
  cp.addButton(W_EXP_FULL).setPosition(colX, y).setSize(colW, btnH).setCaptionLabel("Export Full  (SVG)");

  // Keep the dropdown's expanded list on top of every other widget (ControlP5
  // renders in add order, so later additions otherwise paint above it).
  Controller gt = cp.getController(W_GRAPH_TYPE);
  if (gt != null) gt.bringToFront();
}

// Update the collapsed dropdown bar so it reads the currently selected
// graph type's display name instead of ControlP5's default caption.
void setGraphTypeBarLabel(ControlP5 cp, int idx) {
  if (cp == null) return;
  Controller c = cp.getController(W_GRAPH_TYPE);
  if (c == null) return;
  int safe = constrain(idx, 0, GRAPH_TYPE_LABELS.length - 1);
  c.setCaptionLabel(GRAPH_TYPE_LABELS[safe]);
}

// Adjust slider visibility based on the current graph kind.
void syncUIFromApp(ControlP5 cp, PortolanApp a) {
  setSliderVisible(W_TRI_SIZE,   a.graphKind == 0);
  setSliderVisible(W_KING_SIZE,  a.graphKind == 1);
  setSliderVisible(W_SPI_LAYERS, a.graphKind == 2);
  setSliderVisible(W_SPI_POINTS, a.graphKind == 2);
  setSliderVisible(W_RAND_PTS,   a.graphKind == 3);
}

void setSliderVisible(String name, boolean visible) {
  DragSlider s = sliders.get(name);
  if (s != null) s.visible = visible;
}

// Route a DragSlider value change to the app. Mirrors what the old
// numberbox branch of controlEvent() used to do — when the slider name
// affects graph topology we call app.setGraph() so the mesh is regenerated.
void onSliderChange(DragSlider s) {
  if (app == null) return;
  String n = s.name;
  float v = s.value;
  if (n.equals(W_TRI_SIZE))        { app.triSz = (int) v; if (app.graphKind == 0) app.setGraph(0); }
  else if (n.equals(W_KING_SIZE))  { app.kSz   = (int) v; if (app.graphKind == 1) app.setGraph(1); }
  else if (n.equals(W_SPI_LAYERS)) { app.sLay  = (int) v; if (app.graphKind == 2) app.setGraph(2); }
  else if (n.equals(W_SPI_POINTS)) { app.sPt   = (int) v; if (app.graphKind == 2) app.setGraph(2); }
  else if (n.equals(W_RAND_PTS))   { app.rN    = (int) v; if (app.graphKind == 3) app.setGraph(3); }
  else if (n.equals(W_TAU))        { app.tau    = v; }
  else if (n.equals(W_LAMBDA))     { app.lambda = v; }
}

// True when the graph-type dropdown is currently expanded. We suppress
// slider hit-testing in that case so clicks on the dropdown's list items
// don't also drag a slider underneath.
boolean isDropdownOpen() {
  if (cp5 == null) return false;
  Controller c = cp5.getController(W_GRAPH_TYPE);
  if (c instanceof ScrollableList) return ((ScrollableList) c).isOpen();
  return false;
}

// Forward mouse events to any DragSlider that wants them. Returns true if
// a slider consumed the event (in which case PortolanApp should NOT see it).
//
// Live-update sliders (τ, λ) fire onSliderChange on every press/drag so the
// pattern redraws continuously. Deferred sliders (the size sliders) skip
// those callbacks and only fire onSliderChange on release — the number in
// the caption still updates live because drag() mutates `value` directly.
boolean slidersMousePressed(float mx, float my) {
  if (isDropdownOpen()) return false;
  for (DragSlider s : sliders.values()) {
    if (s.press(mx, my)) {
      if (s.liveUpdate) onSliderChange(s);
      return true;
    }
  }
  return false;
}

boolean slidersMouseDragged(float mx, float my) {
  boolean any = false;
  for (DragSlider s : sliders.values()) {
    if (s.drag(mx, my)) {
      if (s.liveUpdate) onSliderChange(s);
      any = true;
    }
  }
  return any;
}

boolean slidersMouseReleased() {
  boolean any = false;
  for (DragSlider s : sliders.values()) {
    // Capture whether this slider was dragging *before* release() resets it,
    // so we know to fire a deferred commit.
    boolean wasDragging = s.dragging;
    if (s.release()) {
      any = true;
      if (!s.liveUpdate && wasDragging) onSliderChange(s);
    }
  }
  return any;
}

void drawSliders(PApplet p) {
  for (DragSlider s : sliders.values()) s.draw(p);
}

// Pending-graph-export flags so SVG/JSON file dialogs run asynchronously
// without blocking ControlP5 event dispatch.
String pendingSvgExport = null; // "pattern", "full", or "graph"
boolean pendingJsonExport = false;

// Single dispatcher for all ControlP5 events.
void controlEvent(ControlEvent ce) {
  if (app == null) return;
  String n = ce.getName();
  if (n == null) return;

  if (n.equals(W_GRAPH_TYPE)) {
    int idx = (int) ce.getValue();
    app.graphKind = constrain(idx, 0, GRAPH_TYPE_LABELS.length - 1);
    setGraphTypeBarLabel(cp5, app.graphKind);
    // Collapse the list immediately after a selection. ControlP5's
    // ScrollableList keeps the list open after a click by default, which
    // leaves it obscuring the sliders below.
    Controller gt = cp5.getController(W_GRAPH_TYPE);
    if (gt instanceof ScrollableList) ((ScrollableList) gt).close();
    syncUIFromApp(cp5, app);
    app.setGraph(app.graphKind);
  } else if (n.equals(W_SHOW_PACK)) {
    app.shPack = ce.getValue() > 0.5f;
  } else if (n.equals(W_SHOW_TILE)) {
    app.shTile = ce.getValue() > 0.5f;
  } else if (n.equals(W_CLEAR)) {
    app.reset();
  } else if (n.equals(W_EXP_JSON)) {
    pendingJsonExport = true;
  } else if (n.equals(W_EXP_GSVG)) {
    pendingSvgExport = "graph";
  } else if (n.equals(W_IMP_JSON)) {
    selectInput("Load graph JSON", "loadGraphFileSelected");
  } else if (n.equals(W_EXP_PAT)) {
    pendingSvgExport = "pattern";
  } else if (n.equals(W_EXP_FULL)) {
    pendingSvgExport = "full";
  } else {
    return;
  }
  redraw();

  // File dialogs must run after we've returned from the ControlP5 event.
  if (pendingJsonExport) {
    pendingJsonExport = false;
    selectOutput("Save graph as JSON", "saveGraphJsonSelected");
  }
  if (pendingSvgExport != null) {
    String kind = pendingSvgExport;
    pendingSvgExport = null;
    selectOutput("Save " + kind + " as SVG", "saveSvgSelected_" + kind);
  }
}

// ===== File-dialog callbacks (must be top-level) =====

void loadGraphFileSelected(File f) {
  if (f == null || app == null) return;
  try {
    StringBuilder sb = new StringBuilder();
    BufferedReader br = new BufferedReader(new FileReader(f));
    String line;
    while ((line = br.readLine()) != null) sb.append(line).append('\n');
    br.close();
    loadGraphFromJson(app, sb.toString());
    redraw();
  } catch (Exception e) {
    println("[UI] loadGraph failed: " + e.getMessage());
    e.printStackTrace();
  }
}

void saveGraphJsonSelected(File f) {
  if (f == null || app == null) return;
  String path = f.getAbsolutePath();
  if (!path.toLowerCase().endsWith(".json")) path += ".json";
  saveStrings(path, new String[] { graphToJson(app) });
  println("[UI] graph JSON saved: " + path);
}

void saveSvgSelected_pattern(File f) { saveSvgFile(f, "pattern"); }
void saveSvgSelected_full(File f)    { saveSvgFile(f, "full"); }
void saveSvgSelected_graph(File f)   { saveSvgFile(f, "graph"); }

void saveSvgFile(File f, String kind) {
  if (f == null || app == null) return;
  String path = f.getAbsolutePath();
  if (!path.toLowerCase().endsWith(".svg")) path += ".svg";
  String svg;
  if (kind.equals("graph"))        svg = graphToSvg(app);
  else if (kind.equals("pattern")) svg = patternToSvg(app, false);
  else                             svg = patternToSvg(app, true);
  saveStrings(path, new String[] { svg });
  println("[UI] " + kind + " SVG saved: " + path);
}

// ===== JSON helpers (minimal, tailored to our payload shape) =====

String graphToJson(PortolanApp a) {
  StringBuilder sb = new StringBuilder();
  sb.append("{\n  \"points\": [\n");
  for (int i = 0; i < a.mesh.vert.size(); i++) {
    GPoint p = a.mesh.vert.get(i);
    sb.append("    { \"x\": ").append(nfJson(p.x)).append(", \"y\": ").append(nfJson(p.y)).append(" }");
    if (i < a.mesh.vert.size() - 1) sb.append(',');
    sb.append('\n');
  }
  sb.append("  ],\n  \"constraints\": [\n");
  for (int i = 0; i < a.mesh.conEdge.size(); i++) {
    int[] e = a.mesh.conEdge.get(i);
    sb.append("    { \"a\": ").append(e[0]).append(", \"b\": ").append(e[1]).append(" }");
    if (i < a.mesh.conEdge.size() - 1) sb.append(',');
    sb.append('\n');
  }
  sb.append("  ]\n}\n");
  return sb.toString();
}

String nfJson(float v) {
  // Avoid locale-specific comma decimals.
  return String.format(java.util.Locale.US, "%.3f", v);
}

void loadGraphFromJson(PortolanApp a, String json) {
  // Tiny bespoke parser that only understands the shape graphToJson emits.
  Mesh m = new Mesh();
  java.util.regex.Matcher pm = java.util.regex.Pattern
    .compile("\"x\"\\s*:\\s*([-0-9\\.eE]+)\\s*,\\s*\"y\"\\s*:\\s*([-0-9\\.eE]+)")
    .matcher(json);
  while (pm.find()) {
    m.addPoint(new GPoint(Float.parseFloat(pm.group(1)), Float.parseFloat(pm.group(2))));
  }
  java.util.regex.Matcher cm = java.util.regex.Pattern
    .compile("\"a\"\\s*:\\s*(\\d+)\\s*,\\s*\"b\"\\s*:\\s*(\\d+)")
    .matcher(json);
  while (cm.find()) {
    int aa = Integer.parseInt(cm.group(1));
    int bb = Integer.parseInt(cm.group(2));
    if (aa < m.vert.size() && bb < m.vert.size()) m.addConstraint(aa, bb);
  }
  a.mesh = m;
  a.sel = -1;
  a.markMeshDirty();
}

// ===== SVG helpers =====

String graphToSvg(PortolanApp a) {
  Mesh m = a.mesh;
  if (m.numPoints() == 0) return "<svg xmlns=\"http://www.w3.org/2000/svg\"/>";
  float minX = Float.POSITIVE_INFINITY, minY = Float.POSITIVE_INFINITY;
  float maxX = Float.NEGATIVE_INFINITY, maxY = Float.NEGATIVE_INFINITY;
  for (GPoint p : m.vert) {
    if (p.x < minX) minX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.x > maxX) maxX = p.x;
    if (p.y > maxY) maxY = p.y;
  }
  float pad = 30;
  minX -= pad; minY -= pad; maxX += pad; maxY += pad;
  float w = maxX - minX, h = maxY - minY;
  StringBuilder s = new StringBuilder();
  s.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n");
  s.append(String.format(java.util.Locale.US,
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%.0f\" height=\"%.0f\" viewBox=\"%.0f %.0f %.0f %.0f\">\n",
    w, h, minX, minY, w, h));
  s.append(String.format(java.util.Locale.US,
    "  <rect x=\"%.0f\" y=\"%.0f\" width=\"%.0f\" height=\"%.0f\" fill=\"#e7f5f7\"/>\n",
    minX, minY, w, h));
  s.append("  <g stroke=\"#484848\" stroke-width=\"0.5\" fill=\"none\">\n");
  for (int[] t : m.tri) {
    GPoint a0 = m.vert.get(t[0]), b0 = m.vert.get(t[1]), c0 = m.vert.get(t[2]);
    s.append(String.format(java.util.Locale.US,
      "    <polygon points=\"%.3f,%.3f %.3f,%.3f %.3f,%.3f\"/>\n",
      a0.x, a0.y, b0.x, b0.y, c0.x, c0.y));
  }
  s.append("  </g>\n  <g stroke=\"#dd7c74\" stroke-width=\"1.5\" fill=\"none\">\n");
  for (int[] e : m.conEdge) {
    GPoint p = m.vert.get(e[0]), q = m.vert.get(e[1]);
    s.append(String.format(java.util.Locale.US,
      "    <line x1=\"%.3f\" y1=\"%.3f\" x2=\"%.3f\" y2=\"%.3f\"/>\n",
      p.x, p.y, q.x, q.y));
  }
  s.append("  </g>\n  <g>\n");
  for (int i = 0; i < m.numPoints(); i++) {
    GPoint p = m.vert.get(i);
    int col = a.vtxCol(i, m.numPoints());
    String hex = String.format("#%02x%02x%02x", (col >> 16) & 0xff, (col >> 8) & 0xff, col & 0xff);
    boolean b = i < m.vertProps.size() && m.vertProps.get(i).boundary;
    if (b) {
      s.append(String.format(java.util.Locale.US,
        "    <circle cx=\"%.3f\" cy=\"%.3f\" r=\"4\" fill=\"%s\" stroke=\"#ffffff\" stroke-width=\"1.5\"/>\n",
        p.x, p.y, hex));
    } else {
      s.append(String.format(java.util.Locale.US,
        "    <circle cx=\"%.3f\" cy=\"%.3f\" r=\"4\" fill=\"%s\"/>\n",
        p.x, p.y, hex));
    }
  }
  s.append("  </g>\n</svg>\n");
  return s.toString();
}

// Pattern SVG: emit the five-point stars (and optionally packing + tiling)
// in the same canvas-local coordinates that drawAll() uses.
String patternToSvg(PortolanApp a, boolean includePackingAndTiling) {
  StringBuilder s = new StringBuilder();
  s.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n");
  s.append(String.format(java.util.Locale.US,
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n",
    CANVAS_W, CANVAS_H, CANVAS_W, CANVAS_H));
  s.append(String.format(java.util.Locale.US,
    "  <rect x=\"0\" y=\"0\" width=\"%d\" height=\"%d\" fill=\"#ffffff\"/>\n",
    CANVAS_W, CANVAS_H));

  if (includePackingAndTiling) {
    // Packing circles
    s.append("  <g id=\"packing\" fill=\"rgba(240,173,78,0.16)\" stroke=\"none\">\n");
    for (PattC c : a.pCirc.values()) {
      s.append(String.format(java.util.Locale.US,
        "    <circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\"/>\n", c.x, c.y, c.d / 2.0f));
    }
    s.append("  </g>\n");
    // Tiling edges
    s.append("  <g id=\"tiling\" stroke=\"#888888\" stroke-width=\"0.75\" fill=\"none\">\n");
    final StringBuilder tileBuf = s;
    for (CycP q : a.pCyc.values()) {
      q.cE(a.lambda, (p0, p1) -> {
        tileBuf.append(String.format(java.util.Locale.US,
          "    <line x1=\"%.3f\" y1=\"%.3f\" x2=\"%.3f\" y2=\"%.3f\"/>\n",
          p0.x, p0.y, p1.x, p1.y));
      });
    }
    s.append("  </g>\n");
  }

  // Stars — the decoded pattern proper
  s.append("  <g id=\"pattern\" stroke=\"#dd5c50\" stroke-width=\"1\" fill=\"none\">\n");
  final StringBuilder patBuf = s;
  for (Pent t : a.p5) {
    t.cE(a.lambda, (p0, p1) -> {
      patBuf.append(String.format(java.util.Locale.US,
        "    <line x1=\"%.3f\" y1=\"%.3f\" x2=\"%.3f\" y2=\"%.3f\"/>\n",
        p0.x, p0.y, p1.x, p1.y));
    });
  }
  s.append("  </g>\n</svg>\n");
  return s.toString();
}
