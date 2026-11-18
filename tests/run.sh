#!/usr/bin/env bash
# ~/nikita-shell/tests/run.sh
#
# Every check that runs without touching the desktop: the launcher's ranking and
# calculator and shortcut capture (QML, headless), GPU detection and the battery's
# charge limit on simulated machines, the firewall in a network of its own, the
# scripts' syntax, both Hyprland configs, and qmllint for references to things that don't exist (skipped until
# Quickshell has written dotfiles/quickshell/.qmlls.ini; see scripts/lint-qml.sh).
# None of it replaces trying a change on the running desktop.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"
failed=()

check() {   # check <name> <command...>
    local name=$1
    shift
    printf '\n== %s\n' "$name"
    if "$@"; then
        echo "ok"
    else
        failed+=("$name")
    fi
}

qml_tests() {
    QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | grep -E '^(FAIL|Totals)|Actual|Expected|Loc:'
    return "${PIPESTATUS[0]}"
}

script_syntax() {
    local f ok=0
    for f in install.sh scripts/*.sh tests/*.sh; do
        bash -n "$f" || ok=1
    done
    for f in scripts/*.py tests/*.py; do
        python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$f" || ok=1
    done
    return $ok
}

hyprland_configs() {
    local c ok=0
    for c in dotfiles/hypr/hyprland.lua system/greetd/hyprland.lua; do
        env -u HYPRLAND_INSTANCE_SIGNATURE Hyprland --verify-config --config "$c" 2>&1 | grep -q '^config ok$' ||
            { echo "$c has errors: Hyprland --verify-config --config $c"; ok=1; }
    done
    return $ok
}

qml_lint() {
    if [ ! -s dotfiles/quickshell/.qmlls.ini ]; then
        echo "skipped: no .qmlls.ini yet (run scripts/lint-qml.sh once, then reload the shell)"
        return 0
    fi
    scripts/lint-qml.sh
}

check "Launcher ranking and calculator (tests/qml)" qml_tests
check "GPU detection (tests/gpu-drivers.sh)" tests/gpu-drivers.sh
check "Battery charge limit (tests/charge-limit.sh)" tests/charge-limit.sh
check "Firewall, in a network of its own (tests/firewall.sh)" tests/firewall.sh
check "Script syntax" script_syntax
check "Hyprland configs" hyprland_configs
check "QML references (scripts/lint-qml.sh)" qml_lint

echo
if (( ${#failed[@]} )); then
    printf 'FAILED: %s\n' "${failed[@]}"
    exit 1
fi
echo "All checks passed."
