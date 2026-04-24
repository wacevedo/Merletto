// Port of constelation/sketch.js — embedded UI strip below drawing area (see instructions in console)

class PortolanApp {
  PApplet pa;
  int grid = GRID_SIZE;
  int drawW = CANVAS_W, drawH = CANVAS_H;
  // Offset of the drawing area inside the window (so mouseX/mouseY can be
  // converted to canvas-local coords). Set by the main sketch to LEFT_PANEL_W.
  int xOff = 0;
  Mesh mesh;
  int mode; // 0 v 1 e
  int sel = -1;
  float tau = TAU_DEFAULT, lambda = LAMBDA_DEFAULT;
  int triSz = TRI_SIZE_DEF, kSz = KING_SIZE_DEF;
  int sLay = SPIDER_LAYERS_DEF, sPt = SPIDER_POINTS_DEF, rN = RAND_POINTS_DEF;
  boolean shPack = false, shTile = false;
  int graphKind; // 0 tri 1 king 2 spider 3 random
  java.util.HashMap<Integer, PattC> pCirc = new java.util.HashMap<Integer, PattC>();
  java.util.HashMap<Integer, CycP> pCyc = new java.util.HashMap<Integer, CycP>();
  java.util.ArrayList<Pent> p5 = new java.util.ArrayList<Pent>();

  PortolanApp(PApplet p) {
    println("  [LOG] PortolanApp ctor start");
    pa = p;
    mesh = new Mesh();
    mode = 0;
    graphKind = 0;
    println("  [LOG] PortolanApp ctor end: grid=" + grid + " drawW=" + drawW + " drawH=" + drawH + " tau=" + tau + " lambda=" + lambda);
  }

  void runSetup() {
    println("  [LOG] runSetup() calling setGraph(0)");
    setGraph(0);
    println("  [LOG] runSetup() setGraph done. points=" + mesh.numPoints() + " tris=" + mesh.tri.size() + " conEdges=" + mesh.conEdge.size());
  }

  int vtxCol(int idx, int tot) {
    pa.pushStyle();
    pa.colorMode(PApplet.HSB, 360, 100, 100);
    int c = pa.color(360.0f * idx / max(1, tot), 70, 85);
    pa.popStyle();
    return c;
  }

  // Flag set whenever graph topology changes (points/constraints added,
  // removed, or moved). Controls whether drawAll() re-runs the expensive
  // mesh.recompute() — τ/λ slider drags shouldn't trigger it.
  boolean meshDirty = true;
  void markMeshDirty() { meshDirty = true; }

  int drawCallCount = 0;
  void drawAll() {
    drawCallCount++;
    boolean verbose = drawCallCount <= 2;
    if (verbose) println("    [LOG] drawAll#" + drawCallCount + " start. mesh=" + (mesh == null ? "NULL" : "ok"));
    if (mesh == null) return;
    if (meshDirty) {
      if (verbose) println("    [LOG] drawAll: before recompute");
      mesh.recompute();
      meshDirty = false;
      if (verbose) println("    [LOG] drawAll: after recompute points=" + mesh.numPoints() + " tris=" + mesh.tri.size());
    }
    pCirc.clear();
    pCyc.clear();
    p5.clear();
    pa.background(255);
    if (verbose) println("    [LOG] drawAll: before drawL");
    drawL();
    if (verbose) println("    [LOG] drawAll: before pack");
    pack();
    if (verbose) println("    [LOG] drawAll: after pack pCirc=" + pCirc.size() + " pCyc=" + pCyc.size());
    for (CycP q : pCyc.values()) { if (shTile) q.dT(pa); }
    for (CycP q : pCyc.values()) { q.cE(lambda, (a, b) -> { }); }
    if (verbose) println("    [LOG] drawAll: before cB3");
    p5 = cB3(mesh, pCirc, pCyc, tau);
    if (verbose) println("    [LOG] drawAll: after cB3 pents=" + p5.size());
    for (CycP q : pCyc.values()) { q.dM(pa, lambda); }
    for (Pent t : p5) { t.cE(lambda, (a, b) -> { pa.pushStyle(); pa.stroke(220, 90, 80); pa.line(a.x, a.y, b.x, b.y); pa.popStyle(); }); }
    if (verbose) println("    [LOG] drawAll#" + drawCallCount + " DONE");
  }

  void drawL() {
    pa.pushStyle();
    pa.noStroke();
    pa.fill(231, 245, 247);
    pa.rect(0, 0, drawW / 2, drawH);
    pa.fill(200, 200, 200, 180);
    for (int x = 0; x <= drawW / 2; x += grid) {
      for (int y = 0; y <= drawH; y += grid) {
        pa.ellipse(x, y, 2, 2);
      }
    }
    pa.noFill();
    pa.stroke(72, 72, 72);
    pa.strokeWeight(0.5f);
    for (int t = 0; t < mesh.tri.size(); t++) {
      int[] T = mesh.tri.get(t);
      for (int i = 0; i < 3; i++) {
        GPoint a = mesh.vert.get(T[i]), b = mesh.vert.get(T[(i + 1) % 3]);
        pa.line(a.x, a.y, b.x, b.y);
      }
    }
    pa.strokeWeight(1.5f);
    pa.stroke(221, 124, 116);
    for (int e = 0; e < mesh.conEdge.size(); e++) {
      int[] c = mesh.conEdge.get(e);
      GPoint a = mesh.vert.get(c[0]), b = mesh.vert.get(c[1]);
      pa.line(a.x, a.y, b.x, b.y);
    }
    int n = mesh.numPoints();
    for (int i = 0; i < n; i++) {
      GPoint p0 = mesh.vert.get(i);
      int c0 = vtxCol(i, n);
      if (i < mesh.vertProps.size() && mesh.vertProps.get(i).boundary) {
        pa.stroke(255);
        pa.strokeWeight(1.5f);
        pa.fill(c0);
      } else {
        pa.noStroke();
        pa.fill(c0);
      }
      pa.ellipse(p0.x, p0.y, 8, 8);
    }
    if (mode == 1 && sel >= 0) {
      pa.stroke(221, 124, 116);
      pa.strokeWeight(2);
      GPoint a = mesh.vert.get(sel);
      pa.line(a.x, a.y, pa.mouseX - xOff, pa.mouseY);
    }
    pa.popStyle();
  }

  void pack() {
    BoundingBox bb = computeBoundingBox(mesh);
    float sB = max(bb.width, bb.height);
    float sc = sB == 0 ? 1.0f : (0.42f * drawW) / sB;
    int n = mesh.numPoints();
    for (int i = 0; i < n; i++) {
      VertProperty vp = mesh.vertProps.get(i);
      if (vp.center == null) continue;
      GPoint c = vp.center;
      int col = vtxCol(i, n);
      PattC pc = new PattC(
        i, drawW * 0.75f + (c.x - bb.center.x) * sc, drawH * 0.5f + (c.y - bb.center.y) * sc, vp.radius * sc * 2, vp.boundary, col);
      pCirc.put(i, pc);
      if (shPack) {
        pa.pushStyle();
        pa.noStroke();
        if (!vp.boundary) {
          pa.pushStyle();
          pa.colorMode(PApplet.RGB, 255);
          pa.fill(240, 173, 78, 40);
          pa.popStyle();
        } else {
          pa.pushStyle();
          pa.colorMode(PApplet.RGB, 255);
          pa.fill(72, 20);
          pa.popStyle();
        }
        float cx0 = drawW * 0.75f + (c.x - bb.center.x) * sc;
        float cy0 = drawH * 0.5f + (c.y - bb.center.y) * sc;
        float d = vp.radius * sc * 2;
        pa.ellipse(cx0, cy0, d, d);
        pa.popStyle();
      }
    }
    pcPop(mesh, pCirc);
    pCyc.clear();
    for (PattC c : pCirc.values()) {
      if (!c.bd) c.bPoly(tau, pCyc);
    }
  }

  void key(int k) {
    if (k == 'v' || k == 'V') { mode = 0; sel = -1; }
    if (k == 'e' || k == 'E') { mode = 1; sel = -1; }
    if (k == PApplet.ENTER) { reset(); }
    if (k == ' ') { reset(); seed(); }
  }

  void reset() { mesh = new Mesh(); sel = -1; markMeshDirty(); }

  void seed() { mesh = new Mesh(); mSeed(); markMeshDirty(); }

  void mSeed() {
    int sp = 10 * grid;
    int r = 8, c = 8, gw = (c - 1) * sp, gh = (r - 1) * sp;
    float cx = drawW / 4.0f, cy = drawH / 2.0f, sx = cx - gw / 2, sy = cy - gh / 2, off = sp / 2.0f;
    for (int i = 0; i < r; i++) for (int j = 0; j < c; j++) mesh.addPoint(new GPoint(sx + j * sp, sy + i * sp));
    for (int i = 0; i < r - 1; i++) for (int j = 0; j < c - 1; j++) mesh.addPoint(new GPoint(sx + off + j * sp, sy + off + i * sp));
  }

  int mx() { return pa.mouseX - xOff; }
  int my() { return pa.mouseY; }

  void mouseP() {
    int lmx = mx(), lmy = my();
    if (lmy > drawH) return;
    if (lmx > drawW / 2) return;
    float sx = round(lmx / (float) grid) * grid, sy = round(lmy / (float) grid) * grid;
    for (int i = 0; i < mesh.numPoints(); i++) {
      if (PApplet.dist(mesh.vert.get(i).x, mesh.vert.get(i).y, sx, sy) < 7) {
        sel = i;
        if (mode == 0 && pa.keyPressed && (pa.key == PApplet.CODED && pa.keyCode == PApplet.SHIFT)) {
          mesh.removePoint(i);
          sel = -1;
          markMeshDirty();
        }
        return;
      }
    }
    if (mode == 0) {
      boolean ok = true;
      for (GPoint p0 : mesh.vert) { if (PApplet.dist(p0.x, p0.y, sx, sy) < 5) { ok = false; break; } }
      if (ok) { mesh.addPoint(new GPoint(sx, sy)); markMeshDirty(); }
    } else {
      sel = -1;
    }
  }

  void mouseD() {
    if (mode != 0 || sel < 0) return;
    int lmx = mx(), lmy = my();
    if (lmy > drawH) return;
    int nx = min(drawW / 2 - 10, max(10, round(lmx / (float) grid) * grid));
    int ny = min(drawH - 10, max(10, round(lmy / (float) grid) * grid));
    for (GPoint p0 : mesh.vert) { if (p0 == mesh.vert.get(sel)) continue; if (PApplet.dist(p0.x, p0.y, nx, ny) < 5) return; }
    mesh.setPoint(sel, new GPoint(nx, ny));
    markMeshDirty();
  }

  void mouseR() {
    int lmx = mx(), lmy = my();
    if (lmy > drawH) return;
    if (mode == 1 && sel >= 0) {
      int t = -1;
      for (int i = 0; i < mesh.numPoints(); i++) { if (PApplet.dist(mesh.vert.get(i).x, mesh.vert.get(i).y, lmx, lmy) < 7) { t = i; break; } }
      if (t >= 0 && t != sel) { mesh.addConstraint(sel, t); markMeshDirty(); }
    }
    sel = -1;
  }

  void setGraph(int k) {
    println("    [LOG] setGraph(" + k + ") start");
    graphKind = k;
    mesh = new Mesh();
    int margin = 4 * grid, sp = 8 * grid;
    float cx = drawW / 4.0f, cy = drawH / 2.0f;
    if (k == 0) {
      int n = triSz, rows = n, cols = n;
      float gw = (cols - 1) * sp, gh = (rows - 1) * sp, sx = cx - gw / 2, sy = cy - gh / 2;
      println("    [LOG] setGraph(0): grid " + rows + "x" + cols + " sp=" + sp + " sx=" + sx + " sy=" + sy);
      int[][] g = new int[rows][cols];
      for (int i = 0; i < rows; i++) for (int j = 0; j < cols; j++) { int v = mesh.vert.size(); g[i][j] = v; mesh.addPoint(new GPoint(sx + j * sp, sy + i * sp)); }
      println("    [LOG] setGraph(0): points added=" + mesh.numPoints());
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[0][j], g[0][j + 1]);
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[rows - 1][j], g[rows - 1][j + 1]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][0], g[i + 1][0]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][cols - 1], g[i + 1][cols - 1]);
      println("    [LOG] setGraph(0): constraints added=" + mesh.conEdge.size());
    } else if (k == 1) {
      int n = kSz, rows = n, cols = n;
      float gw = (cols - 1) * sp, gh = (rows - 1) * sp, sx = cx - gw / 2, sy = cy - gh / 2;
      int[][] g = new int[rows][cols];
      for (int i = 0; i < rows; i++) for (int j = 0; j < cols; j++) { int v = mesh.vert.size(); g[i][j] = v; mesh.addPoint(new GPoint(sx + j * sp, sy + i * sp)); }
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[0][j], g[0][j + 1]);
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[rows - 1][j], g[rows - 1][j + 1]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][0], g[i + 1][0]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][cols - 1], g[i + 1][cols - 1]);
    } else if (k == 2) {
      mSeed();
    } else {
      for (int i = 0; i < rN; i++) {
        float rx = pa.random(margin, drawW / 2f - margin), ry = pa.random(margin, drawH - margin);
        mesh.addPoint(new GPoint(rx, ry));
      }
    }
    println("    [LOG] setGraph(" + k + "): calling mesh.recompute()");
    mesh.recompute();
    meshDirty = false; // recompute() we just ran is authoritative
    println("    [LOG] setGraph(" + k + ") done. points=" + mesh.numPoints() + " tris=" + mesh.tri.size());
  }
}
