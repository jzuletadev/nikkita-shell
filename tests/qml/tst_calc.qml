// ~/nikita-shell/tests/qml/tst_calc.qml
//
// The launcher's calculator (dotfiles/quickshell/common/Calc.js). Run with tests/run.sh.
import QtQuick
import QtTest
import "../../dotfiles/quickshell/common/Calc.js" as Calc

TestCase {
    name: "Calc"

    function test_order_of_operations() {
        compare(Calc.evaluate("2+3*4"), 14);
        compare(Calc.evaluate("(2+3)*4"), 20);
        compare(Calc.evaluate("2^3^2"), 512);
        compare(Calc.evaluate("-2^2"), -4);
        compare(Calc.evaluate("10 % 4"), 2);
        compare(Calc.evaluate("7/2"), 3.5);
    }

    function test_how_people_type() {
        compare(Calc.evaluate("1,5*2"), 3);
        compare(Calc.evaluate("3 x 4"), 12);
        compare(Calc.evaluate("3×4÷2"), 6);
        compare(Calc.evaluate("sqrt 16 + 1"), 5);
        compare(Calc.evaluate("sqrt(16)"), 4);
        compare(Calc.format(Calc.evaluate("sin(30)")), "0.5");
        compare(Calc.format(Calc.evaluate("2*pi")), "6.28318530718");
        compare(Calc.evaluate("log 1000"), 3);
    }

    function test_a_search_is_not_a_sum() {
        compare(Calc.evaluate(""), null);
        compare(Calc.evaluate("firefox"), null);
        compare(Calc.evaluate("42"), null);
        compare(Calc.evaluate("(42)"), null);
        compare(Calc.evaluate("2+"), null);
        compare(Calc.evaluate("1.2.3+1"), null);
        compare(Calc.evaluate("alert(1)"), null);
        compare(Calc.evaluate("1/0"), null);
    }

    function test_equals_forces_it() {
        compare(Calc.evaluate("=42"), 42);
        compare(Calc.evaluate("= pi"), Math.PI);
        compare(Calc.evaluate("="), null);
    }

    function test_format() {
        compare(Calc.format(0.1 + 0.2), "0.3");
        compare(Calc.format(Calc.evaluate("1/3")), "0.333333333333");
        compare(Calc.format(2e20), "2e+20");
        compare(Calc.format(-0), "0");
    }
}
