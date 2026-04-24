// are three points in counterclockwise order
function isCounterclockwise(p, q, r) {
    let determinant = ((q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)) * -1;
    return determinant > 0;
}

// custom comparator for sorting points on
// a circle in counterclockwise order
function sortCounterclockwise(cx, cy) {
    return function (a, b) {
        let va = createVector(a.x - cx, a.y - cy);
        let vb = createVector(b.x - cx, b.y - cy);
        let v0 = createVector(1, 0); // horizontal unit vector

        let angleA = va.angleBetween(v0);
        angleA = angleA > 0 ? angleA : angleA + TWO_PI;
        let angleB = vb.angleBetween(v0);
        angleB = angleB > 0 ? angleB : angleB + TWO_PI;

        return angleA - angleB;
    }
}

// given two lines each represented by two points,
// returns intersection of lines
function intersectLines(p1, p2, q1, q2) {
    let ua =
        ((q2.x - q1.x) * (p1.y - q1.y) - (q2.y - q1.y) * (p1.x - q1.x)) /
        ((q2.y - q1.y) * (p2.x - p1.x) - (q2.x - q1.x) * (p2.y - p1.y));

    return new Point(p1.x + ua * (p2.x - p1.x), p1.y + ua * (p2.y - p1.y));
}

// compute bounding box of circle packing
function computeBoundingBox(mesh) {
    let left = 0;
    let right = 0;
    let top = 0;
    let bottom = 0;
    for (let idx = 0; idx < mesh.numPoints(); ++idx) {
        if (mesh.vert_props[idx].hasOwnProperty('center')) {
            if (mesh.vert_props[idx].boundary) {
                let c = mesh.vert_props[idx].center;
                let r = mesh.vert_props[idx].radius;
                left = Math.min(c.x - r, left);
                right = Math.max(c.x + r, right);
                top = Math.min(c.y - r, top);
                bottom = Math.max(c.y + r, bottom);
            }
        }
    }
    bb = new BoundingBox();
    bb.width = right - left;
    bb.height = bottom - top;
    bb.center = new Point(left + bb.width / 2, top + bb.height / 2);
    return bb;
}

class BoundingBox {
    constructor(width, height, center) {
        this.width = width;
        this.height = height;
        this.center = center;
    }
}