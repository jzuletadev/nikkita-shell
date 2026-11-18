// ~/nikita-shell/tests/qml/tst_fuzzy.qml
//
// The launcher's ranking (dotfiles/quickshell/common/Fuzzy.js). Run with tests/run.sh.
import QtQuick
import QtTest
import "../../dotfiles/quickshell/common/Fuzzy.js" as Fuzzy

TestCase {
    name: "Fuzzy"

    // The order the launcher would show: best first.
    function rank(query, entries) {
        return entries.map(e => [Fuzzy.fields(query, e), e[0]])
            .filter(x => x[0] !== null)
            .sort((a, b) => b[0] - a[0])
            .map(x => x[1]);
    }

    function test_empty_query_matches_everything() {
        compare(Fuzzy.score("", "Files"), 0);
    }

    function test_no_match_is_null() {
        compare(Fuzzy.score("xyz", "Files"), null);
        compare(Fuzzy.score("a", ""), null);
        compare(Fuzzy.fields("xyz", ["Files", "Access and organize files"]), null);
    }

    function test_case_does_not_matter() {
        compare(Fuzzy.score("FILES", "files"), Fuzzy.score("files", "Files"));
    }

    function test_initials_match() {
        verify(Fuzzy.score("vsc", "Visual Studio Code") !== null);
        compare(rank("vsc", [["Visual Studio Code"], ["vascular"]])[0], "Visual Studio Code");
    }

    // The rule the launcher depends on: any name match beats any description match.
    function test_name_beats_description() {
        const brave = ["Brave", "Access the Internet"];
        const other = ["Some App", "Browse Really Anywhere"];      // "bra" as initials
        compare(rank("bra", [other, brave])[0], "Brave");
        verify(Fuzzy.fields("bra", brave) > Fuzzy.fields("bra", other));
    }

    function test_word_start_beats_middle() {
        compare(rank("co", [["Disco"], ["Code"]])[0], "Code");
    }

    // What you typed is the start of a name: that name first, even over initials.
    function test_prefix_beats_initials() {
        compare(rank("files", [["Find Image Lens Effects Studio"], ["Files"]])[0], "Files");
        compare(rank("vi", [["Video Importer"], ["Vim"]])[0], "Vim");
        compare(rank("term", [["Text Editor Remote Manager"], ["Terminal"]])[0], "Terminal");
    }

    // A frequency boost (services/Frecency.qml, at most 40) must not cross levels.
    function test_levels_are_far_apart() {
        const name = Fuzzy.fields("net", ["Network", ""]);
        const desc = Fuzzy.fields("net", ["Settings", "Network, wired"]);
        verify(name - desc > 40 * 10);
    }
}
