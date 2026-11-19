// ~/nikita-shell/dotfiles/quickshell/common/Fuzzy.js
//
// The launcher's scoring. Two ways to match, keeping the best: as initials ("vsc" ->
// Visual Studio Code) or greedy (rewarding consecutive letters and word starts).
//
// Fields are LEVELS, not weights: any name match beats any description match.
// Otherwise "bra" ranks an app whose description matches as an acronym over Brave.
//
// A text that starts with what was typed is what was meant: PREFIX puts it over
// any initials of the same letters ("files": Files before "Find Image Lens...").
// Initials earn 4 more per letter than a run of letters, so it grows with them.
.pragma library

const START = 18, WORD = 12, CONSECUTIVE = 8, LOOSE = 2, GAP = -1, ACRONYM = 25, FIELD = 1000;
const PREFIX = 10, PREFIX_PER_LETTER = 4;

function isBoundary(c) {
    return /\s/.test(c) || "-_./:([".includes(c);
}

function boundaries(t) {
    const v = [];
    for (let i = 0; i < t.length; i++)
        if (i === 0 || isBoundary(t[i - 1]))
            v.push(i);
    return v;
}

function acronym(needle, text, lower) {
    const f = boundaries(text);
    let fromIdx = 0, total = ACRONYM;
    for (const a of needle) {
        if (/\s/.test(a))
            continue;
        let p = -1;
        for (let k = fromIdx; k < f.length; k++)
            if (lower[f[k]] === a) {
                p = k;
                break;
            }
        if (p < 0)
            return null;
        total += f[p] === 0 ? START : WORD;
        fromIdx = p + 1;
    }
    return total - Math.floor(text.length / 8);
}

function greedy(needle, text, lower) {
    let total = 0, i = 0, prev = -1;
    for (const a of needle) {
        if (/\s/.test(a))
            continue;
        const j = lower.indexOf(a, i);
        if (j < 0)
            return null;
        const atWord = j > 0 && isBoundary(text[j - 1]);
        total += j === 0 ? START : atWord ? WORD : prev === j - 1 ? CONSECUTIVE : LOOSE;
        if (prev >= 0 && !atWord)
            total += GAP * Math.min(20, j - prev - 1);
        prev = j;
        i = j + 1;
    }
    return total - Math.floor(text.length / 8);
}

function score(needle, haystack) {
    if (!needle)
        return 0;
    if (!haystack)
        return null;
    const lower = haystack.toLowerCase();
    const text = lower.length === haystack.length ? haystack : lower;
    const lowNeedle = needle.toLowerCase();
    const a = acronym(lowNeedle, text, lower.length === haystack.length ? lower : text);
    const b = greedy(lowNeedle, text, lower.length === haystack.length ? lower : text);
    const prefix = lower.startsWith(lowNeedle) ? PREFIX + PREFIX_PER_LETTER * lowNeedle.length + ACRONYM : 0;
    if (a === null)
        return b === null ? null : b + prefix;
    if (b === null)
        return a;
    return Math.max(a, b + prefix);
}

// How clearly a text holds one typed word: 3 it starts with it, 2 a word in it does
// (or its initials spell it), 1 it is inside a word, 0 its letters are only scattered.
// "wifi" also finds "Wi-Fi".
function gradeWord(word, lower) {
    let best = 0;
    for (const t of [lower, lower.replace(/[-_.]/g, "")]) {
        if (t.startsWith(word))
            return 3;
        if (boundaries(t).some(i => t.startsWith(word, i)))
            best = Math.max(best, 2);
        else if (t.includes(word))
            best = Math.max(best, 1);
    }
    if (word.length > 1 && acronym(word, lower, lower) !== null)
        best = Math.max(best, 2);
    return best;
}

function grade(needle, text) {
    const lower = text.toLowerCase();
    return Math.min(...needle.toLowerCase().trim().split(/\s+/).map(w => gradeWord(w, lower)));
}

// What the launcher lists for `needle`, best first. `items` have id, name and search
// (the description); `boost(id)` adds what you use. Scattered letters still find
// things, for typos, but only when nothing matches better. A description counts
// from three letters on, or when no name matches at all: two letters are in
// everything.
function rank(needle, items, boost) {
    const hits = [];
    let bestName = -1, bestSearch = -1;
    for (const it of items) {
        const value = fields(needle, [it.name, it.search]);
        if (value === null)
            continue;
        const name = score(needle, it.name) !== null ? grade(needle, it.name) : -1;
        const search = score(needle, it.search) !== null ? grade(needle, it.search) : -1;
        hits.push({ it, value: value + boost(it.id), name, search });
        bestName = Math.max(bestName, name);
        bestSearch = Math.max(bestSearch, search);
    }
    const floor = Math.min(bestName, 2);
    const anyName = bestName >= 0;
    const longEnough = needle.trim().length >= 3;
    return hits.filter(h => (anyName && h.name >= floor)
                         || (anyName ? longEnough && h.search >= 2 : h.search >= Math.min(bestSearch, 2)))
        .sort((a, b) => (b.value - a.value) || a.it.name.localeCompare(b.it.name))
        .map(h => h.it);
}

function fields(needle, items) {
    let best = null;
    for (let n = 0; n < items.length; n++) {
        const s = score(needle, items[n]);
        if (s !== null) {
            const v = s - FIELD * n;
            best = best === null ? v : Math.max(best, v);
        }
    }
    return best;
}
