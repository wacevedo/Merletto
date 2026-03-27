/**
 * PORTOLAN ENGINE - Processing Version
 * Relational Grid Generator for Design
 * Meta-Merletto Veneziano - Pentagon Mesh Generator
 * 
 * Controls:
 * - Click to add nodes (free mode) or connect nodes (template mode)
 * - UP/DOWN: Connections per node | LEFT/RIGHT: Phi tension
 * - '[' / ']': Triangle threshold | '-' / '=': Pentagon radius
 * - 't': Toggle triangles | 'd': Toggle centroids | 'p': Toggle pentagons
 * - 'g': Generate pentagon mesh
 * - 'm': Toggle historic map (template mode only)
 * - 'c': Clear | 'e': Export JSON | 's': Save image
 * - DELETE/BACKSPACE: Remove last | ESC: Exit mode
 */

// === CONFIGURATION ===
int connectionsPerNode = 2;
float phiTension = 1.618;
boolean showHistoricMap = false;  // Disabled by default, only works in template mode

// === TEMPLATE MODE ===
boolean templateMode = false;
boolean showTemplateSelector = false;
int selectedTemplateIndex = -1;
int hoveredTemplateIndex = -1;
Node selectedNodeForConnection = null;
ArrayList<Connection> manualConnections;
String loadedTemplateName = "";
String loadedTemplateCategoryPath = "";  // Path to the template's category folder

// === TEMPLATE FILES ===
ArrayList<TemplateFile> templateFiles;
String templatesPath;
PImage currentPreviewImage = null;
PImage historicMapImage = null;  // Background map image for template mode

// === DATA STRUCTURES ===
ArrayList<Node> nodes;

// === TRIANGULATION & MESH (Phase 2-3) ===
ArrayList<PVector[]> triangles;      // Delaunay triangles
ArrayList<PVector> centroids;        // Triangle centroids
boolean showTriangles = true;        // Toggle triangle visibility
boolean showCentroids = true;        // Toggle centroid visibility
float triangleThreshold = 220;       // Max edge distance for triangles
color triangleColor = #3b82f680;     // Blue with alpha
color centroidColor = #ec489980;     // Pink/magenta

// === PENTAGON MESH (Phase 5-6) ===
ArrayList<PentagonCell> pentagonCells;  // Generated pentagon cells
boolean meshGenerated = false;          // Has mesh been generated?
boolean showPentagons = true;           // Toggle pentagon visibility
float pentagonRadius = 35;              // Base radius for pentagons
float deformationLevel = 0.15;          // Deformation amount (0 = regular, 0.3 = very organic)
boolean useDensityGradient = true;      // Adjust radius based on local density
color pentagonStroke = #f59e0b;         // Amber/gold stroke
color pentagonFill = #f59e0b10;         // Very transparent fill

// === COLORS (matching original design) ===
color bgColor = #0f172a;
color panelBg = #1e293b;
color nodeColor = #f97316;
color nodeGlow = #f9731630;
color lineColor = #f9731699;
color cellColor = #14b8a666;
color cellFill = #14b8a608;
color textColor = #f8fafc;
color accentColor = #f97316;
color tealColor = #14b8a6;
color disabledColor = #475569;
color selectedNodeColor = #22d3ee;
color modalBg = #0f172acc;

// === UI DIMENSIONS ===
int panelWidth = 320;
int canvasWidth;

// === FONTS ===
PFont fontBold;
PFont fontRegular;

// === UI POSITIONS ===
int sliderMargin = 24;
int selectFormBtnY = 72;
int connectionsSliderY = 195;
int phiSliderY = 257;
int thresholdSliderY = 319;
int checkboxY = 357;
int triangleCheckboxY = 395;
int centroidCheckboxY = 420;
int generateMeshBtnY = 470;
int pentagonRadiusSliderY = 520;
int deformationSliderY = 560;
int pentagonCheckboxY = 595;

void setup() {
  pixelDensity(1);
  size(1200, 800);
  smooth(8);
  
  fontBold = createFont("SansSerif.bold", 32);
  fontRegular = createFont("SansSerif", 32);
  
  canvasWidth = width - panelWidth;
  
  nodes = new ArrayList<Node>();
  manualConnections = new ArrayList<Connection>();
  templateFiles = new ArrayList<TemplateFile>();
  triangles = new ArrayList<PVector[]>();
  centroids = new ArrayList<PVector>();
  pentagonCells = new ArrayList<PentagonCell>();
  
  // Set templates path relative to sketch
  templatesPath = sketchPath("templates");
  
  // Scan for template files
  scanTemplateFiles();
}

void draw() {
  background(bgColor);
  
  drawCanvasArea();
  
  // Generate triangulation (updates every frame based on current nodes)
  if (nodes.size() >= 3) {
    generateDelaunayTriangles();
  }
  
  // Draw triangulation layer (Phase 2)
  if (showTriangles && triangles.size() > 0) {
    drawTriangles();
  }
  
  // Draw centroids layer (Phase 3)
  if (showCentroids && centroids.size() > 0) {
    drawCentroids();
  }
  
  // Draw pentagon mesh (Phase 5-6)
  if (meshGenerated && showPentagons && pentagonCells.size() > 0) {
    drawPentagonMesh();
  }
  
  if (templateMode) {
    // In template mode: draw auto-connections (if connectionsPerNode > 0) + manual connections
    if (connectionsPerNode > 0) {
      drawConnections();  // Auto-connect to N nearest neighbors
    }
    drawManualConnections();  // Plus any manual connections
  } else {
    drawConnections();
  }
  
  drawNodes();
  drawControlPanel();
  
  if (showTemplateSelector) {
    drawTemplateSelector();
  }
}

// === SCAN TEMPLATE FILES ===
void scanTemplateFiles() {
  templateFiles.clear();
  
  File templatesDir = new File(templatesPath);
  if (!templatesDir.exists()) {
    println("Templates directory not found: " + templatesPath);
    return;
  }
  
  // Iterate through category folders (e.g., "venesia")
  File[] categories = templatesDir.listFiles();
  if (categories == null) return;
  
  for (File category : categories) {
    if (category.isDirectory()) {
      File nodesDir = new File(category, "nodes");
      if (nodesDir.exists() && nodesDir.isDirectory()) {
        File[] jsonFiles = nodesDir.listFiles(new java.io.FilenameFilter() {
          public boolean accept(File dir, String name) {
            return name.toLowerCase().endsWith(".json");
          }
        });
        
        if (jsonFiles != null) {
          for (File jsonFile : jsonFiles) {
            try {
              JSONObject json = loadJSONObject(jsonFile.getAbsolutePath());
              String name = json.getString("name", jsonFile.getName());
              String imageName = json.getString("image", "");
              String imagePath = "";
              if (!imageName.isEmpty()) {
                imagePath = new File(nodesDir, imageName).getAbsolutePath();
              }
              templateFiles.add(new TemplateFile(
                name,
                jsonFile.getAbsolutePath(),
                imagePath,
                category.getName(),
                category.getAbsolutePath()  // Full path to category folder
              ));
            } catch (Exception e) {
              println("Error loading template: " + jsonFile.getName());
            }
          }
        }
      }
    }
  }
  
  println("Found " + templateFiles.size() + " templates");
}

// === CANVAS AREA ===
void drawCanvasArea() {
  fill(#0f172a);
  stroke(#334155);
  strokeWeight(1);
  rect(20, 20, canvasWidth - 40, height - 40, 16);
  
  // Show historic map background (only in template mode)
  if (templateMode && showHistoricMap && historicMapImage != null) {
    // Calculate scale to fit canvas while maintaining aspect ratio
    float canvasW = canvasWidth - 40;
    float canvasH = height - 40;
    float scale = min(canvasW / historicMapImage.width, canvasH / historicMapImage.height);
    float imgW = historicMapImage.width * scale;
    float imgH = historicMapImage.height * scale;
    float imgX = 20 + (canvasW - imgW) / 2;
    float imgY = 20 + (canvasH - imgH) / 2;
    
    // Draw with transparency
    tint(255, 80);  // Semi-transparent
    image(historicMapImage, imgX, imgY, imgW, imgH);
    noTint();
  }
  
  // Template mode indicator
  if (templateMode) {
    fill(tealColor);
    textFont(fontBold);
    textSize(12);
    textAlign(LEFT);
    text("TEMPLATE MODE: " + loadedTemplateName, 35, 45);
    fill(#64748b);
    textFont(fontRegular);
    textSize(10);
    text("Click two nodes to connect them", 35, 60);
  }
}

// === DRAW MANUAL CONNECTIONS (Template Mode) ===
void drawManualConnections() {
  for (Connection conn : manualConnections) {
    Node n1 = conn.node1;
    Node n2 = conn.node2;
    
    stroke(lineColor);
    strokeWeight(1.5);
    line(n1.x, n1.y, n2.x, n2.y);
    
    drawRhombicCell(n1, n2);
  }
}

// === DRAW AUTO CONNECTIONS (Free Mode) ===
void drawConnections() {
  if (nodes.size() < 1) return;
  
  for (Node node : nodes) {
    ArrayList<NodeDistance> distances = new ArrayList<NodeDistance>();
    
    for (Node other : nodes) {
      if (other != node) {
        float d = dist(node.x, node.y, other.x, other.y);
        distances.add(new NodeDistance(other, d));
      }
    }
    
    java.util.Collections.sort(distances);
    
    int limit = min(connectionsPerNode, distances.size());
    for (int i = 0; i < limit; i++) {
      Node target = distances.get(i).node;
      
      stroke(lineColor);
      strokeWeight(1.5);
      line(node.x, node.y, target.x, target.y);
      
      drawRhombicCell(node, target);
    }
  }
}

void drawRhombicCell(Node p1, Node p2) {
  float midX = (p1.x + p2.x) / 2;
  float midY = (p1.y + p2.y) / 2;
  float d = dist(p1.x, p1.y, p2.x, p2.y);
  float angle = atan2(p2.y - p1.y, p2.x - p1.x);
  
  float offset = d / (phiTension * 2.2);
  
  float v1x = midX + cos(angle + HALF_PI) * offset;
  float v1y = midY + sin(angle + HALF_PI) * offset;
  float v2x = midX + cos(angle - HALF_PI) * offset;
  float v2y = midY + sin(angle - HALF_PI) * offset;
  
  stroke(cellColor);
  strokeWeight(1);
  fill(cellFill);
  
  beginShape();
  vertex(p1.x, p1.y);
  vertex(v1x, v1y);
  vertex(p2.x, p2.y);
  vertex(v2x, v2y);
  endShape(CLOSE);
}

// === PHASE 2: DELAUNAY TRIANGULATION ===
void generateDelaunayTriangles() {
  triangles.clear();
  centroids.clear();
  
  if (nodes.size() < 3) return;
  
  // Bowyer-Watson algorithm for Delaunay triangulation
  // Start with a super-triangle that contains all points
  float minX = Float.MAX_VALUE, maxX = Float.MIN_VALUE;
  float minY = Float.MAX_VALUE, maxY = Float.MIN_VALUE;
  
  for (Node n : nodes) {
    minX = min(minX, n.x);
    maxX = max(maxX, n.x);
    minY = min(minY, n.y);
    maxY = max(maxY, n.y);
  }
  
  float dx = maxX - minX;
  float dy = maxY - minY;
  float deltaMax = max(dx, dy) * 2;
  
  float midx = (minX + maxX) / 2;
  float midy = (minY + maxY) / 2;
  
  // Super-triangle vertices
  PVector p1 = new PVector(midx - deltaMax, midy - deltaMax);
  PVector p2 = new PVector(midx, midy + deltaMax);
  PVector p3 = new PVector(midx + deltaMax, midy - deltaMax);
  
  ArrayList<PVector[]> tempTriangles = new ArrayList<PVector[]>();
  tempTriangles.add(new PVector[]{p1, p2, p3});
  
  // Add each point one at a time
  for (Node node : nodes) {
    PVector point = new PVector(node.x, node.y);
    ArrayList<PVector[]> badTriangles = new ArrayList<PVector[]>();
    
    // Find all triangles whose circumcircle contains the point
    for (PVector[] tri : tempTriangles) {
      if (isPointInCircumcircle(point, tri)) {
        badTriangles.add(tri);
      }
    }
    
    // Find the boundary of the polygonal hole
    ArrayList<PVector[]> polygon = new ArrayList<PVector[]>();
    for (PVector[] tri : badTriangles) {
      for (int i = 0; i < 3; i++) {
        PVector[] edge = new PVector[]{tri[i], tri[(i + 1) % 3]};
        boolean shared = false;
        
        for (PVector[] other : badTriangles) {
          if (other == tri) continue;
          if (hasEdge(other, edge)) {
            shared = true;
            break;
          }
        }
        
        if (!shared) {
          polygon.add(edge);
        }
      }
    }
    
    // Remove bad triangles
    tempTriangles.removeAll(badTriangles);
    
    // Re-triangulate the hole
    for (PVector[] edge : polygon) {
      tempTriangles.add(new PVector[]{edge[0], edge[1], point});
    }
  }
  
  // Remove triangles that share vertices with super-triangle
  for (PVector[] tri : tempTriangles) {
    boolean valid = true;
    for (PVector v : tri) {
      if (v == p1 || v == p2 || v == p3) {
        valid = false;
        break;
      }
    }
    
    if (valid) {
      // Apply distance threshold filter
      float d1 = dist(tri[0].x, tri[0].y, tri[1].x, tri[1].y);
      float d2 = dist(tri[1].x, tri[1].y, tri[2].x, tri[2].y);
      float d3 = dist(tri[2].x, tri[2].y, tri[0].x, tri[0].y);
      
      if (d1 <= triangleThreshold && d2 <= triangleThreshold && d3 <= triangleThreshold) {
        triangles.add(tri);
        
        // Calculate and store centroid (Phase 3)
        PVector centroid = calcCentroid(tri);
        centroids.add(centroid);
      }
    }
  }
}

// Check if point is inside the circumcircle of a triangle
boolean isPointInCircumcircle(PVector p, PVector[] tri) {
  float ax = tri[0].x, ay = tri[0].y;
  float bx = tri[1].x, by = tri[1].y;
  float cx = tri[2].x, cy = tri[2].y;
  
  float d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
  if (abs(d) < 0.0001) return false;
  
  float ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d;
  float uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d;
  
  float radius = dist(ux, uy, ax, ay);
  float distToPoint = dist(ux, uy, p.x, p.y);
  
  return distToPoint <= radius;
}

// Check if triangle has a specific edge
boolean hasEdge(PVector[] tri, PVector[] edge) {
  for (int i = 0; i < 3; i++) {
    PVector a = tri[i];
    PVector b = tri[(i + 1) % 3];
    if ((a == edge[0] && b == edge[1]) || (a == edge[1] && b == edge[0])) {
      return true;
    }
  }
  return false;
}

// === PHASE 3: CENTROID CALCULATION ===
PVector calcCentroid(PVector[] tri) {
  float cx = (tri[0].x + tri[1].x + tri[2].x) / 3.0;
  float cy = (tri[0].y + tri[1].y + tri[2].y) / 3.0;
  return new PVector(cx, cy);
}

// Calculate orientation angle of a triangle (for future pentagon rotation)
float calcOrientation(PVector[] tri) {
  // Use the angle of the first edge (A→B)
  return atan2(tri[1].y - tri[0].y, tri[1].x - tri[0].x);
}

// Draw the Delaunay triangulation
void drawTriangles() {
  stroke(triangleColor);
  strokeWeight(1);
  noFill();
  
  for (PVector[] tri : triangles) {
    beginShape();
    vertex(tri[0].x, tri[0].y);
    vertex(tri[1].x, tri[1].y);
    vertex(tri[2].x, tri[2].y);
    endShape(CLOSE);
  }
}

// Draw the centroids
void drawCentroids() {
  fill(centroidColor);
  noStroke();
  
  for (PVector centro : centroids) {
    ellipse(centro.x, centro.y, 6, 6);
  }
}

// === PHASE 5-6: PENTAGON MESH GENERATION ===
void generatePentagonMesh() {
  pentagonCells.clear();
  
  if (centroids.size() == 0) {
    println("No centroids available. Make sure you have at least 3 nodes.");
    return;
  }
  
  // Find primary pole (center of mass of all nodes) for gradient effect
  PVector primaryPole = new PVector(0, 0);
  for (Node n : nodes) {
    primaryPole.x += n.x;
    primaryPole.y += n.y;
  }
  primaryPole.x /= nodes.size();
  primaryPole.y /= nodes.size();
  
  // Calculate max distance for gradient
  float maxDist = 0;
  for (PVector c : centroids) {
    float d = dist(c.x, c.y, primaryPole.x, primaryPole.y);
    maxDist = max(maxDist, d);
  }
  
  // Generate a pentagon for each centroid
  for (int i = 0; i < centroids.size(); i++) {
    PVector centro = centroids.get(i);
    PVector[] tri = triangles.get(i);
    float orientation = calcOrientation(tri);
    
    // Calculate local density (Phase 6)
    float density = getLocalDensity(centro, 100);
    
    // Adjust radius based on density if enabled
    float radius = pentagonRadius;
    if (useDensityGradient) {
      // More dense = smaller pentagons, less dense = larger
      radius = map(density, 0, 10, pentagonRadius * 1.3, pentagonRadius * 0.7);
      
      // Also adjust based on distance from primary pole
      float distFromPole = dist(centro.x, centro.y, primaryPole.x, primaryPole.y);
      float distFactor = map(distFromPole, 0, maxDist, 1.2, 0.8);
      radius *= distFactor;
    }
    
    PentagonCell cell = new PentagonCell(centro.x, centro.y, radius, orientation, density);
    pentagonCells.add(cell);
  }
  
  meshGenerated = true;
  println("Generated " + pentagonCells.size() + " pentagons");
}

// Calculate local node density around a point
float getLocalDensity(PVector point, float searchRadius) {
  int count = 0;
  for (Node n : nodes) {
    if (dist(point.x, point.y, n.x, n.y) <= searchRadius) {
      count++;
    }
  }
  return count;
}

// Draw all pentagon cells
void drawPentagonMesh() {
  // Find primary pole for gradient effect
  PVector primaryPole = new PVector(0, 0);
  for (Node n : nodes) {
    primaryPole.x += n.x;
    primaryPole.y += n.y;
  }
  if (nodes.size() > 0) {
    primaryPole.x /= nodes.size();
    primaryPole.y /= nodes.size();
  }
  
  // Calculate max distance
  float maxDist = 0;
  for (PentagonCell cell : pentagonCells) {
    float d = dist(cell.center.x, cell.center.y, primaryPole.x, primaryPole.y);
    maxDist = max(maxDist, d);
  }
  if (maxDist == 0) maxDist = 1;
  
  // Draw each pentagon
  for (PentagonCell cell : pentagonCells) {
    if (useDensityGradient) {
      cell.displayWithGradient(primaryPole, maxDist);
    } else {
      cell.display();
    }
  }
}

// Regenerate pentagons with current settings (called when sliders change)
void updatePentagonMesh() {
  if (!meshGenerated || pentagonCells.size() == 0) return;
  
  for (int i = 0; i < pentagonCells.size(); i++) {
    PentagonCell cell = pentagonCells.get(i);
    PVector[] tri = triangles.get(i);
    float orientation = calcOrientation(tri);
    
    // Recalculate radius
    float radius = pentagonRadius;
    if (useDensityGradient) {
      float density = cell.localDensity;
      radius = map(density, 0, 10, pentagonRadius * 1.3, pentagonRadius * 0.7);
    }
    
    cell.update(radius, orientation);
  }
}

// Clear the pentagon mesh
void clearPentagonMesh() {
  pentagonCells.clear();
  meshGenerated = false;
}

void drawNodes() {
  for (Node node : nodes) {
    // Outer glow
    noFill();
    if (node == selectedNodeForConnection) {
      stroke(selectedNodeColor);
      strokeWeight(2);
      ellipse(node.x, node.y, 30, 30);
    } else {
      stroke(nodeGlow);
      strokeWeight(1);
      ellipse(node.x, node.y, 24, 24);
    }
    
    // Inner node
    if (node == selectedNodeForConnection) {
      fill(selectedNodeColor);
    } else if (node.isFixed) {
      fill(tealColor);
    } else {
      fill(nodeColor);
    }
    noStroke();
    ellipse(node.x, node.y, 8, 8);
  }
}

// === CONTROL PANEL ===
void drawControlPanel() {
  int px = canvasWidth;
  
  fill(panelBg);
  noStroke();
  rect(px, 0, panelWidth, height);
  
  stroke(#334155);
  strokeWeight(1);
  line(px, 0, px, height);
  
  int margin = 24;
  int yPos = 40;
  
  // Title
  textFont(fontBold);
  fill(accentColor);
  textSize(22);
  textAlign(LEFT);
  text("PORTOLAN ENGINE", px + margin, yPos);
  yPos += 20;
  
  textFont(fontRegular);
  fill(#94a3b8);
  textSize(11);
  text("Relational Grid Generator", px + margin, yPos);
  yPos += 25;
  
  // Select Form Button
  selectFormBtnY = yPos;
  if (templateMode) {
    fill(#dc2626);
  } else {
    fill(#3b82f6);
  }
  noStroke();
  rect(px + margin, yPos, panelWidth - 2*margin, 32, 6);
  textFont(fontBold);
  fill(textColor);
  textSize(12);
  textAlign(CENTER);
  text(templateMode ? "Exit Template Mode" : "Select Form", px + panelWidth/2, yPos + 21);
  textAlign(LEFT);
  yPos += 50;
  
  // Separator
  stroke(#334155);
  line(px + margin, yPos - 12, px + panelWidth - margin, yPos - 12);
  
  // Section: Input
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  text("INPUT: NODES & TRAJECTORIES", px + margin, yPos);
  yPos += 30;
  
  // Connections per node (0 = manual only in template mode, 1-10 = auto-connect to N nearest)
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(14);
  text("Connections per Node:", px + margin, yPos);
  textFont(fontBold);
  fill(accentColor);
  textAlign(RIGHT);
  textSize(16);
  text(str(connectionsPerNode), px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 24;
  
  connectionsSliderY = yPos;
  int minConn = templateMode ? 0 : 1;  // Allow 0 in template mode (manual only)
  drawSlider(px + margin, yPos, panelWidth - 2*margin, connectionsPerNode, minConn, 10, accentColor, false);
  yPos += 38;
  
  // Phi tension
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(14);
  text("Rhombic Tension (Phi):", px + margin, yPos);
  textFont(fontBold);
  fill(tealColor);
  textAlign(RIGHT);
  textSize(16);
  text(nf(phiTension, 1, 3), px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 24;
  
  phiSliderY = yPos;
  drawSlider(px + margin, yPos, panelWidth - 2*margin, phiTension, 1.0, 2.0, tealColor, false);
  yPos += 38;
  
  // Triangle Threshold slider (Phase 2)
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(14);
  text("Triangle Threshold:", px + margin, yPos);
  textFont(fontBold);
  fill(#3b82f6);  // Blue for triangulation
  textAlign(RIGHT);
  textSize(16);
  text(str(int(triangleThreshold)) + "px", px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 24;
  
  thresholdSliderY = yPos;
  drawSlider(px + margin, yPos, panelWidth - 2*margin, triangleThreshold, 50, 400, #3b82f6, false);
  yPos += 32;
  
  // Show Triangles checkbox
  triangleCheckboxY = yPos;
  fill(showTriangles ? #3b82f6 : #64748b);
  noStroke();
  rect(px + margin, yPos - 12, 18, 18, 3);
  if (showTriangles) {
    fill(bgColor);
    textFont(fontBold);
    textSize(14);
    text("✓", px + margin + 3, yPos + 2);
  }
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(13);
  text("Show Triangles (" + triangles.size() + ")", px + margin + 28, yPos);
  yPos += 26;
  
  // Show Centroids checkbox
  centroidCheckboxY = yPos;
  fill(showCentroids ? #ec4899 : #64748b);  // Pink for centroids
  noStroke();
  rect(px + margin, yPos - 12, 18, 18, 3);
  if (showCentroids) {
    fill(bgColor);
    textFont(fontBold);
    textSize(14);
    text("✓", px + margin + 3, yPos + 2);
  }
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(13);
  text("Show Centroids (" + centroids.size() + ")", px + margin + 28, yPos);
  yPos += 32;
  
  // Checkbox - Show Historic Map (only enabled in template mode)
  checkboxY = yPos;
  boolean mapCheckboxEnabled = templateMode && historicMapImage != null;
  
  if (mapCheckboxEnabled) {
    fill(showHistoricMap ? tealColor : #64748b);
  } else {
    fill(#334155);  // Disabled color
  }
  noStroke();
  rect(px + margin, yPos - 12, 18, 18, 3);
  
  if (showHistoricMap && mapCheckboxEnabled) {
    fill(bgColor);
    textFont(fontBold);
    textSize(14);
    text("✓", px + margin + 3, yPos + 2);
  }
  
  textFont(fontRegular);
  fill(mapCheckboxEnabled ? #cbd5e1 : disabledColor);
  textSize(13);
  text("Show Historic Map", px + margin + 28, yPos);
  
  // Show hint if disabled
  if (!templateMode) {
    fill(#64748b);
    textSize(9);
    text("(select a form first)", px + margin + 28, yPos + 12);
  }
  yPos += 35;
  
  // Separator
  stroke(#334155);
  line(px + margin, yPos - 12, px + panelWidth - margin, yPos - 12);
  
  // Section: Pentagon Mesh (Phase 5-6)
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  text("PENTAGON MESH", px + margin, yPos);
  yPos += 25;
  
  // Generate Mesh Button
  generateMeshBtnY = yPos;
  boolean canGenerate = centroids.size() > 0;
  if (canGenerate) {
    fill(meshGenerated ? #22c55e : #8b5cf6);  // Green if generated, purple otherwise
  } else {
    fill(#334155);
  }
  noStroke();
  rect(px + margin, yPos, panelWidth - 2*margin, 32, 6);
  textFont(fontBold);
  fill(canGenerate ? textColor : disabledColor);
  textSize(12);
  textAlign(CENTER);
  String meshBtnText = meshGenerated ? "Regenerate Mesh (" + pentagonCells.size() + ")" : "Generate Mesh";
  text(meshBtnText, px + panelWidth/2, yPos + 21);
  textAlign(LEFT);
  yPos += 42;
  
  // Pentagon Radius slider
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(13);
  text("Pentagon Radius:", px + margin, yPos);
  textFont(fontBold);
  fill(#f59e0b);  // Amber
  textAlign(RIGHT);
  textSize(14);
  text(str(int(pentagonRadius)) + "px", px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 20;
  
  pentagonRadiusSliderY = yPos;
  drawSlider(px + margin, yPos, panelWidth - 2*margin, pentagonRadius, 15, 80, #f59e0b, false);
  yPos += 30;
  
  // Deformation slider
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(13);
  text("Deformation:", px + margin, yPos);
  textFont(fontBold);
  fill(#f59e0b);
  textAlign(RIGHT);
  textSize(14);
  text(nf(deformationLevel, 1, 2), px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 20;
  
  deformationSliderY = yPos;
  drawSlider(px + margin, yPos, panelWidth - 2*margin, deformationLevel, 0, 0.4, #f59e0b, false);
  yPos += 28;
  
  // Show Pentagons checkbox
  pentagonCheckboxY = yPos;
  fill(showPentagons ? #f59e0b : #64748b);
  noStroke();
  rect(px + margin, yPos - 12, 18, 18, 3);
  if (showPentagons) {
    fill(bgColor);
    textFont(fontBold);
    textSize(14);
    text("✓", px + margin + 3, yPos + 2);
  }
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(12);
  text("Show Pentagons", px + margin + 28, yPos);
  
  // Density gradient checkbox (inline)
  fill(useDensityGradient ? #f59e0b : #64748b);
  rect(px + margin + 140, yPos - 12, 18, 18, 3);
  if (useDensityGradient) {
    fill(bgColor);
    textFont(fontBold);
    textSize(14);
    text("✓", px + margin + 143, yPos + 2);
  }
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(12);
  text("Gradient", px + margin + 165, yPos);
  yPos += 30;
  
  // Separator
  stroke(#334155);
  line(px + margin, yPos - 8, px + panelWidth - margin, yPos - 8);
  
  // Section: Analysis Output
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  text("OUTPUT ANALYSIS", px + margin, yPos);
  yPos += 25;
  
  int boxW = (panelWidth - 3*margin) / 2;
  int boxH = 70;
  
  // Nodi Attivi
  fill(#0f172a);
  stroke(#334155);
  strokeWeight(1);
  rect(px + margin, yPos, boxW, boxH, 10);
  textFont(fontRegular);
  fill(#64748b);
  textSize(11);
  text("ACTIVE NODES", px + margin + 12, yPos + 22);
  textFont(fontBold);
  fill(accentColor);
  textSize(28);
  text(str(nodes.size()), px + margin + 12, yPos + 55);
  
  // Connections count
  fill(#0f172a);
  stroke(#334155);
  rect(px + margin + boxW + margin, yPos, boxW, boxH, 10);
  textFont(fontRegular);
  fill(#64748b);
  textSize(11);
  text(templateMode ? "CONNECTIONS" : "GEN. CELLS", px + margin + boxW + margin + 8, yPos + 22);
  textFont(fontBold);
  fill(tealColor);
  textSize(28);
  int connCount = templateMode ? manualConnections.size() : max(0, nodes.size() - 1);
  text(str(connCount), px + margin + boxW + margin + 8, yPos + 55);
  
  yPos += boxH + 18;
  
  // Data log
  fill(#0a0f1a);
  stroke(#1e293b);
  strokeWeight(1);
  int logHeight = 120;
  rect(px + margin, yPos, panelWidth - 2*margin, logHeight, 10);
  
  textFont(fontRegular);
  fill(#14b8a6cc);
  textSize(11);
  int logY = yPos + 18;
  int lineHeight = 14;
  int maxLines = (logHeight - 20) / lineHeight;
  
  if (templateMode && manualConnections.size() > 0) {
    int displayCount = min(manualConnections.size(), maxLines);
    int startIdx = max(0, manualConnections.size() - displayCount);
    for (int i = startIdx; i < manualConnections.size(); i++) {
      Connection c = manualConnections.get(i);
      text("CONN " + i + ": N" + c.node1.id + " → N" + c.node2.id, px + margin + 12, logY);
      logY += lineHeight;
    }
  } else if (nodes.size() > 0) {
    int displayCount = min(nodes.size(), maxLines);
    int startIdx = max(0, nodes.size() - displayCount);
    for (int i = startIdx; i < nodes.size(); i++) {
      Node n = nodes.get(i);
      String prefix = n.isFixed ? "[F] " : "";
      text(prefix + "NODE_" + n.id + " [" + round(n.x) + "," + round(n.y) + "]", px + margin + 12, logY);
      logY += lineHeight;
    }
  } else {
    fill(#64748b);
    text("// Awaiting input...", px + margin + 12, logY);
  }
  
  // Buttons
  int bottomY = height - 100;
  
  fill(#1e293b);
  stroke(#475569);
  strokeWeight(1);
  rect(px + margin, bottomY, panelWidth - 2*margin, 38, 8);
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  textAlign(CENTER);
  text("CLEAR FRAMEWORK", px + panelWidth/2, bottomY + 25);
  
  bottomY += 48;
  
  fill(accentColor);
  noStroke();
  rect(px + margin, bottomY, panelWidth - 2*margin, 42, 10);
  fill(textColor);
  textSize(14);
  text("Export Coordinates (JSON)", px + panelWidth/2, bottomY + 28);
  
  textAlign(LEFT);
  textFont(fontRegular);
}

void drawSlider(float x, float y, float w, float value, float minVal, float maxVal, color c, boolean disabled) {
  noStroke();
  fill(disabled ? #1e293b : #334155);
  rect(x, y - 3, w, 6, 3);
  
  if (!disabled) {
    float pct = map(value, minVal, maxVal, 0, 1);
    fill(c);
    rect(x, y - 3, w * pct, 6, 3);
    
    fill(c);
    noStroke();
    ellipse(x + w * pct, y, 16, 16);
  }
}

// === TEMPLATE SELECTOR MODAL ===
void drawTemplateSelector() {
  // Dim background
  fill(modalBg);
  noStroke();
  rect(0, 0, width, height);
  
  // Modal window
  int modalW = 500;
  int modalH = 600;
  int modalX = (width - modalW) / 2;
  int modalY = (height - modalH) / 2;
  
  // Modal background
  fill(panelBg);
  stroke(#475569);
  strokeWeight(2);
  rect(modalX, modalY, modalW, modalH, 16);
  
  // Header
  fill(#3b82f6);
  noStroke();
  rect(modalX, modalY, modalW, 50, 16, 16, 0, 0);
  
  textFont(fontBold);
  fill(textColor);
  textSize(18);
  textAlign(LEFT);
  text("Select Form", modalX + 20, modalY + 32);
  
  // Close button
  fill(#ef4444);
  ellipse(modalX + modalW - 25, modalY + 25, 20, 20);
  fill(textColor);
  textSize(14);
  textAlign(CENTER);
  text("×", modalX + modalW - 25, modalY + 30);
  
  // Preview area
  int previewX = modalX + 20;
  int previewY = modalY + 70;
  int previewW = modalW - 40;
  int previewH = 250;
  
  fill(#0f172a);
  stroke(#334155);
  strokeWeight(1);
  rect(previewX, previewY, previewW, previewH, 8);
  
  // Draw preview image or placeholder
  if (currentPreviewImage != null && hoveredTemplateIndex >= 0) {
    // Scale and center image
    float scale = min((float)(previewW - 20) / currentPreviewImage.width, 
                      (float)(previewH - 20) / currentPreviewImage.height);
    float imgW = currentPreviewImage.width * scale;
    float imgH = currentPreviewImage.height * scale;
    float imgX = previewX + (previewW - imgW) / 2;
    float imgY = previewY + (previewH - imgH) / 2;
    image(currentPreviewImage, imgX, imgY, imgW, imgH);
  } else {
    // Placeholder X
    stroke(#334155);
    strokeWeight(2);
    line(previewX + 20, previewY + 20, previewX + previewW - 20, previewY + previewH - 20);
    line(previewX + previewW - 20, previewY + 20, previewX + 20, previewY + previewH - 20);
    
    textFont(fontRegular);
    fill(#64748b);
    textSize(12);
    textAlign(CENTER);
    text("Hover over a template to preview", previewX + previewW/2, previewY + previewH/2 + 50);
  }
  
  // Template list
  int listY = previewY + previewH + 20;
  int itemH = 40;
  
  textAlign(LEFT);
  
  if (templateFiles.size() == 0) {
    fill(#64748b);
    textFont(fontRegular);
    textSize(14);
    text("No templates found in templates folder", modalX + 20, listY + 25);
  } else {
    for (int i = 0; i < templateFiles.size(); i++) {
      TemplateFile tf = templateFiles.get(i);
      int itemY = listY + i * itemH;
      
      // Check if hovered
      boolean hovered = mouseX > modalX + 10 && mouseX < modalX + modalW - 10 &&
                        mouseY > itemY && mouseY < itemY + itemH - 5;
      
      if (hovered) {
        hoveredTemplateIndex = i;
        // Load preview image if needed
        if (currentPreviewImage == null || selectedTemplateIndex != i) {
          if (!tf.imagePath.isEmpty()) {
            try {
              PImage tempImg = loadImage(tf.imagePath);
              // Verify image loaded correctly
              if (tempImg != null && tempImg.width > 0 && tempImg.height > 0) {
                currentPreviewImage = tempImg;
              } else {
                currentPreviewImage = null;
              }
            } catch (Exception e) {
              currentPreviewImage = null;
            }
          }
          selectedTemplateIndex = i;
        }
      }
      
      // Item background
      fill(hovered ? #334155 : #1e293b);
      stroke(#475569);
      strokeWeight(1);
      rect(modalX + 10, itemY, modalW - 20, itemH - 5, 8);
      
      // Template name
      textFont(fontBold);
      fill(hovered ? accentColor : textColor);
      textSize(14);
      text("Template " + nf(i, 2) + ": " + tf.name, modalX + 20, itemY + 25);
      
      // Category
      textFont(fontRegular);
      fill(#64748b);
      textSize(10);
      text(tf.category, modalX + modalW - 80, itemY + 25);
    }
  }
  
  textAlign(LEFT);
}

// === INPUT HANDLING ===
void mousePressed() {
  // Template selector modal
  if (showTemplateSelector) {
    int modalW = 500;
    int modalH = 600;
    int modalX = (width - modalW) / 2;
    int modalY = (height - modalH) / 2;
    
    // Close button
    if (dist(mouseX, mouseY, modalX + modalW - 25, modalY + 25) < 15) {
      showTemplateSelector = false;
      currentPreviewImage = null;
      hoveredTemplateIndex = -1;
      return;
    }
    
    // Click outside modal
    if (mouseX < modalX || mouseX > modalX + modalW || 
        mouseY < modalY || mouseY > modalY + modalH) {
      showTemplateSelector = false;
      currentPreviewImage = null;
      hoveredTemplateIndex = -1;
      return;
    }
    
    // Template item click
    int previewH = 250;
    int listY = modalY + 70 + previewH + 20;
    int itemH = 40;
    
    for (int i = 0; i < templateFiles.size(); i++) {
      int itemY = listY + i * itemH;
      if (mouseX > modalX + 10 && mouseX < modalX + modalW - 10 &&
          mouseY > itemY && mouseY < itemY + itemH - 5) {
        loadTemplateFromFile(templateFiles.get(i));
        showTemplateSelector = false;
        currentPreviewImage = null;
        hoveredTemplateIndex = -1;
        return;
      }
    }
    return;
  }
  
  int px = canvasWidth;
  float sliderWidth = panelWidth - 2 * sliderMargin;
  
  // Select Form / Exit Template Mode button
  if (mouseX > px + sliderMargin && mouseX < px + panelWidth - sliderMargin &&
      mouseY > selectFormBtnY && mouseY < selectFormBtnY + 32) {
    if (templateMode) {
      exitTemplateMode();
    } else {
      showTemplateSelector = true;
      hoveredTemplateIndex = -1;
      currentPreviewImage = null;
    }
    return;
  }
  
  // Connections slider (works in both modes, min is 0 in template mode, 1 in free mode)
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > connectionsSliderY - 10 && mouseY < connectionsSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    int minConn = templateMode ? 0 : 1;
    connectionsPerNode = round(map(pct, 0, 1, minConn, 10));
    return;
  }
  
  // Phi slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > phiSliderY - 10 && mouseY < phiSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    phiTension = map(pct, 0, 1, 1.0, 2.0);
    return;
  }
  
  // Triangle threshold slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > thresholdSliderY - 10 && mouseY < thresholdSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    triangleThreshold = map(pct, 0, 1, 50, 400);
    return;
  }
  
  // Show Triangles checkbox
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + 18 &&
      mouseY > triangleCheckboxY - 12 && mouseY < triangleCheckboxY + 6) {
    showTriangles = !showTriangles;
    return;
  }
  
  // Show Centroids checkbox
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + 18 &&
      mouseY > centroidCheckboxY - 12 && mouseY < centroidCheckboxY + 6) {
    showCentroids = !showCentroids;
    return;
  }
  
  // Checkbox - Show Historic Map (only works in template mode with a map image)
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + 18 &&
      mouseY > checkboxY - 12 && mouseY < checkboxY + 6) {
    if (templateMode && historicMapImage != null) {
      showHistoricMap = !showHistoricMap;
    }
    return;
  }
  
  // Generate Mesh button
  if (mouseX > px + sliderMargin && mouseX < px + panelWidth - sliderMargin &&
      mouseY > generateMeshBtnY && mouseY < generateMeshBtnY + 32) {
    if (centroids.size() > 0) {
      generatePentagonMesh();
    }
    return;
  }
  
  // Pentagon Radius slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > pentagonRadiusSliderY - 10 && mouseY < pentagonRadiusSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    pentagonRadius = map(pct, 0, 1, 15, 80);
    updatePentagonMesh();
    return;
  }
  
  // Deformation slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > deformationSliderY - 10 && mouseY < deformationSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    deformationLevel = map(pct, 0, 1, 0, 0.4);
    // Regenerate mesh with new deformation
    if (meshGenerated) generatePentagonMesh();
    return;
  }
  
  // Show Pentagons checkbox
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + 18 &&
      mouseY > pentagonCheckboxY - 12 && mouseY < pentagonCheckboxY + 6) {
    showPentagons = !showPentagons;
    return;
  }
  
  // Density Gradient checkbox
  if (mouseX > px + sliderMargin + 140 && mouseX < px + sliderMargin + 158 &&
      mouseY > pentagonCheckboxY - 12 && mouseY < pentagonCheckboxY + 6) {
    useDensityGradient = !useDensityGradient;
    updatePentagonMesh();
    return;
  }
  
  // Clear button
  int clearBtnY = height - 100;
  if (mouseX > px + sliderMargin && mouseX < px + panelWidth - sliderMargin &&
      mouseY > clearBtnY && mouseY < clearBtnY + 38) {
    clearCanvas();
    return;
  }
  
  // Export button
  int exportBtnY = height - 52;
  if (mouseX > px + sliderMargin && mouseX < px + panelWidth - sliderMargin &&
      mouseY > exportBtnY && mouseY < exportBtnY + 42) {
    exportJSON();
    return;
  }
  
  // Canvas area clicks
  if (mouseX > 20 && mouseX < canvasWidth - 20 && mouseY > 20 && mouseY < height - 20) {
    if (templateMode) {
      // In template mode: click nodes to connect
      Node clickedNode = getNodeAt(mouseX, mouseY);
      if (clickedNode != null) {
        if (selectedNodeForConnection == null) {
          selectedNodeForConnection = clickedNode;
        } else if (clickedNode != selectedNodeForConnection) {
          // Create connection
          if (!connectionExists(selectedNodeForConnection, clickedNode)) {
            manualConnections.add(new Connection(selectedNodeForConnection, clickedNode));
          }
          selectedNodeForConnection = null;
        } else {
          // Clicked same node, deselect
          selectedNodeForConnection = null;
        }
      }
    } else {
      // Free mode: add new node
      nodes.add(new Node(mouseX, mouseY, nodes.size(), false));
    }
  }
}

void mouseDragged() {
  if (showTemplateSelector) return;
  
  int px = canvasWidth;
  float sliderWidth = panelWidth - 2 * sliderMargin;
  
  // Connections slider (only in free mode)
  // Connections slider drag
  if (mouseY > connectionsSliderY - 20 && mouseY < connectionsSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    int minConn = templateMode ? 0 : 1;
    connectionsPerNode = round(map(pct, 0, 1, minConn, 10));
    return;
  }
  
  // Phi slider
  if (mouseY > phiSliderY - 20 && mouseY < phiSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    phiTension = map(pct, 0, 1, 1.0, 2.0);
    return;
  }
  
  // Triangle threshold slider
  if (mouseY > thresholdSliderY - 20 && mouseY < thresholdSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    triangleThreshold = map(pct, 0, 1, 50, 400);
    return;
  }
  
  // Pentagon Radius slider
  if (mouseY > pentagonRadiusSliderY - 20 && mouseY < pentagonRadiusSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    pentagonRadius = map(pct, 0, 1, 15, 80);
    updatePentagonMesh();
    return;
  }
  
  // Deformation slider
  if (mouseY > deformationSliderY - 20 && mouseY < deformationSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    deformationLevel = map(pct, 0, 1, 0, 0.4);
    // Note: deformation requires regenerating mesh since radii are randomized
  }
}

void keyPressed() {
  if (key == ESC) {
    key = 0;  // Prevent closing sketch
    if (showTemplateSelector) {
      showTemplateSelector = false;
      currentPreviewImage = null;
    } else if (templateMode) {
      exitTemplateMode();
    }
    return;
  }
  
  if (showTemplateSelector) return;
  
  // Connections adjustment (works in both modes, min is 0 in template mode)
  int minConn = templateMode ? 0 : 1;
  if (keyCode == UP) {
    connectionsPerNode = min(10, connectionsPerNode + 1);
  } else if (keyCode == DOWN) {
    connectionsPerNode = max(minConn, connectionsPerNode - 1);
  }
  
  // Phi adjustment
  if (keyCode == RIGHT) {
    phiTension = min(2.0, phiTension + 0.05);
  } else if (keyCode == LEFT) {
    phiTension = max(1.0, phiTension - 0.05);
  }
  
  if (key == 'c' || key == 'C') {
    clearCanvas();
  }
  
  if (key == 'e' || key == 'E') {
    exportJSON();
  }
  
  if (key == 's' || key == 'S') {
    saveFrame("portolan_export_####.png");
    println("Image saved!");
  }
  
  if (key == 'm' || key == 'M') {
    if (templateMode && historicMapImage != null) {
      showHistoricMap = !showHistoricMap;
    }
  }
  
  // Toggle triangles visibility
  if (key == 't' || key == 'T') {
    showTriangles = !showTriangles;
  }
  
  // Toggle centroids visibility (d for dots)
  if (key == 'd' || key == 'D') {
    showCentroids = !showCentroids;
  }
  
  // Adjust triangle threshold with [ and ]
  if (key == '[') {
    triangleThreshold = max(50, triangleThreshold - 20);
  }
  if (key == ']') {
    triangleThreshold = min(400, triangleThreshold + 20);
  }
  
  // Toggle pentagons visibility
  if (key == 'p' || key == 'P') {
    showPentagons = !showPentagons;
  }
  
  // Generate/regenerate pentagon mesh
  if (key == 'g' || key == 'G') {
    if (centroids.size() > 0) {
      generatePentagonMesh();
    }
  }
  
  // Adjust pentagon radius with - and =
  if (key == '-' || key == '_') {
    pentagonRadius = max(15, pentagonRadius - 5);
    updatePentagonMesh();
  }
  if (key == '=' || key == '+') {
    pentagonRadius = min(80, pentagonRadius + 5);
    updatePentagonMesh();
  }
  
  // Delete last
  if (keyCode == DELETE || keyCode == BACKSPACE) {
    if (templateMode) {
      if (manualConnections.size() > 0) {
        manualConnections.remove(manualConnections.size() - 1);
      }
    } else {
      if (nodes.size() > 0) {
        Node last = nodes.get(nodes.size() - 1);
        if (!last.isFixed) {
          nodes.remove(nodes.size() - 1);
        }
      }
    }
  }
}

// === TEMPLATE LOADING ===
void loadTemplateFromFile(TemplateFile tf) {
  try {
    JSONObject json = loadJSONObject(tf.path);
    JSONArray jsonNodes = json.getJSONArray("nodes");
    
    nodes.clear();
    manualConnections.clear();
    selectedNodeForConnection = null;
    showHistoricMap = false;  // Reset checkbox when loading new template
    
    // Calculate scale to fit canvas
    float minX = Float.MAX_VALUE, maxX = Float.MIN_VALUE;
    float minY = Float.MAX_VALUE, maxY = Float.MIN_VALUE;
    
    for (int i = 0; i < jsonNodes.size(); i++) {
      JSONObject nodeObj = jsonNodes.getJSONObject(i);
      float x = nodeObj.getFloat("x");
      float y = nodeObj.getFloat("y");
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
    }
    
    float dataW = maxX - minX;
    float dataH = maxY - minY;
    float canvasDrawW = canvasWidth - 100;
    float canvasDrawH = height - 100;
    float scale = min(canvasDrawW / dataW, canvasDrawH / dataH) * 0.9;
    float offsetX = 50 + (canvasDrawW - dataW * scale) / 2;
    float offsetY = 50 + (canvasDrawH - dataH * scale) / 2;
    
    for (int i = 0; i < jsonNodes.size(); i++) {
      JSONObject nodeObj = jsonNodes.getJSONObject(i);
      float x = (nodeObj.getFloat("x") - minX) * scale + offsetX;
      float y = (nodeObj.getFloat("y") - minY) * scale + offsetY;
      int id = nodeObj.getInt("id", i);
      nodes.add(new Node(x, y, id, true));
    }
    
    templateMode = true;
    loadedTemplateName = tf.name;
    loadedTemplateCategoryPath = tf.categoryPath;
    connectionsPerNode = 0;  // Default to manual-only in template mode
    
    // Load the historic map image from the map folder
    loadHistoricMapImage(tf.categoryPath);
    
    println("Loaded template: " + tf.name + " with " + nodes.size() + " nodes");
    
  } catch (Exception e) {
    println("Error loading template: " + e.getMessage());
  }
}

void loadHistoricMapImage(String categoryPath) {
  historicMapImage = null;
  
  File mapDir = new File(categoryPath, "map");
  if (mapDir.exists() && mapDir.isDirectory()) {
    // Find the first image file in the map folder (prefer PNG over JPEG for compatibility)
    File[] imageFiles = mapDir.listFiles(new java.io.FilenameFilter() {
      public boolean accept(File dir, String name) {
        String lower = name.toLowerCase();
        return lower.endsWith(".png") || lower.endsWith(".gif") ||
               lower.endsWith(".jpg") || lower.endsWith(".jpeg");
      }
    });
    
    if (imageFiles != null && imageFiles.length > 0) {
      // Sort to prefer PNG files (more compatible)
      java.util.Arrays.sort(imageFiles, new java.util.Comparator<File>() {
        public int compare(File a, File b) {
          boolean aIsPng = a.getName().toLowerCase().endsWith(".png");
          boolean bIsPng = b.getName().toLowerCase().endsWith(".png");
          if (aIsPng && !bIsPng) return -1;
          if (!aIsPng && bIsPng) return 1;
          return a.getName().compareTo(b.getName());
        }
      });
      
      try {
        historicMapImage = loadImage(imageFiles[0].getAbsolutePath());
        // Verify image loaded correctly
        if (historicMapImage != null && historicMapImage.width > 0 && historicMapImage.height > 0) {
          println("Loaded historic map: " + imageFiles[0].getName());
        } else {
          println("Warning: Historic map image failed to load properly: " + imageFiles[0].getName());
          historicMapImage = null;
        }
      } catch (Exception e) {
        println("Error loading historic map: " + e.getMessage());
        historicMapImage = null;
      }
    }
  }
}

void exitTemplateMode() {
  templateMode = false;
  loadedTemplateName = "";
  loadedTemplateCategoryPath = "";
  nodes.clear();
  manualConnections.clear();
  selectedNodeForConnection = null;
  historicMapImage = null;
  showHistoricMap = false;
  connectionsPerNode = 2;  // Reset to default for free mode
  clearPentagonMesh();
}

void clearCanvas() {
  if (templateMode) {
    manualConnections.clear();
    selectedNodeForConnection = null;
  } else {
    nodes.clear();
  }
  clearPentagonMesh();
}

// === HELPER FUNCTIONS ===
Node getNodeAt(float x, float y) {
  for (Node node : nodes) {
    if (dist(x, y, node.x, node.y) < 15) {
      return node;
    }
  }
  return null;
}

boolean connectionExists(Node n1, Node n2) {
  for (Connection c : manualConnections) {
    if ((c.node1 == n1 && c.node2 == n2) || (c.node1 == n2 && c.node2 == n1)) {
      return true;
    }
  }
  return false;
}

// === EXPORT ===
void exportJSON() {
  JSONArray jsonNodes = new JSONArray();
  
  for (int i = 0; i < nodes.size(); i++) {
    Node n = nodes.get(i);
    JSONObject nodeObj = new JSONObject();
    nodeObj.setInt("id", n.id);
    nodeObj.setFloat("x", n.x);
    nodeObj.setFloat("y", n.y);
    nodeObj.setBoolean("isFixed", n.isFixed);
    jsonNodes.setJSONObject(i, nodeObj);
  }
  
  JSONObject export = new JSONObject();
  export.setString("name", "Portolan Export");
  export.setString("mode", templateMode ? "template" : "free");
  if (templateMode) {
    export.setString("template", loadedTemplateName);
    
    JSONArray jsonConns = new JSONArray();
    for (int i = 0; i < manualConnections.size(); i++) {
      Connection c = manualConnections.get(i);
      JSONObject connObj = new JSONObject();
      connObj.setInt("from", c.node1.id);
      connObj.setInt("to", c.node2.id);
      jsonConns.setJSONObject(i, connObj);
    }
    export.setJSONArray("connections", jsonConns);
  }
  export.setInt("connectionsPerNode", connectionsPerNode);
  export.setFloat("phiTension", phiTension);
  export.setFloat("triangleThreshold", triangleThreshold);
  export.setJSONArray("nodes", jsonNodes);
  
  // Export triangles (Phase 2)
  JSONArray jsonTriangles = new JSONArray();
  for (int i = 0; i < triangles.size(); i++) {
    PVector[] tri = triangles.get(i);
    JSONObject triObj = new JSONObject();
    JSONArray verts = new JSONArray();
    for (int j = 0; j < 3; j++) {
      JSONObject v = new JSONObject();
      v.setFloat("x", tri[j].x);
      v.setFloat("y", tri[j].y);
      verts.setJSONObject(j, v);
    }
    triObj.setJSONArray("vertices", verts);
    
    // Include centroid and orientation for this triangle
    PVector centro = centroids.get(i);
    triObj.setFloat("centroidX", centro.x);
    triObj.setFloat("centroidY", centro.y);
    triObj.setFloat("orientation", calcOrientation(tri));
    
    jsonTriangles.setJSONObject(i, triObj);
  }
  export.setJSONArray("triangles", jsonTriangles);
  
  // Export centroids separately for convenience (Phase 3)
  JSONArray jsonCentroids = new JSONArray();
  for (int i = 0; i < centroids.size(); i++) {
    PVector c = centroids.get(i);
    JSONObject centObj = new JSONObject();
    centObj.setFloat("x", c.x);
    centObj.setFloat("y", c.y);
    centObj.setFloat("orientation", calcOrientation(triangles.get(i)));
    jsonCentroids.setJSONObject(i, centObj);
  }
  export.setJSONArray("centroids", jsonCentroids);
  
  // Export pentagons (Phase 5-6) - for Grasshopper/Rhino
  export.setFloat("pentagonRadius", pentagonRadius);
  export.setFloat("deformationLevel", deformationLevel);
  
  JSONArray jsonPentagons = new JSONArray();
  for (int i = 0; i < pentagonCells.size(); i++) {
    PentagonCell cell = pentagonCells.get(i);
    JSONObject cellObj = new JSONObject();
    
    // Center position
    cellObj.setFloat("cx", cell.center.x);
    cellObj.setFloat("cy", cell.center.y);
    cellObj.setFloat("radius", cell.baseRadius);
    cellObj.setFloat("rotation", cell.rotation);
    cellObj.setFloat("density", cell.localDensity);
    
    // 5 vertices for direct use in Grasshopper
    JSONArray verts = new JSONArray();
    for (int j = 0; j < 5; j++) {
      JSONObject v = new JSONObject();
      v.setFloat("x", cell.vertices[j].x);
      v.setFloat("y", cell.vertices[j].y);
      verts.setJSONObject(j, v);
    }
    cellObj.setJSONArray("vertices", verts);
    
    // Individual radii (for deformation reconstruction)
    JSONArray radii = new JSONArray();
    for (int j = 0; j < 5; j++) {
      radii.setFloat(j, cell.radii[j]);
    }
    cellObj.setJSONArray("radii", radii);
    
    jsonPentagons.setJSONObject(i, cellObj);
  }
  export.setJSONArray("pentagons", jsonPentagons);
  
  String filename = "portolan_export_" + year() + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + ".json";
  saveJSONObject(export, filename);
  println("Exported to: " + filename);
  println("  - " + nodes.size() + " nodes");
  println("  - " + triangles.size() + " triangles");
  println("  - " + centroids.size() + " centroids");
  println("  - " + pentagonCells.size() + " pentagons");
}

// === CLASSES ===
class Node {
  float x, y;
  int id;
  boolean isFixed;
  
  Node(float x, float y, int id, boolean isFixed) {
    this.x = x;
    this.y = y;
    this.id = id;
    this.isFixed = isFixed;
  }
}

class NodeDistance implements Comparable<NodeDistance> {
  Node node;
  float distance;
  
  NodeDistance(Node node, float distance) {
    this.node = node;
    this.distance = distance;
  }
  
  int compareTo(NodeDistance other) {
    return Float.compare(this.distance, other.distance);
  }
}

class Connection {
  Node node1, node2;
  
  Connection(Node n1, Node n2) {
    this.node1 = n1;
    this.node2 = n2;
  }
}

class TemplateFile {
  String name;
  String path;
  String imagePath;
  String category;
  String categoryPath;  // Full path to the category folder (for loading map images)
  
  TemplateFile(String name, String path, String imagePath, String category, String categoryPath) {
    this.name = name;
    this.path = path;
    this.imagePath = imagePath;
    this.category = category;
    this.categoryPath = categoryPath;
  }
}

// === PHASE 5-6: PENTAGON CELL CLASS ===
class PentagonCell {
  PVector center;           // Centroid position
  float baseRadius;         // Base radius before deformation
  float rotation;           // Orientation from triangle
  PVector[] vertices;       // 5 vertices of the pentagon
  float[] radii;            // Individual radius for each vertex (for deformation)
  float localDensity;       // Local node density (affects size)
  
  PentagonCell(float cx, float cy, float r, float rot, float density) {
    this.center = new PVector(cx, cy);
    this.baseRadius = r;
    this.rotation = rot;
    this.localDensity = density;
    this.vertices = new PVector[5];
    this.radii = new float[5];
    
    initRadii();
    calculateVertices();
  }
  
  // Initialize radii with deformation
  void initRadii() {
    for (int i = 0; i < 5; i++) {
      // Apply deformation: 1.0 = no deformation, range based on deformationLevel
      float minR = 1.0 - deformationLevel;
      float maxR = 1.0 + deformationLevel;
      radii[i] = random(minR, maxR);
    }
  }
  
  // Calculate the 5 vertices based on center, radius, rotation, and deformation
  void calculateVertices() {
    for (int i = 0; i < 5; i++) {
      float angle = rotation + i * TWO_PI / 5.0;
      float r = baseRadius * radii[i];
      vertices[i] = new PVector(
        center.x + r * cos(angle),
        center.y + r * sin(angle)
      );
    }
  }
  
  // Recalculate with new parameters
  void update(float newRadius, float newRotation) {
    this.baseRadius = newRadius;
    this.rotation = newRotation;
    calculateVertices();
  }
  
  // Draw the pentagon
  void display() {
    stroke(pentagonStroke);
    strokeWeight(1.2);
    fill(pentagonFill);
    
    beginShape();
    for (int i = 0; i < 5; i++) {
      vertex(vertices[i].x, vertices[i].y);
    }
    endShape(CLOSE);
  }
  
  // Draw with distance-based opacity (Phase 6 gradient effect)
  void displayWithGradient(PVector primaryPole, float maxDist) {
    float distFromPole = dist(center.x, center.y, primaryPole.x, primaryPole.y);
    float alpha = map(distFromPole, 0, maxDist, 255, 60);
    
    stroke(pentagonStroke, alpha);
    strokeWeight(1.2);
    fill(pentagonStroke, alpha * 0.04);
    
    beginShape();
    for (int i = 0; i < 5; i++) {
      vertex(vertices[i].x, vertices[i].y);
    }
    endShape(CLOSE);
  }
}
