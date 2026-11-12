// ~/nikkita-shell/dotfiles/quickshell/common/Calc.js
//
// The launcher's calculator: + - * / % (remainder) ^, parentheses, decimals with a
// point or a comma, x and × for times, ÷, and sqrt sin cos tan asin acos atan log
// (base 10) ln abs round floor ceil, pi and e. Angles in degrees. A small parser,
// never eval: nothing typed runs as code.
.pragma library

const functions = {
    sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
    ln: Math.log, log: Math.log10,
    sin: x => Math.sin(x * Math.PI / 180), cos: x => Math.cos(x * Math.PI / 180), tan: x => Math.tan(x * Math.PI / 180),
    asin: x => Math.asin(x) * 180 / Math.PI, acos: x => Math.acos(x) * 180 / Math.PI, atan: x => Math.atan(x) * 180 / Math.PI
};
const constants = { pi: Math.PI, e: Math.E };

function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const c = s[i];
        if (c === " ") {
            i++;
        } else if (/[0-9.,]/.test(c)) {
            let j = i;
            while (j < s.length && /[0-9.,]/.test(s[j]))
                j++;
            const raw = s.slice(i, j);
            // One separator is the decimal point, a point or a comma alike.
            if ((raw.match(/[.,]/g) || []).length > 1)
                return null;
            out.push({ t: "num", v: parseFloat(raw.replace(",", ".")) });
            i = j;
        } else if (/[a-z]/i.test(c)) {
            let j = i;
            while (j < s.length && /[a-z]/i.test(s[j]))
                j++;
            const w = s.slice(i, j).toLowerCase();
            if (w === "x")
                out.push({ t: "op", v: "*" });
            else if (functions[w] !== undefined)
                out.push({ t: "fn", v: w });
            else if (constants[w] !== undefined)
                out.push({ t: "num", v: constants[w] });
            else
                return null;
            i = j;
        } else if ("+-*/%^()×÷".indexOf(c) >= 0) {
            out.push({ t: "op", v: c === "×" ? "*" : c === "÷" ? "/" : c });
            i++;
        } else {
            return null;
        }
    }
    return out;
}

// expr := term (("+" | "-") term)*      term := unary (("*" | "/" | "%") unary)*
// unary := "-" unary | "+" unary | power  power := atom ("^" unary)?
// atom := number | fn atom | "(" expr ")"
// So -2^2 is -4 and 2^3^2 is 2^9, as on paper.
function parse(tokens) {
    let i = 0;
    const peek = () => tokens[i];
    const isOp = v => peek() !== undefined && peek().t === "op" && peek().v === v;
    function expr() {
        let v = term();
        while (isOp("+") || isOp("-"))
            v = tokens[i++].v === "+" ? v + term() : v - term();
        return v;
    }
    function term() {
        let v = unary();
        while (isOp("*") || isOp("/") || isOp("%")) {
            const op = tokens[i++].v;
            const r = unary();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function power() {
        const b = atom();
        if (isOp("^")) {
            i++;
            return Math.pow(b, unary());
        }
        return b;
    }
    function unary() {
        if (isOp("-")) {
            i++;
            return -unary();
        }
        if (isOp("+")) {
            i++;
            return unary();
        }
        return power();
    }
    function atom() {
        const tk = tokens[i++];
        if (tk === undefined)
            throw "end";
        if (tk.t === "num")
            return tk.v;
        if (tk.t === "fn")
            return functions[tk.v](atom());
        if (tk.t === "op" && tk.v === "(") {
            const v = expr();
            if (!isOp(")"))
                throw "paren";
            i++;
            return v;
        }
        throw "token";
    }
    const v = expr();
    if (i !== tokens.length)
        throw "rest";
    return v;
}

// The value of `text`, or null if it isn't a sum to do. A lone number isn't one
// (that's a search), unless it starts with "=".
function evaluate(text) {
    let s = (text || "").trim();
    const forced = s.startsWith("=");
    if (forced)
        s = s.slice(1).trim();
    if (s === "")
        return null;
    const tokens = tokenize(s);
    if (tokens === null)
        return null;
    if (!forced && !tokens.some(t => t.t === "fn" || (t.t === "op" && t.v !== "(" && t.v !== ")")))
        return null;
    try {
        const v = parse(tokens);
        return isFinite(v) ? v : null;
    } catch (e) {
        return null;
    }
}

// 0.1 + 0.2 shows as 0.3: twelve significant digits, no trailing zeros.
function format(v) {
    if (v === 0)
        return "0";
    const r = parseFloat(v.toPrecision(12));
    return Math.abs(r) >= 1e15 || Math.abs(r) < 1e-9 ? r.toExponential(6).replace(/\.?0+e/, "e") : String(r);
}
