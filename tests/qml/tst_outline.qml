// ~/nikita-shell/tests/qml/tst_outline.qml
//
// The outline of a panel and of its rim (dotfiles/quickshell/common/Outline.js). Run
// with tests/run.sh.
import QtQuick
import QtTest
import "../../dotfiles/quickshell/common/Outline.js" as Outline

TestCase {
    name: "Outline"

    readonly property int w: 1920
    readonly property int h: 1080

    // The points a path visits, as "x y".
    function points(path) {
        return path.split(/ (?=[MLAZ])/).filter(s => s !== "Z").map(s => {
            const f = s.split(" ");
            return f[0] === "A" ? f[6] + " " + f[7] : f[1] + " " + f[2];
        });
    }

    function test_a_closed_panel_has_no_path() {
        compare(Outline.outline(0, 0, 0, 100, w, h, 16, 18), "M 0 0");
        compare(Outline.rim(0, 0, 0, 100, w, h, 16, 18), "M 0 0");
    }

    function test_outline_of_a_top_left_corner() {
        compare(Outline.outline(0, 0, 300, 200, w, h, 16, 18),
                "M 150 0 L 318 0 A 18 18 0 0 0 300 18 L 300 184 A 16 16 0 0 1 284 200 L 18 200 A 18 18 0 0 0 0 218 L 0 0 Z");
    }

    function test_the_rim_of_a_corner_never_runs_along_the_screen() {
        // From the notch on the top edge round to the one on the left edge.
        compare(Outline.rim(0, 0, 300, 200, w, h, 16, 18),
                "M 318 0 A 18 18 0 0 0 300 18 L 300 184 A 16 16 0 0 1 284 200 L 18 200 A 18 18 0 0 0 0 218");
    }

    function test_the_rim_of_every_placement_stays_off_the_edges() {
        const panels = [
            [0, 0, 300, 200], [w - 300, 0, 300, 200], [0, h - 200, 300, 200], [w - 300, h - 200, 300, 200],
            [500, 0, 800, 300], [500, h - 58, 800, 58], [0, 400, 60, 200], [w - 60, 400, 60, 200]
        ];
        for (const b of panels) {
            const path = Outline.rim(b[0], b[1], b[2], b[3], w, h, 16, 18);
            verify(!path.endsWith("Z"), path);
            compare(path.match(/M/g).length, 1, path);
            // Only its two ends may touch the edge of the screen.
            const p = points(path);
            for (const q of p.slice(1, -1)) {
                const f = q.split(" ").map(Number);
                verify(f[0] > 0 && f[0] < w && f[1] > 0 && f[1] < h, path);
            }
        }
    }

    function test_a_floating_box_gets_a_closed_rim() {
        verify(Outline.rim(100, 100, 300, 200, w, h, 16, 18).endsWith("Z"));
    }
}
