// Top-level constants (fields of the sketch class). Processing does not allow
// `static` on classes defined in .pde tabs because they compile as inner
// classes, so we expose settings as plain top-level final fields and reference
// them by bare name from any tab / inner class.

// Canvas / grid
final int CANVAS_W = 1200;
final int CANVAS_H = 800;
final int GRID_SIZE = 5;
// Rendering density is now selected at runtime via displayDensity() inside
// settings(), so we no longer expose a hard-coded PIXEL_DENSITY here.

// UI side panel (right-hand column only). Mesh draws at canvas-local coords
// 0..CANVAS_W so no translation is needed; the control column lives in
// absolute window coords to the right of the drawing area.
final int RIGHT_PANEL_W = 340;
final int WINDOW_W = CANVAS_W + RIGHT_PANEL_W;
// Legacy name retained so PortolanApp's mouse offset stays 0 (drawing starts
// at x=0). The controls now live entirely on the right.
final int LEFT_PANEL_W = 0;

// Pattern parameters
final float TAU_DEFAULT = 0.85f;
final float LAMBDA_DEFAULT = 0.42f;

// Flip DEBUG_LOG to true when diagnosing Mesh / setGraph behavior. It's
// kept off by default because each println flushes to the Processing
// console synchronously and those flushes dominate the frame time when
// dragging a slider across an integer range.
final boolean DEBUG_LOG = false;

// Graph defaults
final int TRI_SIZE_DEF = 10;
final int KING_SIZE_DEF = 10;
final int SPIDER_LAYERS_DEF = 3;
final int SPIDER_POINTS_DEF = 8;
final int RAND_POINTS_DEF = 30;
