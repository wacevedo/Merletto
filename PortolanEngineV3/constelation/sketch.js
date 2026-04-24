const SketchMode = {
    VERTEX: 'VERTEX',
    EDGE: 'EDGE',
};

class SketchApp {
    constructor() {
        this.gridSize = Settings.canvas.gridSize;
        this.state = {
            mesh: null,
            mode: SketchMode.VERTEX,
            selectionIndex: -1,
            parameters: {
                tau: Settings.pattern.tau.default,
                lambda: Settings.pattern.lambda.default
            },
            graphParameters: {
                triSize: Settings.graph.triSize.default,
                kingSize: Settings.graph.kingSize.default,
                spiderLayers: Settings.graph.spiderLayers.default,
                spiderPoints: Settings.graph.spiderPoints.default,
                randomPoints: Settings.graph.randomPoints.default,
            },
            geometry: {
                circles: {},
                polygons: {},
                pentagons: [],
            },
            toggles: {
                showPacking: false,
                showTiles: false,
            },
            edges: [],
            currentGraph: 'tri',
        };
        this.ui = {
            canvas: null,
            tauSlider: null,
            lambdaSlider: null,
            tauLabel: null,
            lambdaLabel: null,
            showPackingCheckbox: null,
            showTilesCheckbox: null,
            triSizeSlider: null,
            spiderLayersSlider: null,
            spiderPointsSlider: null,
            kingSizeSlider: null,
            randomPointsSlider: null,
        };
    }

    setup() {
        this.createCanvas();
        this.createControls();
        this.resetGeometry();
        // Initialize with triangular grid (matches default dropdown selection)
        this.setDefaultGraph('tri');
        noLoop();
    }

    createCanvas() {
        pixelDensity(Settings.canvas.pixelDensity); // High-resolution rendering for crisp visuals
        const canvas = createCanvas(Settings.canvas.width, Settings.canvas.height);
        canvas.parent(document.getElementById('app'));
        this.ui.canvas = canvas;
    }

    createControls() {
        const { tau, lambda } = this.state.parameters;
        const { triSize, spiderLayers, spiderPoints, kingSize, randomPoints } = this.state.graphParameters;

        // Initialize display values from Settings
        const tauValueSpan = document.getElementById('tau-value');
        if (tauValueSpan) tauValueSpan.textContent = tau.toFixed(2);
        const lambdaValueSpan = document.getElementById('lambda-value');
        if (lambdaValueSpan) lambdaValueSpan.textContent = lambda.toFixed(2);

        // Create pattern parameter sliders
        const tauSlider = createSlider(
            Settings.pattern.tau.min,
            Settings.pattern.tau.max,
            tau,
            Settings.pattern.tau.step
        );
        const lambdaSlider = createSlider(
            Settings.pattern.lambda.min,
            Settings.pattern.lambda.max,
            lambda,
            Settings.pattern.lambda.step
        );

        tauSlider.parent('tau-slider-container');
        lambdaSlider.parent('lambda-slider-container');

        tauSlider.class('param-slider');
        lambdaSlider.class('param-slider');

        tauSlider.input(() => this.updateParameter('tau', tauSlider.value()));
        lambdaSlider.input(() => this.updateParameter('lambda', lambdaSlider.value()));

        // Create graph parameter sliders
        // Use input() for live label updates and changed() for actual recomputation
        const triSizeSlider = createSlider(
            Settings.graph.triSize.min,
            Settings.graph.triSize.max,
            triSize,
            Settings.graph.triSize.step
        );
        triSizeSlider.parent('tri-size-slider-container');
        triSizeSlider.class('param-slider');
        triSizeSlider.input(() => this.updateGraphParameterLabel('triSize', triSizeSlider.value()));
        triSizeSlider.changed(() => this.updateGraphParameter('triSize', triSizeSlider.value()));

        const spiderLayersSlider = createSlider(
            Settings.graph.spiderLayers.min,
            Settings.graph.spiderLayers.max,
            spiderLayers,
            Settings.graph.spiderLayers.step
        );
        spiderLayersSlider.parent('spider-layers-slider-container');
        spiderLayersSlider.class('param-slider');
        spiderLayersSlider.input(() => this.updateGraphParameterLabel('spiderLayers', spiderLayersSlider.value()));
        spiderLayersSlider.changed(() => this.updateGraphParameter('spiderLayers', spiderLayersSlider.value()));

        const spiderPointsSlider = createSlider(
            Settings.graph.spiderPoints.min,
            Settings.graph.spiderPoints.max,
            spiderPoints,
            Settings.graph.spiderPoints.step
        );
        spiderPointsSlider.parent('spider-points-slider-container');
        spiderPointsSlider.class('param-slider');
        spiderPointsSlider.input(() => this.updateGraphParameterLabel('spiderPoints', spiderPointsSlider.value()));
        spiderPointsSlider.changed(() => this.updateGraphParameter('spiderPoints', spiderPointsSlider.value()));

        const kingSizeSlider = createSlider(
            Settings.graph.kingSize.min,
            Settings.graph.kingSize.max,
            kingSize,
            Settings.graph.kingSize.step
        );
        kingSizeSlider.parent('king-size-slider-container');
        kingSizeSlider.class('param-slider');
        kingSizeSlider.input(() => this.updateGraphParameterLabel('kingSize', kingSizeSlider.value()));
        kingSizeSlider.changed(() => this.updateGraphParameter('kingSize', kingSizeSlider.value()));

        const randomPointsSlider = createSlider(
            Settings.graph.randomPoints.min,
            Settings.graph.randomPoints.max,
            randomPoints,
            Settings.graph.randomPoints.step
        );
        randomPointsSlider.parent('random-points-slider-container');
        randomPointsSlider.class('param-slider');
        randomPointsSlider.input(() => this.updateGraphParameterLabel('randomPoints', randomPointsSlider.value()));
        randomPointsSlider.changed(() => this.updateGraphParameter('randomPoints', randomPointsSlider.value()));

        // Create checkboxes
        const showPackingCheckbox = createCheckbox('Show Packing', false);
        const showTilesCheckbox = createCheckbox('Show Tiling', false);

        showPackingCheckbox.parent('packing-checkbox-container');
        showTilesCheckbox.parent('tiling-checkbox-container');

        showPackingCheckbox.class('param-checkbox');
        showTilesCheckbox.class('param-checkbox');

        showPackingCheckbox.changed(() => {
            this.state.toggles.showPacking = showPackingCheckbox.checked();
            this.requestRedraw();
        });
        showTilesCheckbox.changed(() => {
            this.state.toggles.showTiles = showTilesCheckbox.checked();
            this.requestRedraw();
        });

        this.ui = {
            ...this.ui,
            tauSlider,
            lambdaSlider,
            showPackingCheckbox,
            showTilesCheckbox,
            triSizeSlider,
            spiderLayersSlider,
            spiderPointsSlider,
            kingSizeSlider,
            randomPointsSlider,
        };
    }

    resetGeometry() {
        this.state.mesh = new Mesh();
        this.state.mode = SketchMode.VERTEX;
        this.state.selectionIndex = -1;
        this.state.geometry = {
            circles: {},
            polygons: {},
            pentagons: [],
        };
        this.state.edges = [];
    }

    seedDefaultPoints(rows = 8, cols = 8, spacing = 10 * this.gridSize) {
        const { mesh } = this.state;

        // Calculate the total size of the grid
        const gridWidth = (cols - 1) * spacing;
        const gridHeight = (rows - 1) * spacing;

        // Center on the left half of the canvas
        const centerX = width / 4;
        const centerY = height / 2;

        // Calculate starting position to center the grid
        const startX = centerX - gridWidth / 2;
        const startY = centerY - gridHeight / 2;

        const offset = spacing / 2;

        // Create main grid points
        for (let i = 0; i < rows; i++) {
            for (let j = 0; j < cols; j++) {
                const x = startX + j * spacing;
                const y = startY + i * spacing;
                mesh.addPoint(new Point(x, y));
            }
        }

        // Create offset grid points
        for (let i = 0; i < rows - 1; i++) {
            for (let j = 0; j < cols - 1; j++) {
                const x = startX + offset + j * spacing;
                const y = startY + offset + i * spacing;
                mesh.addPoint(new Point(x, y));
            }
        }
    }

    draw() {
        if (!this.state.mesh) {
            return;
        }

        background(255);
        this.state.mesh.recompute();
        this.state.geometry.circles = {};
        this.state.geometry.polygons = {};
        this.state.geometry.pentagons = [];

        this.drawMesh();
        this.buildCirclePacking();
        this.renderPolygonsAndPentagons();
    }

    drawMesh() {
        push();
        noStroke();
        fill(Settings.colors.graph.background);
        rect(0, 0, width / 2, height);
        this.drawGrid(this.gridSize);
        this.drawTriangles();
        this.drawConstrainedEdges();
        this.drawVertices();
        this.drawDraggedEdge();
        pop();
    }

    drawGrid(spacing) {
        noStroke();
        const c = Settings.colors.graph.gridDots;
        fill(c.r, c.g, c.b, c.a);
        for (let x = 0; x <= width / 2; x += spacing) {
            for (let y = 0; y <= height; y += spacing) {
                circle(x, y, Settings.visual.gridDotSize);
            }
        }
    }

    drawTriangles() {
        noFill();
        const c = Settings.colors.graph.triangles;
        stroke(c.r, c.g, c.b);
        strokeWeight(Settings.visual.triangleStrokeWeight);
        for (const triangle of this.state.mesh.tri) {
            for (let i = 0; i < 3; ++i) {
                const p = this.state.mesh.vert[triangle[i]];
                const q = this.state.mesh.vert[triangle[(i + 1) % 3]];
                line(p.x, p.y, q.x, q.y);
            }
        }
    }

    drawConstrainedEdges() {
        strokeWeight(Settings.visual.constrainedEdgeStrokeWeight);
        stroke(Settings.colors.graph.constrainedEdges);
        for (const edge of this.state.mesh.con_edge) {
            const p = this.state.mesh.vert[edge[0]];
            const q = this.state.mesh.vert[edge[1]];
            line(p.x, p.y, q.x, q.y);
        }
    }

    drawVertices() {
        noStroke();
        const numPoints = this.state.mesh.numPoints();

        for (let idx = 0; idx < numPoints; ++idx) {
            // Assign color based on index using HSB color space for rainbow gradient
            const hue = (idx / numPoints) * 360;
            const color = this.getVertexColor(idx, numPoints);

            if (this.state.mesh.vert_props[idx].boundary) {
                fill(color);
                const bs = Settings.colors.graph.vertex.boundaryStroke;
                stroke(bs.r, bs.g, bs.b);
                strokeWeight(Settings.visual.vertexStrokeWeight);
            } else {
                fill(color);
                noStroke();
            }
            const point = this.state.mesh.vert[idx];
            circle(point.x, point.y, Settings.visual.vertexSize);
        }
    }

    getVertexColor(idx, total) {
        // Create a rainbow gradient using HSB color space
        push();
        colorMode(HSB, 360, 100, 100);
        const vertexColorSettings = Settings.getVertexColor(idx, total);
        const col = color(vertexColorSettings.hue, vertexColorSettings.saturation, vertexColorSettings.brightness);
        pop();
        return col;
    }

    drawDraggedEdge() {
        if (this.state.mode === SketchMode.EDGE && this.state.selectionIndex >= 0) {
            stroke(Settings.colors.graph.draggedEdge);
            strokeWeight(Settings.visual.draggedEdgeStrokeWeight);
            const point = this.state.mesh.vert[this.state.selectionIndex];
            line(point.x, point.y, mouseX, mouseY);
        }
    }

    buildCirclePacking() {
        const { mesh, geometry, toggles, parameters } = this.state;
        const boundingBox = computeBoundingBox(mesh);
        const scaleBase = Math.max(boundingBox.width, boundingBox.height);
        // Scale to fit within right half (50% of canvas width), with some padding
        const scale = scaleBase === 0 ? 1 : (0.42 * width) / scaleBase;

        const circles = {};
        const numPoints = mesh.numPoints();

        for (let idx = 0; idx < numPoints; ++idx) {
            const props = mesh.vert_props[idx];
            if (props.hasOwnProperty('center')) {
                const center = props.center;
                const radius = props.radius;

                // Get the vertex color
                const vertexColor = this.getVertexColor(idx, numPoints);

                const circleObj = new Circle(
                    idx,
                    width * 0.75 + (center.x - boundingBox.center.x) * scale,
                    height * 0.5 + (center.y - boundingBox.center.y) * scale,
                    radius * scale * 2,
                    props.boundary,
                    vertexColor
                );
                circles[idx] = circleObj;
                if (toggles.showPacking) {
                    circleObj.display();
                }
            }
        }
        geometry.circles = circles;

        populateCircleInformation(mesh, circles);

        const polygons = {};
        for (const circle of Object.values(circles)) {
            if (!circle.boundary) {
                circle.buildCyclicPolygon(parameters.tau, polygons);
            } else {
                circle.gon = null;
            }
        }
        geometry.polygons = polygons;
    }

    renderPolygonsAndPentagons() {
        const { polygons, circles } = this.state.geometry;
        strokeWeight(1);
        for (const polygon of Object.values(polygons)) {
            if (this.state.toggles.showTiles) {
                polygon.display();
            }
            polygon.motif(this.state.parameters.lambda);
        }

        const pentagons = build3Patch(
            this.state.mesh,
            circles,
            polygons,
            this.state.parameters.tau
        );
        this.state.geometry.pentagons = pentagons;
        pentagons.forEach(pentagon => {
            if (this.state.toggles.showTiles) {
                pentagon.display();
            }
            pentagon.motif(this.state.parameters.lambda);
        });
    }

    mousePressed() {
        if (!this.isWithinEditableArea(mouseX, mouseY)) {
            this.state.selectionIndex = -1;
            return;
        }

        const snapped = this.snapToGrid(mouseX, mouseY);
        const existingIndex = this.findVertexIndexNear(snapped.x, snapped.y);
        if (existingIndex !== -1) {
            this.state.selectionIndex = existingIndex;
            if (this.state.mode === SketchMode.VERTEX && keyIsPressed && keyCode === SHIFT) {
                this.state.mesh.removePoint(existingIndex);
                this.state.selectionIndex = -1;
                this.requestRedraw();
            }
            return;
        }

        if (this.state.mode === SketchMode.VERTEX) {
            // Prevent adding a point too close to an existing point
            if (!this.isPositionTooCloseToAnyPoint(snapped.x, snapped.y)) {
                this.state.mesh.addPoint(new Point(snapped.x, snapped.y));
            }
        } else {
            this.state.selectionIndex = -1;
        }
        this.requestRedraw();
    }

    mouseDragged() {
        if (this.state.mode === SketchMode.VERTEX && this.state.selectionIndex >= 0) {
            const snapped = this.snapToGrid(mouseX, mouseY);
            // Ensure the dragged position is within the editable area (left side of canvas)
            if (!this.isWithinEditableArea(snapped.x, snapped.y)) {
                // Clamp to the editable area boundaries
                const margin = 10;
                snapped.x = Math.max(margin, Math.min(width / 2 - margin, snapped.x));
                snapped.y = Math.max(margin, Math.min(height - margin, snapped.y));
            }
            // Prevent dragging a point too close to another point
            if (!this.isPositionTooCloseToAnyPoint(snapped.x, snapped.y, this.state.selectionIndex)) {
                this.state.mesh.setPoint(this.state.selectionIndex, new Point(snapped.x, snapped.y));
            }
        }
        this.requestRedraw();
    }

    mouseReleased() {
        if (this.state.mode === SketchMode.EDGE && this.state.selectionIndex >= 0) {
            // Only allow creating edges if the mouse is released within the editable area
            if (this.isWithinEditableArea(mouseX, mouseY)) {
                const targetIndex = this.findVertexIndexNear(mouseX, mouseY, 7);
                if (targetIndex !== -1) {
                    this.state.mesh.addConstraint(this.state.selectionIndex, targetIndex);
                }
            }
        }
        this.state.selectionIndex = -1;
        this.requestRedraw();
    }

    keyPressed() {
        if (key === 'v') {
            this.setMode(SketchMode.VERTEX);
        } else if (key === 'e') {
            this.setMode(SketchMode.EDGE);
        } else if (keyCode === ENTER) {
            this.resetGeometry();
        } else if (key === ' ') {
            this.resetGeometry();
            this.seedDefaultPoints();
        } else if (key === 'c') {
            this.exportEdges();
        } else if (key === 'g') {
            this.exportGraph();
        } else if (key === 'l') {
            this.promptLoadGraph();
        }
        this.requestRedraw();
    }

    setMode(mode) {
        this.state.mode = mode;
        this.state.selectionIndex = -1;
    }

    updateParameter(name, value) {
        const numeric = Number(value);
        this.state.parameters[name] = numeric;
        if (name === 'tau') {
            const tauValueSpan = document.getElementById('tau-value');
            if (tauValueSpan) tauValueSpan.textContent = numeric.toFixed(2);
        } else if (name === 'lambda') {
            const lambdaValueSpan = document.getElementById('lambda-value');
            if (lambdaValueSpan) lambdaValueSpan.textContent = numeric.toFixed(2);
        }
        this.requestRedraw();
    }

    updateGraphParameterLabel(name, value) {
        const numeric = Number(value);

        // Only update UI labels (no recomputation)
        if (name === 'triSize') {
            const span = document.getElementById('tri-size-value');
            if (span) span.textContent = numeric;
        } else if (name === 'spiderLayers') {
            const span = document.getElementById('spider-layers-value');
            if (span) span.textContent = numeric;
        } else if (name === 'spiderPoints') {
            const span = document.getElementById('spider-points-value');
            if (span) span.textContent = numeric;
        } else if (name === 'kingSize') {
            const span = document.getElementById('king-size-value');
            if (span) span.textContent = numeric;
        } else if (name === 'randomPoints') {
            const span = document.getElementById('random-points-value');
            if (span) span.textContent = numeric;
        }
    }

    showLoadingIndicator() {
        const indicator = document.getElementById('loading-indicator');
        if (indicator) {
            indicator.style.display = 'flex';
        }
    }

    hideLoadingIndicator() {
        const indicator = document.getElementById('loading-indicator');
        if (indicator) {
            indicator.style.display = 'none';
        }
    }

    updateGraphParameter(name, value) {
        const numeric = Number(value);
        this.state.graphParameters[name] = numeric;

        // Update UI label
        this.updateGraphParameterLabel(name, value);

        // Show loading indicator and regenerate graph after a short delay
        this.showLoadingIndicator();
        setTimeout(() => {
            this.setDefaultGraph(this.state.currentGraph);
            this.hideLoadingIndicator();
        }, 10); // Short delay to allow indicator to show
    }

    exportEdges() {
        // Collect edges as coordinate pairs
        const edges = [];
        const addEdge = (start, end) => {
            edges.push({ x1: start.x, y1: start.y, x2: end.x, y2: end.y });
        };

        for (const polygon of Object.values(this.state.geometry.polygons)) {
            polygon.collectEdges(this.state.parameters.lambda, addEdge);
        }
        this.state.geometry.pentagons.forEach(pentagon => {
            pentagon.collectEdges(this.state.parameters.lambda, addEdge);
        });

        if (edges.length === 0) {
            alert('No pattern to export. Add some points first!');
            return;
        }

        // Calculate bounding box
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        edges.forEach(edge => {
            minX = Math.min(minX, edge.x1, edge.x2);
            minY = Math.min(minY, edge.y1, edge.y2);
            maxX = Math.max(maxX, edge.x1, edge.x2);
            maxY = Math.max(maxY, edge.y1, edge.y2);
        });

        // Add padding
        const padding = 20;
        minX -= padding;
        minY -= padding;
        maxX += padding;
        maxY += padding;

        const width = maxX - minX;
        const height = maxY - minY;

        // Generate SVG
        let svg = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="${width}"
     height="${height}"
     viewBox="${minX} ${minY} ${width} ${height}">
  <title>Constellation Pattern</title>
  <desc>Generated pattern with τ=${this.state.parameters.tau.toFixed(2)}, λ=${this.state.parameters.lambda.toFixed(2)}</desc>

  <!-- Background -->
  <rect x="${minX}" y="${minY}" width="${width}" height="${height}" fill="${Settings.colors.export.background}"/>

  <!-- Pattern -->
  <g stroke="${Settings.colors.export.pattern}" stroke-width="${Settings.visual.patternStrokeWeight}" stroke-linecap="round" fill="none">
`;

        // Add all edges as lines
        edges.forEach(edge => {
            svg += `    <line x1="${edge.x1.toFixed(3)}" y1="${edge.y1.toFixed(3)}" x2="${edge.x2.toFixed(3)}" y2="${edge.y2.toFixed(3)}"/>\n`;
        });

        svg += `  </g>
</svg>`;

        // Download SVG
        const blob = new Blob([svg], { type: 'image/svg+xml' });
        const downloadLink = document.createElement('a');
        downloadLink.href = URL.createObjectURL(blob);
        const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
        downloadLink.download = `constellation-pattern-${timestamp}.svg`;
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);
        URL.revokeObjectURL(downloadLink.href);
    }

    colorToHex(color) {
        // Convert p5.js color to hex string
        const r = Math.round(red(color));
        const g = Math.round(green(color));
        const b = Math.round(blue(color));
        return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
    }

    exportFull() {
        // Collect pattern edges
        const edges = [];
        const addEdge = (start, end) => {
            edges.push({ x1: start.x, y1: start.y, x2: end.x, y2: end.y });
        };

        for (const polygon of Object.values(this.state.geometry.polygons)) {
            polygon.collectEdges(this.state.parameters.lambda, addEdge);
        }
        this.state.geometry.pentagons.forEach(pentagon => {
            pentagon.collectEdges(this.state.parameters.lambda, addEdge);
        });

        // Collect circles - export ALL circles, not just active ones
        // Note: circle.r stores diameter (for p5.js circle() function), but SVG uses radius
        const circles = [];
        for (const circle of Object.values(this.state.geometry.circles)) {
            if (circle) {
                let fillColor = Settings.colors.circles.default.fill;
                let opacity = Settings.colors.circles.default.opacity;

                if (circle.vertexColor) {
                    fillColor = this.colorToHex(circle.vertexColor);
                    opacity = Settings.colors.circles.vertexColored.opacity;
                } else if (circle.boundary) {
                    fillColor = Settings.colors.circles.boundary.fill;
                    opacity = Settings.colors.circles.boundary.opacity;
                }

                circles.push({
                    cx: circle.x,
                    cy: circle.y,
                    r: circle.r / 2, // Convert diameter to radius for SVG
                    fill: fillColor,
                    opacity: opacity
                });
            }
        }

        // Collect polygon outlines (tiling/scaffolding)
        const polygonOutlines = [];
        for (const polygon of Object.values(this.state.geometry.polygons)) {
            if (polygon && polygon.active && polygon.v && polygon.v.length > 0) {
                const points = polygon.v.map(v => `${v.x.toFixed(3)},${v.y.toFixed(3)}`).join(' ');
                polygonOutlines.push(points);
            }
        }

        // Collect pentagon outlines (tiling/scaffolding)
        const pentagonOutlines = [];
        for (const pentagon of this.state.geometry.pentagons) {
            if (pentagon && pentagon.v && pentagon.v.length > 0) {
                // Check if at least one neighbor is active
                const hasActiveNeighbor = (pentagon.nbr1 && pentagon.nbr1[0] && pentagon.nbr1[0].active) ||
                                         (pentagon.nbr2 && pentagon.nbr2[0] && pentagon.nbr2[0].active);
                if (hasActiveNeighbor) {
                    const points = pentagon.v.map(v => `${v.x.toFixed(3)},${v.y.toFixed(3)}`).join(' ');
                    pentagonOutlines.push(points);
                }
            }
        }

        if (edges.length === 0 && circles.length === 0) {
            alert('No pattern to export. Add some points first!');
            return;
        }

        // Calculate bounding box including all elements
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

        // Include pattern edges
        edges.forEach(edge => {
            minX = Math.min(minX, edge.x1, edge.x2);
            minY = Math.min(minY, edge.y1, edge.y2);
            maxX = Math.max(maxX, edge.x1, edge.x2);
            maxY = Math.max(maxY, edge.y1, edge.y2);
        });

        // Include circles
        circles.forEach(circle => {
            minX = Math.min(minX, circle.cx - circle.r);
            minY = Math.min(minY, circle.cy - circle.r);
            maxX = Math.max(maxX, circle.cx + circle.r);
            maxY = Math.max(maxY, circle.cy + circle.r);
        });

        // Include polygon outlines
        for (const polygon of Object.values(this.state.geometry.polygons)) {
            if (polygon && polygon.v) {
                polygon.v.forEach(v => {
                    minX = Math.min(minX, v.x);
                    minY = Math.min(minY, v.y);
                    maxX = Math.max(maxX, v.x);
                    maxY = Math.max(maxY, v.y);
                });
            }
        }

        // Include pentagon outlines
        this.state.geometry.pentagons.forEach(pentagon => {
            if (pentagon && pentagon.v) {
                pentagon.v.forEach(v => {
                    minX = Math.min(minX, v.x);
                    minY = Math.min(minY, v.y);
                    maxX = Math.max(maxX, v.x);
                    maxY = Math.max(maxY, v.y);
                });
            }
        });

        // Add padding
        const padding = 20;
        minX -= padding;
        minY -= padding;
        maxX += padding;
        maxY += padding;

        const width = maxX - minX;
        const height = maxY - minY;

        // Generate SVG with all layers
        let svg = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="${width}"
     height="${height}"
     viewBox="${minX} ${minY} ${width} ${height}">
  <title>Constellation Pattern (Full)</title>
  <desc>Generated pattern with τ=${this.state.parameters.tau.toFixed(2)}, λ=${this.state.parameters.lambda.toFixed(2)} - Includes pattern, circle packing, and tiling</desc>

  <!-- Background -->
  <rect x="${minX}" y="${minY}" width="${width}" height="${height}" fill="${Settings.colors.export.background}"/>

  <!-- Circle Packing Layer -->
  <g id="circles" opacity="1">
`;

        // Add circles
        circles.forEach(circle => {
            svg += `    <circle cx="${circle.cx.toFixed(3)}" cy="${circle.cy.toFixed(3)}" r="${circle.r.toFixed(3)}" fill="${circle.fill}" opacity="${circle.opacity}" stroke="none"/>\n`;
        });

        svg += `  </g>

  <!-- Geometric Tiling/Scaffolding Layer -->
  <g id="tiling" stroke="${Settings.colors.export.tiling}" stroke-width="${Settings.visual.tilingStrokeWeight}" fill="none" opacity="1">
`;

        // Add polygon outlines
        polygonOutlines.forEach(points => {
            svg += `    <polygon points="${points}"/>\n`;
        });

        // Add pentagon outlines
        pentagonOutlines.forEach(points => {
            svg += `    <polygon points="${points}"/>\n`;
        });

        svg += `  </g>

  <!-- Pattern Layer -->
  <g id="pattern" stroke="${Settings.colors.export.pattern}" stroke-width="${Settings.visual.patternStrokeWeight}" stroke-linecap="round" fill="none" opacity="1">
`;

        // Add pattern edges
        edges.forEach(edge => {
            svg += `    <line x1="${edge.x1.toFixed(3)}" y1="${edge.y1.toFixed(3)}" x2="${edge.x2.toFixed(3)}" y2="${edge.y2.toFixed(3)}"/>\n`;
        });

        svg += `  </g>
</svg>`;

        // Download SVG
        const blob = new Blob([svg], { type: 'image/svg+xml' });
        const downloadLink = document.createElement('a');
        downloadLink.href = URL.createObjectURL(blob);
        const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
        downloadLink.download = `constellation-full-${timestamp}.svg`;
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);
        URL.revokeObjectURL(downloadLink.href);
    }

    findVertexIndexNear(x, y, threshold = 7) {
        let index = 0;
        for (const point of this.state.mesh.vert) {
            if (dist(point.x, point.y, x, y) < threshold) {
                return index;
            }
            index += 1;
        }
        return -1;
    }

    isPositionTooCloseToAnyPoint(x, y, excludeIndex = -1, minDistance = 5) {
        let index = 0;
        for (const point of this.state.mesh.vert) {
            if (index !== excludeIndex && dist(point.x, point.y, x, y) < minDistance) {
                return true;
            }
            index += 1;
        }
        return false;
    }

    snapToGrid(x, y) {
        return {
            x: Math.round(x / this.gridSize) * this.gridSize,
            y: Math.round(y / this.gridSize) * this.gridSize,
        };
    }

    isWithinEditableArea(x, y) {
        return (
            x > 10 &&
            x < width / 2 - 10 &&
            y > 10 &&
            y < height - 10
        );
    }

    requestRedraw() {
        redraw();
    }

    exportGraph() {
        const points = this.state.mesh.vert.map(p => ({ x: p.x, y: p.y }));
        const constraints = this.state.mesh.con_edge.map(e => ({ a: e[0], b: e[1] }));
        const payload = { points, constraints };
        const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'graph.json';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(a.href);
    }

    exportGraphSVG() {
        const { mesh } = this.state;
        const numPoints = mesh.numPoints();

        if (numPoints === 0) {
            alert('No graph to export. Add some points first!');
            return;
        }

        // Calculate bounding box
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

        // Include all vertices
        mesh.vert.forEach(point => {
            minX = Math.min(minX, point.x);
            minY = Math.min(minY, point.y);
            maxX = Math.max(maxX, point.x);
            maxY = Math.max(maxY, point.y);
        });

        // Add padding
        const padding = 30;
        minX -= padding;
        minY -= padding;
        maxX += padding;
        maxY += padding;

        const svgWidth = maxX - minX;
        const svgHeight = maxY - minY;

        // Generate SVG
        let svg = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="${svgWidth}"
     height="${svgHeight}"
     viewBox="${minX} ${minY} ${svgWidth} ${svgHeight}">
  <title>Graph Structure</title>
  <desc>Graph visualization with ${numPoints} vertices and ${mesh.con_edge.length} constrained edges</desc>

  <!-- Background -->
  <rect x="${minX}" y="${minY}" width="${svgWidth}" height="${svgHeight}" fill="${Settings.colors.graph.background}"/>

  <!-- Triangles (Delaunay triangulation) -->
  <g id="triangles" stroke="${Settings.colors.export.triangles}" stroke-width="${Settings.visual.triangleStrokeWeight}" fill="none" opacity="1">
`;

        // Add triangles
        for (const triangle of mesh.tri) {
            const p1 = mesh.vert[triangle[0]];
            const p2 = mesh.vert[triangle[1]];
            const p3 = mesh.vert[triangle[2]];
            svg += `    <polygon points="${p1.x.toFixed(3)},${p1.y.toFixed(3)} ${p2.x.toFixed(3)},${p2.y.toFixed(3)} ${p3.x.toFixed(3)},${p3.y.toFixed(3)}"/>\n`;
        }

        svg += `  </g>

  <!-- Constrained Edges -->
  <g id="constrained-edges" stroke="${Settings.colors.export.constrainedEdges}" stroke-width="${Settings.visual.constrainedEdgeStrokeWeight}" fill="none" opacity="1">
`;

        // Add constrained edges
        for (const edge of mesh.con_edge) {
            const p = mesh.vert[edge[0]];
            const q = mesh.vert[edge[1]];
            svg += `    <line x1="${p.x.toFixed(3)}" y1="${p.y.toFixed(3)}" x2="${q.x.toFixed(3)}" y2="${q.y.toFixed(3)}"/>\n`;
        }

        svg += `  </g>

  <!-- Vertices -->
  <g id="vertices">
`;

        // Add vertices with colors
        for (let idx = 0; idx < numPoints; idx++) {
            const point = mesh.vert[idx];
            const vertexColor = this.getVertexColor(idx, numPoints);
            const colorHex = this.colorToHex(vertexColor);
            const isBoundary = mesh.vert_props[idx].boundary;

            if (isBoundary) {
                // Boundary vertices have white stroke
                svg += `    <circle cx="${point.x.toFixed(3)}" cy="${point.y.toFixed(3)}" r="4" fill="${colorHex}" stroke="${Settings.colors.export.vertexBoundaryStroke}" stroke-width="${Settings.visual.vertexStrokeWeight}"/>\n`;
            } else {
                svg += `    <circle cx="${point.x.toFixed(3)}" cy="${point.y.toFixed(3)}" r="4" fill="${colorHex}" stroke="none"/>\n`;
            }
        }

        svg += `  </g>
</svg>`;

        // Download SVG
        const blob = new Blob([svg], { type: 'image/svg+xml' });
        const downloadLink = document.createElement('a');
        downloadLink.href = URL.createObjectURL(blob);
        const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
        downloadLink.download = `graph-${timestamp}.svg`;
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);
        URL.revokeObjectURL(downloadLink.href);
    }

    promptLoadGraph() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'application/json,.json';
        input.onchange = (ev) => {
            const file = ev.target.files && ev.target.files[0];
            if (!file) return;
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const data = JSON.parse(String(reader.result));
                    this.loadGraph(data);
                    this.requestRedraw();
                } catch (e) {
                    console.error('Failed parsing graph JSON:', e);
                }
            };
            reader.readAsText(file);
        };
        input.click();
    }

    loadGraph(data) {
        if (!data || !Array.isArray(data.points)) return;
        this.resetGeometry();
        for (let i = 0; i < data.points.length; i++) {
            const p = data.points[i];
            if (p && typeof p.x === 'number' && typeof p.y === 'number') {
                this.state.mesh.addPoint(new Point(p.x, p.y));
            }
        }
        if (Array.isArray(data.constraints)) {
            for (let j = 0; j < data.constraints.length; j++) {
                const c = data.constraints[j];
                if (!c) continue;
                const a = c.a;
                const b = c.b;
                if (Number.isInteger(a) && Number.isInteger(b) && a >= 0 && b >= 0 &&
                    a < this.state.mesh.numPoints() && b < this.state.mesh.numPoints()) {
                    this.state.mesh.addConstraint(a, b);
                }
            }
        }
        this.state.mesh.recompute();
    }

    generateTriangularGridPoints(rows = 8, cols = 8, spacing = 4 * this.gridSize) {
        const margin = this.gridSize * 2;
        const triHeight = spacing * Math.sqrt(3) / 2;
        for (let r = 0; r < rows; r++) {
            const xOffset = (r % 2) * (spacing / 2);
            for (let c = 0; c < cols; c++) {
                const x = margin + xOffset + c * spacing;
                const y = margin + r * triHeight;
                if (x <= width / 2 - margin && y <= height - margin) {
                    this.state.mesh.addPoint(new Point(x, y));
                }
            }
        }
    }


    generateSpiderGraph(numLayers = 4, pointsPerLayer = 10) {
        const cx = width / 4;
        const cy = height / 2;
        const margin = this.gridSize * 2;

        // Calculate max radius to fit in left half of canvas
        const maxRadius = Math.min((width / 2) - 2 * margin, height - 2 * margin) / 2;
        const outerRadius = maxRadius * 0.85;

        // Add center point
        const centerIdx = this.state.mesh.vert.length;
        this.state.mesh.addPoint(new Point(cx, cy));

        // Store indices by layer for triangulation
        const layers = [[centerIdx]];

        // Create concentric layers of points
        for (let layer = 1; layer <= numLayers; layer++) {
            const layerRadius = (layer / numLayers) * outerRadius;
            const layerIndices = [];

            for (let i = 0; i < pointsPerLayer; i++) {
                const angle = (i * 2 * Math.PI) / pointsPerLayer - Math.PI / 2; // Start from top
                const x = cx + layerRadius * Math.cos(angle);
                const y = cy + layerRadius * Math.sin(angle);
                const idx = this.state.mesh.vert.length;
                this.state.mesh.addPoint(new Point(x, y));
                layerIndices.push(idx);
            }

            layers.push(layerIndices);
        }

        // Add boundary constraints (outermost layer)
        const outerLayer = layers[layers.length - 1];
        for (let i = 0; i < outerLayer.length; i++) {
            const curr = outerLayer[i];
            const next = outerLayer[(i + 1) % outerLayer.length];
            this.state.mesh.addConstraint(curr, next);
        }

        // Triangulate with consistent orientation
        // Connect center to first layer with radial spokes
        for (let i = 0; i < layers[1].length; i++) {
            this.state.mesh.addConstraint(centerIdx, layers[1][i]);
            // Also connect to next spoke to form triangles
            const nextSpoke = (i + 1) % layers[1].length;
            this.state.mesh.addConstraint(layers[1][i], layers[1][nextSpoke]);
        }

        // Connect layers with consistent triangulation
        for (let layer = 1; layer < layers.length; layer++) {
            const innerLayer = layers[layer];
            const outerLayer = layers[layer + 1];

            if (!outerLayer) break;

            for (let i = 0; i < innerLayer.length; i++) {
                const inner = innerLayer[i];
                const innerNext = innerLayer[(i + 1) % innerLayer.length];
                const outer = outerLayer[i];
                const outerNext = outerLayer[(i + 1) % outerLayer.length];

                // Create two triangles between layers (consistent orientation)
                // Triangle 1: inner -> outer -> innerNext
                this.state.mesh.addConstraint(inner, outer);
                this.state.mesh.addConstraint(outer, innerNext);

                // Triangle 2: outer -> outerNext -> innerNext
                this.state.mesh.addConstraint(outer, outerNext);
                this.state.mesh.addConstraint(outerNext, innerNext);
            }
        }

        const totalConstraints = pointsPerLayer + 2 * pointsPerLayer + 4 * pointsPerLayer * (numLayers - 1);
        console.log(`Generated spider graph with ${numLayers} layers and ${pointsPerLayer} points per layer (fully triangulated: ~${totalConstraints} constraints)`);
    }

    generateTriangularGridGraph(size = 10) {
        // size parameter = number of vertices along each edge of the boundary
        // e.g., size=10 means 10 vertices on top edge, 10 on right, 10 on bottom, 10 on left
        const rows = size;
        const cols = size;

        const { mesh } = this.state;
        const margin = this.gridSize * 4;
        const spacing = 8 * this.gridSize;

        // Calculate the total size of the grid
        const gridWidth = (cols - 1) * spacing;
        const gridHeight = (rows - 1) * spacing;

        // Center on the left half of the canvas
        const centerX = width / 4;
        const centerY = height / 2;

        // Calculate starting position to center the grid
        const startX = centerX - gridWidth / 2;
        const startY = centerY - gridHeight / 2;

        // Create grid points and store indices in 2D array
        const gridIndices = [];
        for (let i = 0; i < rows; i++) {
            gridIndices[i] = [];
            for (let j = 0; j < cols; j++) {
                const x = startX + j * spacing;
                const y = startY + i * spacing;
                const idx = mesh.vert.length;
                mesh.addPoint(new Point(x, y));
                gridIndices[i][j] = idx;
            }
        }

        // Add boundary constraints to form a square perimeter
        // Top edge: cols vertices
        for (let j = 0; j < cols - 1; j++) {
            mesh.addConstraint(gridIndices[0][j], gridIndices[0][j + 1]);
        }

        // Bottom edge: cols vertices
        for (let j = 0; j < cols - 1; j++) {
            mesh.addConstraint(gridIndices[rows - 1][j], gridIndices[rows - 1][j + 1]);
        }

        // Left edge: rows vertices
        for (let i = 0; i < rows - 1; i++) {
            mesh.addConstraint(gridIndices[i][0], gridIndices[i + 1][0]);
        }

        // Right edge: rows vertices
        for (let i = 0; i < rows - 1; i++) {
            mesh.addConstraint(gridIndices[i][cols - 1], gridIndices[i + 1][cols - 1]);
        }

        console.log(`Generated triangular grid with ${size} vertices per boundary edge (${rows}×${cols} = ${rows * cols} total points)`);
    }

    generateKingsGraph(size = 8) {
        // size parameter = number of vertices along each edge of the boundary
        // e.g., size=8 means 8 vertices on each boundary edge
        // Creates main grid + center points where diagonals intersect
        const rows = size;
        const cols = size;

        const { mesh } = this.state;
        const margin = this.gridSize * 4;
        const spacing = 8 * this.gridSize;

        // Calculate the total size of the grid
        const gridWidth = (cols - 1) * spacing;
        const gridHeight = (rows - 1) * spacing;

        // Center on the left half of the canvas
        const centerX = width / 4;
        const centerY = height / 2;

        // Calculate starting position to center the grid
        const startX = centerX - gridWidth / 2;
        const startY = centerY - gridHeight / 2;

        // Create main grid points and store indices in 2D array
        const gridIndices = [];
        for (let i = 0; i < rows; i++) {
            gridIndices[i] = [];
            for (let j = 0; j < cols; j++) {
                const x = startX + j * spacing;
                const y = startY + i * spacing;
                const idx = mesh.vert.length;
                mesh.addPoint(new Point(x, y));
                gridIndices[i][j] = idx;
            }
        }

        // Create center points (offset grid) where diagonals intersect
        // These are at the centers of each cell
        const centerIndices = [];
        for (let i = 0; i < rows - 1; i++) {
            centerIndices[i] = [];
            for (let j = 0; j < cols - 1; j++) {
                const x = startX + (j + 0.5) * spacing;
                const y = startY + (i + 0.5) * spacing;
                const idx = mesh.vert.length;
                mesh.addPoint(new Point(x, y));
                centerIndices[i][j] = idx;
            }
        }

        // Only add boundary constraints - let Delaunay triangulation handle interior
        // This dramatically speeds up computation!

        // Top edge: cols vertices
        for (let j = 0; j < cols - 1; j++) {
            mesh.addConstraint(gridIndices[0][j], gridIndices[0][j + 1]);
        }

        // Bottom edge: cols vertices
        for (let j = 0; j < cols - 1; j++) {
            mesh.addConstraint(gridIndices[rows - 1][j], gridIndices[rows - 1][j + 1]);
        }

        // Left edge: rows vertices
        for (let i = 0; i < rows - 1; i++) {
            mesh.addConstraint(gridIndices[i][0], gridIndices[i + 1][0]);
        }

        // Right edge: rows vertices
        for (let i = 0; i < rows - 1; i++) {
            mesh.addConstraint(gridIndices[i][cols - 1], gridIndices[i + 1][cols - 1]);
        }

        const totalPoints = rows * cols + (rows - 1) * (cols - 1);
        console.log(`Generated King's graph with ${size} vertices per boundary edge (${rows}×${cols} grid + ${(rows - 1)}×${(cols - 1)} centers = ${totalPoints} total points)`);
    }

    clearGraph() {
        this.resetGeometry();
        this.requestRedraw();
    }

    setDefaultGraph(kind) {
        this.resetGeometry();
        this.state.currentGraph = kind;

        // Show/hide appropriate parameter divs
        document.getElementById('tri-params').style.display = kind === 'tri' ? 'flex' : 'none';
        document.getElementById('spider-params').style.display = kind === 'spider' ? 'flex' : 'none';
        document.getElementById('king-params').style.display = kind === 'king' ? 'flex' : 'none';
        document.getElementById('random-params').style.display = kind === 'random' ? 'flex' : 'none';

        const { triSize, spiderLayers, spiderPoints, kingSize, randomPoints } = this.state.graphParameters;

        switch (kind) {
            case 'tri':
                // Triangular grid (rectangular grid with square boundary)
                this.generateTriangularGridGraph(triSize);
                break;

            case 'spider':
                // Spider graph (concentric layers with radial spokes)
                this.generateSpiderGraph(spiderLayers, spiderPoints);
                break;

            case 'king':
                // King's graph (8-connected grid)
                this.generateKingsGraph(kingSize);
                break;

            case 'random':
                // Random Delaunay triangulation
                this.generateRandomDelaunay(randomPoints);
                break;

            default:
                // Default grid pattern
                this.seedDefaultPoints();
                break;
        }

        this.requestRedraw();
    }

    generateRandomDelaunay(numPoints = 30) {
        const { mesh } = this.state;
        const margin = this.gridSize * 4;

        // Calculate the drawable area in the left half of the canvas
        const centerX = width / 4;
        const centerY = height / 2;
        const maxWidth = (width / 2) - 2 * margin;
        const maxHeight = height - 2 * margin;
        const boundaryWidth = maxWidth * 0.85;
        const boundaryHeight = maxHeight * 0.85;

        // Add random points without any boundary constraints
        // The boundary will be naturally determined by the convex hull
        for (let i = 0; i < numPoints; i++) {
            const rx = centerX - boundaryWidth / 2 + random(boundaryWidth);
            const ry = centerY - boundaryHeight / 2 + random(boundaryHeight);
            mesh.addPoint(new Point(rx, ry));
        }

        console.log(`Generated random Delaunay triangulation with ${numPoints} random points (no boundary constraints)`);
    }

    addRandomPoints(n = 10) {
        const margin = 10;
        const left = margin;
        const right = width / 2 - margin;
        const top = margin;
        const bottom = height - margin;

        for (let i = 0; i < n; i++) {
            const rx = random(left, right);
            const ry = random(top, bottom);
            this.state.mesh.addPoint(new Point(rx, ry));
        }
        this.requestRedraw();
    }
}

let app;

function setup() {
    app = new SketchApp();
    app.setup();
    // Expose app to window for button callbacks
    window.app = app;
}

function draw() {
    app.draw();
}

function mousePressed() {
    app.mousePressed();
}

function mouseDragged() {
    app.mouseDragged();
}

function mouseReleased() {
    app.mouseReleased();
}

function keyPressed() {
    app.keyPressed();
}
