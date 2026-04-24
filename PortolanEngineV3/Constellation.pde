// constelation/patch.js — pattern layer (PattC, CycP, Pent, build3Patch, helpers)

interface EmitSeg { void add(GPoint a, GPoint b); }

final float PC_CONTACT = 1.3f, PC_STAR = 4.0f;

GPoint pcC(PattC a, PattC b) { float s = a.d + b.d, t = s==0?0.5f:a.d/s; return new GPoint(lerp(a.x, b.x, t), lerp(a.y, b.y, t)); }
GPoint pcM(GPoint a, GPoint b) { return new GPoint(lerp(a.x, b.x, 0.5f), lerp(a.y, b.y, 0.5f)); }
GPoint pcE(GPoint o, PVector d, float sc) { return new GPoint(o.x + d.x * sc, o.y + d.y * sc); }
GPoint pcB(float cx, float cy, PVector u, PVector w, float sc) {
  PVector b = u.copy(); float an = PVector.angleBetween(u, w);
  if (!Float.isFinite(an) || b.magSq() == 0) { if (b.magSq() != 0) { b.setMag(sc); return new GPoint(cx + b.x, cy + b.y);} return new GPoint(cx, cy); }
  b.rotate(an / 2.0f); b.mult(sc); return new GPoint(cx + b.x, cy + b.y);
}
int pcW(int i, int s) { return (i + s) % s; }
PVector pcRot(PVector v, float a) { PVector c = v.copy(); rotate2D(c, a); return c; }

void pcPop(Mesh m, java.util.HashMap<Integer, PattC> R) {
  for (int t = 0; t < m.tri.size(); t++) {
    int[] T = m.tri.get(t);
    PattC a = R.get(T[0]), b = R.get(T[1]), c = R.get(T[2]);
    if (a==null||b==null||c==null) continue;
    if (a.bd||b.bd||c.bd) { a.on=b.on=c.on=false; }
    GPoint t0 = pcC(a, b); a.ix.put(T[1], t0); b.ix.put(T[0], t0);
    GPoint t1 = pcC(a, c); a.ix.put(T[2], t1); c.ix.put(T[0], t1);
    GPoint t2 = pcC(b, c); b.ix.put(T[2], t2); c.ix.put(T[1], t2);
  }
}

class PnB { CycP p; int k; PnB(CycP p, int k) { this.p = p; this.k = k; } }

class PattC { int id; float x, y, d; boolean bd; int col; java.util.HashMap<Integer, GPoint> ix; CycP g; boolean on;
  PattC(int i, float x, float y, float d0, boolean b, int c) { id=i; this.x=x; this.y=y; d=d0; bd=b; col=c; ix=new java.util.HashMap<Integer, GPoint>(); g=null; on=true; }
  void bPoly(float tau, java.util.HashMap<Integer, CycP> R) {
    java.util.ArrayList<GPoint> C = new java.util.ArrayList<GPoint>(ix.values());
    if (C.size() < 2) { g = null; return; }
    sortGPointsByAngle(C, x, y);
    java.util.ArrayList<GPoint> V = new java.util.ArrayList<GPoint>();
    for (int i = 0; i < C.size(); i++) {
      GPoint n = C.get((i + 1) % C.size());
      PVector u = new PVector(C.get(i).x - x, C.get(i).y - y);
      PVector w = new PVector(n.x - x, n.y - y);
      u.mult(tau); w.mult(tau);
      V.add(new GPoint(x + u.x, y + u.y));
      u.rotate(PVector.angleBetween(u, w) / 2.0f);
      V.add(new GPoint(x + u.x, y + u.y));
    }
    g = new CycP(id, x, y, d * tau, V, on);
    R.put(id, g);
  }
}
class CycP { int id; float x, y, sc; java.util.ArrayList<GPoint> v; int n; boolean on; PVector[][] ca;
  CycP(int i, float cx, float cy, float r, java.util.ArrayList<GPoint> V, boolean a) {
    id = i; x = cx; y = cy; sc = r; v = V; n = v.size(); on = a; ca = new PVector[n][2];
  }
  int vIx(GPoint p) { for (int i=0;i<n;i++) if (PApplet.dist(p.x, p.y, v.get(i).x, v.get(i).y) < 0.12f) return i; return -1; }
  void cE(float L, EmitSeg o) { if (!on) return; for (Cnx q : cF(L)) for (GPoint[] s : q.sg) o.add(s[0], s[1]); }
  class Cnx { GPoint[][] sg; Cnx(GPoint[][] a) { sg = a; } }
  class CnxL extends java.util.ArrayList<Cnx> { }
  CnxL cF(float L) { CnxL F = new CnxL(); if (n==0) return F; for (int i=0;i<n;i++) { ca[i][0]=null; ca[i][1]=null; }
    int cnt = n;
    for (int i=0;i<cnt;i++) {
      GPoint m0=pcM(v.get(pcW(i-1,cnt)), v.get(i)), m1=pcM(v.get(i), v.get(pcW(i+1,cnt)));
      GPoint m2=pcM(v.get(pcW(i+1,cnt)), v.get(pcW(i+2,cnt))), m3=pcM(v.get(pcW(i+2,cnt)), v.get(pcW(i+3,cnt)));
      PVector g0 = new PVector(m0.x-x, m0.y-y), g1 = new PVector(m1.x-x, m1.y-y);
      PVector g2 = new PVector(m2.x-x, m2.y-y), g3 = new PVector(m3.x-x, m3.y-y);
      GPoint p13=pcB(x,y,g1,g3,L), p02=pcB(x,y,g0,g2,L);
      GPoint in=intersectLines(m1, p13, m2, p02);
      ca[i][0]=new PVector(m1.x-p13.x, m1.y-p13.y);
      ca[pcW(i+2,cnt)][1]=new PVector(m3.x-p13.x, m3.y-p13.y);
      F.add(new Cnx(new GPoint[][] { {m1, in}, {in, p13}, {m2, in}, {in, p02} } ));
    } return F; }
  void dM(PApplet p, float L) { if (!on) return; p.pushStyle(); p.stroke(220, 90, 80); p.noFill(); cE(L, (a, b) -> p.line(a.x, a.y, b.x, b.y)); p.popStyle(); }
  void dT(PApplet p) { if (!on) return; p.pushStyle(); p.stroke(0, 155, 170); p.noFill(); p.beginShape(); for (GPoint q : v) p.vertex(q.x, q.y); p.endShape(PApplet.CLOSE); p.popStyle(); }
}
class Pent { GPoint[] s; PnB a, b; boolean in;
  Pent(GPoint[] t, PnB e1, PnB e2, boolean i) { s = t; a = e1; b = e2; in = i; }
  void cE(float L, EmitSeg o) { tN(o); }
  void tN(EmitSeg em) { if (!a.p.on && !b.p.on) return;
    if (!a.p.on) { PVector c1=pcRot(new PVector(s[3].x - s[2].x, s[3].y - s[2].y), -PC_CONTACT);
      if (b.p.ca==null || b.p.ca.length<=b.k || b.p.ca[b.k]==null || b.p.ca[b.k][1]==null) return;
      eJ(em, pcM(s[2], s[3]), c1, pcM(s[3], s[4]), b.p.ca[b.k][1]);
      eJ(em, pcM(s[3], s[4]), b.p.ca[b.k][0], pcM(s[0], s[4]), pcRot(new PVector(s[0].x - s[4].x, s[0].y - s[4].y), PC_CONTACT)); return; }
    if (!b.p.on) { PVector c1=pcRot(new PVector(s[1].x - s[0].x, s[1].y - s[0].y), -PC_CONTACT);
      if (a.p.ca==null || a.p.ca.length<=a.k || a.p.ca[a.k]==null || a.p.ca[a.k][1]==null) return;
      eJ(em, pcM(s[0], s[1]), c1, pcM(s[1], s[2]), a.p.ca[a.k][1]);
      eJ(em, pcM(s[1], s[2]), a.p.ca[a.k][0], pcM(s[2], s[3]), pcRot(new PVector(s[3].x - s[2].x, s[3].y - s[2].y), PC_CONTACT)); return; }
    int lim = in ? 5 : 4;
    PVector[][] sp = new PVector[5][];
    sp[0]=null; sp[1]=a.p.ca[a.k]; sp[2]=null; sp[3]=b.p.ca[b.k]; sp[4]=null;
    for (int i=0;i<lim;i++) {
      PVector c1 = (sp[i] != null) ? sp[i][0] : pcRot(new PVector(s[(i+1)%5].x - s[i].x, s[(i+1)%5].y - s[i].y), -PC_CONTACT);
      PVector c2 = (sp[(i+1)%5] != null) ? sp[(i+1)%5][1] : pcRot(new PVector(s[(i+1)%5].x - s[(i+2)%5].x, s[(i+1)%5].y - s[(i+2)%5].y), PC_CONTACT);
      eI(em, pcM(s[i], s[(i+1)%5]), c1, pcM(s[(i+1)%5], s[(i+2)%5]), c2);
    } }
  void eJ(EmitSeg em, GPoint p1, PVector d1, GPoint p2, PVector d2) { eI(em, p1, d1, p2, d2); }
  void eI(EmitSeg em, GPoint p1, PVector d1, GPoint p2, PVector d2) { GPoint e1=pcE(p1, d1, PC_STAR), e2=pcE(p2, d2, PC_STAR);
    GPoint z = intersectLines(p1, e1, p2, e2); em.add(p1, z); em.add(p2, z);
  } }

java.util.ArrayList<Pent> cB3(Mesh m, java.util.HashMap<Integer, PattC> R, java.util.HashMap<Integer, CycP> P, float tau) {
  java.util.ArrayList<Pent> L = new java.util.ArrayList<Pent>();
  for (int t = 0; t < m.tri.size(); t++) {
    int[] T = m.tri.get(t);
    int ai = T[0], bi = T[1], ci = T[2];
    PattC A = R.get(ai), B = R.get(bi), C = R.get(ci);
    if (A==null || B==null || C==null) continue; if (A.bd || B.bd || C.bd) continue;
    GPoint pAB = A.ix.get(bi), pAC = A.ix.get(ci), pBC = B.ix.get(ci);
    PVector abV = new PVector(pAB.x - A.x, pAB.y - A.y), acV = new PVector(pAC.x - A.x, pAC.y - A.y);
    abV.mult(tau); acV.mult(tau);
    GPoint aPrev = new GPoint(A.x + abV.x, A.y + abV.y), aPost = new GPoint(A.x + acV.x, A.y + acV.y);
    abV = new PVector(pAB.x - A.x, pAB.y - A.y); abV.mult(tau);
    acV = new PVector(pAC.x - A.x, pAC.y - A.y); acV.mult(tau);
    abV.rotate(PVector.angleBetween(abV, acV) / 2.0f);
    GPoint ap = new GPoint(A.x + abV.x, A.y + abV.y);
    PVector bba = new PVector(pAB.x - B.x, pAB.y - B.y);
    PVector bbc0 = new PVector(pBC.x - B.x, pBC.y - B.y);
    bba.mult(tau);
    bbc0.mult(tau);
    GPoint bPost = new GPoint(B.x + bba.x, B.y + bba.y);
    GPoint bPrev = new GPoint(B.x + bbc0.x, B.y + bbc0.y);
    PVector bbcR = bbc0.copy();
    bbcR.rotate(PVector.angleBetween(bbc0, bba) / 2.0f);
    GPoint bp = new GPoint(B.x + bbcR.x, B.y + bbcR.y);
    PVector cca = new PVector(pAC.x - C.x, pAC.y - C.y), ccb = new PVector(pBC.x - C.x, pBC.y - C.y);
    cca.mult(tau); ccb.mult(tau);
    GPoint cPrev = new GPoint(C.x + cca.x, C.y + cca.y), cPost = new GPoint(C.x + ccb.x, C.y + ccb.y);
    cca = new PVector(pAC.x - C.x, pAC.y - C.y); cca.mult(tau);
    ccb = new PVector(pBC.x - C.x, pBC.y - C.y); ccb.mult(tau);
    cca.rotate(PVector.angleBetween(cca, ccb) / 2.0f);
    GPoint cp = new GPoint(C.x + cca.x, C.y + cca.y);
    GPoint o = new GPoint((ap.x + bp.x + cp.x) / 3, (ap.y + bp.y + cp.y) / 3);
    CycP dA = A.g, dB = B.g, dC = C.g;
    if (dA==null || dB==null || dC==null) continue;
    int i = dA.vIx(ap), j = dB.vIx(bp), k = dC.vIx(cp);
    if (i<0 || j<0 || k<0) continue;
    int nA = dA.n, nB = dB.n, nC = dC.n;
    boolean in = dA.on && dB.on && dC.on;
    L.add(new Pent(new GPoint[] {o, ap, aPrev, bPost, bp}, new PnB(dA, (i-1+nA)%nA), new PnB(dB, j), in));
    L.add(new Pent(new GPoint[] {o, bp, bPrev, cPost, cp}, new PnB(dB, (j-1+nB)%nB), new PnB(dC, k), in));
    L.add(new Pent(new GPoint[] {o, cp, cPrev, aPost, ap}, new PnB(dC, (k-1+nC)%nC), new PnB(dA, i), in));
  } return L; }
