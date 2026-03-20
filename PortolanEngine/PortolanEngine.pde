/**
 * PORTOLAN ENGINE - Processing Version
 * Generatore di Griglie Relazionali per il Design
 * 
 * Controls:
 * - Click to add nodes
 * - UP/DOWN arrows: Change connections per node
 * - LEFT/RIGHT arrows: Adjust Phi tension
 * - 'c' or 'C': Clear all nodes
 * - 'e' or 'E': Export coordinates to JSON
 * - 't' or 'T': Cycle through templates
 * - 'm' or 'M': Toggle map/grid overlay
 * - 's' or 'S': Save canvas as image
 * - DELETE/BACKSPACE: Remove last node
 */

// === CONFIGURATION ===
int connectionsPerNode = 2;
float phiTension = 1.618;
boolean showMapOverlay = true;
int currentTemplate = 0;

// === DATA STRUCTURES ===
ArrayList<Node> nodes;
ArrayList<Node> fixedNodes;  // Template fixed points

// === COLORS (matching original design) ===
color bgColor = #0f172a;
color panelBg = #1e293b;
color nodeColor = #f97316;      // Orange
color nodeGlow = #f9731630;     // Orange with alpha
color lineColor = #f9731699;    // Orange connections
color cellColor = #14b8a666;    // Teal cells
color cellFill = #14b8a608;     // Teal fill
color textColor = #f8fafc;
color accentColor = #f97316;
color tealColor = #14b8a6;

// === UI DIMENSIONS ===
int panelWidth = 320;
int canvasLeft = 0;
int canvasWidth;

// === FONTS ===
PFont fontBold;
PFont fontRegular;

// === TEMPLATES ===
String[] templateNames = {
  "Vuoto (Libero)",
  "Triangolo",
  "Quadrato", 
  "Pentagono",
  "Esagono",
  "Griglia 3x3",
  "Cerchio (8 punti)",
  "Stella a 5 punte"
};

void setup() {
  size(1200, 800);
  smooth(8);
  
  // Create fonts - using system fonts for bold text
  fontBold = createFont("SansSerif.bold", 32);
  fontRegular = createFont("SansSerif", 32);
  
  canvasWidth = width - panelWidth;
  
  nodes = new ArrayList<Node>();
  fixedNodes = new ArrayList<Node>();
  
  loadTemplate(currentTemplate);
}

void draw() {
  background(bgColor);
  
  // Draw canvas area
  drawCanvasArea();
  
  // Draw connections and cells
  drawConnections();
  
  // Draw nodes
  drawNodes();
  
  // Draw control panel
  drawControlPanel();
}

// === CANVAS AREA ===
void drawCanvasArea() {
  // Canvas background
  fill(#0f172a);
  stroke(#334155);
  strokeWeight(1);
  rect(20, 20, canvasWidth - 40, height - 40, 16);
  
  // Grid overlay
  if (showMapOverlay) {
    stroke(#33415540);
    strokeWeight(0.5);
    int gridSize = 50;
    for (int x = 20; x < canvasWidth - 20; x += gridSize) {
      line(x, 20, x, height - 20);
    }
    for (int y = 20; y < height - 20; y += gridSize) {
      line(20, y, canvasWidth - 20, y);
    }
  }
}

// === DRAWING FUNCTIONS ===
void drawConnections() {
  if (nodes.size() < 1) return;
  
  for (Node node : nodes) {
    // Get nearest neighbors
    ArrayList<NodeDistance> distances = new ArrayList<NodeDistance>();
    
    for (Node other : nodes) {
      if (other != node) {
        float d = dist(node.x, node.y, other.x, other.y);
        distances.add(new NodeDistance(other, d));
      }
    }
    
    // Sort by distance
    java.util.Collections.sort(distances);
    
    // Connect to N nearest
    int limit = min(connectionsPerNode, distances.size());
    for (int i = 0; i < limit; i++) {
      Node target = distances.get(i).node;
      
      // Draw primary connection line
      stroke(lineColor);
      strokeWeight(1.5);
      line(node.x, node.y, target.x, target.y);
      
      // Draw rhombic cell
      drawRhombicCell(node, target);
    }
  }
}

void drawRhombicCell(Node p1, Node p2) {
  float midX = (p1.x + p2.x) / 2;
  float midY = (p1.y + p2.y) / 2;
  float d = dist(p1.x, p1.y, p2.x, p2.y);
  float angle = atan2(p2.y - p1.y, p2.x - p1.x);
  
  // Rhomb amplitude guided by Phi
  float offset = d / (phiTension * 2.2);
  
  float v1x = midX + cos(angle + HALF_PI) * offset;
  float v1y = midY + sin(angle + HALF_PI) * offset;
  float v2x = midX + cos(angle - HALF_PI) * offset;
  float v2y = midY + sin(angle - HALF_PI) * offset;
  
  // Draw rhombic shape
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

void drawNodes() {
  for (Node node : nodes) {
    // Outer glow
    noFill();
    stroke(nodeGlow);
    strokeWeight(1);
    ellipse(node.x, node.y, 24, 24);
    
    // Inner node
    if (node.isFixed) {
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
  int py = 0;
  
  // Panel background
  fill(panelBg);
  noStroke();
  rect(px, py, panelWidth, height);
  
  // Left border
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
  yPos += 22;
  
  textFont(fontRegular);
  fill(#94a3b8);
  textSize(12);
  text("Generatore di Griglie Relazionali", px + margin, yPos);
  yPos += 45;
  
  // Separator
  stroke(#334155);
  strokeWeight(1);
  line(px + margin, yPos - 18, px + panelWidth - margin, yPos - 18);
  
  // Section: Input
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  text("INPUT: NODI & TRAIETTORIE", px + margin, yPos);
  yPos += 32;
  
  // Connections per node
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(14);
  text("Connessioni per Nodo:", px + margin, yPos);
  textFont(fontBold);
  fill(accentColor);
  textAlign(RIGHT);
  textSize(16);
  text(str(connectionsPerNode), px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 24;
  
  // Slider visual
  drawSlider(px + margin, yPos, panelWidth - 2*margin, connectionsPerNode, 1, 5, accentColor);
  yPos += 38;
  
  // Phi tension
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(14);
  text("Tensione Rombica (Phi):", px + margin, yPos);
  textFont(fontBold);
  fill(tealColor);
  textAlign(RIGHT);
  textSize(16);
  text(nf(phiTension, 1, 3), px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 24;
  
  // Slider visual
  drawSlider(px + margin, yPos, panelWidth - 2*margin, phiTension, 1.0, 2.0, tealColor);
  yPos += 38;
  
  // Show map checkbox
  fill(showMapOverlay ? tealColor : #64748b);
  noStroke();
  rect(px + margin, yPos - 12, 18, 18, 3);
  if (showMapOverlay) {
    fill(bgColor);
    textFont(fontBold);
    textSize(14);
    text("✓", px + margin + 3, yPos + 2);
  }
  textFont(fontRegular);
  fill(#cbd5e1);
  textSize(14);
  text("Mostra Mappa Storica", px + margin + 28, yPos);
  yPos += 45;
  
  // Separator
  stroke(#334155);
  line(px + margin, yPos - 18, px + panelWidth - margin, yPos - 18);
  
  // Section: Analysis Output
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  text("ANALISI OUTPUT", px + margin, yPos);
  yPos += 28;
  
  // Stats boxes
  int boxW = (panelWidth - 3*margin) / 2;
  int boxH = 70;
  
  // Nodi Attivi box
  fill(#0f172a);
  stroke(#334155);
  strokeWeight(1);
  rect(px + margin, yPos, boxW, boxH, 10);
  textFont(fontRegular);
  fill(#64748b);
  textSize(11);
  text("NODI ATTIVI", px + margin + 12, yPos + 22);
  textFont(fontBold);
  fill(accentColor);
  textSize(28);
  text(str(nodes.size()), px + margin + 12, yPos + 55);
  
  // Celle Generative box
  fill(#0f172a);
  stroke(#334155);
  rect(px + margin + boxW + margin, yPos, boxW, boxH, 10);
  textFont(fontRegular);
  fill(#64748b);
  textSize(11);
  text("CELLE GENERATIVE", px + margin + boxW + margin + 10, yPos + 22);
  textFont(fontBold);
  fill(tealColor);
  textSize(28);
  text(str(max(0, nodes.size() - 1)), px + margin + boxW + margin + 10, yPos + 55);
  
  yPos += boxH + 18;
  
  // Data log area
  fill(#0a0f1a);
  stroke(#1e293b);
  strokeWeight(1);
  int logHeight = 140;
  rect(px + margin, yPos, panelWidth - 2*margin, logHeight, 10);
  
  textFont(fontRegular);
  fill(#14b8a6cc);
  textSize(11);
  int logY = yPos + 18;
  int lineHeight = 14;
  int maxLines = (logHeight - 20) / lineHeight;
  int displayCount = min(nodes.size(), maxLines);
  int startIdx = max(0, nodes.size() - displayCount);
  
  if (nodes.size() == 0) {
    fill(#64748b);
    text("// In attesa di input...", px + margin + 12, logY);
  } else {
    for (int i = startIdx; i < nodes.size(); i++) {
      Node n = nodes.get(i);
      String prefix = n.isFixed ? "[F] " : "";
      text(prefix + "NODE_" + n.id + " [" + round(n.x) + "," + round(n.y) + "]", px + margin + 12, logY);
      logY += lineHeight;
    }
  }
  
  // Bottom section - fixed position from bottom
  int bottomY = height - 100;
  
  // Clear button
  fill(#1e293b);
  stroke(#475569);
  strokeWeight(1);
  rect(px + margin, bottomY, panelWidth - 2*margin, 38, 8);
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  textAlign(CENTER);
  text("PULISCI FRAMEWORK", px + panelWidth/2, bottomY + 25);
  
  bottomY += 48;
  
  // Export button
  fill(accentColor);
  noStroke();
  rect(px + margin, bottomY, panelWidth - 2*margin, 42, 10);
  fill(textColor);
  textSize(14);
  text("Esporta Coordinate (JSON)", px + panelWidth/2, bottomY + 28);
  
  textAlign(LEFT);
  textFont(fontRegular);
}

void drawSlider(float x, float y, float w, float value, float minVal, float maxVal, color c) {
  // Track background
  noStroke();
  fill(#334155);
  rect(x, y - 3, w, 6, 3);
  
  // Filled portion
  float pct = map(value, minVal, maxVal, 0, 1);
  fill(c);
  rect(x, y - 3, w * pct, 6, 3);
  
  // Handle
  fill(c);
  noStroke();
  ellipse(x + w * pct, y, 16, 16);
}

// === INPUT HANDLING ===

// Store UI element positions for click detection
int sliderMargin = 24;
int connectionsSliderY = 163;
int phiSliderY = 225;
int checkboxY = 263;
int clearBtnY;
int exportBtnY;

void mousePressed() {
  int px = canvasWidth;
  float sliderWidth = panelWidth - 2 * sliderMargin;
  
  // Update button positions
  clearBtnY = height - 100;
  exportBtnY = height - 52;
  
  // Check if click is on Connections slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > connectionsSliderY - 10 && mouseY < connectionsSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    connectionsPerNode = round(map(pct, 0, 1, 1, 5));
    return;
  }
  
  // Check if click is on Phi slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > phiSliderY - 10 && mouseY < phiSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    phiTension = map(pct, 0, 1, 1.0, 2.0);
    return;
  }
  
  // Check if click is on checkbox
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + 18 &&
      mouseY > checkboxY - 12 && mouseY < checkboxY + 6) {
    showMapOverlay = !showMapOverlay;
    return;
  }
  
  // Check if click is on Clear button
  if (mouseX > px + sliderMargin && mouseX < px + panelWidth - sliderMargin &&
      mouseY > clearBtnY && mouseY < clearBtnY + 38) {
    nodes.clear();
    loadTemplate(currentTemplate);
    return;
  }
  
  // Check if click is on Export button
  if (mouseX > px + sliderMargin && mouseX < px + panelWidth - sliderMargin &&
      mouseY > exportBtnY && mouseY < exportBtnY + 42) {
    exportJSON();
    return;
  }
  
  // Check if click is in canvas area (add node)
  if (mouseX > 20 && mouseX < canvasWidth - 20 && mouseY > 20 && mouseY < height - 20) {
    nodes.add(new Node(mouseX, mouseY, nodes.size(), false));
  }
}

void mouseDragged() {
  int px = canvasWidth;
  float sliderWidth = panelWidth - 2 * sliderMargin;
  
  // Drag on Connections slider
  if (mouseX > px + sliderMargin - 20 && mouseX < px + sliderMargin + sliderWidth + 20 &&
      mouseY > connectionsSliderY - 15 && mouseY < connectionsSliderY + 15) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    connectionsPerNode = round(map(pct, 0, 1, 1, 5));
    return;
  }
  
  // Drag on Phi slider
  if (mouseX > px + sliderMargin - 20 && mouseX < px + sliderMargin + sliderWidth + 20 &&
      mouseY > phiSliderY - 15 && mouseY < phiSliderY + 15) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    phiTension = map(pct, 0, 1, 1.0, 2.0);
    return;
  }
}

void keyPressed() {
  // Connections adjustment
  if (keyCode == UP) {
    connectionsPerNode = min(5, connectionsPerNode + 1);
  } else if (keyCode == DOWN) {
    connectionsPerNode = max(1, connectionsPerNode - 1);
  }
  
  // Phi adjustment
  if (keyCode == RIGHT) {
    phiTension = min(2.0, phiTension + 0.05);
  } else if (keyCode == LEFT) {
    phiTension = max(1.0, phiTension - 0.05);
  }
  
  // Clear
  if (key == 'c' || key == 'C') {
    nodes.clear();
    loadTemplate(currentTemplate);
  }
  
  // Export
  if (key == 'e' || key == 'E') {
    exportJSON();
  }
  
  // Save image
  if (key == 's' || key == 'S') {
    saveFrame("portolan_export_####.png");
    println("Image saved!");
  }
  
  // Toggle map
  if (key == 'm' || key == 'M') {
    showMapOverlay = !showMapOverlay;
  }
  
  // Cycle templates
  if (key == 't' || key == 'T') {
    currentTemplate = (currentTemplate + 1) % templateNames.length;
    nodes.clear();
    loadTemplate(currentTemplate);
  }
  
  // Delete last node
  if (keyCode == DELETE || keyCode == BACKSPACE) {
    if (nodes.size() > 0) {
      Node last = nodes.get(nodes.size() - 1);
      if (!last.isFixed) {
        nodes.remove(nodes.size() - 1);
      }
    }
  }
}

// === TEMPLATES ===
void loadTemplate(int templateIndex) {
  float cx = (canvasWidth - 40) / 2 + 20;
  float cy = height / 2;
  float radius = min(canvasWidth - 100, height - 100) / 3;
  
  switch(templateIndex) {
    case 0: // Empty
      break;
      
    case 1: // Triangle
      addPolygonPoints(3, cx, cy, radius);
      break;
      
    case 2: // Square
      addPolygonPoints(4, cx, cy, radius);
      break;
      
    case 3: // Pentagon
      addPolygonPoints(5, cx, cy, radius);
      break;
      
    case 4: // Hexagon
      addPolygonPoints(6, cx, cy, radius);
      break;
      
    case 5: // 3x3 Grid
      addGridPoints(3, 3, cx, cy, radius * 1.5);
      break;
      
    case 6: // Circle (8 points)
      addPolygonPoints(8, cx, cy, radius);
      break;
      
    case 7: // 5-point star
      addStarPoints(5, cx, cy, radius, radius * 0.4);
      break;
  }
}

void addPolygonPoints(int n, float cx, float cy, float r) {
  for (int i = 0; i < n; i++) {
    float angle = TWO_PI * i / n - HALF_PI;
    float x = cx + cos(angle) * r;
    float y = cy + sin(angle) * r;
    nodes.add(new Node(x, y, nodes.size(), true));
  }
}

void addGridPoints(int cols, int rows, float cx, float cy, float size) {
  float cellW = size / (cols - 1);
  float cellH = size / (rows - 1);
  float startX = cx - size/2;
  float startY = cy - size/2;
  
  for (int row = 0; row < rows; row++) {
    for (int col = 0; col < cols; col++) {
      float x = startX + col * cellW;
      float y = startY + row * cellH;
      nodes.add(new Node(x, y, nodes.size(), true));
    }
  }
}

void addStarPoints(int points, float cx, float cy, float outerR, float innerR) {
  for (int i = 0; i < points * 2; i++) {
    float angle = TWO_PI * i / (points * 2) - HALF_PI;
    float r = (i % 2 == 0) ? outerR : innerR;
    float x = cx + cos(angle) * r;
    float y = cy + sin(angle) * r;
    nodes.add(new Node(x, y, nodes.size(), true));
  }
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
  
  // Create export object with metadata
  JSONObject export = new JSONObject();
  export.setString("name", "Portolan Export");
  export.setString("template", templateNames[currentTemplate]);
  export.setInt("connectionsPerNode", connectionsPerNode);
  export.setFloat("phiTension", phiTension);
  export.setJSONArray("nodes", jsonNodes);
  
  // Save with timestamp
  String filename = "portolan_export_" + year() + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + ".json";
  saveJSONObject(export, filename);
  println("Exported to: " + filename);
}

// === HELPER CLASSES ===
class Node {
  float x, y;
  int id;
  boolean isFixed;  // Template fixed point vs user-added
  
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
