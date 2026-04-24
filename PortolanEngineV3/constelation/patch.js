const CONTACT_ANGLE = 1.3;
const STAR_RAY_LENGTH = 4;

function populateCircleInformation(mesh, circleRegistry) {
    for (const triangle of mesh.tri) {
        const [aIdx, bIdx, cIdx] = triangle;
        const circleA = circleRegistry[aIdx];
        const circleB = circleRegistry[bIdx];
        const circleC = circleRegistry[cIdx];

        if (!circleA || !circleB || !circleC) {
            continue;
        }

        if (circleA.boundary || circleB.boundary || circleC.boundary) {
            circleA.active = false;
            circleB.active = false;
            circleC.active = false;
        }

        const contactAB = computeContactPoint(circleA, circleB);
        circleA.idx2ct[bIdx] = contactAB;
        circleB.idx2ct[aIdx] = contactAB;

        const contactAC = computeContactPoint(circleA, circleC);
        circleA.idx2ct[cIdx] = contactAC;
        circleC.idx2ct[aIdx] = contactAC;

        const contactBC = computeContactPoint(circleB, circleC);
        circleB.idx2ct[cIdx] = contactBC;
        circleC.idx2ct[bIdx] = contactBC;
    }
}

function build3Patch(mesh, circleRegistry, polygonRegistry, tau) {
    const pentagons = [];

    for (const triangle of mesh.tri) {
        const [aIdx, bIdx, cIdx] = triangle;
        const circleA = circleRegistry[aIdx];
        const circleB = circleRegistry[bIdx];
        const circleC = circleRegistry[cIdx];

        if (!circleA || !circleB || !circleC) {
            continue;
        }

        if (circleA.boundary || circleB.boundary || circleC.boundary) {
            continue;
        }

        const AB = circleA.idx2ct[bIdx];
        const AC = circleA.idx2ct[cIdx];
        const BC = circleB.idx2ct[cIdx];

        const ab = createVector(AB.x - circleA.x, AB.y - circleA.y).mult(tau);
        const aPrev = new Point(circleA.x + ab.x, circleA.y + ab.y);
        const ac = createVector(AC.x - circleA.x, AC.y - circleA.y).mult(tau);
        const aPost = new Point(circleA.x + ac.x, circleA.y + ac.y);

        let midwayAngle = ab.angleBetween(ac) / 2;
        ab.rotate(midwayAngle);
        const a = new Point(circleA.x + ab.x, circleA.y + ab.y);

        const ba = createVector(AB.x - circleB.x, AB.y - circleB.y).mult(tau);
        const bPost = new Point(circleB.x + ba.x, circleB.y + ba.y);
        const bc = createVector(BC.x - circleB.x, BC.y - circleB.y).mult(tau);
        const bPrev = new Point(circleB.x + bc.x, circleB.y + bc.y);

        midwayAngle = bc.angleBetween(ba) / 2;
        bc.rotate(midwayAngle);
        const b = new Point(circleB.x + bc.x, circleB.y + bc.y);

        const ca = createVector(AC.x - circleC.x, AC.y - circleC.y).mult(tau);
        const cPrev = new Point(circleC.x + ca.x, circleC.y + ca.y);
        const cb = createVector(BC.x - circleC.x, BC.y - circleC.y).mult(tau);
        const cPost = new Point(circleC.x + cb.x, circleC.y + cb.y);

        midwayAngle = ca.angleBetween(cb) / 2;
        ca.rotate(midwayAngle);
        const c = new Point(circleC.x + ca.x, circleC.y + ca.y);

        const o = new Point((a.x + b.x + c.x) / 3, (a.y + b.y + c.y) / 3);

        const polygonA = circleA.gon;
        const polygonB = circleB.gon;
        const polygonC = circleC.gon;
        if (!polygonA || !polygonB || !polygonC) {
            continue;
        }
        const i = polygonA.indexOfVertex(a);
        const j = polygonB.indexOfVertex(b);
        const k = polygonC.indexOfVertex(c);

        const internal = polygonA.active && polygonB.active && polygonC.active;
        pentagons.push(new Pentagon(
            [o, a, aPrev, bPost, b],
            [polygonA, (i - 1 + polygonA.n) % polygonA.n],
            [polygonB, j],
            internal
        ));
        pentagons.push(new Pentagon(
            [o, b, bPrev, cPost, c],
            [polygonB, (j - 1 + polygonB.n) % polygonB.n],
            [polygonC, k],
            internal
        ));
        pentagons.push(new Pentagon(
            [o, c, cPrev, aPost, a],
            [polygonC, (k - 1 + polygonC.n) % polygonC.n],
            [polygonA, i],
            internal
        ));
    }

    return pentagons;
}

class Circle {
    constructor(idx, cx, cy, radius, boundary, vertexColor) {
        this.idx = idx;
        this.x = cx;
        this.y = cy;
        this.r = radius;
        this.boundary = boundary;
        this.vertexColor = vertexColor; // Store the color from the vertex
        this.idx2ct = {};
        this.gon = null;
        this.active = true;
    }

    display() {
        push();
        noStroke(); // Remove all circle outlines
        if (this.vertexColor) {
            // Use the vertex color with more transparency
            const col = this.vertexColor;
            const opacity = Settings.colors.circles.vertexColored.opacity * 255; // Convert to 0-255 range
            fill(red(col), green(col), blue(col), opacity);
        } else if (this.boundary) {
            const c = Settings.colors.circles.boundary;
            const opacity = c.opacity * 255; // Convert to 0-255 range
            // Parse hex color to RGB
            const hex = c.fill.replace('#', '');
            const r = parseInt(hex.substr(0, 2), 16);
            const g = parseInt(hex.substr(2, 2), 16);
            const b = parseInt(hex.substr(4, 2), 16);
            fill(r, g, b, opacity);
        } else {
            const c = Settings.colors.circles.default;
            const opacity = c.opacity * 255; // Convert to 0-255 range
            // Parse hex color to RGB
            const hex = c.fill.replace('#', '');
            const r = parseInt(hex.substr(0, 2), 16);
            const g = parseInt(hex.substr(2, 2), 16);
            const b = parseInt(hex.substr(4, 2), 16);
            fill(r, g, b, opacity);
        }
        circle(this.x, this.y, this.r);
        pop();
    }

    buildCyclicPolygon(tau, polygonRegistry) {
        const contacts = Object.values(this.idx2ct);
        if (contacts.length < 2) {
            this.gon = null;
            return;
        }
        contacts.sort(sortCounterclockwise(this.x, this.y));

        const vertices = [];
        for (let i = 0; i < contacts.length; ++i) {
            const nextIndex = (i + 1) % contacts.length;
            const v1 = createVector(contacts[i].x - this.x, contacts[i].y - this.y).mult(tau);
            const v2 = createVector(contacts[nextIndex].x - this.x, contacts[nextIndex].y - this.y).mult(tau);

            vertices.push(new Point(this.x + v1.x, this.y + v1.y));
            const midwayAngle = v1.angleBetween(v2) / 2;
            v1.rotate(midwayAngle);
            vertices.push(new Point(this.x + v1.x, this.y + v1.y));
        }

        const polygon = new CyclicPolygon(this.idx, this.x, this.y, this.r * tau, vertices, this.active);
        polygonRegistry[this.idx] = polygon;
        this.gon = polygon;
    }
}

class CyclicPolygon {
    constructor(idx, cx, cy, radius, vertices, active) {
        this.idx = idx;
        this.x = cx;
        this.y = cy;
        this.r = radius;
        this.v = vertices;
        this.n = vertices.length;
        this.active = active;
        this.ca = Array.from({ length: this.v.length }, () => [null, null]);
    }

    collectEdges(lambda, addEdge) {
        if (!this.active) {
            return;
        }
        this.traceMotifSegments(lambda, (start, end) => addEdge(start, end));
    }

    display() {
        if (!this.active) {
            return;
        }

        push();
        stroke(Settings.colors.pattern.tiling);
        noFill();
        beginShape();
        for (const point of this.v) {
            vertex(point.x, point.y);
        }
        endShape(CLOSE);
        pop();
    }

    motif(lambda) {
        if (!this.active) {
            return;
        }

        push();
        stroke(Settings.colors.pattern.edges);
        noFill();
        this.traceMotifSegments(lambda, (start, end) => {
            line(start.x, start.y, end.x, end.y);
        });
        pop();
    }

    indexOfVertex(v) {
        for (let i = 0; i < this.v.length; ++i) {
            if (dist(v.x, v.y, this.v[i].x, this.v[i].y) < 0.1) {
                return i;
            }
        }
        return -1;
    }

    traceMotifSegments(lambda, emit) {
        const connectors = this.computeConnectorData(lambda);
        for (const connector of connectors) {
            for (const [start, end] of connector.segments) {
                emit(start, end);
            }
        }
    }

    computeConnectorData(lambda) {
        const connectors = [];
        for (let i = 0; i < this.ca.length; ++i) {
            this.ca[i][0] = null;
            this.ca[i][1] = null;
        }

        const count = this.v.length;
        if (count === 0) {
            return connectors;
        }

        for (let i = 0; i < count; ++i) {
            const prev = wrapIndex(i - 1, count);
            const next = wrapIndex(i + 1, count);
            const next2 = wrapIndex(i + 2, count);
            const next3 = wrapIndex(i + 3, count);

            const m0 = midpoint(this.v[prev], this.v[i]);
            const m1 = midpoint(this.v[i], this.v[next]);
            const m2 = midpoint(this.v[next], this.v[next2]);
            const m3 = midpoint(this.v[next2], this.v[next3]);

            const v0 = createVector(m0.x - this.x, m0.y - this.y);
            const v1 = createVector(m1.x - this.x, m1.y - this.y);
            const v2 = createVector(m2.x - this.x, m2.y - this.y);
            const v3 = createVector(m3.x - this.x, m3.y - this.y);

            const b13 = bisectorPoint(this.x, this.y, v1, v3, lambda);
            const b02 = bisectorPoint(this.x, this.y, v0, v2, lambda);

            const intersection = intersectLines(m1, b13, m2, b02);

            this.ca[i][0] = createVector(m1.x - b13.x, m1.y - b13.y);
            this.ca[(i + 2) % count][1] = createVector(m3.x - b13.x, m3.y - b13.y);

            connectors.push({
                segments: [
                    [m1, intersection],
                    [intersection, b13],
                    [m2, intersection],
                    [intersection, b02],
                ],
            });
        }

        return connectors;
    }
}

class Pentagon {
    constructor(vertices, nbr1, nbr2, internal) {
        this.v = vertices;
        this.nbr1 = nbr1;
        this.nbr2 = nbr2;
        this.internal = internal;
    }

    collectEdges(lambda, addEdge) {
        this.traceConnectors(lambda, (start, end) => addEdge(start, end));
    }

    display() {
        if (!this.nbr1[0].active && !this.nbr2[0].active) {
            return;
        }

        push();
        stroke(Settings.colors.pattern.tiling);
        noFill();
        beginShape();
        for (const point of this.v) {
            vertex(point.x, point.y);
        }
        endShape(CLOSE);
        pop();
    }

    motif(lambda) {
        push();
        stroke(Settings.colors.pattern.edges);
        noFill();
        this.traceConnectors(lambda, (start, end) => {
            line(start.x, start.y, end.x, end.y);
        });
        pop();
    }

    traceConnectors(lambda, emit) {
        if (!this.nbr1[0].active && !this.nbr2[0].active) {
            return;
        }

        const emitIntersection = (s1, c1, s2, c2) => {
            const e1 = extendFrom(s1, c1, STAR_RAY_LENGTH);
            const e2 = extendFrom(s2, c2, STAR_RAY_LENGTH);
            const intersection = intersectLines(s1, e1, s2, e2);
            emit(s1, intersection);
            emit(s2, intersection);
        };

        if (!this.nbr1[0].active) {
            const c1 = createVector(this.v[3].x - this.v[2].x, this.v[3].y - this.v[2].y).rotate(CONTACT_ANGLE * -1);
            const c2 = this.nbr2[0].ca[this.nbr2[1]][1];
            const s1 = midpoint(this.v[2], this.v[3]);
            const s2 = midpoint(this.v[3], this.v[4]);
            emitIntersection(s1, c1, s2, c2);

            const nextC1 = this.nbr2[0].ca[this.nbr2[1]][0];
            const nextC2 = createVector(this.v[0].x - this.v[4].x, this.v[0].y - this.v[4].y).rotate(CONTACT_ANGLE);
            const s3 = midpoint(this.v[0], this.v[4]);
            emitIntersection(s2, nextC1, s3, nextC2);
            return;
        }

        if (!this.nbr2[0].active) {
            const c1 = createVector(this.v[1].x - this.v[0].x, this.v[1].y - this.v[0].y).rotate(CONTACT_ANGLE * -1);
            const c2 = this.nbr1[0].ca[this.nbr1[1]][1];
            const s1 = midpoint(this.v[0], this.v[1]);
            const s2 = midpoint(this.v[1], this.v[2]);
            emitIntersection(s1, c1, s2, c2);

            const nextC1 = this.nbr1[0].ca[this.nbr1[1]][0];
            const nextC2 = createVector(this.v[3].x - this.v[2].x, this.v[3].y - this.v[2].y).rotate(CONTACT_ANGLE);
            const s3 = midpoint(this.v[2], this.v[3]);
            emitIntersection(s2, nextC1, s3, nextC2);
            return;
        }

        const limit = this.internal ? 5 : 4;
        const ca = [null, this.nbr1[0].ca[this.nbr1[1]], null, this.nbr2[0].ca[this.nbr2[1]], null];

        for (let i = 0; i < limit; ++i) {
            const c1 = ca[i]
                ? ca[i][0]
                : createVector(this.v[(i + 1) % 5].x - this.v[i].x, this.v[(i + 1) % 5].y - this.v[i].y).rotate(CONTACT_ANGLE * -1);
            const c2 = ca[(i + 1) % 5]
                ? ca[(i + 1) % 5][1]
                : createVector(this.v[(i + 1) % 5].x - this.v[(i + 2) % 5].x, this.v[(i + 1) % 5].y - this.v[(i + 2) % 5].y).rotate(CONTACT_ANGLE);

            const s1 = midpoint(this.v[i], this.v[(i + 1) % 5]);
            const s2 = midpoint(this.v[(i + 1) % 5], this.v[(i + 2) % 5]);
            emitIntersection(s1, c1, s2, c2);
        }
    }
}

function computeContactPoint(circleA, circleB) {
    const sum = circleA.r + circleB.r;
    const ratio = sum === 0 ? 0.5 : circleA.r / sum;
    return new Point(lerp(circleA.x, circleB.x, ratio), lerp(circleA.y, circleB.y, ratio));
}

function midpoint(a, b) {
    return new Point(lerp(a.x, b.x, 0.5), lerp(a.y, b.y, 0.5));
}

function extendFrom(origin, vec, scale) {
    return new Point(origin.x + vec.x * scale, origin.y + vec.y * scale);
}

function bisectorPoint(cx, cy, startVec, endVec, scale) {
    const bisector = startVec.copy();
    const angle = startVec.angleBetween(endVec);
    if (!isFinite(angle) || bisector.magSq() === 0) {
        if (bisector.magSq() !== 0) {
            bisector.setMag(scale);
            return new Point(cx + bisector.x, cy + bisector.y);
        }
        return new Point(cx, cy);
    }
    bisector.rotate(angle / 2);
    bisector.mult(scale);
    return new Point(cx + bisector.x, cy + bisector.y);
}

function wrapIndex(index, size) {
    return (index + size) % size;
}
