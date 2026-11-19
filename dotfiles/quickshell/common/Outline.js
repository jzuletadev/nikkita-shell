// ~/nikita-shell/dotfiles/quickshell/common/Outline.js
//
// The outline of a panel that grows out of a screen edge, as an SVG path in
// screen coordinates. Instead of drawing one orientation and rotating it, each
// corner of the visible rectangle decides on its own what it is:
//
//   s   screen corner             -> square
//   nv  touches a vertical edge   -> concave notch opening along that edge
//   nh  touches a horizontal edge -> the same, on the top or bottom edge
//   r   touches nothing           -> inner radius
//
// So a corner panel gets a notch on BOTH edges, and the same code serves all
// eight places. The path runs clockwise: convex corners use sweep 1, notches 0.
.pragma library

function cornerType(cx, cy, W, H) {
    const atV = cx <= 0.5 || cx >= W - 0.5;
    const atH = cy <= 0.5 || cy >= H - 0.5;
    if (atV && atH)
        return "s";
    if (atV)
        return "nv";
    if (atH)
        return "nh";
    return "r";
}

// The four corners, clockwise from the top right. Each says where the outline
// comes in (`x`, `y`) and, if it curves, the arc that takes it out.
function corners(x0, y0, w, h, W, H, r, n) {
    const x1 = x0 + w, y1 = y0 + h;
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    n = Math.max(0, n);
    const at = (x, y, rad, sweep, ex, ey) => ({ x, y, arc: rad === undefined ? "" : `A ${rad} ${rad} 0 0 ${sweep} ${ex} ${ey}` });
    const pick = (cx, cy, s, rr, nv, nh) => ({ s, r: rr, nv, nh })[cornerType(cx, cy, W, H)];
    return [
        pick(x1, y0, at(x1, y0),
             at(x1 - r, y0, r, 1, x1, y0 + r), at(x1 - n, y0, n, 0, x1, y0 - n), at(x1 + n, y0, n, 0, x1, y0 + n)),
        pick(x1, y1, at(x1, y1),
             at(x1, y1 - r, r, 1, x1 - r, y1), at(x1, y1 + n, n, 0, x1 - n, y1), at(x1, y1 - n, n, 0, x1 + n, y1)),
        pick(x0, y1, at(x0, y1),
             at(x0 + r, y1, r, 1, x0, y1 - r), at(x0 + n, y1, n, 0, x0, y1 + n), at(x0 - n, y1, n, 0, x0, y1 - n)),
        pick(x0, y0, at(x0, y0),
             at(x0, y0 + r, r, 1, x0 + r, y0), at(x0, y0 - n, n, 0, x0 + n, y0), at(x0, y0 + n, n, 0, x0 - n, y0))
    ];
}

function outline(x0, y0, w, h, W, H, r, n) {
    if (w <= 0.5 || h <= 0.5)
        return "M 0 0";
    const p = [`M ${x0 + w / 2} ${y0}`];
    for (const c of corners(x0, y0, w, h, W, H, r, n)) {
        p.push(`L ${c.x} ${c.y}`);
        if (c.arc)
            p.push(c.arc);
    }
    p.push("Z");
    return p.join(" ");
}

// Where the arc of a corner ends.
function arcEnd(c) {
    if (!c.arc)
        return [c.x, c.y];
    const f = c.arc.split(" ");
    return [Number(f[6]), Number(f[7])];
}

// The same outline without the stretches that lie along a screen edge: what a panel's
// rim and shadow follow. Stroking those would draw a line down the edge of the screen.
function rim(x0, y0, w, h, W, H, r, n) {
    if (w <= 0.5 || h <= 0.5)
        return "M 0 0";
    const c = corners(x0, y0, w, h, W, H, r, n);
    const onEdge = (a, b) => (Math.abs(a[1] - b[1]) < 0.5 && (a[1] <= 0.5 || a[1] >= H - 0.5))
        || (Math.abs(a[0] - b[0]) < 0.5 && (a[0] <= 0.5 || a[0] >= W - 0.5));
    // The side leaving corner i, toward the next one.
    const skipped = i => onEdge(arcEnd(c[i]), [c[(i + 1) % 4].x, c[(i + 1) % 4].y]);
    // A screen corner between two such stretches: nothing of it shows.
    const hidden = i => !c[i].arc && skipped(i) && skipped((i + 3) % 4);
    // Start right after a skipped side, so the line is never broken in two needlessly.
    let first = 0;
    for (let i = 0; i < 4; i++) {
        if (skipped((i + 3) % 4) && !hidden(i)) {
            first = i;
            break;
        }
    }
    const p = [];
    for (let k = 0; k < 4; k++) {
        const i = (first + k) % 4;
        if (hidden(i))
            continue;
        p.push(`${p.length === 0 || skipped((i + 3) % 4) ? "M" : "L"} ${c[i].x} ${c[i].y}`);
        if (c[i].arc)
            p.push(c[i].arc);
    }
    if (!skipped((first + 3) % 4))
        p.push("Z");
    return p.join(" ");
}
