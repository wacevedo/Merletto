// CDT + circle packing — port of constelation/cdt.js

class Mesh {
  java.util.ArrayList<GPoint> vert;
  java.util.ArrayList<int[]> tri;
  java.util.ArrayList<int[]> adj;
  java.util.ArrayList<int[]> conEdge;
  java.util.ArrayList<VertProperty> vertProps;
  java.util.ArrayList<java.util.ArrayList<Integer>> vertToTri;

  Mesh() {
    reset();
  }

  void reset() {
    vert = new java.util.ArrayList<GPoint>();
    tri = new java.util.ArrayList<int[]>();
    adj = new java.util.ArrayList<int[]>();
    conEdge = new java.util.ArrayList<int[]>();
    vertProps = new java.util.ArrayList<VertProperty>();
    vertToTri = new java.util.ArrayList<java.util.ArrayList<Integer>>();
  }

  int numPoints() {
    return vert.size();
  }

  void addPoint(GPoint p) {
    vert.add(p);
  }

  GPoint getPoint(int i) {
    return vert.get(i);
  }

  // NOTE on recompute(): addConstraint, setPoint, and removePoint used to
  // call recompute() internally. That forced an O(N²) full CDT + circle
  // packing pass for every single mutation. In practice every caller of
  // these methods already either (a) marks the mesh dirty and lets the
  // next draw run a single recompute, or (b) calls mesh.recompute()
  // explicitly after a batch of mutations (e.g. PortolanApp.setGraph adds
  // dozens of constraints then recomputes once). Letting callers own the
  // recompute makes a 15x15 triangular grid ~50x faster to build.

  void setPoint(int i, GPoint p) {
    vert.set(i, p);
  }

  void removePoint(int i) {
    vert.remove(i);
    java.util.ArrayList<int[]> ncon = new java.util.ArrayList<int[]>();
    for (int[] e : conEdge) {
      int a = e[0], b = e[1];
      if (a == i || b == i) continue;
      if (a > i) a--;
      if (b > i) b--;
      ncon.add(new int[] {a, b});
    }
    conEdge = ncon;
  }

  void addConstraint(int i, int j) {
    conEdge.add(new int[] {i, j});
  }

  void recompute() {
    long t0 = DEBUG_LOG ? System.currentTimeMillis() : 0;
    if (DEBUG_LOG) println("      [MESH] recompute start. pts=" + vert.size() + " cons=" + conEdge.size());
    vertProps.clear();
    for (int idx = 0; idx < vert.size(); ++idx) {
      vertProps.add(new VertProperty());
    }
    if (vert.size() >= 3) {
      long t1 = DEBUG_LOG ? System.currentTimeMillis() : 0;
      delaunay();
      if (DEBUG_LOG) println("      [MESH] delaunay done in " + (System.currentTimeMillis() - t1) + "ms. tris=" + tri.size());
      if (conEdge.size() > 0) {
        long t2 = DEBUG_LOG ? System.currentTimeMillis() : 0;
        constrainEdges();
        if (DEBUG_LOG) println("      [MESH] constrainEdges done in " + (System.currentTimeMillis() - t2) + "ms");
      }
      long t3 = DEBUG_LOG ? System.currentTimeMillis() : 0;
      calcGraphStructure();
      if (DEBUG_LOG) println("      [MESH] calcGraphStructure done in " + (System.currentTimeMillis() - t3) + "ms");
      if (vert.size() >= 3) {
        long t4 = DEBUG_LOG ? System.currentTimeMillis() : 0;
        calcCirclePacking();
        if (DEBUG_LOG) println("      [MESH] calcCirclePacking done in " + (System.currentTimeMillis() - t4) + "ms");
      }
    }
    if (DEBUG_LOG) println("      [MESH] recompute total=" + (System.currentTimeMillis() - t0) + "ms");
  }

  void setupDelaunay() {
    float xmin = vert.get(0).x, ymin = vert.get(0).y, xmax = vert.get(0).x, ymax = vert.get(0).y;
    for (GPoint p : vert) {
      xmin = min(xmin, p.x);
      xmax = max(xmax, p.x);
      ymin = min(ymin, p.y);
      ymax = max(ymax, p.y);
    }
    int nVertex = vert.size();
    float di = 1000.0f * max(xmax - xmin, ymax - ymin);
    vert.add(new GPoint(-di + 0.5f, -di / sqrt(3.0f) + 0.5f));
    vert.add(new GPoint(di + 0.5f, -di / sqrt(3.0f) + 0.5f));
    vert.add(new GPoint(0.5f, 2 * di / sqrt(3.0f) + 0.5f));
    tri.clear();
    adj.clear();
    tri.add(new int[] {nVertex, nVertex + 1, nVertex + 2});
    adj.add(new int[] {-1, -1, -1});
    // Reset vert-to-tri so swapDiagonal's stale-data path stays disabled during
    // the initial (unconstrained) Delaunay phase. constrainEdges() will rebuild it.
    vertToTri.clear();
  }

  boolean isDelaunay2(GPoint[] vTri, GPoint p) {
    GPoint vecp0 = vTri[0].sub(p);
    GPoint vecp1 = vTri[1].sub(p);
    GPoint vecp2 = vTri[2].sub(p);
    float p0sq = vecp0.x * vecp0.x + vecp0.y * vecp0.y;
    float p1sq = vecp1.x * vecp1.x + vecp1.y * vecp1.y;
    float p2sq = vecp2.x * vecp2.x + vecp2.y * vecp2.y;
    float det = vecp0.x * (vecp1.y * p2sq - p1sq * vecp2.y)
      - vecp0.y * (vecp1.x * p2sq - p1sq * vecp2.x)
      + p0sq * (vecp1.x * vecp2.y - vecp1.y * vecp2.x);
    return det <= 0;
  }

  void delaunay() {
    int nRealBefore = vert.size();
    boolean removedBoundary = false;
    try {
      setupDelaunay();
      int N = vert.size() - 3;
      int indTri = 0;
      for (int newI = 0; newI < N; ++newI) {
        GPoint pNew = vert.get(newI);
        int[] res = findEnclosingTriangle(pNew, indTri);
        indTri = res[0];
        if (indTri < 0) {
          // Always log this one — it only fires on a real failure, not per frame.
          println("      [MESH] delaunay: findEnclosingTriangle failed at newI=" + newI
            + " pt=(" + pNew.x + "," + pNew.y + ") vertSize=" + vert.size() + " triSize=" + tri.size());
          throw new RuntimeException("Could not find a triangle containing the new vertex (idx=" + newI + ")");
        }
        int[] curTri = tri.get(indTri).clone();
        int a = curTri[0], b = curTri[1], c = curTri[2];
        int newTri0[] = {a, b, newI};
        int newTri1[] = {newI, b, c};
        int newTri2[] = {a, newI, c};
        tri.set(indTri, newTri0);
        int nTri = tri.size();
        int[] curTriAdj = adj.get(indTri).clone();
        adj.set(indTri, new int[] {nTri, nTri + 1, curTriAdj[2]});
        tri.add(newTri1);
        tri.add(newTri2);
        adj.add(new int[] {curTriAdj[0], nTri + 1, indTri});
        adj.add(new int[] {nTri, curTriAdj[1], indTri});
        java.util.ArrayList<int[]> stack = new java.util.ArrayList<int[]>();
        if (curTriAdj[2] >= 0) {
          int na = indexOf(adj.get(curTriAdj[2]), indTri);
          stack.add(new int[] {curTriAdj[2], na});
        }
        if (curTriAdj[0] >= 0) {
          int na = indexOf(adj.get(curTriAdj[0]), indTri);
          adj.get(curTriAdj[0])[na] = nTri;
          stack.add(new int[] {curTriAdj[0], na});
        }
        if (curTriAdj[1] >= 0) {
          int na = indexOf(adj.get(curTriAdj[1]), indTri);
          adj.get(curTriAdj[1])[na] = nTri + 1;
          stack.add(new int[] {curTriAdj[1], na});
        }
        restoreDelaunay(newI, stack);
      }
      removeBoundaryTriangles();
      removedBoundary = true;
    } finally {
      // Safety net: guarantee vert is trimmed back to the "real" vertex count so
      // the 3 super-triangle points can never leak across frames even if delaunay
      // throws. removeBoundaryTriangles already does this on the happy path.
      if (!removedBoundary) {
        while (vert.size() > nRealBefore) {
          vert.remove(vert.size() - 1);
        }
        tri.clear();
        adj.clear();
      }
    }
  }

  int[] findEnclosingTriangle(GPoint target, int indTriCur) {
    int maxHops = max(10, adj.size());
    int nhops = 0;
    while (indTriCur >= 0 && nhops < maxHops) {
      int[] triCur = tri.get(indTriCur);
      GPoint v0 = vert.get(triCur[0]);
      GPoint v1 = vert.get(triCur[1]);
      GPoint v2 = vert.get(triCur[2]);
      float o0 = getPointOrientation(edgePair(v1, v2), target);
      float o1 = getPointOrientation(edgePair(v2, v0), target);
      float o2 = getPointOrientation(edgePair(v0, v1), target);
      if (o0 >= 0 && o1 >= 0 && o2 >= 0) {
        return new int[] {indTriCur, nhops};
      }
      int baseInd = -1;
      for (int iedge = 0; iedge < 3; iedge++) {
        float o = (iedge == 0) ? o0 : (iedge == 1) ? o1 : o2;
        if (o >= 0) {
          baseInd = iedge;
          break;
        }
      }
      float[] orients = {o0, o1, o2};
      int baseP1 = (baseInd + 1) % 3;
      int baseP2 = (baseInd + 2) % 3;
      if (orients[baseP1] >= 0 && orients[baseP2] < 0) {
        indTriCur = adj.get(indTriCur)[baseP2];
      } else if (orients[baseP1] < 0 && orients[baseP2] >= 0) {
        indTriCur = adj.get(indTriCur)[baseP1];
      } else {
        GPoint tBase = vert.get(triCur[baseInd]);
        GPoint tP1 = vert.get(triCur[baseP1]);
        GPoint tP2 = vert.get(triCur[baseP2]);
        GPoint vec0 = tP1.sub(tBase);
        GPoint vec1 = target.sub(tBase);
        if (vec0.dot(vec1) > 0) {
          indTriCur = adj.get(indTriCur)[baseP2];
        } else {
          indTriCur = adj.get(indTriCur)[baseP1];
        }
      }
      nhops++;
    }
    return new int[] {indTriCur, max(0, nhops - 1)};
  }

  int indexOf(int[] a, int v) {
    for (int i = 0; i < 3; i++) {
      if (a[i] == v) return i;
    }
    return -1;
  }

  int indexInTri(int[] t, int v) {
    for (int i = 0; i < 3; i++) {
      if (t[i] == v) return i;
    }
    return -1;
  }

  void restoreDelaunay(int indVert, java.util.ArrayList<int[]> stack) {
    GPoint vNew = vert.get(indVert);
    while (stack.size() > 0) {
      int[] pair = stack.remove(stack.size() - 1);
      int indT = pair[0];
      int[] triV = tri.get(indT);
      GPoint[] vTriM = {vert.get(triV[0]), vert.get(triV[1]), vert.get(triV[2])};
      if (isDelaunay2(vTriM, vNew)) {
        continue;
      }
      int outernode = pair[1];
      int indNeigh = adj.get(indT)[outernode];
      if (indNeigh < 0) {
        throw new RuntimeException("negative index");
      }
      swapDiagonal(indT, indNeigh);
      int nNode = indexInTri(tri.get(indT), indVert);
      int out2 = adj.get(indT)[nNode];
      if (out2 >= 0) {
        int nn = indexOf(adj.get(out2), indT);
        stack.add(new int[] {out2, nn});
      }
      int nNodeN = indexInTri(tri.get(indNeigh), indVert);
      int outN = adj.get(indNeigh)[nNodeN];
      if (outN >= 0) {
        int nn2 = indexOf(adj.get(outN), indNeigh);
        stack.add(new int[] {outN, nn2});
      }
    }
  }

  void swapDiagonal(int indTriA, int indTriB) {
    int ouA = indexOf(adj.get(indTriA), indTriB);
    int ouB = indexOf(adj.get(indTriB), indTriA);
    int p1A = (ouA + 1) % 3, p2A = (ouA + 2) % 3;
    int p1B = (ouB + 1) % 3, p2B = (ouB + 2) % 3;
    int[] tA = tri.get(indTriA);
    int[] tB = tri.get(indTriB);
    tA[p2A] = tB[ouB];
    tB[p2B] = tA[ouA];
    int[] aA = adj.get(indTriA);
    int[] aB = adj.get(indTriB);
    aA[ouA] = aB[p1B];
    aB[ouB] = aA[p1A];
    int nO = aA[p1A];
    if (nO >= 0) {
      adj.get(nO)[indexOf(adj.get(nO), indTriA)] = indTriB;
    }
    int nB = aB[p1B];
    if (nB >= 0) {
      adj.get(nB)[indexOf(adj.get(nB), indTriB)] = indTriA;
    }
    aA[p1A] = indTriB;
    aB[p1B] = indTriA;
    if (vertToTri != null && vertToTri.size() > 0) {
      int vIdxA = tA[ouA];
      int vIdxB = tB[ouB];
      vertToTri.get(vIdxA).add(Integer.valueOf(indTriB));
      vertToTri.get(vIdxB).add(Integer.valueOf(indTriA));
      int vAtP1A = tA[p1A];
      int vAtP1B = tB[p1B];
      java.util.ArrayList<Integer> lA = vertToTri.get(vAtP1A);
      java.util.ArrayList<Integer> lB = vertToTri.get(vAtP1B);
      lA.remove(Integer.valueOf(indTriB));
      lB.remove(Integer.valueOf(indTriA));
    }
  }

  void removeBoundaryTriangles() {
    int n = vert.size() - 3;
    for (int t = 0; t < tri.size(); t++) {
      int[] T = tri.get(t);
      if (T[0] < n && T[1] < n && T[2] < n) {
        continue;
      }
      for (int v = 0; v < 3; ++v) {
        int vidx = T[v];
        if (vidx < n) {
          vertProps.get(vidx).boundary = true;
        }
      }
    }
    java.util.ArrayList<int[]> newTri = new java.util.ArrayList<int[]>();
    for (int t = 0; t < tri.size(); t++) {
      int[] T = tri.get(t);
      if (T[0] < n && T[1] < n && T[2] < n) {
        newTri.add(new int[] {T[0], T[1], T[2]});
      }
    }
    tri = newTri;
    int nt = tri.size();
    adj = new java.util.ArrayList<int[]>();
    for (int i = 0; i < nt; i++) {
      adj.add(new int[] {-1, -1, -1});
    }
    for (int a = 0; a < nt; a++) {
      int[] Ta = tri.get(a);
      for (int b = a + 1; b < nt; b++) {
        int[] Tb = tri.get(b);
        if (!trisShareEdge(Ta, Tb)) {
          continue;
        }
        int oa = oppositeCorner(Ta, Tb);
        int ob = oppositeCorner(Tb, Ta);
        if (oa >= 0 && ob >= 0) {
          adj.get(a)[oa] = b;
          adj.get(b)[ob] = a;
        }
      }
    }
    for (int k = 0; k < 3; k++) {
      if (vert.size() > 0) vert.remove(vert.size() - 1);
    }
  }

  boolean trisShareEdge(int[] Ta, int[] Tb) {
    int m = 0;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (Ta[i] == Tb[j]) m++;
      }
    }
    return m >= 2;
  }

  // corner index in Ta opposite the shared edge with Tb
  int oppositeCorner(int[] Ta, int[] Tb) {
    for (int i = 0; i < 3; i++) {
      if (Ta[i] != Tb[0] && Ta[i] != Tb[1] && Ta[i] != Tb[2]) {
        return i;
      }
    }
    return -1;
  }

  void constrainEdges() {
    if (conEdge.isEmpty()) return;
    buildVertexConnectivity();
    java.util.ArrayList<int[]> newEdgeList = new java.util.ArrayList<int[]>();
    for (int iedge = 0; iedge < conEdge.size(); iedge++) {
      java.util.ArrayList<int[]> intersections = getEdgeIntersections(iedge);
      int iter = 0;
      int maxIter = max(intersections.size(), 1);
      while (intersections.size() > 0 && iter < maxIter) {
        fixEdgeIntersections(intersections, iedge, newEdgeList);
        intersections = getEdgeIntersections(iedge);
        iter++;
      }
      if (intersections.size() > 0) {
        throw new RuntimeException("Could not add edge " + iedge);
      }
    }
    while (true) {
      int numSw = 0;
      for (int iedge = 0; iedge < newEdgeList.size(); iedge++) {
        int[] newEdge = newEdgeList.get(iedge);
        boolean isCon = false;
        for (int j = 0; j < conEdge.size(); j++) {
          if (isSameEdge(newEdge, conEdge.get(j))) {
            isCon = true;
            break;
          }
        }
        if (isCon) continue;
        int v0 = newEdge[0], v1 = newEdge[1];
        java.util.ArrayList<Integer> tAround = vertToTri.get(v0);
        int t0i = -1, t1i = -1;
        int tCount = 0;
        for (int k = 0; k < tAround.size(); k++) {
          int ti = tAround.get(k).intValue();
          int[] T = tri.get(ti);
          if (indexInTri(T, v1) >= 0) {
            if (tCount == 0) t0i = ti; else t1i = ti;
            tCount++;
            if (tCount == 2) break;
          }
        }
        if (t0i < 0 || t1i < 0) continue;
        GPoint[] triA = {vert.get(tri.get(t0i)[0]), vert.get(tri.get(t0i)[1]), vert.get(tri.get(t0i)[2])};
        int ouB = indexOf(adj.get(t1i), t0i);
        GPoint triBVert = vert.get(tri.get(t1i)[ouB]);
        if (!isDelaunay2(triA, triBVert)) {
          int ouA = indexOf(adj.get(t0i), t1i);
          swapDiagonal(t0i, t1i);
          numSw++;
          newEdgeList.set(iedge, new int[] {tri.get(t0i)[ouA], tri.get(t1i)[ouB]});
        }
      }
      if (numSw == 0) break;
    }
  }

  void buildVertexConnectivity() {
    vertToTri.clear();
    for (int i = 0; i < vert.size(); i++) {
      vertToTri.add(new java.util.ArrayList<Integer>());
    }
    for (int itri = 0; itri < tri.size(); itri++) {
      int[] T = tri.get(itri);
      for (int node = 0; node < 3; node++) {
        int v = T[node];
        while (v >= vertToTri.size()) {
          vertToTri.add(new java.util.ArrayList<Integer>());
        }
        vertToTri.get(v).add(Integer.valueOf(itri));
      }
    }
  }

  java.util.ArrayList<int[]> getEdgeIntersections(int iedge) {
    int edgeV0 = conEdge.get(iedge)[0];
    int edgeV1 = conEdge.get(iedge)[1];
    GPoint[] edgeCoords = {vert.get(edgeV0), vert.get(edgeV1)};
    java.util.ArrayList<Integer> tAround0 = vertToTri.get(edgeV0);
    boolean edgeInT = false;
    java.util.ArrayList<int[]> intersections = new java.util.ArrayList<int[]>();
    for (int k = 0; k < tAround0.size(); k++) {
      int tIdx = tAround0.get(k).intValue();
      int[] curT = tri.get(tIdx);
      int v0n = indexInTri(curT, edgeV0);
      int v0p1 = (v0n + 1) % 3, v0p2 = (v0n + 2) % 3;
      if (edgeV1 == curT[v0p1]) { edgeInT = true; break; }
      if (edgeV1 == curT[v0p2]) { edgeInT = true; break; }
      GPoint[] opp = {vert.get(curT[v0p1]), vert.get(curT[v0p2])};
      if (isEdgeIntersecting(edgeCoords, opp)) {
        intersections.add(new int[] {tIdx, v0n});
        break;
      }
    }
    if (!edgeInT) {
      if (intersections.isEmpty()) {
        throw new RuntimeException("Cannot have no intersections!");
      }
      while (true) {
        int[] prev = intersections.get(intersections.size() - 1);
        int tInd = adj.get(prev[0])[prev[1]];
        int[] tr = tri.get(tInd);
        if (tr[0] == edgeV1 || tr[1] == edgeV1 || tr[2] == edgeV1) break;
        int prevE = indexOf(adj.get(tInd), prev[0]);
        if (prevE < 0) throw new RuntimeException("Could not find edge");
        boolean found = false;
        for (int offset = 1; offset < 3; offset++) {
          int n0 = (prevE + offset + 1) % 3;
          int n1 = (prevE + offset + 2) % 3;
          GPoint[] cec = {vert.get(tr[n0]), vert.get(tr[n1])};
          if (isEdgeIntersecting(edgeCoords, cec)) {
            intersections.add(new int[] {tInd, (prevE + offset) % 3});
            found = true;
            break;
          }
        }
        if (!found) break;
      }
    }
    return intersections;
  }

  void fixEdgeIntersections(java.util.ArrayList<int[]> intersectionList, int conInd, java.util.ArrayList<int[]> newEdgeList) {
    int[] conN = conEdge.get(conInd);
    GPoint[] cec = {vert.get(conN[0]), vert.get(conN[1])};
    int nI = intersectionList.size();
    for (int i = 0; i < nI; i++) {
      int idx = nI - 1 - i;
      int tri0 = intersectionList.get(idx)[0];
      int tri0n = intersectionList.get(idx)[1];
      int tri1 = adj.get(tri0)[tri0n];
      int tri1n = indexOf(adj.get(tri1), tri0);
      GPoint q0 = vert.get(tri.get(tri0)[tri0n]);
      GPoint q1 = vert.get(tri.get(tri0)[(tri0n + 1) % 3]);
      GPoint q2 = vert.get(tri.get(tri1)[tri1n]);
      GPoint q3 = vert.get(tri.get(tri0)[(tri0n + 2) % 3]);
      if (isQuadConvex(q0, q1, q2, q3)) {
        swapDiagonal(tri0, tri1);
        int[] d = {tri.get(tri0)[tri0n], tri.get(tri1)[tri1n]};
        GPoint[] ndc = {q0, q2};
        boolean hasCommon = (d[0] == conN[0] || d[0] == conN[1] || d[1] == conN[0] || d[1] == conN[1]);
        if (hasCommon || !isEdgeIntersecting(cec, ndc)) {
          newEdgeList.add(d);
        }
      }
    }
  }

  void calcGraphStructure() {
    for (int idx = 0; idx < vert.size(); ++idx) {
      vertProps.get(idx).adj.clear();
    }
    for (int[] T : tri) {
      for (int a = 0; a < 3; a++) {
        for (int b = 0; b < 3; b++) {
          if (a == b) continue;
          if (!vertProps.get(T[a]).adj.contains(T[b])) {
            vertProps.get(T[a]).adj.add(T[b]);
          }
        }
      }
    }
    for (int idx = 0; idx < vert.size(); ++idx) {
      GPoint cen = vert.get(idx);
      java.util.ArrayList<Integer> nbrs = vertProps.get(idx).adj;
      final GPoint c = cen;
      final java.util.ArrayList<GPoint> vlist = vert;
      nbrs.sort((v1, v2) -> {
        GPoint p = vlist.get(v1).sub(c);
        GPoint q = vlist.get(v2).sub(c);
        return Float.compare(atan2(p.y, p.x), atan2(q.y, q.x));
      });
    }
  }

  void calcCirclePacking() {
    // Match JS semantics (doubles). float is too imprecise for tolerance 1+1e-11.
    final double tolerance = 1.0 + 1e-11;
    java.util.HashMap<Integer, java.util.ArrayList<Integer>> internal = new java.util.HashMap<Integer, java.util.ArrayList<Integer>>();
    java.util.HashSet<Integer> externalSet = new java.util.HashSet<Integer>();
    for (int idx = 0; idx < vert.size(); ++idx) {
      if (vertProps.get(idx).boundary) {
        externalSet.add(Integer.valueOf(idx));
      } else {
        internal.put(Integer.valueOf(idx), new java.util.ArrayList<Integer>(vertProps.get(idx).adj));
      }
    }
    if (internal.isEmpty()) return;
    java.util.HashMap<Integer, Double> radii = new java.util.HashMap<Integer, Double>();
    Double ONE = Double.valueOf(1.0);
    for (Integer e : externalSet) radii.put(e, ONE);
    for (Integer k : internal.keySet()) radii.put(k, ONE);
    double lastChange = 2.0;
    int iter = 0;
    final int MAX_ITER = 2000;
    while (lastChange > tolerance && iter < MAX_ITER) {
      lastChange = 1.0;
      for (Integer k : internal.keySet()) {
        java.util.ArrayList<Integer> ring = internal.get(k);
        if (ring == null || ring.isEmpty()) continue;
        int len = ring.size();
        double rad = radii.get(k).doubleValue();
        double theta = 0.0;
        for (int i = 0; i < len; ++i) {
          int a = ring.get(i).intValue();
          int b = ring.get((i + 1) % len).intValue();
          Double raF = radii.get(Integer.valueOf(a));
          Double rbbF = radii.get(Integer.valueOf(b));
          if (raF == null || rbbF == null) continue;
          theta += acxyzD(rad, raF.doubleValue(), rbbF.doubleValue());
        }
        double hat = rad / (1.0 / Math.sin(theta / (2.0 * len)) - 1.0);
        double newrad = hat * (1.0 / Math.sin(Math.PI / len) - 1.0);
        if (Double.isNaN(newrad) || Double.isInfinite(newrad) || newrad <= 0) continue;
        double kc = Math.max(newrad / rad, rad / newrad);
        if (kc > lastChange) lastChange = kc;
        radii.put(k, Double.valueOf(newrad));
      }
      iter++;
    }
    if (DEBUG_LOG) println("      [MESH] circlePack iterations=" + iter + " lastChange=" + lastChange);
    Integer k1 = internal.keySet().iterator().next();
    java.util.HashMap<Integer, GPoint> placements = new java.util.HashMap<Integer, GPoint>();
    placements.put(k1, new GPoint(0, 0));
    int k2 = vertProps.get(k1).adj.get(0);
    placements.put(k2, new GPoint((float)(radii.get(k1).doubleValue() + radii.get(Integer.valueOf(k2)).doubleValue()), 0.0f));
    placePacking(placements, radii, internal, k1);
    placePacking(placements, radii, internal, k2);
    for (Integer k : placements.keySet()) {
      int ki = k.intValue();
      vertProps.get(ki).center = placements.get(k);
      vertProps.get(ki).radius = radii.get(k).floatValue();
    }
  }

  void placePacking(
    java.util.HashMap<Integer, GPoint> placements,
    java.util.HashMap<Integer, Double> radii,
    java.util.HashMap<Integer, java.util.ArrayList<Integer>> internal,
    int center) {
    Integer cKey = center;
    if (!internal.containsKey(cKey)) return;
    java.util.ArrayList<Integer> cycle = internal.get(cKey);
    if (cycle == null) return;
    int len = cycle.size();
    for (int i = -len; i < len - 1; ++i) {
      int s = cycle.get((i + len) % len).intValue();
      int t = cycle.get((i + 1 + len) % len).intValue();
      if (placements.containsKey(s) && !placements.containsKey(t)) {
        double th = acxyzD(radii.get(cKey).doubleValue(), radii.get(Integer.valueOf(s)).doubleValue(), radii.get(Integer.valueOf(t)).doubleValue());
        GPoint off = placements.get(s).sub(placements.get(cKey)).scale((float)(1.0 / (radii.get(Integer.valueOf(s)).doubleValue() + radii.get(cKey).doubleValue())));
        double cang = Math.cos(-th);
        double sang = Math.sin(-th);
        float ox = (float)(cang * off.x - sang * off.y);
        float oy = (float)(sang * off.x + cang * off.y);
        GPoint nOff = new GPoint(ox, oy);
        GPoint p = placements.get(cKey).add(nOff.scale((float)(radii.get(Integer.valueOf(t)).doubleValue() + radii.get(cKey).doubleValue())));
        placements.put(t, p);
        placePacking(placements, radii, internal, t);
      }
    }
  }

  double acxyzD(double x, double y, double z) {
    double den = (2.0 * (x + y) * (x + z));
    if (Math.abs(den) < 1e-20) return 0.0;
    double r = ((x + y) * (x + y) + (x + z) * (x + z) - (y + z) * (y + z)) / den;
    if (r < -1.0) r = -1.0;
    else if (r > 1.0) r = 1.0;
    return Math.acos(r);
  }
}
