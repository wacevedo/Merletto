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
final String W_GRAPH_TYPE  = "graphType";
final String W_TRI_SIZE    = "triSize";
final String W_KING_SIZE   = "kingSize";
final String W_SPI_LAYERS  = "spiderLayers";
final String W_SPI_POINTS  = "spiderPoints";
final String W_RAND_PTS    = "randomPoints";
final String W_ROSONE_TYPE = "rosoneType";
final String W_CLEAR       = "clearGraph";
final String W_EXP_JSON    = "exportGraphJson";
final String W_EXP_GSVG    = "exportGraphSvg";
final String W_IMP_JSON    = "importGraphJson";

final String W_TAU        = "tau";          // slider label: "Star Size"
final String W_INNER_TAU  = "innerTau";      // slider label: "Tau" (inner-circle radius)
final String W_LAMBDA     = "lambda";
final String W_ZOOM       = "rightZoom";
final String W_LINE_SCALE = "lineScale";
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

// Labels for the "Rosone Type" dropdown. Index → PortolanApp.rosoneKind.
// 0 = "Rosone 1" — chord-based {N/skip} star polygon per cell.
// 1 = "Rosone 2" — per-cell rosette with outer circle, lens petals, nested
//                  rings (full geometry — no gap to the polygon edges).
// 2 = "Rosone 3" — gothic per-cell rosette inscribed in a smaller circle,
//                  paired with a separate gap-filler that draws the cyclic
//                  polygon outlines as the irregular network around them.
// 3 = "Rosone 4" — N kite/rhombus cells fanning out from the cell's center
//                  (rhombus tessellation; true rhombi when q is a regular
//                  N-gon), bounded by the polygon outline.
final String[] ROSONE_TYPE_LABELS = {
  "Rosone 1",
  "Rosone 2",
  "Rosone 3",
  "Rosone 4"
};

// ===== Layout constants (referenced by PortolanEngineV3.pde's card-drawing) =====
// The right column is 340px wide. Each card is inset 12px on each side.
final int UI_CARD_X  = CANVAS_W + 12;
final int UI_CARD_W  = RIGHT_PANEL_W - 24;       // 316
final int UI_ENC_Y1  = 12;                       // top of "Graphical Encoding" card
final int UI_ENC_H   = 408;                      // height of encoding card (extra room for the Rosone Type dropdown)
final int UI_ENC_Y2  = UI_ENC_Y1 + UI_ENC_H;     // bottom (start of gap) → 352
final int UI_DEC_H   = 384;                      // height of decoded-pattern card (room for Zoom + Line Weight + Star Size + Tau + Lambda sliders)

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

  // Rosone Type dropdown — selects the visual style for the right-panel
  // pattern. Sits between the size sliders and the action buttons so that
  // the topology controls cluster at the top and the I/O actions at the
  // bottom of the card.
  cp.addLabel("lbl_rosoneType")
    .setText("Rosone Type")
    .setPosition(colX, y)
    .setColorValue(UI_LABEL_COLOR);
  y += 16;

  java.util.List<String> rosoneItems = java.util.Arrays.asList(ROSONE_TYPE_LABELS);
  cp.addScrollableList(W_ROSONE_TYPE)
    .setPosition(colX, y)
    .setSize(colW, 24 + 22 * ROSONE_TYPE_LABELS.length)
    .setBarHeight(24)
    .setItemHeight(22)
    .addItems(rosoneItems)
    .setType(ControlP5.LIST)
    .setOpen(false)
    .close()
    .setValue(a.rosoneKind);
  setRosoneTypeBarLabel(cp, a.rosoneKind);
  y += 24 + 14;

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

  // Viewing controls (don't change pattern geometry, only how it's drawn):
  //   • Zoom        — matrix scale around the right-canvas center.
  //   • Line Weight — multiplier on every rosone stroke weight.
  // These sit above tau/lambda because they're rendering settings, not
  // pattern parameters. Spacing is +16 (vs the usual +22) so all three
  // sliders + the layout below still fit inside the 800 px window.
  addSlider(W_ZOOM, colX, y, colW, 0.5f, 4.0f, a.rightZoom, 2, false, "Zoom");
  y += rowH + 16;
  addSlider(W_LINE_SCALE, colX, y, colW, 0.2f, 2.0f, a.lineScale, 2, false, "Line Weight");
  y += rowH + 16;

  // Pattern-shape sliders — 2 decimal places, no integer snap.
  // Star Size = outer-rosette radius / packing-circle radius (the old
  //             "tau" — semantics unchanged, label simplified).
  // Tau       = inner-circle radius / packing-circle radius (new, drives
  //             each rosone's inner ring; clamped to stay inside the
  //             outer rosette at draw time).
  // Lambda    = star-tip sharpness (chord skip / cell apex pull).
  addSlider(W_TAU,       colX, y, colW, 0.4f, 1.0f, a.tau,      2, false, "Star Size");
  y += rowH + 16;
  addSlider(W_INNER_TAU, colX, y, colW, 0.1f, 0.9f, a.innerTau, 2, false, "Tau");
  y += rowH + 16;
  addSlider(W_LAMBDA,    colX, y, colW, 0.3f, 0.5f, a.lambda,   2, false, "lambda (sharpness)");
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

  // Keep dropdowns' expanded lists on top of every other widget (ControlP5
  // renders in add order, so later additions otherwise paint above them).
  // Order matters: the LAST bringToFront wins, so Graph Type ends on top —
  // it expands the largest and would otherwise be hidden by the Rosone Type
  // bar and the buttons below.
  Controller rt = cp.getController(W_ROSONE_TYPE);
  if (rt != null) rt.bringToFront();
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

// Same idea as setGraphTypeBarLabel but for the Rosone Type dropdown.
void setRosoneTypeBarLabel(ControlP5 cp, int idx) {
  if (cp == null) return;
  Controller c = cp.getController(W_ROSONE_TYPE);
  if (c == null) return;
  int safe = constrain(idx, 0, ROSONE_TYPE_LABELS.length - 1);
  c.setCaptionLabel(ROSONE_TYPE_LABELS[safe]);
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
  else if (n.equals(W_TAU))        { app.tau      = v; }
  else if (n.equals(W_INNER_TAU))  { app.innerTau = v; }
  else if (n.equals(W_LAMBDA))     { app.lambda   = v; }
  else if (n.equals(W_ZOOM))       { app.rightZoom = v; }
  else if (n.equals(W_LINE_SCALE)) { app.lineScale = v; }
}

// True when ANY of our dropdowns is currently expanded. We suppress slider
// hit-testing in that case so clicks on a dropdown's list items don't also
// drag a slider underneath.
boolean isDropdownOpen() {
  if (cp5 == null) return false;
  return isScrollableListOpen(W_GRAPH_TYPE) || isScrollableListOpen(W_ROSONE_TYPE);
}

boolean isScrollableListOpen(String name) {
  Controller c = cp5.getController(name);
  return (c instanceof ScrollableList) && ((ScrollableList) c).isOpen();
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

// Set true while applyLoadedStateToUi() is pushing values into ControlP5
// widgets during a JSON import. ControlP5's setValue fires controlEvent
// synchronously, and W_GRAPH_TYPE's handler regenerates the mesh from
// scratch — which would wipe the points + constraints we just loaded.
// Guarding controlEvent with this flag lets us reuse the same
// dropdown/toggle setters without disabling the user's interactions.
boolean suppressControlEvents = false;

// Single dispatcher for all ControlP5 events.
void controlEvent(ControlEvent ce) {
  if (app == null) return;
  if (suppressControlEvents) return;
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
  } else if (n.equals(W_ROSONE_TYPE)) {
    int idx = (int) ce.getValue();
    app.rosoneKind = constrain(idx, 0, ROSONE_TYPE_LABELS.length - 1);
    setRosoneTypeBarLabel(cp5, app.rosoneKind);
    Controller rt = cp5.getController(W_ROSONE_TYPE);
    if (rt instanceof ScrollableList) ((ScrollableList) rt).close();
    // No mesh recompute needed — Rosone 2 is a render-time overlay only.
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

// Graph JSON shape:
//   { "points": [...], "constraints": [...], "meta": { ... } }
//
// `points` and `constraints` match the JS reference exactly (same field
// names, same numeric format) so files exported here remain importable
// by the original constelation/ web app and vice versa.
//
// The `meta` block is a Processing-port extension that captures the
// rest of the editor state — graph type + per-type sizes, the active
// rosone, all three pattern shape sliders (Star Size, Tau, Lambda),
// the show-packing/show-tiling toggles, and view-only line scale +
// zoom — so loading restores the entire workspace, not just the mesh.
// `loadGraphFromJson` reads `meta` if present and silently ignores it
// when missing (i.e. files from the JS app still load cleanly).
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
  sb.append("  ],\n  \"meta\": {\n");
  sb.append("    \"graphKind\": ").append(a.graphKind).append(",\n");
  sb.append("    \"triSz\": ").append(a.triSz).append(",\n");
  sb.append("    \"kSz\": ").append(a.kSz).append(",\n");
  sb.append("    \"sLay\": ").append(a.sLay).append(",\n");
  sb.append("    \"sPt\": ").append(a.sPt).append(",\n");
  sb.append("    \"rN\": ").append(a.rN).append(",\n");
  sb.append("    \"rosoneKind\": ").append(a.rosoneKind).append(",\n");
  sb.append("    \"tau\": ").append(nfJson(a.tau)).append(",\n");
  sb.append("    \"innerTau\": ").append(nfJson(a.innerTau)).append(",\n");
  sb.append("    \"lambda\": ").append(nfJson(a.lambda)).append(",\n");
  sb.append("    \"shPack\": ").append(a.shPack).append(",\n");
  sb.append("    \"shTile\": ").append(a.shTile).append(",\n");
  sb.append("    \"lineScale\": ").append(nfJson(a.lineScale)).append(",\n");
  sb.append("    \"rightZoom\": ").append(nfJson(a.rightZoom)).append("\n");
  sb.append("  }\n}\n");
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

  // Parse optional `meta` fields. Each readJson*() walks the whole JSON
  // and grabs the first match for that key, returning a default when
  // the field is absent — that way files exported by the JS reference
  // (which only has `points` + `constraints`) load with the current
  // editor settings preserved instead of getting reset.
  a.graphKind  = readJsonInt(json, "graphKind",  a.graphKind);
  a.triSz      = readJsonInt(json, "triSz",      a.triSz);
  a.kSz        = readJsonInt(json, "kSz",        a.kSz);
  a.sLay       = readJsonInt(json, "sLay",       a.sLay);
  a.sPt        = readJsonInt(json, "sPt",        a.sPt);
  a.rN         = readJsonInt(json, "rN",         a.rN);
  a.rosoneKind = readJsonInt(json, "rosoneKind", a.rosoneKind);
  a.tau        = readJsonFloat(json, "tau",        a.tau);
  a.innerTau   = readJsonFloat(json, "innerTau",   a.innerTau);
  a.lambda     = readJsonFloat(json, "lambda",     a.lambda);
  a.shPack     = readJsonBool(json,  "shPack",     a.shPack);
  a.shTile     = readJsonBool(json,  "shTile",     a.shTile);
  a.lineScale  = readJsonFloat(json, "lineScale",  a.lineScale);
  a.rightZoom  = readJsonFloat(json, "rightZoom",  a.rightZoom);

  applyLoadedStateToUi(a);
}

int readJsonInt(String json, String key, int fallback) {
  java.util.regex.Matcher m = java.util.regex.Pattern
    .compile("\"" + java.util.regex.Pattern.quote(key) + "\"\\s*:\\s*(-?\\d+)")
    .matcher(json);
  return m.find() ? Integer.parseInt(m.group(1)) : fallback;
}
float readJsonFloat(String json, String key, float fallback) {
  java.util.regex.Matcher m = java.util.regex.Pattern
    .compile("\"" + java.util.regex.Pattern.quote(key) + "\"\\s*:\\s*(-?[0-9]*\\.?[0-9]+(?:[eE][-+]?\\d+)?)")
    .matcher(json);
  return m.find() ? Float.parseFloat(m.group(1)) : fallback;
}
boolean readJsonBool(String json, String key, boolean fallback) {
  java.util.regex.Matcher m = java.util.regex.Pattern
    .compile("\"" + java.util.regex.Pattern.quote(key) + "\"\\s*:\\s*(true|false)")
    .matcher(json);
  return m.find() ? m.group(1).equals("true") : fallback;
}

// After a JSON load mutates app fields directly, the UI widgets still
// show their pre-load values — DragSliders cache `value` internally,
// ControlP5 dropdowns/toggles keep their own state. This pushes the
// freshly-loaded app state back into every visible widget so the panel
// matches the file we just imported. ControlP5's setValue fires
// controlEvent synchronously, so we guard with suppressControlEvents
// to keep the dropdown handler from regenerating the mesh and wiping
// the freshly-loaded points.
void applyLoadedStateToUi(PortolanApp a) {
  if (cp5 == null) return;
  setSliderValue(W_TRI_SIZE,    a.triSz);
  setSliderValue(W_KING_SIZE,   a.kSz);
  setSliderValue(W_SPI_LAYERS,  a.sLay);
  setSliderValue(W_SPI_POINTS,  a.sPt);
  setSliderValue(W_RAND_PTS,    a.rN);
  setSliderValue(W_TAU,         a.tau);
  setSliderValue(W_INNER_TAU,   a.innerTau);
  setSliderValue(W_LAMBDA,      a.lambda);
  setSliderValue(W_LINE_SCALE,  a.lineScale);
  setSliderValue(W_ZOOM,        a.rightZoom);

  suppressControlEvents = true;
  try {
    Controller gt = cp5.getController(W_GRAPH_TYPE);
    if (gt != null) gt.setValue(a.graphKind);
    setGraphTypeBarLabel(cp5, a.graphKind);

    Controller rt = cp5.getController(W_ROSONE_TYPE);
    if (rt != null) rt.setValue(a.rosoneKind);
    setRosoneTypeBarLabel(cp5, a.rosoneKind);

    Controller togPack = cp5.getController(W_SHOW_PACK);
    if (togPack != null) togPack.setValue(a.shPack ? 1 : 0);
    Controller togTile = cp5.getController(W_SHOW_TILE);
    if (togTile != null) togTile.setValue(a.shTile ? 1 : 0);
  } finally {
    suppressControlEvents = false;
  }

  syncUIFromApp(cp5, a);
}

void setSliderValue(String name, float v) {
  DragSlider s = sliders.get(name);
  if (s != null) s.setValue(v);
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

// Pattern SVG: emit the currently-selected Rosone (1, 2, 3, or 4) and
// optionally the underlying packing circles + cyclic-polygon outlines.
// drawAll() and this function both go through the SAME drawCurrentRosone
// dispatcher so the SVG is geometrically identical to what's on screen,
// and SVGRenderer.setStroke produces a separate <g> per color/weight
// run (preserving Rosone 3's gray construction guides + red main rosette,
// Rosone 1's optional teal tile outlines, etc.).
//
// The viewBox is computed from the packing circles (with padding) so the
// exported file crops tightly around the actual pattern instead of the
// full canvas area.
String patternToSvg(PortolanApp a, boolean includePackingAndTiling) {
  // -- Bounding box from packing circles (the rosones never extend past
  //    their enclosing packing circle, so this gives a tight crop). --
  float bbMinX = Float.POSITIVE_INFINITY, bbMinY = Float.POSITIVE_INFINITY;
  float bbMaxX = Float.NEGATIVE_INFINITY, bbMaxY = Float.NEGATIVE_INFINITY;
  for (PattC c : a.pCirc.values()) {
    float r = c.d / 2.0f;
    if (c.x - r < bbMinX) bbMinX = c.x - r;
    if (c.y - r < bbMinY) bbMinY = c.y - r;
    if (c.x + r > bbMaxX) bbMaxX = c.x + r;
    if (c.y + r > bbMaxY) bbMaxY = c.y + r;
  }
  if (bbMinX == Float.POSITIVE_INFINITY) {
    // No packing — fall back to the right half of the canvas so the SVG
    // is still well-formed (just with an empty pattern area).
    bbMinX = CANVAS_W * 0.5f; bbMinY = 0;
    bbMaxX = CANVAS_W;        bbMaxY = CANVAS_H;
  }
  float pad = 30;
  bbMinX -= pad; bbMinY -= pad; bbMaxX += pad; bbMaxY += pad;
  float bbW = bbMaxX - bbMinX, bbH = bbMaxY - bbMinY;

  StringBuilder s = new StringBuilder();
  s.append("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n");
  s.append(String.format(java.util.Locale.US,
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%.0f\" height=\"%.0f\" viewBox=\"%.3f %.3f %.3f %.3f\">\n",
    bbW, bbH, bbMinX, bbMinY, bbW, bbH));
  s.append(String.format(java.util.Locale.US,
    "  <title>Portolan pattern (Rosone %d)</title>\n", a.rosoneKind + 1));
  s.append(String.format(java.util.Locale.US,
    "  <desc>tau=%.2f, innerTau=%.2f, lambda=%.2f</desc>\n",
    a.tau, a.innerTau, a.lambda));
  s.append(String.format(java.util.Locale.US,
    "  <rect x=\"%.3f\" y=\"%.3f\" width=\"%.3f\" height=\"%.3f\" fill=\"#ffffff\"/>\n",
    bbMinX, bbMinY, bbW, bbH));

  if (includePackingAndTiling) {
    s.append("  <g id=\"packing\" fill=\"rgba(240,173,78,0.16)\" stroke=\"none\">\n");
    for (PattC c : a.pCirc.values()) {
      s.append(String.format(java.util.Locale.US,
        "    <circle cx=\"%.3f\" cy=\"%.3f\" r=\"%.3f\"/>\n", c.x, c.y, c.d / 2.0f));
    }
    s.append("  </g>\n");
    s.append("  <g id=\"tiling\">\n");
    SVGRenderer tileR = new SVGRenderer(s, "    ");
    tileR.setStroke(0x88, 0x88, 0x88, 0.75f);
    for (CycP q : a.pCyc.values()) {
      if (!q.on) continue;
      renderPolygonClosed(tileR, a.cycPVerts(q));
    }
    tileR.close();
    s.append("  </g>\n");
  }

  // Pattern itself — drawCurrentRosone routes every stroke change
  // through SVGRenderer.setStroke, so each color/weight run becomes
  // its own <g>. After dispatch we close the trailing group.
  s.append("  <g id=\"pattern\">\n");
  SVGRenderer patR = new SVGRenderer(s, "    ");
  a.drawCurrentRosone(patR);
  patR.close();
  s.append("  </g>\n</svg>\n");
  return s.toString();
}
