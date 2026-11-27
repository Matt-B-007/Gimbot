#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Every check CI runs, in the same order with the same flags. CI calls this
# script and nothing else for checks, so a run here and a run on GitHub can't
# disagree. Run it from anywhere:
#
#   bash scripts/check.sh
#
# Optional environment:
#   OBSBOT_SDK_DIR   build against the real SDK (CI builds the simulated camera only)
#   GIMBOT_MIN_QT    oldest Qt to accept (default 6.8)
#   BUILD_DIR        where to build (default build-check)
#
# Exit codes: 0 every check passed, 1 a check failed, 3 only tools are
# missing (nothing was checked; the list says what to install).
#
# Colors only when the output is a terminal and NO_COLOR isn't set.

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

SHELLCHECK_PIN="0.11.0"     # CI: pip install shellcheck-py==0.11.0.1
ACTIONLINT_PIN="1.7.12"     # CI: pip install actionlint-py==1.7.12.25
BUILD_DIR="${BUILD_DIR:-build-check}"

if [[ -t 1 && -z "${NO_COLOR+x}" ]]; then
    bold=$'\e[1m' red=$'\e[1;31m' green=$'\e[1;32m' off=$'\e[0m'
else
    bold="" red="" green="" off=""
fi
step() { printf '\n%s==> %s%s\n' "$bold" "$*" "$off"; }
fail() { printf '\n%sFAILED: %s%s\n' "$red" "$*" "$off" >&2; exit 1; }

step "Required tools"
missing=()   # "what (arch package)"
packages=()
want() { # want <description> <arch package> <found?>
    if [[ "$3" != yes ]]; then missing+=("$1"); packages+=("$2"); fi
}
has() { if command -v "$1" >/dev/null 2>&1; then echo yes; else echo no; fi; }
want "cmake" cmake "$(has cmake)"
want "make" make "$(has make)"
want "a C++ compiler (c++)" gcc "$(has c++)"
want "shellcheck" shellcheck "$(has shellcheck)"
want "actionlint" actionlint "$(has actionlint)"
want "awk" gawk "$(has awk)"
qtpaths=""
for q in qtpaths6 /usr/lib/qt6/bin/qtpaths6 /usr/lib/qt6/bin/qtpaths; do
    if command -v "$q" >/dev/null 2>&1; then qtpaths="$q"; break; fi
done
want "Qt 6 (qtpaths6)" qt6-base "$([[ -n "$qtpaths" ]] && echo yes || echo no)"
if [[ -n "$qtpaths" ]]; then
    qml="$("$qtpaths" --query QT_INSTALL_QML)"
    libs="$("$qtpaths" --query QT_INSTALL_LIBS)"
    want "Qt Quick" qt6-declarative "$([[ -d "$qml/QtQuick" ]] && echo yes || echo no)"
    want "Qt Multimedia" qt6-multimedia "$([[ -d "$qml/QtMultimedia" ]] && echo yes || echo no)"
    svg=no
    for f in "$libs"/libQt6Svg.so*; do if [[ -e "$f" ]]; then svg=yes; fi; done
    want "Qt SVG" qt6-svg "$svg"
fi
if (( ${#missing[@]} > 0 )); then
    printf '%sMissing tools, so nothing was checked:%s\n' "$red" "$off" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    printf '\nInstall them with:\n  sudo pacman -S --needed %s\n' "${packages[*]}" >&2
    exit 3
fi
sc_ver="$(shellcheck --version | sed -n 's/^version: //p')"
al_ver="$(actionlint --version | head -n1)"
echo "shellcheck $sc_ver (CI: $SHELLCHECK_PIN), actionlint $al_ver (CI: $ACTIONLINT_PIN), $(cmake --version | head -n1)"
if [[ "$sc_ver" != "$SHELLCHECK_PIN" || "$al_ver" != "$ACTIONLINT_PIN" ]]; then
    echo "Note: these aren't the versions CI uses, so findings may differ slightly. That's fine on your PC."
fi

step "Check shell scripts (bash -n + shellcheck -s bash, all severities)"
shopt -s nullglob
scripts=(install.sh scripts/*.sh tests/*.sh)
shopt -u nullglob
for f in "${scripts[@]}"; do
    bash -n "$f" || fail "bash -n $f"
done
shellcheck -s bash "${scripts[@]}" || fail "shellcheck"
echo "${#scripts[@]} scripts: ${scripts[*]}"

step "Check workflow files (actionlint, which runs shellcheck on their steps)"
actionlint || fail "actionlint"

step "Check web addresses (tests/check_urls.sh)"
bash tests/check_urls.sh . || fail "unexpected web address"

step "Check version numbers agree (CMakeLists.txt, CHANGELOG.md, metainfo, beta PKGBUILD)"
version="$(sed -nE 's/^set\(GIMBOT_VERSION "([^"]+)".*/\1/p' CMakeLists.txt | head -n1)"
project="$(sed -nE 's/^project\(gimbot VERSION ([0-9.]+).*/\1/p' CMakeLists.txt)"
changelog="$(sed -nE 's/^## v?([^ ]+).*/\1/p' CHANGELOG.md | head -n1)"
metainfo="$(sed -nE 's/.*<release version="([^"]+)".*/\1/p' data/io.github.Matt_B_007.Gimbot.metainfo.xml | head -n1)"
pkgver="$(sed -nE 's/^pkgver=([^ ]+).*/\1/p' packaging/aur/gimbot-beta/PKGBUILD)"
echo "CMakeLists $version (project $project), CHANGELOG $changelog, metainfo $metainfo, gimbot-beta pkgver $pkgver"
[[ -n "$version" && "$version" == "$project"* ]] || fail "GIMBOT_VERSION must start with the project() version"
[[ "$changelog" == "$version" ]] || fail "CHANGELOG.md's top entry ($changelog) isn't $version"
[[ "$metainfo" == "$version" ]] || fail "the metainfo's newest release ($metainfo) isn't $version"
if [[ "$version" == *-* ]]; then
    [[ "$pkgver" == "${version//[-.]/}" || "$pkgver" == "$(echo "$version" | sed -E 's/-//; s/\.([0-9]+)$/\1/')" ]] \
        || fail "packaging/aur/gimbot-beta/PKGBUILD pkgver ($pkgver) doesn't match $version"
fi

step "Licence headers (SPDX-License-Identifier: MIT in every source file)"
no_spdx=()
while IFS= read -r -d '' f; do
    if ! head -n 3 "$f" | grep -q "SPDX-License-Identifier: MIT"; then no_spdx+=("$f"); fi
done < <(find . \( -path ./.git -o -path "./build*" \) -prune -o -type f \
    \( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' -o -name '*.qml' -o -name '*.sh' -o -name '*.yml' \
       -o -name '*.cmake' -o -name '*.py' -o -name CMakeLists.txt -o -name PKGBUILD \) -print0)
if (( ${#no_spdx[@]} > 0 )); then
    printf '  %s\n' "${no_spdx[@]}" >&2
    fail "these files need '// SPDX-License-Identifier: MIT' (or '# …') in their first lines"
fi
echo "every source file has one"

step "Configure and build (cmake, Debug, tests on, warnings are errors)"
cmake_args=(-S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON -DGIMBOT_WERROR=ON "-DGIMBOT_MIN_QT=${GIMBOT_MIN_QT:-6.8}")
if [[ -n "${OBSBOT_SDK_DIR:-}" ]]; then cmake_args+=("-DOBSBOT_SDK_DIR=$OBSBOT_SDK_DIR"); fi
cmake "${cmake_args[@]}" >/dev/null || fail "cmake configure"
cmake --build "$BUILD_DIR" -j"$(nproc)" || fail "build"

step "Unit and controller tests (ctest)"
QT_QPA_PLATFORM=offscreen ctest --test-dir "$BUILD_DIR" --output-on-failure || fail "ctest"

step "Self-test (gimbot --self-test)"
QT_QPA_PLATFORM=offscreen "$BUILD_DIR/gimbot" --self-test || fail "gimbot --self-test"

step "Release build and its self-test (cmake Release, gimbot --self-test)"
release_args=(-S . -B "$BUILD_DIR-release" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DGIMBOT_WERROR=ON "-DGIMBOT_MIN_QT=${GIMBOT_MIN_QT:-6.8}")
if [[ -n "${OBSBOT_SDK_DIR:-}" ]]; then release_args+=("-DOBSBOT_SDK_DIR=$OBSBOT_SDK_DIR"); fi
cmake "${release_args[@]}" >/dev/null || fail "cmake configure (Release)"
cmake --build "$BUILD_DIR-release" -j"$(nproc)" || fail "build (Release)"
QT_QPA_PLATFORM=offscreen "$BUILD_DIR-release/gimbot" --self-test || fail "gimbot --self-test (Release build)"

step "Installer self-test (install.sh --self-test)"
bash install.sh --self-test || fail "install.sh --self-test"

step "Screens load without QML errors (gimbot --fake --screenshots)"
rm -rf "$BUILD_DIR/shots"
shots_rc=0
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$BUILD_DIR/gimbot" --fake --screenshots "$BUILD_DIR/shots" >"$BUILD_DIR/screens.log" 2>&1 || shots_rc=$?
if (( shots_rc != 0 )); then
    tail -n 20 "$BUILD_DIR/screens.log" >&2
    if (( shots_rc > 128 )); then
        fail "the screenshot run crashed (signal $((shots_rc - 128))) after $(find "$BUILD_DIR/shots" -name '*.png' | wc -l) screens"
    fi
    fail "the screenshot run exited with code $shots_rc (see $BUILD_DIR/screens.log)"
fi
if grep -E " W qrc:| E |TypeError|ReferenceError" "$BUILD_DIR/screens.log"; then
    fail "QML errors while loading the screens"
fi
shots="$(find "$BUILD_DIR/shots" -name '*.png' | wc -l)"
(( shots >= 20 )) || fail "only $shots screenshots were saved"
echo "$shots screens"

printf '\n%s==> All checks passed%s\n' "$green" "$off"
