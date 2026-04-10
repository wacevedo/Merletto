/**
 * PortolanEngine V2 - Generative Mesh System
 * Template #1: Venice Major Churches
 * 
 * A Delaunay triangulation-based generative mesh tool with step-by-step visualization.
 * Uses iterative point insertion (not subdivision) for organic mesh growth.
 * 
 * Controls:
 *   Mouse Click - Advance state / Continue growth (in state 6)
 *   'r' - Reset to initial state
 *   'c' - Toggle circumcircle display
 *   's' - Save current frame
 */

// ============================================================================
// GLOBAL STATE
// ============================================================================

int state = 0;
int maxState = 7;
int growthIterations = 0;
int maxGrowthIterations = 8;
boolean showCircumcircles = false;

PImage mapImg;
MeshEngine engine;

// Visual parameters
color bgColor = color(255);
color gridColor = color(200, 200, 200, 80);
color pointColor = color(180, 60, 60);
color edgeColor = color(40, 40, 40);
color circumColor = color(100, 150, 200, 60);
color highlightColor = color(255, 220, 180, 40);

float gridSpacing = 50;
float pointRadius = 6;
float edgeWeight = 0.8;

// ============================================================================
// SETUP & DRAW
// ============================================================================

void setup() {
  size(1200, 800);
  smooth(8);
  
  mapImg = loadImage("data/map.png");
  
  engine = new MeshEngine();
  engine.initialize();
}

void draw() {
  background(bgColor);
  
  switch(state) {
    case 0: drawState0(); break;
    case 1: drawState1(); break;
    case 2: drawState2(); break;
    case 3: drawState3(); break;
    case 4: drawState4(); break;
    case 5: drawState5(); break;
    case 6: drawState6(); break;
    case 7: drawState7(); break;
  }
  
  drawStateInfo();
}

// ============================================================================
// STATE DRAWING FUNCTIONS
// ============================================================================

// STATE 0: Map + base grid
void drawState0() {
  drawMap();
  drawGrid();
}

// STATE 1: Venice selection highlight
void drawState1() {
  drawMap();
  drawGrid();
  drawSelectionHighlight();
}

// STATE 2: Show 5 main points
void drawState2() {
  drawMap();
  drawGrid();
  drawSelectionHighlight();
  drawPoints(engine.mesh.points, pointColor, pointRadius);
}

// STATE 3: Initial triangulation
void drawState3() {
  drawMap();
  drawGrid();
  drawMesh(engine.mesh);
  drawPoints(engine.mesh.points, pointColor, pointRadius);
}

// STATE 4: Circumcircles visible
void drawState4() {
  drawMap();
  drawGrid();
  drawCircumcircles(engine.mesh);
  drawMesh(engine.mesh);
  drawPoints(engine.mesh.points, pointColor, pointRadius);
}

// STATE 5: Growth initialization (first iteration)
void drawState5() {
  drawMap();
  drawGrid();
  if (showCircumcircles) drawCircumcircles(engine.mesh);
  drawMesh(engine.mesh);
  drawPoints(engine.mesh.points, pointColor, pointRadius);
}

// STATE 6: Progressive growth
void drawState6() {
  drawMap();
  drawGrid();
  if (showCircumcircles) drawCircumcircles(engine.mesh);
  drawMesh(engine.mesh);
  drawPoints(engine.mesh.points, pointColor, pointRadius * 0.7);
}

// STATE 7: Final mesh
void drawState7() {
  drawMap();
  drawMeshFinal(engine.mesh);
  drawPoints(engine.mesh.points, color(100, 100, 100), pointRadius * 0.4);
}

// ============================================================================
// DRAWING HELPERS
// ============================================================================

void drawMap() {
  if (mapImg != null) {
    pushStyle();
    tint(255, 180);
    imageMode(CENTER);
    
    float scale = min((float)width / mapImg.width, (float)height / mapImg.height);
    float imgW = mapImg.width * scale;
    float imgH = mapImg.height * scale;
    
    image(mapImg, width/2, height/2, imgW, imgH);
    popStyle();
  }
}

void drawGrid() {
  pushStyle();
  stroke(gridColor);
  strokeWeight(0.5);
  
  for (float x = 0; x < width; x += gridSpacing) {
    line(x, 0, x, height);
  }
  for (float y = 0; y < height; y += gridSpacing) {
    line(0, y, width, y);
  }
  popStyle();
}

void drawSelectionHighlight() {
  pushStyle();
  noStroke();
  fill(highlightColor);
  
  float cx = width * 0.52;
  float cy = height * 0.52;
  float w = width * 0.5;
  float h = height * 0.6;
  
  ellipse(cx, cy, w, h);
  popStyle();
}

void drawPoints(ArrayList<Point> points, color c, float radius) {
  pushStyle();
  fill(c);
  noStroke();
  
  for (Point p : points) {
    ellipse(p.x, p.y, radius * 2, radius * 2);
  }
  popStyle();
}

void drawMesh(Mesh mesh) {
  pushStyle();
  stroke(edgeColor);
  strokeWeight(edgeWeight);
  noFill();
  
  for (Triangle t : mesh.triangles) {
    if (!t.isSuperTriangle) {
      line(t.a.x, t.a.y, t.b.x, t.b.y);
      line(t.b.x, t.b.y, t.c.x, t.c.y);
      line(t.c.x, t.c.y, t.a.x, t.a.y);
    }
  }
  popStyle();
}

void drawMeshFinal(Mesh mesh) {
  pushStyle();
  stroke(edgeColor, 200);
  strokeWeight(0.6);
  noFill();
  
  for (Triangle t : mesh.triangles) {
    if (!t.isSuperTriangle) {
      beginShape();
      vertex(t.a.x, t.a.y);
      vertex(t.b.x, t.b.y);
      vertex(t.c.x, t.c.y);
      endShape(CLOSE);
    }
  }
  popStyle();
}

void drawCircumcircles(Mesh mesh) {
  pushStyle();
  stroke(circumColor);
  strokeWeight(0.5);
  noFill();
  
  for (Triangle t : mesh.triangles) {
    if (!t.isSuperTriangle) {
      Point cc = t.circumcenter();
      float r = t.circumRadius();
      if (r < 500) {
        ellipse(cc.x, cc.y, r * 2, r * 2);
      }
    }
  }
  popStyle();
}

void drawStateInfo() {
  pushStyle();
  fill(80);
  textSize(12);
  textAlign(LEFT, TOP);
  
  String info = "State: " + state + "/" + maxState;
  if (state == 6) {
    info += "  |  Growth: " + growthIterations + "/" + maxGrowthIterations;
  }
  info += "  |  Points: " + engine.mesh.points.size();
  info += "  |  Triangles: " + engine.mesh.countValidTriangles();
  
  text(info, 10, 10);
  
  textAlign(LEFT, BOTTOM);
  text("Click: advance  |  'r': reset  |  'c': circumcircles  |  's': save", 10, height - 10);
  popStyle();
}

// ============================================================================
// INTERACTION
// ============================================================================

void mousePressed() {
  if (state < maxState) {
    state++;
    onStateEnter(state);
  } else if (state == 6 && growthIterations < maxGrowthIterations) {
    engine.growthEngine.iterate();
    growthIterations++;
  }
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    resetAll();
  } else if (key == 'c' || key == 'C') {
    showCircumcircles = !showCircumcircles;
  } else if (key == 's' || key == 'S') {
    saveFrame("output/frame-####.png");
  }
}

void onStateEnter(int newState) {
  switch(newState) {
    case 3:
      engine.computeTriangulation();
      break;
    case 5:
      engine.growthEngine.iterate();
      growthIterations = 1;
      break;
    case 6:
      break;
    case 7:
      showCircumcircles = false;
      break;
  }
}

void resetAll() {
  state = 0;
  growthIterations = 0;
  showCircumcircles = false;
  engine.initialize();
}

// ============================================================================
// POINT CLASS
// ============================================================================

class Point {
  float x, y;
  int id;
  String name;
  
  Point(float x, float y) {
    this.x = x;
    this.y = y;
    this.id = -1;
    this.name = "";
  }
  
  Point(float x, float y, int id, String name) {
    this.x = x;
    this.y = y;
    this.id = id;
    this.name = name;
  }
  
  float distanceTo(Point other) {
    return dist(this.x, this.y, other.x, other.y);
  }
  
  boolean equals(Point other) {
    return abs(this.x - other.x) < 0.001 && abs(this.y - other.y) < 0.001;
  }
  
  Point copy() {
    return new Point(this.x, this.y, this.id, this.name);
  }
}

// ============================================================================
// EDGE CLASS
// ============================================================================

class Edge {
  Point a, b;
  
  Edge(Point a, Point b) {
    this.a = a;
    this.b = b;
  }
  
  float length() {
    return a.distanceTo(b);
  }
  
  Point midpoint() {
    return new Point((a.x + b.x) / 2, (a.y + b.y) / 2);
  }
  
  boolean equals(Edge other) {
    return (a.equals(other.a) && b.equals(other.b)) || 
           (a.equals(other.b) && b.equals(other.a));
  }
  
  boolean sharesVertex(Edge other) {
    return a.equals(other.a) || a.equals(other.b) || 
           b.equals(other.a) || b.equals(other.b);
  }
}

// ============================================================================
// TRIANGLE CLASS
// ============================================================================

class Triangle {
  Point a, b, c;
  boolean isSuperTriangle;
  
  Triangle(Point a, Point b, Point c) {
    this.a = a;
    this.b = b;
    this.c = c;
    this.isSuperTriangle = false;
  }
  
  Point centroid() {
    return new Point((a.x + b.x + c.x) / 3, (a.y + b.y + c.y) / 3);
  }
  
  float area() {
    return abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2;
  }
  
  Point circumcenter() {
    float ax = a.x, ay = a.y;
    float bx = b.x, by = b.y;
    float cx = c.x, cy = c.y;
    
    float d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    
    if (abs(d) < 0.0001) {
      return centroid();
    }
    
    float ux = ((ax * ax + ay * ay) * (by - cy) + 
                (bx * bx + by * by) * (cy - ay) + 
                (cx * cx + cy * cy) * (ay - by)) / d;
    float uy = ((ax * ax + ay * ay) * (cx - bx) + 
                (bx * bx + by * by) * (ax - cx) + 
                (cx * cx + cy * cy) * (bx - ax)) / d;
    
    return new Point(ux, uy);
  }
  
  float circumRadius() {
    Point cc = circumcenter();
    return cc.distanceTo(a);
  }
  
  ArrayList<Edge> getEdges() {
    ArrayList<Edge> edges = new ArrayList<Edge>();
    edges.add(new Edge(a, b));
    edges.add(new Edge(b, c));
    edges.add(new Edge(c, a));
    return edges;
  }
  
  boolean containsVertex(Point p) {
    return a.equals(p) || b.equals(p) || c.equals(p);
  }
  
  boolean isPointInCircumcircle(Point p) {
    Point cc = circumcenter();
    float r = circumRadius();
    return p.distanceTo(cc) < r;
  }
}

// ============================================================================
// MESH CLASS
// ============================================================================

class Mesh {
  ArrayList<Point> points;
  ArrayList<Triangle> triangles;
  
  Mesh() {
    points = new ArrayList<Point>();
    triangles = new ArrayList<Triangle>();
  }
  
  void addPoint(Point p) {
    for (Point existing : points) {
      if (existing.equals(p)) return;
    }
    points.add(p);
  }
  
  void addTriangle(Triangle t) {
    triangles.add(t);
  }
  
  void clear() {
    points.clear();
    triangles.clear();
  }
  
  void clearTriangles() {
    triangles.clear();
  }
  
  int countValidTriangles() {
    int count = 0;
    for (Triangle t : triangles) {
      if (!t.isSuperTriangle) count++;
    }
    return count;
  }
  
  ArrayList<Edge> getAllEdges() {
    ArrayList<Edge> edges = new ArrayList<Edge>();
    for (Triangle t : triangles) {
      if (!t.isSuperTriangle) {
        for (Edge e : t.getEdges()) {
          boolean exists = false;
          for (Edge existing : edges) {
            if (existing.equals(e)) {
              exists = true;
              break;
            }
          }
          if (!exists) edges.add(e);
        }
      }
    }
    return edges;
  }
}

// ============================================================================
// DELAUNAY ENGINE (Bowyer-Watson Algorithm)
// ============================================================================

class DelaunayEngine {
  Mesh mesh;
  Triangle superTriangle;
  
  DelaunayEngine(Mesh mesh) {
    this.mesh = mesh;
  }
  
  void triangulate() {
    mesh.clearTriangles();
    
    if (mesh.points.size() < 3) return;
    
    createSuperTriangle();
    mesh.addTriangle(superTriangle);
    
    for (Point p : mesh.points) {
      insertPoint(p);
    }
    
    removeSuperTriangleVertices();
  }
  
  void createSuperTriangle() {
    float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
    float maxX = Float.MIN_VALUE, maxY = Float.MIN_VALUE;
    
    for (Point p : mesh.points) {
      minX = min(minX, p.x);
      minY = min(minY, p.y);
      maxX = max(maxX, p.x);
      maxY = max(maxY, p.y);
    }
    
    float dx = (maxX - minX) * 2;
    float dy = (maxY - minY) * 2;
    float deltaMax = max(dx, dy);
    
    float midX = (minX + maxX) / 2;
    float midY = (minY + maxY) / 2;
    
    Point p1 = new Point(midX - deltaMax * 2, midY - deltaMax);
    Point p2 = new Point(midX, midY + deltaMax * 2);
    Point p3 = new Point(midX + deltaMax * 2, midY - deltaMax);
    
    superTriangle = new Triangle(p1, p2, p3);
    superTriangle.isSuperTriangle = true;
  }
  
  void insertPoint(Point p) {
    ArrayList<Triangle> badTriangles = new ArrayList<Triangle>();
    
    for (Triangle t : mesh.triangles) {
      if (t.isPointInCircumcircle(p)) {
        badTriangles.add(t);
      }
    }
    
    ArrayList<Edge> polygon = new ArrayList<Edge>();
    
    for (Triangle t : badTriangles) {
      for (Edge e : t.getEdges()) {
        boolean isShared = false;
        for (Triangle other : badTriangles) {
          if (t != other) {
            for (Edge otherEdge : other.getEdges()) {
              if (e.equals(otherEdge)) {
                isShared = true;
                break;
              }
            }
          }
          if (isShared) break;
        }
        if (!isShared) {
          polygon.add(e);
        }
      }
    }
    
    for (Triangle t : badTriangles) {
      mesh.triangles.remove(t);
    }
    
    for (Edge e : polygon) {
      Triangle newTri = new Triangle(e.a, e.b, p);
      mesh.addTriangle(newTri);
    }
  }
  
  void removeSuperTriangleVertices() {
    ArrayList<Triangle> toRemove = new ArrayList<Triangle>();
    
    for (Triangle t : mesh.triangles) {
      if (t.containsVertex(superTriangle.a) ||
          t.containsVertex(superTriangle.b) ||
          t.containsVertex(superTriangle.c)) {
        toRemove.add(t);
      }
    }
    
    for (Triangle t : toRemove) {
      mesh.triangles.remove(t);
    }
  }
}

// ============================================================================
// GROWTH ENGINE
// ============================================================================

class GrowthEngine {
  Mesh mesh;
  DelaunayEngine delaunay;
  
  float minEdgeLength = 30;
  float minTriangleArea = 400;
  float maxEdgeForMidpoint = 150;
  
  GrowthEngine(Mesh mesh, DelaunayEngine delaunay) {
    this.mesh = mesh;
    this.delaunay = delaunay;
  }
  
  void iterate() {
    ArrayList<Point> newPoints = new ArrayList<Point>();
    
    for (Triangle t : mesh.triangles) {
      if (t.isSuperTriangle) continue;
      
      float area = t.area();
      if (area < minTriangleArea) continue;
      
      Point centroid = t.centroid();
      if (isValidNewPoint(centroid, newPoints)) {
        newPoints.add(centroid);
      }
      
      Point circumcenter = t.circumcenter();
      if (area > minTriangleArea * 2) {
        if (isValidNewPoint(circumcenter, newPoints) && isInsideBounds(circumcenter)) {
          newPoints.add(circumcenter);
        }
      }
    }
    
    ArrayList<Edge> edges = mesh.getAllEdges();
    for (Edge e : edges) {
      float len = e.length();
      if (len > maxEdgeForMidpoint) {
        Point mid = e.midpoint();
        if (isValidNewPoint(mid, newPoints)) {
          newPoints.add(mid);
        }
      }
    }
    
    for (Point p : newPoints) {
      mesh.addPoint(p);
    }
    
    delaunay.triangulate();
    
    updateThresholds();
  }
  
  boolean isValidNewPoint(Point p, ArrayList<Point> pending) {
    for (Point existing : mesh.points) {
      if (existing.distanceTo(p) < minEdgeLength) {
        return false;
      }
    }
    
    for (Point pend : pending) {
      if (pend.distanceTo(p) < minEdgeLength) {
        return false;
      }
    }
    
    return isInsideBounds(p);
  }
  
  boolean isInsideBounds(Point p) {
    float margin = 50;
    return p.x > margin && p.x < width - margin && 
           p.y > margin && p.y < height - margin;
  }
  
  void updateThresholds() {
    minEdgeLength *= 0.85;
    minTriangleArea *= 0.7;
    maxEdgeForMidpoint *= 0.8;
    
    minEdgeLength = max(minEdgeLength, 10);
    minTriangleArea = max(minTriangleArea, 50);
    maxEdgeForMidpoint = max(maxEdgeForMidpoint, 40);
  }
}

// ============================================================================
// MESH ENGINE (Main Orchestrator)
// ============================================================================

class MeshEngine {
  Mesh mesh;
  DelaunayEngine delaunayEngine;
  GrowthEngine growthEngine;
  
  ArrayList<Point> initialPoints;
  
  MeshEngine() {
    mesh = new Mesh();
    delaunayEngine = new DelaunayEngine(mesh);
    growthEngine = new GrowthEngine(mesh, delaunayEngine);
    initialPoints = new ArrayList<Point>();
    
    defineInitialPoints();
  }
  
  void defineInitialPoints() {
    initialPoints.clear();
    
    // Five major churches of Venice (coordinates adjusted for 1200x800 canvas)
    // Original coordinates were for a smaller canvas, scaling to fit
    float scaleX = 1.15;
    float scaleY = 1.0;
    float offsetX = 0;
    float offsetY = 0;
    
    // San Marco Basilica
    initialPoints.add(new Point(
      540 * scaleX + offsetX, 
      335 * scaleY + offsetY, 
      0, "San Marco Basilica"
    ));
    
    // Santa Maria della Salute
    initialPoints.add(new Point(
      625 * scaleX + offsetX, 
      399 * scaleY + offsetY, 
      1, "Santa Maria della Salute"
    ));
    
    // San Giorgio Maggiore
    initialPoints.add(new Point(
      548 * scaleX + offsetX, 
      488 * scaleY + offsetY, 
      2, "San Giorgio Maggiore"
    ));
    
    // Chiesa del Santissimo Redentore
    initialPoints.add(new Point(
      450 * scaleX + offsetX, 
      565 * scaleY + offsetY, 
      3, "Il Redentore"
    ));
    
    // San Pietro di Castello (eastern Venice)
    initialPoints.add(new Point(
      850 * scaleX + offsetX, 
      340 * scaleY + offsetY, 
      4, "San Pietro di Castello"
    ));
  }
  
  void initialize() {
    mesh.clear();
    
    for (Point p : initialPoints) {
      mesh.addPoint(p.copy());
    }
    
    growthEngine.minEdgeLength = 30;
    growthEngine.minTriangleArea = 400;
    growthEngine.maxEdgeForMidpoint = 150;
  }
  
  void computeTriangulation() {
    delaunayEngine.triangulate();
  }
}
