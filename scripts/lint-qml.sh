#!/usr/bin/env bash
# ~/nikkita-shell/scripts/lint-qml.sh
#
# qmllint over the desktop's QML, keeping what points at a real mistake: a property
# or function that doesn't exist (a renamed token, a removed function). Exits 1 if it
# finds any. Style warnings (unqualified access, ...) are left out.
#
# It needs the import paths Quickshell writes into dotfiles/quickshell/.qmlls.ini
# while `qs` runs (the same file makes qmlls work in an editor). If the file is
# missing, this creates it empty: reload the shell (or save any QML file) and run
# this again.
#
#   scripts/lint-qml.sh            every file
#   scripts/lint-qml.sh FILE...    only these (paths inside dotfiles/quickshell)

set -uo pipefail

QS="$(cd "$(dirname "$0")/.." && pwd)/dotfiles/quickshell"
QMLLINT=/usr/lib/qt6/bin/qmllint
[ -x "$QMLLINT" ] || { echo "qmllint not found (qt6-declarative)" >&2; exit 2; }

ini="$QS/.qmlls.ini"
if [ ! -s "$ini" ]; then
    touch "$ini"
    echo "Created $ini: reload the shell so Quickshell fills it, then run this again." >&2
    exit 2
fi
vfs=$(sed -n 's/^buildDir="\(.*\)"$/\1/p' "$ini")
[ -d "$vfs/qs" ] || { echo "Quickshell's import folder ($vfs) is gone: reload the shell." >&2; exit 2; }

cd "$QS"
if (( $# )); then
    files=("$@")
else
    # The login screen has its own root (greeter.qml): its imports aren't in this folder.
    mapfile -t files < <(find . -name '*.qml' -not -path './greeter/*' -not -name greeter.qml | sort)
fi

# "Member X not found on type Y" is a false alarm when Y is a singleton next to the
# file: qmllint reads the folder without its qmldir, so it doesn't know Y is one.
# The pairs below are types it can't see through (StdioCollector, object models).
out=$("$QMLLINT" -I "$vfs" -I /usr/lib/qt6/qml "${files[@]}" 2>&1)
found=$(printf '%s\n' "$out" | python3 -I -c '
import re, sys, os
singletons = {}
for d in os.listdir("."):
    if os.path.isdir(d):
        singletons[d] = {f[:-4] for f in os.listdir(d)
                         if f.endswith(".qml") and "pragma Singleton" in open(os.path.join(d, f)).read()}
for line in sys.stdin:
    m = re.match(r"Warning: (?:\./)?([^:]+):(\d+):\d+: (Member \"(\w+)\" not found on type \"?([\w:]+)\"?.*)\[missing-property\]", line)
    if not m:
        continue
    path, num, text, member, typ = m.groups()
    folder = path.split("/")[0] if "/" in path else ""
    # "const QMetaObject": an assignment to such a singleton. "QObject": what a
    # Loader loaded, which qmllint cannot see.
    if typ in singletons.get(folder, set()) or typ in ("const", "QObject"):
        continue
    if (typ, member) in {("DataStreamParser", "text"), ("UntypedObjectModel", "values")}:
        continue
    print(f"{path}:{num}: {text.strip()}")
')

if [ -n "$found" ]; then
    printf '%s\n' "$found"
    echo "qmllint: $(printf '%s\n' "$found" | wc -l) reference(s) to something that doesn't exist" >&2
    exit 1
fi
echo "qmllint: ${#files[@]} files, no missing properties"
