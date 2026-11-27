#!/usr/bin/env bash
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
# Tools: cmake, a C++ compiler, Qt 6, shellcheck and actionlint. The versions
# CI uses are pinned below; `pip install shellcheck-py==… actionlint-py==…`
# installs the same ones.

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

SHELLCHECK_PIN="0.11.0"     # pip: shellcheck-py==0.11.0.1
ACTIONLINT_PIN="1.7.12"     # pip: actionlint-py==1.7.12.25
BUILD_DIR="${BUILD_DIR:-build-check}"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nFAILED: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || fail "$1 isn't installed ($2)"; }

step "Tool versions"
need shellcheck "pip install shellcheck-py==0.11.0.1"
need actionlint "pip install actionlint-py==1.7.12.25"
need cmake "pacman -S cmake"
sc_ver="$(shellcheck --version | sed -n 's/^version: //p')"
al_ver="$(actionlint --version | head -n1)"
echo "shellcheck $sc_ver (CI: $SHELLCHECK_PIN), actionlint $al_ver (CI: $ACTIONLINT_PIN), $(cmake --version | head -n1)"
if [[ "$sc_ver" != "$SHELLCHECK_PIN" || "$al_ver" != "$ACTIONLINT_PIN" ]]; then
    echo "Note: a different tool version than CI may report different findings."
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

step "Configure and build (cmake, Debug, tests on)"
cmake_args=(-S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON "-DGIMBOT_MIN_QT=${GIMBOT_MIN_QT:-6.8}")
if [[ -n "${OBSBOT_SDK_DIR:-}" ]]; then cmake_args+=("-DOBSBOT_SDK_DIR=$OBSBOT_SDK_DIR"); fi
cmake "${cmake_args[@]}" >/dev/null || fail "cmake configure"
cmake --build "$BUILD_DIR" -j"$(nproc)" || fail "build"

step "Unit and controller tests (ctest)"
QT_QPA_PLATFORM=offscreen ctest --test-dir "$BUILD_DIR" --output-on-failure || fail "ctest"

step "Self-test (gimbot --self-test)"
QT_QPA_PLATFORM=offscreen "$BUILD_DIR/gimbot" --self-test || fail "gimbot --self-test"

step "Installer self-test (install.sh --selftest)"
bash install.sh --selftest || fail "install.sh --selftest"

step "Screens load without QML errors (gimbot --fake --screenshots)"
rm -rf "$BUILD_DIR/shots"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    "$BUILD_DIR/gimbot" --fake --screenshots "$BUILD_DIR/shots" >"$BUILD_DIR/screens.log" 2>&1 \
    || fail "the screenshot run exited with an error (see $BUILD_DIR/screens.log)"
if grep -E " W qrc:| E |TypeError|ReferenceError" "$BUILD_DIR/screens.log"; then
    fail "QML errors while loading the screens"
fi
shots="$(find "$BUILD_DIR/shots" -name '*.png' | wc -l)"
(( shots >= 20 )) || fail "only $shots screenshots were saved"
echo "$shots screens"

step "All checks passed"
