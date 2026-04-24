// Top-level constants (fields of the sketch class). Processing does not allow
// `static` on classes defined in .pde tabs because they compile as inner
// classes, so we expose settings as plain top-level final fields and reference
// them by bare name from any tab / inner class.

// Canvas / grid
final int CANVAS_W = 1200;
final int CANVAS_H = 800;
final int GRID_SIZE = 5;
final int PIXEL_DENSITY = 2;

// UI side panels (absolute window coords). The drawing area is translated
// right by LEFT_PANEL_W so mesh coords (0..CANVAS_W, 0..CANVAS_H) stay local.
final int LEFT_PANEL_W = 300;
final int RIGHT_PANEL_W = 300;
final int WINDOW_W = LEFT_PANEL_W + CANVAS_W + RIGHT_PANEL_W;

// Pattern parameters
final float TAU_DEFAULT = 0.85f;
final float LAMBDA_DEFAULT = 0.42f;

// Graph defaults
final int TRI_SIZE_DEF = 10;
final int KING_SIZE_DEF = 10;
final int SPIDER_LAYERS_DEF = 3;
final int SPIDER_POINTS_DEF = 8;
final int RAND_POINTS_DEF = 30;
