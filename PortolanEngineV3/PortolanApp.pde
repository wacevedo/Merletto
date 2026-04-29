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
  // Inner-circle radius as a fraction of the packing circle (q.sc / 2).
  // Each rosone uses this for its primary "inner ring" — the central
  // star's tip circle (Rosone 1 / 2), the central rosette's first ring
  // (Rosone 3), or the rhombus tessellation's inner-vertex ring
  // (Rosone 4). Clamped to stay strictly inside the outer rosette
  // (tau-driven) at draw time via effectiveInnerFactor().
  float innerTau = INNER_TAU_DEFAULT;
  int triSz = TRI_SIZE_DEF, kSz = KING_SIZE_DEF;
  int sLay = SPIDER_LAYERS_DEF, sPt = SPIDER_POINTS_DEF, rN = RAND_POINTS_DEF;
  boolean shPack = false, shTile = false;
  int graphKind; // 0 tri 1 king 2 spider 3 random
  // Pattern style for the right-panel render. 0 = "Rosone 1" (the existing
  // multi-circle motif). 1 = "Rosone 2", which keeps the same engine and
  // overlays an outer enclosing circle + convex-hull polygon + lens petals
  // along each hull edge. See drawRosone2Decoration() for the geometry.
  int rosoneKind = 0;

  // View-only zoom for the right pattern canvas. 1.0 = no zoom. Applied as
  // a matrix scale around the right-canvas pattern center in drawAll();
  // packing/cyclic-polygon coordinates and the left graph editor are
  // completely unaffected, so the pattern's data and exports stay correct
  // regardless of zoom level.
  float rightZoom = 1.0f;

  // Multiplier on every stroke weight used by the rosone draws on the
  // right canvas. Default 0.55 produces noticeably thinner lines than
  // raw weight values would, so fine details (chord intersections, kite
  // edges, construction guides) stay legible even when overlaid. Each
  // rosone keeps its OWN relative thick/thin ratios — we just scale the
  // whole set down. The left graph editor's stroke weights are not
  // touched (its drawL() doesn't reference this field).
  float lineScale = 0.55f;
  java.util.HashMap<Integer, PattC> pCirc = new java.util.HashMap<Integer, PattC>();
  java.util.HashMap<Integer, CycP> pCyc = new java.util.HashMap<Integer, CycP>();
  java.util.ArrayList<Pent> p5 = new java.util.ArrayList<Pent>();

  PortolanApp(PApplet p) {
    pa = p;
    mesh = new Mesh();
    mode = 0;
    graphKind = 0;
    if (DEBUG_LOG) println("  [LOG] PortolanApp ctor done: grid=" + grid + " tau=" + tau + " lambda=" + lambda);
  }

  void runSetup() {
    setGraph(0);
    if (DEBUG_LOG) println("  [LOG] runSetup: points=" + mesh.numPoints()
      + " tris=" + mesh.tri.size() + " conEdges=" + mesh.conEdge.size());
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

  void drawAll() {
    if (mesh == null) return;
    if (meshDirty) {
      mesh.recompute();
      meshDirty = false;
    }
    pCirc.clear();
    pCyc.clear();
    p5.clear();
    pa.background(255);
    drawL();

    // Right canvas: clip to the right half so a zoomed-in pattern can't
    // bleed into the left graph editor, then scale the rendered geometry
    // around the pattern's natural center (drawW * 0.75, drawH * 0.5).
    // Only the *visual output* is transformed — pCirc / pCyc positions
    // are still computed in unzoomed canvas coordinates, so the data the
    // SVG export reads, the cyclic polygons the user clicks, and the
    // mesh itself are all unaffected by the zoom level. try/finally
    // guards the matrix/clip stack against exceptions inside drawing.
    pa.pushStyle();
    pa.clip(drawW * 0.5f, 0, drawW * 0.5f, drawH);
    pa.pushMatrix();
    float zcx = drawW * 0.75f, zcy = drawH * 0.5f;
    pa.translate(zcx, zcy);
    pa.scale(rightZoom);
    pa.translate(-zcx, -zcy);

    try {
      pack();
      if (rosoneKind == 1) {
        // Rosone 2 — clean per-cell rosette with outer circle, lens
        // petals, mid/inner pentagonal cells, and a central star.
        drawRosone2Cells();
      } else if (rosoneKind == 2) {
        // Rosone 3 — gothic per-cell rosette + gap-filler polygon
        // outlines as the irregular surrounding network.
        drawRosone3Cells();
      } else if (rosoneKind == 3) {
        // Rosone 4 — N kite/rhombus cells fanning out from each
        // cyclic polygon's center (rhombus tessellation of the cell).
        drawRosone4Cells();
      } else {
        // Rosone 1 — chord-based {N/skip} star polygon per cell. shTile
        // still draws the polygon outlines when enabled.
        drawRosone1Cells();
      }
    } finally {
      pa.popMatrix();
      pa.noClip();
      pa.popStyle();
    }
  }

  // Rosone 1 — chord-based star polygon per cyclic polygon. For each q in
  // pCyc, draw the {q.n / skip} star polygon connecting its vertices,
  // where skip is picked from the lambda slider (low λ → small skip,
  // near-polygon look; high λ → max skip, sharpest star). The chord
  // intersections carve out the rosette's pentagonal cells and central
  // star automatically — no separate cell construction needed.
  void drawRosone1Cells() {
    pa.pushStyle();
    pa.noFill();
    Renderer r = new PARenderer(pa);
    if (shTile) {
      pa.stroke(0, 155, 170);
      pa.strokeWeight(0.75f * lineScale);
      for (CycP q : pCyc.values()) {
        if (!q.on) continue;
        renderPolygonClosed(r, cycPVerts(q));
      }
    }
    pa.stroke(220, 90, 80);
    pa.strokeWeight(1.0f * lineScale);
    for (CycP q : pCyc.values()) {
      if (!q.on || q.n < 4) continue;
      drawRosone1OnPolygon(r, q);
    }
    pa.popStyle();
  }

  void drawRosone1OnPolygon(Renderer r, CycP q) {
    // q.v is the full packing-circle polygon; tau scales the chord-star
    // vertices toward the cell's center so the star size becomes a
    // fraction of the enclosing packing circle (tau=1.0 → vertices on
    // the packing circle, tau=0.85 → 85% of the way out, etc.). lambda
    // picks the chord skip {n/skip}: low λ → small skip (near polygon,
    // blunt), high λ → max skip (sharpest, deepest star points).
    int skip = chooseStarSkipLambda(q.n, lambdaSharpness());
    drawStarPolygon(r, scaleVerticesTowardCenter(q, tau), skip);
    // Inner concentric chord star at the "inner circle" radius. The
    // outer chord star's logic is untouched; this is an additive layer
    // controlled exclusively by Tau (innerTau), giving Rosone 1 a
    // visible nested rosette whose size scales with the new slider.
    drawStarPolygon(r, scaleVerticesTowardCenter(q, effectiveInnerFactor()), skip);
  }

  // Convenience: copy q's vertex list into a primitive array (which is
  // what drawStarPolygon / renderPolygonClosed expect).
  GPoint[] cycPVerts(CycP q) {
    GPoint[] V = new GPoint[q.n];
    for (int i = 0; i < q.n; ++i) V[i] = q.v.get(i);
    return V;
  }

  // Rosone 2 — for each cyclic polygon produced by the packing, render a
  // self-contained Rosone 2 motif inscribed in it. The polygon (a CycP) is
  // treated as the OUTER inscribed n-gon of the rosette, and we build the
  // rest of the rosette parametrically from its vertices and circumradius:
  //
  //   1. Outer circle (passes through the polygon's vertices, radius q.sc/2)
  //   2. Polygon outline (q itself)
  //   3. Lens petal arc on each polygon edge (chord-bulge arc; the outer
  //      circle's arc is the petal's outer edge)
  //   4. Mid-ring W: q.v scaled toward q.center by MID_R_F
  //   5. n outer pentagonal cells: V[i], V[i+1], W[i+1], apex, W[i]
  //   6. Mid-ring polygon outline
  //   7. Inner-ring U: q.v scaled toward q.center by INNER_R_F
  //   8. n inner pentagonal cells: W[i], W[i+1], U[i+1], apex, U[i]
  //   9. Central {n/skip} star polygon connecting U vertices across center
  //
  // This is fully driven by the graph the user designs on the left: each
  // polygon's size (q.sc), shape, and side count (q.n) come from the
  // circle packing the user's mesh produces, so editing the graph
  // immediately changes every mini-rosette on the right.
  void drawRosone2Cells() {
    pa.pushStyle();
    pa.stroke(220, 90, 80);
    pa.strokeWeight(1.0f * lineScale);
    pa.noFill();
    Renderer r = new PARenderer(pa);
    for (CycP q : pCyc.values()) {
      if (!q.on) continue;
      drawRosone2OnPolygon(r, q);
    }
    pa.popStyle();
  }

  void drawRosone2OnPolygon(Renderer r, CycP q) {
    // lambda controls how pointed the rosette feels. S ∈ [0,1]: at S=0
    // the lens petals are nearly flat and the pentagonal cells' apexes
    // sit out near the rings (blunt cells, gentle bulges); at S=1 the
    // petals bulge out aggressively and apexes are pulled hard toward
    // the center, sharpening the inner star points. The central
    // {n/skip} star also uses the λ-driven skip so its tips match.
    float S = lambdaSharpness();
    final float MID_R_F   = 0.62f;                  // mid-ring fraction of outer rosette
    // Inner ring (where the central star's tips sit) is driven by the
    // Tau slider as a direct fraction of the packing-circle radius.
    // INNER_R_F is therefore derived: it has to be relative to the
    // outer rosette (which is tau * R_pack), so INNER_R_F = innerTau / tau.
    final float innerFactor = effectiveInnerFactor();
    final float INNER_R_F = tau > 1e-3f ? innerFactor / tau : 0.30f;
    final float APEX_F    = lerp(1.00f, 0.55f, S);
    final float APEX2_F   = lerp(0.95f, 0.50f, S);
    final float PETAL_F   = lerp(0.04f, 0.30f, S);

    int N = q.n;
    if (N < 3) return;
    GPoint C = new GPoint(q.x, q.y);

    // Outer ring: tau scales the polygon vertices toward C, making the
    // rosette's outer extent a fraction of the packing circle. All
    // nested rings (mid, inner) are then proportional to this outer
    // ring, so the entire motif scales together while q.sc / q.v stay
    // anchored to the (full) packing circle.
    GPoint[] V = scaleVerticesTowardCenter(q, tau);
    float R = q.sc / 2.0f * tau;

    r.circle(q.x, q.y, q.sc * tau);

    renderPolygonClosed(r, V);

    for (int i = 0; i < N; ++i) {
      GPoint p1 = V[i];
      GPoint p2 = V[(i + 1) % N];
      float dx = p2.x - p1.x, dy = p2.y - p1.y;
      float L = sqrt(dx * dx + dy * dy);
      if (L < 1e-3f) continue;
      drawArcBulge(r, p1, p2, C, L * PETAL_F, 16);
    }

    GPoint[] W = scaleVerticesTowardCenter(q, tau * MID_R_F);
    GPoint[] U = scaleVerticesTowardCenter(q, tau * INNER_R_F);

    for (int i = 0; i < N; ++i) {
      GPoint v1 = V[i];
      GPoint v2 = V[(i + 1) % N];
      GPoint mid = new GPoint((v1.x + v2.x) / 2, (v1.y + v2.y) / 2);
      GPoint apex = pullToRadius(mid, C, R * MID_R_F * APEX_F);
      renderPolygonClosed(r, new GPoint[] { v1, v2, W[(i + 1) % N], apex, W[i] });
    }

    renderPolygonClosed(r, W);

    for (int i = 0; i < N; ++i) {
      GPoint w1 = W[i];
      GPoint w2 = W[(i + 1) % N];
      GPoint mid = new GPoint((w1.x + w2.x) / 2, (w1.y + w2.y) / 2);
      GPoint apex = pullToRadius(mid, C, R * INNER_R_F * APEX2_F);
      renderPolygonClosed(r, new GPoint[] { w1, w2, U[(i + 1) % N], apex, U[i] });
    }

    drawStarPolygon(r, U, chooseStarSkipLambda(N, S));
  }

  // ===================================================================
  // Rosone 3 — gothic per-cell rosette + irregular polygonal gap filler
  // ===================================================================
  //
  // For each cyclic polygon q in pCyc:
  //
  //   • Inscribe a gothic rosette inside q's *apothem* (q's inscribed
  //     circle), so the rosette never crosses a polygon edge. The space
  //     between the rosette's outer circle and the polygon edges is the
  //     "gap" we leave for drawRosone3Gaps() to fill.
  //   • Build the rosette from polar coordinates: a center (q.x, q.y), an
  //     angular subdivision n = constrain(q.n * 2, 12, 16), and four
  //     concentric construction radii r1..r4 (a fifth, r3ext, pushes
  //     petal-layer outer points outward to create the pointed gothic
  //     petals). Aligning the rosette's first ray with q.v[0] makes the
  //     rosette's symmetry follow the polygon's own.
  //   • Render in three visually-distinct layers: thin gray construction
  //     guides (concentric circles + radial spokes), thick red main lines
  //     (inner star + cross-sector diagonals + petals + outer ring), and
  //     a separate gap-filler pass that draws every polygon outline so
  //     the irregular network around the rosettes is clearly visible.
  //
  // Same per-polygon, graph-driven model as Rosone 1 / 2 — editing the
  // graph on the left immediately changes every Rosone 3 cell.
  void drawRosone3Cells() {
    pa.pushStyle();
    pa.noFill();
    Renderer r = new PARenderer(pa);

    // Gap pass first so the rosettes draw on top of the polygon outlines.
    drawRosone3Gaps(r);

    for (CycP q : pCyc.values()) {
      if (!q.on || q.n < 3) continue;
      drawRosone3OnPolygon(r, q);
    }

    pa.popStyle();
  }

  void drawRosone3OnPolygon(Renderer r, CycP q) {
    int n = constrain(q.n * 2, 12, 16);
    float R = q.sc / 2.0f;
    // tau scales the rosette outward toward the polygon's apothem
    // (cos(PI/q.n) * R = distance from center to a polygon edge mid).
    // tau=1.0 → rosette touches the polygon edges; tau<1.0 → leaves an
    // annular gap inside the polygon for drawRosone3Gaps() to fill.
    float rosR = tau * R * cos(PI / max(3, q.n));
    // lambda controls gothic petal sharpness via r3ext (how far the
    // petal-layer outer points are pushed past the r3 ring) and the
    // inner chord star's skip — higher λ = sharper petals + deeper
    // chord star intersections.
    float S = lambdaSharpness();
    float r2 = rosR * 0.42f;
    float r3 = rosR * 0.65f;
    float r3ext = r3 * lerp(1.00f, 1.22f, S);
    float r4 = rosR * 0.95f;
    // r1 (the central rosette's first ring) is driven by the new Tau
    // slider as a fraction of the packing-circle radius (q.sc / 2 = R).
    // Clamped to be strictly inside r2 so the cross-sector diagonals
    // (ring1 → ring2) don't invert when the user pushes Tau very high.
    float r1 = constrain(effectiveInnerFactor() * R, R * 0.05f, r2 * 0.85f);
    int innerSkip = chooseStarSkipLambda(n, S);

    float a0 = atan2(q.v.get(0).y - q.y, q.v.get(0).x - q.x);
    float angleStep = TWO_PI / n;

    GPoint[] ring1  = new GPoint[n];
    GPoint[] ring2  = new GPoint[n];
    GPoint[] ring3  = new GPoint[n];
    GPoint[] ring3e = new GPoint[n];
    GPoint[] ring4  = new GPoint[n];
    for (int i = 0; i < n; ++i) {
      float a = a0 + i * angleStep;
      float cc = cos(a), ss = sin(a);
      ring1[i]  = new GPoint(q.x + cc * r1,    q.y + ss * r1);
      ring2[i]  = new GPoint(q.x + cc * r2,    q.y + ss * r2);
      ring3[i]  = new GPoint(q.x + cc * r3,    q.y + ss * r3);
      ring3e[i] = new GPoint(q.x + cc * r3ext, q.y + ss * r3ext);
      ring4[i]  = new GPoint(q.x + cc * r4,    q.y + ss * r4);
    }

    // ---- Construction guides (thin, light gray) ----
    pa.stroke(190, 190, 190);
    pa.strokeWeight(0.5f * lineScale);
    r.circle(q.x, q.y, r1 * 2);
    r.circle(q.x, q.y, r2 * 2);
    r.circle(q.x, q.y, r3 * 2);
    r.circle(q.x, q.y, r4 * 2);
    for (int i = 0; i < n; ++i) {
      r.line(q.x, q.y, ring4[i].x, ring4[i].y);
    }

    // ---- Main rosette (thick, red) ----
    pa.stroke(220, 90, 80);
    pa.strokeWeight(1.5f * lineScale);

    // Inner star — center → ring 1 spokes.
    for (int i = 0; i < n; ++i) {
      r.line(q.x, q.y, ring1[i].x, ring1[i].y);
    }
    // Ring 1 chord star (i → i+innerSkip mod n) — the sharp inner
    // rosette. innerSkip is λ-driven so sliding lambda visibly changes
    // the central star pattern's depth.
    drawStarPolygon(r, ring1, innerSkip);

    // Cross-sector diagonals between ring 1 and ring 2 — each ring 1 point
    // connects to its two angular neighbours one ring out, producing the
    // diamond facet pattern visible around the central star in gothic
    // rosettes.
    for (int i = 0; i < n; ++i) {
      r.line(ring1[i].x, ring1[i].y, ring2[(i + 1) % n].x,         ring2[(i + 1) % n].y);
      r.line(ring1[i].x, ring1[i].y, ring2[(i - 1 + n) % n].x,     ring2[(i - 1 + n) % n].y);
    }
    renderPolygonClosed(r, ring2);

    // Petal kites between ring 2 and the extended r3ext ring. Each kite's
    // four corners are (ring2[i], r3ext[i], r3ext[i+1], ring2[i+1]). We
    // skip the inner edge (ring2[i] → ring2[i+1]) here because it is
    // already drawn by renderPolygonClosed(ring2) above.
    for (int i = 0; i < n; ++i) {
      GPoint p2a = ring2[i],  p2b = ring2[(i + 1) % n];
      GPoint p3a = ring3e[i], p3b = ring3e[(i + 1) % n];
      r.line(p2a.x, p2a.y, p3a.x, p3a.y);
      r.line(p3a.x, p3a.y, p3b.x, p3b.y);
      r.line(p3b.x, p3b.y, p2b.x, p2b.y);
    }

    // Outer ring closure + radial connectors closing each petal cell.
    renderPolygonClosed(r, ring4);
    for (int i = 0; i < n; ++i) {
      r.line(ring3[i].x, ring3[i].y, ring4[i].x, ring4[i].y);
    }
  }

  // Gap filler — every cyclic polygon's outline drawn as the irregular
  // network around the per-cell rosettes. Because drawRosone3OnPolygon
  // confines its rosette inside the polygon's apothem, the polygon edges
  // are always visible as a clean boundary between adjacent cells, and
  // chaining them produces the "irregular polygonal mesh" look the
  // reference image has surrounding its central rosette.
  void drawRosone3Gaps(Renderer r) {
    pa.stroke(80, 80, 80);
    pa.strokeWeight(1.0f * lineScale);
    for (CycP q : pCyc.values()) {
      if (!q.on) continue;
      renderPolygonClosed(r, cycPVerts(q));
    }
  }

  // ===================================================================
  // Rosone 4 — N kite / rhombus cells fanning out from each cell center
  // ===================================================================
  //
  // For each cyclic polygon q in pCyc:
  //
  //   • Use q's vertices V[0..N-1] as the OUTER vertices of N kite cells
  //     (each kite's apex). Each V[k] sits on q's circumscribed circle
  //     at radius R = q.sc / 2.
  //   • Build an inner ring W[0..N-1] where W[k] sits on the bisector
  //     ray of edge V[k]–V[k+1] (the line from C through that edge's
  //     midpoint), at radius rInner = R / (2·cos(π/N)). For a regular
  //     N-gon this radius makes every kite a TRUE rhombus (all four
  //     sides equal); for irregular cells the rhombus condition only
  //     holds approximately, but the kite construction stays valid.
  //   • Each cell becomes a kite with vertices (C, W[k-1], V[k], W[k]).
  //     Drawn as: N spokes from C to each W, plus 2N edges V↔W (each
  //     V connects to the W on its left and right), plus the polygon
  //     outline as the outer boundary.
  //
  // Triangles (q.n = 3) are skipped because rInner = R/(2·cos(60°)) = R
  // would put the inner ring on top of the outer ring (degenerate). For
  // N ≥ 4 the construction is well-defined.
  //
  // Same per-polygon, graph-driven model as the other Rosones.
  void drawRosone4Cells() {
    pa.pushStyle();
    pa.noFill();
    pa.stroke(220, 90, 80);
    pa.strokeWeight(1.5f * lineScale);
    Renderer r = new PARenderer(pa);
    for (CycP q : pCyc.values()) {
      if (!q.on || q.n < 4) continue;
      drawRosone4OnPolygon(r, q);
    }
    pa.popStyle();
  }

  void drawRosone4OnPolygon(Renderer r, CycP q) {
    int N = q.n;
    if (N < 4) return;
    // tau scales the entire kite tessellation (outer V ring + inner W
    // ring + polygon outline) toward the cell's center, so the whole
    // Rosone 4 motif sizes itself as a fraction of the enclosing
    // packing circle. The rhombus-condition formula stays the same; we
    // just substitute the tau-scaled outer radius.
    float R = q.sc / 2.0f * tau;
    // rInner (the inner W ring on which the kite "outer base" vertices
    // sit) is now driven by the new Tau slider as a direct fraction of
    // the packing-circle radius. effectiveInnerFactor() clamps it
    // strictly inside the outer V ring (which is tau * R_pack), so the
    // kites never invert no matter how the two sliders are crossed.
    // lambda's old kite-shape scaling has been retired here — innerTau
    // now owns the inner-ring geometry — but we keep a small lambda
    // bias so the slider still nudges the kite proportions: high λ
    // pulls W slightly further toward center (sharper V tips), low λ
    // pushes it slightly further out (blunter tips).
    float S = lambdaSharpness();
    float R_pack = q.sc / 2.0f;
    // lambda multiplier stays in [0, 1] so rInner is always ≤
    // effectiveInnerFactor * R_pack — and that's already clamped below
    // the outer V ring, so the kites can't invert no matter how the
    // sliders are crossed.
    float rInner = effectiveInnerFactor() * R_pack * lerp(1.00f, 0.75f, S);

    GPoint[] V = scaleVerticesTowardCenter(q, tau);

    // W[k] lies on the C→edgeMidpoint(V[k], V[k+1]) ray, at radius rInner
    // from C. For a regular N-gon this is the angle bisector between
    // V[k] and V[k+1]. For irregular q's we still pick the geometric
    // edge midpoint direction, which keeps adjacent V↔W edges of similar
    // length even if not exactly equal.
    GPoint[] W = new GPoint[N];
    for (int k = 0; k < N; ++k) {
      GPoint a = V[k], b = V[(k + 1) % N];
      float mx = (a.x + b.x) * 0.5f, my = (a.y + b.y) * 0.5f;
      float dx = mx - q.x, dy = my - q.y;
      float d = sqrt(dx * dx + dy * dy);
      if (d < 1e-6f) { W[k] = new GPoint(mx, my); continue; }
      float s = rInner / d;
      W[k] = new GPoint(q.x + dx * s, q.y + dy * s);
    }

    // Spokes: center → each inner-ring vertex. These are the radial
    // diagonals of the kite cells.
    for (int k = 0; k < N; ++k) {
      r.line(q.x, q.y, W[k].x, W[k].y);
    }

    // Each outer V[k] is the apex of one kite; it connects to the two
    // inner-ring vertices on either side of it (W[k-1] on the left,
    // W[k] on the right). These are the kite's outer side edges.
    for (int k = 0; k < N; ++k) {
      GPoint v = V[k];
      GPoint wL = W[(k - 1 + N) % N];
      GPoint wR = W[k];
      r.line(v.x, v.y, wL.x, wL.y);
      r.line(v.x, v.y, wR.x, wR.y);
    }

    // Polygon outline — the kite cells live INSIDE this boundary.
    renderPolygonClosed(r, V);
  }

  // Scale each vertex of q.v toward q's center by `factor`. Because every
  // vertex of a CycP sits on the circumscribed packing circle (pack()
  // calls PattC.bPoly with tau = 1.0, so q.v is anchored to the full
  // packing circle), this produces a smaller similar polygon at radius
  // factor * R, with vertices on the same radials. The rosone draws use
  // this with the tau slider as the factor to scale star/motif size as
  // a fraction of the enclosing packing circle.
  GPoint[] scaleVerticesTowardCenter(CycP q, float factor) {
    GPoint[] out = new GPoint[q.n];
    for (int i = 0; i < q.n; ++i) {
      GPoint v = q.v.get(i);
      out[i] = new GPoint(q.x + (v.x - q.x) * factor, q.y + (v.y - q.y) * factor);
    }
    return out;
  }

  // Project `p` onto the ray from `c` through `p`, scaled so the result is
  // exactly `targetR` away from `c`. Used to place each pentagonal cell's
  // apex at a chosen ring radius along the bisector of its base edge.
  GPoint pullToRadius(GPoint p, GPoint c, float targetR) {
    float dx = p.x - c.x, dy = p.y - c.y;
    float r = sqrt(dx * dx + dy * dy);
    if (r < 1e-6f) return new GPoint(c.x + targetR, c.y);
    float k = targetR / r;
    return new GPoint(c.x + dx * k, c.y + dy * k);
  }

  // Normalize the lambda slider's [0.3, 0.5] range into a "sharpness"
  // parameter S ∈ [0, 1] that every rosone interprets as "how pointed
  // the star points should look". S = 0 → blunt, S = 1 → sharp/deep.
  // Default λ = 0.42 → S = 0.6, a moderately sharp look.
  float lambdaSharpness() {
    return constrain((lambda - 0.3f) / 0.2f, 0.0f, 1.0f);
  }

  // Inner-ring radius as a fraction of the packing circle, clamped so it
  // never reaches the outer rosette (whose fraction is tau). The clamp
  // keeps the inner star strictly inside the outer star even when the
  // user slides Tau higher than Star Size — instead of exploding outside,
  // the inner ring caps just inside the outer one.
  float effectiveInnerFactor() {
    return constrain(innerTau, 0.0f, tau * 0.95f);
  }

  // λ-aware star skip picker. Interpolates target skip from 2 (blunt,
  // near polygon) to ⌊(n-1)/2⌋ (deepest possible {n/skip} star) by S,
  // then walks outward from `target` to find a coprime skip so the
  // chord star traces a single connected line. Falls back to `target`
  // (drawStarPolygon handles compound stars) if no coprime skip is
  // found in range.
  int chooseStarSkipLambda(int n, float S) {
    if (n < 4) return 1;
    int maxSkip = (n - 1) / 2;
    int target = round(lerp(2, maxSkip, S));
    target = constrain(target, 2, maxSkip);
    for (int delta = 0; delta <= maxSkip; ++delta) {
      int up   = target + delta;
      int down = target - delta;
      if (up   >= 2 && up   <= maxSkip && gcd2(n, up)   == 1) return up;
      if (down >= 2 && down <= maxSkip && gcd2(n, down) == 1) return down;
    }
    return max(2, target);
  }

  // Pick a star-polygon skip {n/skip} that produces a visually pleasing
  // star: large enough to look pointy (skip > 1), but coprime-ish with n
  // so the polygon traces a single connected line rather than collapsing
  // to a smaller regular polygon. We aim for skip ≈ ⌈n/3⌉ which gives
  // 6→2 (hexagram), 8→3 (octagram), 10→3 (decagram), etc., then walk
  // outward to find a coprime skip when ⌈n/3⌉ shares a factor with n.
  int chooseStarSkip(int n) {
    if (n < 4) return 1;
    int target = (n + 2) / 3;          // ⌈n/3⌉
    if (target < 2) target = 2;
    int maxSkip = (n - 1) / 2;
    if (target > maxSkip) target = maxSkip;
    for (int delta = 0; delta <= maxSkip; ++delta) {
      int up   = target + delta;
      int down = target - delta;
      if (up >= 2 && up <= maxSkip && gcd2(n, up) == 1) return up;
      if (down >= 2 && down <= maxSkip && gcd2(n, down) == 1) return down;
    }
    // No coprime skip found in range → fall back to ⌈n/3⌉; drawStarPolygon
    // handles compound stars via multi-traversal so this still draws.
    return max(2, target);
  }

  int gcd2(int a, int b) {
    while (b != 0) { int t = b; b = a % b; a = t; }
    return a;
  }

  // Draw a {n/skip} star polygon through `pts`. When gcd(n, skip) > 1 the
  // single traversal would close after only n/gcd vertices, leaving the
  // others unvisited — so we restart at each unvisited index, producing
  // the correct compound (e.g. {6/2} = hexagram = two interlocked tris).
  void drawStarPolygon(Renderer r, GPoint[] pts, int skip) {
    int n = pts.length;
    if (n < 2 || skip < 1) return;
    boolean[] seen = new boolean[n];
    for (int start = 0; start < n; ++start) {
      if (seen[start]) continue;
      int idx = start;
      do {
        seen[idx] = true;
        int next = (idx + skip) % n;
        r.line(pts[idx].x, pts[idx].y, pts[next].x, pts[next].y);
        idx = next;
      } while (idx != start);
    }
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
    // Build cyclic polygons at the FULL packing-circle radius (tau = 1.0).
    // tau no longer shrinks the polygon itself — each rosone applies tau
    // to its own inner geometry instead, so the slider controls the star
    // size *relative to the enclosing packing circle* (the user's mental
    // model) rather than scaling the whole rosone uniformly.
    for (PattC c : pCirc.values()) {
      if (!c.bd) c.bPoly(1.0f, pCyc);
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
    graphKind = k;
    mesh = new Mesh();
    int margin = 4 * grid, sp = 8 * grid;
    float cx = drawW / 4.0f, cy = drawH / 2.0f;
    if (k == 0) {
      int n = triSz, rows = n, cols = n;
      float gw = (cols - 1) * sp, gh = (rows - 1) * sp, sx = cx - gw / 2, sy = cy - gh / 2;
      int[][] g = new int[rows][cols];
      for (int i = 0; i < rows; i++) for (int j = 0; j < cols; j++) { int v = mesh.vert.size(); g[i][j] = v; mesh.addPoint(new GPoint(sx + j * sp, sy + i * sp)); }
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[0][j], g[0][j + 1]);
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[rows - 1][j], g[rows - 1][j + 1]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][0], g[i + 1][0]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][cols - 1], g[i + 1][cols - 1]);
    } else if (k == 1) {
      // King's Graph — rows×cols main grid + (rows-1)×(cols-1) cell-
      // center points (the offset "queen-move" lattice). Only the
      // perimeter is constrained; Delaunay handles the interior, which
      // naturally produces the 8-neighbour (king-move) triangulation
      // because every center point sits equidistant from its 4 corner
      // neighbours. Ports constelation/sketch.js#generateKingsGraph.
      int n = kSz, rows = n, cols = n;
      float gw = (cols - 1) * sp, gh = (rows - 1) * sp, sx = cx - gw / 2, sy = cy - gh / 2;
      int[][] g = new int[rows][cols];
      for (int i = 0; i < rows; i++) for (int j = 0; j < cols; j++) { int v = mesh.vert.size(); g[i][j] = v; mesh.addPoint(new GPoint(sx + j * sp, sy + i * sp)); }
      for (int i = 0; i < rows - 1; i++) for (int j = 0; j < cols - 1; j++) {
        mesh.addPoint(new GPoint(sx + (j + 0.5f) * sp, sy + (i + 0.5f) * sp));
      }
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[0][j], g[0][j + 1]);
      for (int j = 0; j < cols - 1; j++) mesh.addConstraint(g[rows - 1][j], g[rows - 1][j + 1]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][0], g[i + 1][0]);
      for (int i = 0; i < rows - 1; i++) mesh.addConstraint(g[i][cols - 1], g[i + 1][cols - 1]);
    } else if (k == 2) {
      // Triangulated Spider Graph — `numLayers` concentric rings of
      // `pointsPerLayer` points around a center vertex, fully
      // triangulated with radial spokes, ring chords, and cross-layer
      // diagonals. Produces the heptagonal/octagonal "net" pattern.
      // Ports constelation/sketch.js#generateSpiderGraph.
      int numLayers = sLay, pointsPerLayer = sPt;
      float spMargin = grid * 2;
      float maxRadius = min(drawW / 2.0f - 2 * spMargin, drawH - 2 * spMargin) / 2.0f;
      float outerRadius = maxRadius * 0.85f;

      int centerIdx = mesh.vert.size();
      mesh.addPoint(new GPoint(cx, cy));

      int[][] layers = new int[numLayers + 1][];
      layers[0] = new int[] { centerIdx };

      for (int layer = 1; layer <= numLayers; layer++) {
        float layerRadius = ((float) layer / numLayers) * outerRadius;
        int[] layerIdx = new int[pointsPerLayer];
        for (int i = 0; i < pointsPerLayer; i++) {
          float angle = (i * TWO_PI) / pointsPerLayer - HALF_PI;
          float px = cx + layerRadius * cos(angle);
          float py = cy + layerRadius * sin(angle);
          layerIdx[i] = mesh.vert.size();
          mesh.addPoint(new GPoint(px, py));
        }
        layers[layer] = layerIdx;
      }

      // Outer ring constraint (closes the boundary so the CDT respects it).
      int[] outerLayer = layers[numLayers];
      for (int i = 0; i < outerLayer.length; i++) {
        mesh.addConstraint(outerLayer[i], outerLayer[(i + 1) % outerLayer.length]);
      }

      // Center → layer-1 spokes + layer-1 ring edges.
      for (int i = 0; i < layers[1].length; i++) {
        mesh.addConstraint(centerIdx, layers[1][i]);
        mesh.addConstraint(layers[1][i], layers[1][(i + 1) % layers[1].length]);
      }

      // Cross-layer triangulation: between each pair of adjacent
      // layers, add the four constraints that pin two triangles per
      // sector (inner→outer, outer→innerNext, outer→outerNext,
      // outerNext→innerNext) so the band stays a clean net even if
      // the Delaunay step would otherwise pick different diagonals.
      for (int layer = 1; layer < numLayers; layer++) {
        int[] inner = layers[layer];
        int[] outer = layers[layer + 1];
        for (int i = 0; i < inner.length; i++) {
          int innerNext = (i + 1) % inner.length;
          int outerNext = (i + 1) % outer.length;
          mesh.addConstraint(inner[i], outer[i]);
          mesh.addConstraint(outer[i], inner[innerNext]);
          mesh.addConstraint(outer[i], outer[outerNext]);
          mesh.addConstraint(outer[outerNext], inner[innerNext]);
        }
      }
    } else {
      for (int i = 0; i < rN; i++) {
        float rx = pa.random(margin, drawW / 2f - margin), ry = pa.random(margin, drawH - margin);
        mesh.addPoint(new GPoint(rx, ry));
      }
    }
    mesh.recompute();
    meshDirty = false; // recompute() we just ran is authoritative
    if (DEBUG_LOG) println("    [LOG] setGraph(" + k + "): points=" + mesh.numPoints()
      + " tris=" + mesh.tri.size());
  }
}
