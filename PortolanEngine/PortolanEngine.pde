/**
 * PORTOLAN ENGINE - Processing Version
 * Relational Grid Generator for Design
 * 
 * Controls:
 * - Click to add nodes (free mode) or connect nodes (template mode)
 * - UP/DOWN arrows: Change connections per node (free mode only)
 * - LEFT/RIGHT arrows: Adjust Phi tension
 * - 'c' or 'C': Clear all nodes
 * - 'e' or 'E': Export coordinates to JSON
 * - 'm' or 'M': Toggle historic map overlay (template mode only)
 * - 's' or 'S': Save canvas as image
 * - DELETE/BACKSPACE: Remove last connection (template mode) or node (free mode)
 * - ESC: Close template selector / Exit template mode
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
int checkboxY = 295;

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
  
  // Set templates path relative to sketch
  templatesPath = sketchPath("templates");
  
  // Scan for template files
  scanTemplateFiles();
}

void draw() {
  background(bgColor);
  
  drawCanvasArea();
  
  if (templateMode) {
    drawManualConnections();
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
  
  // Connections per node (disabled in template mode)
  textFont(fontRegular);
  fill(templateMode ? disabledColor : #cbd5e1);
  textSize(14);
  text("Connections per Node:", px + margin, yPos);
  textFont(fontBold);
  fill(templateMode ? disabledColor : accentColor);
  textAlign(RIGHT);
  textSize(16);
  text(templateMode ? "Manual" : str(connectionsPerNode), px + panelWidth - margin, yPos);
  textAlign(LEFT);
  yPos += 24;
  
  connectionsSliderY = yPos;
  drawSlider(px + margin, yPos, panelWidth - 2*margin, connectionsPerNode, 1, 5, 
             templateMode ? disabledColor : accentColor, templateMode);
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
  textSize(14);
  text("Show Historic Map", px + margin + 28, yPos);
  
  // Show hint if disabled
  if (!templateMode) {
    fill(#64748b);
    textSize(9);
    text("(select a form first)", px + margin + 28, yPos + 14);
  }
  yPos += 45;
  
  // Separator
  stroke(#334155);
  line(px + margin, yPos - 18, px + panelWidth - margin, yPos - 18);
  
  // Section: Analysis Output
  textFont(fontBold);
  fill(textColor);
  textSize(13);
  text("OUTPUT ANALYSIS", px + margin, yPos);
  yPos += 28;
  
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
  
  // Connections slider (only in free mode)
  if (!templateMode && mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > connectionsSliderY - 10 && mouseY < connectionsSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    connectionsPerNode = round(map(pct, 0, 1, 1, 5));
    return;
  }
  
  // Phi slider
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + sliderWidth &&
      mouseY > phiSliderY - 10 && mouseY < phiSliderY + 10) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    phiTension = map(pct, 0, 1, 1.0, 2.0);
    return;
  }
  
  // Checkbox - only works in template mode with a map image
  if (mouseX > px + sliderMargin && mouseX < px + sliderMargin + 18 &&
      mouseY > checkboxY - 12 && mouseY < checkboxY + 6) {
    if (templateMode && historicMapImage != null) {
      showHistoricMap = !showHistoricMap;
    }
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
  if (!templateMode && mouseY > connectionsSliderY - 20 && mouseY < connectionsSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    connectionsPerNode = round(map(pct, 0, 1, 1, 5));
    return;
  }
  
  // Phi slider
  if (mouseY > phiSliderY - 20 && mouseY < phiSliderY + 20) {
    float pct = constrain((mouseX - (px + sliderMargin)) / sliderWidth, 0, 1);
    phiTension = map(pct, 0, 1, 1.0, 2.0);
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
  
  // Connections adjustment (free mode only)
  if (!templateMode) {
    if (keyCode == UP) {
      connectionsPerNode = min(5, connectionsPerNode + 1);
    } else if (keyCode == DOWN) {
      connectionsPerNode = max(1, connectionsPerNode - 1);
    }
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
}

void clearCanvas() {
  if (templateMode) {
    manualConnections.clear();
    selectedNodeForConnection = null;
  } else {
    nodes.clear();
  }
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
  export.setJSONArray("nodes", jsonNodes);
  
  String filename = "portolan_export_" + year() + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + ".json";
  saveJSONObject(export, filename);
  println("Exported to: " + filename);
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
