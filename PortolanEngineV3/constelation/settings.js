// Centralized settings and configuration for Constellation Patterns
const Settings = {
    // Pattern Parameters
    pattern: {
        tau: {
            default: 0.85,
            min: 0.7,
            max: 0.9,
            step: 0.01
        },
        lambda: {
            default: 0.42,
            min: 0.3,
            max: 0.5,
            step: 0.01
        }
    },

    // Graph Parameters
    graph: {
        triSize: {
            default: 10,
            min: 5,
            max: 15,
            step: 1
        },
        kingSize: {
            default: 10,
            min: 5,
            max: 12,
            step: 1
        },
        spiderLayers: {
            default: 3,
            min: 3,
            max: 8,
            step: 1
        },
        spiderPoints: {
            default: 8,
            min: 8,
            max: 20,
            step: 1
        },
        randomPoints: {
            default: 30,
            min: 10,
            max: 100,
            step: 1
        }
    },

    // Canvas Settings
    canvas: {
        width: 1200,
        height: 600,
        gridSize: 5,
        pixelDensity: 2
    },

    // Visual Settings
    visual: {
        vertexSize: 8,
        gridDotSize: 2,
        vertexStrokeWeight: 1.5,
        triangleStrokeWeight: 0.5,
        constrainedEdgeStrokeWeight: 1.5,
        draggedEdgeStrokeWeight: 2,
        patternStrokeWeight: 1.5,
        tilingStrokeWeight: 1
    },

    // Color Palettes
    colors: {
        // Graph/Canvas Colors
        graph: {
            background: '#e7f5f7',
            gridDots: { r: 200, g: 200, b: 200, a: 180 },
            triangles: { r: 72, g: 72, b: 72 },
            constrainedEdges: '#dd7c74',
            draggedEdge: '#dd7c74',
            vertex: {
                // Rainbow gradient using HSB
                saturation: 70,
                brightness: 85,
                boundaryStroke: { r: 255, g: 255, b: 255 }
            }
        },

        // Pattern Colors
        pattern: {
            edges: '#dd7c74',
            tiling: '#089bab'
        },

        // Circle Colors
        circles: {
            default: {
                fill: '#f0ad4e',
                opacity: 0.12
            },
            vertexColored: {
                opacity: 0.16  // ~40/255
            },
            boundary: {
                fill: '#484848',
                opacity: 0.08  // ~20/255
            }
        },

        // Export SVG Colors
        export: {
            background: 'white',
            triangles: '#484848',
            constrainedEdges: '#dd7c74',
            pattern: '#dd7c74',
            tiling: '#089bab',
            vertexBoundaryStroke: '#ffffff'
        }
    },

    // Helper function to get vertex color (rainbow gradient)
    getVertexColor: function(idx, total) {
        // This will be implemented in sketch.js using p5.js colorMode
        // Returns HSB color with hue based on index
        return {
            hue: (idx / total) * 360,
            saturation: this.colors.graph.vertex.saturation,
            brightness: this.colors.graph.vertex.brightness
        };
    }
};

