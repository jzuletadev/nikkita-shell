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

function outline(x0, y0, w, h, W, H, r, n) {
    if (w <= 0.5 || h <= 0.5)
        return "M 0 0";
    const x1 = x0 + w, y1 = y0 + h;
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    n = Math.max(0, n);
    const p = [];
    const L = (x, y) => p.push(`L ${x} ${y}`);
    const A = (rad, sweep, x, y) => p.push(`A ${rad} ${rad} 0 0 ${sweep} ${x} ${y}`);

    p.push(`M ${(x0 + x1) / 2} ${y0}`);
    switch (cornerType(x1, y0, W, H)) {
    case "s": L(x1, y0); break;
    case "r": L(x1 - r, y0); A(r, 1, x1, y0 + r); break;
    case "nv": L(x1 - n, y0); A(n, 0, x1, y0 - n); break;
    case "nh": L(x1 + n, y0); A(n, 0, x1, y0 + n); break;
    }
    switch (cornerType(x1, y1, W, H)) {
    case "s": L(x1, y1); break;
    case "r": L(x1, y1 - r); A(r, 1, x1 - r, y1); break;
    case "nv": L(x1, y1 + n); A(n, 0, x1 - n, y1); break;
    case "nh": L(x1, y1 - n); A(n, 0, x1 + n, y1); break;
    }
    switch (cornerType(x0, y1, W, H)) {
    case "s": L(x0, y1); break;
    case "r": L(x0 + r, y1); A(r, 1, x0, y1 - r); break;
    case "nv": L(x0 + n, y1); A(n, 0, x0, y1 + n); break;
    case "nh": L(x0 - n, y1); A(n, 0, x0, y1 - n); break;
    }
    switch (cornerType(x0, y0, W, H)) {
    case "s": L(x0, y0); break;
    case "r": L(x0, y0 + r); A(r, 1, x0 + r, y0); break;
    case "nv": L(x0, y0 - n); A(n, 0, x0 + n, y0); break;
    case "nh": L(x0, y0 + n); A(n, 0, x0 - n, y0); break;
    }
    p.push("Z");
    return p.join(" ");
}
