#!/usr/bin/env bash
# Gimbot installer and updater for CachyOS, Arch and other Arch-based systems.
#
# Install:   curl -fsSL https://raw.githubusercontent.com/Matt-B-007/Gimbot/main/install.sh | bash
# Update:    gimbot-update            (the app's "Update now" button runs this)
# From zip:  bash install.sh         (run inside the unzipped folder)
# Uninstall: gimbot-update --uninstall
#            curl -fsSL https://raw.githubusercontent.com/Matt-B-007/Gimbot/main/install.sh | bash -s -- --uninstall
#
# It builds Gimbot on this computer with your own copy of the OBSBOT SDK
# (OBSBOT emails it to you; the script finds it in ~/Downloads), packages it
# for pacman and installs it. The SDK zip is moved out of Downloads into
# ~/.local/share/gimbot/sdk, so later updates need nothing from you.
#
# Options:
#   --channel stable|beta   Which releases to follow (default: stable, or your saved choice)
#   --version TAG           Install this release tag instead of the newest
#   --sdk FILE              Use this SDK zip
#   --source DIR            Build from a local source folder instead of downloading
#   --check                 Print the newest version for the channel and exit
#   --uninstall             Remove Gimbot (asks whether to delete settings too)
#   --purge                 With --uninstall: also delete settings, logs and the saved SDK
#   --keep-data             With --uninstall: keep them
#   --yes                   Don't ask questions
#   --gui                   Machine-readable progress for the Gimbot app (implies --yes)

set -euo pipefail

DEFAULT_REPO="Matt-B-007/Gimbot" # GitHub owner/repo
REPO="${GIMBOT_REPO:-$DEFAULT_REPO}"
LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gimbot/logs"
SDK_CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/gimbot/sdk"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gimbot/gimbot.conf"
DEPS=(cmake extra-cmake-modules base-devel unzip curl
      qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg
      kcoreaddons kcrash kglobalaccel kstatusnotifieritem)

channel=""
version=""
sdk=""
source_dir=""
check_only=0
assume_yes=0
gui=0
uninstall=0
purge="" # yes | no | "" (ask)

# ---------------------------------------------------------------- output

if [[ -t 1 ]]; then bold=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; green=$'\e[32m'; reset=$'\e[0m'
else bold=""; dim=""; red=""; green=""; reset=""; fi

# Progress: a percentage and a short message. The app reads the ::progress lines.
step() {
    if (( gui )); then echo "::progress $1 $2"; else echo "${bold}==>${reset} $2"; fi
}
info() { if (( gui )); then echo "$*"; else echo "    ${dim}$*${reset}"; fi; }
die() {
    local code="${2:-1}"
    if (( gui )); then echo "::error $1"; else echo "${red}${bold}error:${reset} $1" >&2; fi
    exit "$code"
}
ask() { # ask "Question" default -> answer (reads the keyboard even when piped from curl)
    local answer=""
    if (( assume_yes )) || [[ ! -r /dev/tty ]]; then echo "$2"; return; fi
    read -r -p "$1 " answer </dev/tty || true
    echo "${answer:-$2}"
}

# Run a command as root: sudo in a terminal, the desktop password prompt from the app.
as_root() {
    if (( gui )); then pkexec "$@"; else sudo "$@"; fi
}

# ---------------------------------------------------------------- helpers

# v1.3.0-beta.1 -> 1.3.0beta1 (pacman sorts this before 1.3.0, as it should)
pkgver_from_tag() {
    local v="${1#v}"
    v="$(sed -E 's/-([A-Za-z]+)\.?/\1/; s/[^A-Za-z0-9.]//g' <<<"$v")"
    echo "$v"
}

# Newest SDK zip among the places it's likely to be (highest version wins).
find_sdk_zip() {
    local candidates=()
    shopt -s nullglob
    candidates+=("$SDK_CACHE"/libdev*.zip)
    candidates+=("$HOME"/Downloads/libdev*.zip "$HOME"/Downloads/*/libdev*.zip)
    candidates+=("$PWD"/libdev*.zip)
    [[ -n "$source_dir" ]] && candidates+=("$source_dir"/libdev*.zip)
    shopt -u nullglob
    (( ${#candidates[@]} )) || return 1
    local best
    best="$(for f in "${candidates[@]}"; do printf '%s\t%s\n' "$(basename "$f")" "$f"; done \
            | sort -t$'\t' -k1,1V | tail -n1 | cut -f2)"
    echo "$best"
}

# Value of a "key": "value" or "key": true pair in a JSON object (good enough for GitHub's API).
json_field() { grep -oE "\"$1\": *(\"[^\"]*\"|true|false)" | head -n1 | sed -E 's/^[^:]+: *"?//; s/"$//'; }

# The version in a source folder: set(GIMBOT_VERSION "0.1.0-beta.4") -> v0.1.0-beta.4
source_tag() {
    local v
    v="$(sed -nE 's/^set\(GIMBOT_VERSION "([^"]+)".*/\1/p' "$1/CMakeLists.txt" | head -n1)"
    [[ -n "$v" ]] || v="$(sed -nE 's/^project\(gimbot VERSION ([0-9.]+).*/\1/p' "$1/CMakeLists.txt")"
    echo "v$v"
}

# ---------------------------------------------------------------- network
#
# curl, but if this computer can't look up web addresses (broken DNS), ask a
# public DNS service over HTTPS instead. Those are reached by IP address, so
# they work even when name lookups don't.
DOH_URLS=(https://1.1.1.1/dns-query https://8.8.8.8/dns-query)
net() {
    local rc=0 doh
    curl "$@" && return 0 || rc=$?
    (( rc == 6 )) || return "$rc" # 6 = couldn't resolve the host name
    for doh in "${DOH_URLS[@]}"; do
        if curl --doh-url "$doh" "$@"; then
            if [[ -z "${GIMBOT_DOH_NOTED:-}" ]]; then
                info "This computer can't look up web addresses (DNS), so the installer asked $doh instead." >&2
                export GIMBOT_DOH_NOTED=1
            fi
            return 0
        fi
    done
    return "$rc"
}

# A plain-language reason when GitHub can't be reached.
net_problem() {
    if ! getent hosts github.com >/dev/null 2>&1; then
        echo "this computer can't look up web addresses (DNS isn't working). See \"Can't reach GitHub\" in the README"
    else
        echo "check your internet connection, or try again in a few minutes"
    fi
}

latest_tag() { # latest_tag stable|beta
    local url
    if [[ "$1" == beta ]]; then
        # Newest published release of either kind.
        url="https://api.github.com/repos/$REPO/releases?per_page=1"
    else
        # GitHub's "latest" skips pre-releases and drafts.
        url="https://api.github.com/repos/$REPO/releases/latest"
    fi
    local json
    json="$(net -fsSL --max-time 20 -H "Accept: application/vnd.github+json" "$url")" || return 1
    printf '%s\n' "$json" | json_field tag_name
}

saved_channel() {
    [[ -f "$CONFIG" ]] || return 0
    case "$(sed -nE 's/^updateChannel=([0-9]+).*/\1/p' "$CONFIG" | tail -n1)" in
        2) echo beta ;;
        1) echo stable ;;
    esac
}

save_channel() { # only when Gimbot has no settings yet; the app owns them after that
    [[ -f "$CONFIG" ]] && return 0
    mkdir -p "$(dirname "$CONFIG")"
    printf '[settings]\nupdateChannel=%s\n' "$([[ "$1" == beta ]] && echo 2 || echo 1)" >"$CONFIG"
}

selftest() {
    local fail=0
    t() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
    t "release tag"   "$(pkgver_from_tag v1.2.0)" "1.2.0"
    t "beta tag"      "$(pkgver_from_tag v1.3.0-beta.1)" "1.3.0beta1"
    t "rc tag"        "$(pkgver_from_tag 2.0.0-rc2)" "2.0.0rc2"
    t "json string"   "$(echo '{"tag_name": "v1.4.0", "x": 1}' | json_field tag_name)" "v1.4.0"
    t "json bool"     "$(echo '{"prerelease": true}' | json_field prerelease)" "true"
    local srcdir; srcdir="$(mktemp -d)"
    printf 'project(gimbot VERSION 0.1.0 LANGUAGES CXX)\nset(GIMBOT_VERSION "0.1.0-beta.4")\n' >"$srcdir/CMakeLists.txt"
    t "source tag"    "$(source_tag "$srcdir")" "v0.1.0-beta.4"
    t "beta pkgver"   "$(pkgver_from_tag "$(source_tag "$srcdir")")" "0.1.0beta4"
    rm -rf "$srcdir"
    local tmp; tmp="$(mktemp -d)"
    HOME="$tmp" SDK_CACHE="$tmp/cache"; mkdir -p "$tmp/Downloads" "$tmp/cache"
    touch "$tmp/Downloads/libdev_v2.1.0_8.zip" "$tmp/cache/libdev_v2.1.0_10.zip" "$tmp/Downloads/libdev_v2.0.9_1.zip"
    t "newest sdk"    "$(basename "$(find_sdk_zip)")" "libdev_v2.1.0_10.zip"
    rm -rf "$tmp"
    exit "$fail"
}

# ---------------------------------------------------------------- arguments

while (( $# )); do
    case "$1" in
        --channel) channel="${2:-}"; shift 2 ;;
        --version) version="${2:-}"; shift 2 ;;
        --sdk) sdk="${2:-}"; shift 2 ;;
        --source) source_dir="${2:-}"; shift 2 ;;
        --check) check_only=1; shift ;;
        --uninstall) uninstall=1; shift ;;
        --purge) purge=yes; shift ;;
        --keep-data) purge=no; shift ;;
        --yes|-y) assume_yes=1; shift ;;
        --gui) gui=1; assume_yes=1; shift ;;
        --selftest) selftest ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1 (see --help)" 2 ;;
    esac
done

# ---------------------------------------------------------------- uninstall

if (( uninstall )); then
    (( EUID != 0 )) || die "run this as your normal user, not root (it asks for your password when needed)"
    command -v pacman >/dev/null || die "this uninstaller is for Arch-based systems"
    data_dirs=("${XDG_CONFIG_HOME:-$HOME/.config}/gimbot" "${XDG_DATA_HOME:-$HOME/.local/share}/gimbot"
               "${XDG_CACHE_HOME:-$HOME/.cache}/gimbot" "${XDG_CONFIG_HOME:-$HOME/.config}/gimbot-screenshots"
               "${XDG_DATA_HOME:-$HOME/.local/share}/gimbot-screenshots")
    autostart="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/io.github.Matt_B_007.Gimbot.desktop"

    step 10 "Removing Gimbot"
    mapfile -t pkgs < <(pacman -Qq gimbot gimbot-beta gimbot-git 2>/dev/null || true)
    if (( ${#pkgs[@]} )); then
        info "Removing package: ${pkgs[*]}"
        as_root pacman -Rns --noconfirm "${pkgs[@]}" || die "removing the package was cancelled or failed"
    else
        info "The Gimbot package isn't installed"
    fi
    rm -f "$autostart" # would point at a program that's gone

    if [[ -z "$purge" ]]; then
        case "$(ask "Also delete your Gimbot settings, logs and the saved OBSBOT SDK? [y/N]" n)" in
            y|Y|yes) purge=yes ;;
            *) purge=no ;;
        esac
    fi
    if [[ "$purge" == yes ]]; then
        step 70 "Deleting settings, logs and the saved SDK"
        for d in "${data_dirs[@]}"; do [[ -e "$d" ]] && { info "Deleting $d"; rm -rf "$d"; }; done
    else
        info "Kept your settings and the OBSBOT SDK in ${XDG_DATA_HOME:-$HOME/.local/share}/gimbot"
    fi
    step 100 "Gimbot is uninstalled"
    (( gui )) || echo "  ${green}${bold}Done.${reset} Gimbot has been removed."
    exit 0
fi

# Running inside the source folder (unzipped or cloned)? Build that.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -z "$source_dir" && -n "$script_dir" && -f "$script_dir/CMakeLists.txt" ]] \
   && grep -q 'project(gimbot' "$script_dir/CMakeLists.txt"; then
    source_dir="$script_dir"
fi

[[ -n "$channel" ]] || channel="$(saved_channel)"
[[ "$channel" == beta || "$channel" == stable || -z "$channel" ]] || die "--channel must be stable or beta" 2

if (( check_only )); then
    latest_tag "${channel:-stable}" || { [[ "${channel:-stable}" == stable ]] && latest_tag beta; } || die "couldn't reach GitHub: $(net_problem)"
    exit 0
fi

# ---------------------------------------------------------------- checks

(( EUID != 0 )) || die "run this as your normal user, not root (it asks for your password when needed)"
command -v pacman >/dev/null || die "this installer is for CachyOS, Arch and other Arch-based systems. Elsewhere, see 'Build from source' in the README."

if (( ! gui )); then
    echo
    echo "  ${bold}Gimbot${reset} — control app for OBSBOT cameras"
    echo "  ${dim}Unofficial; not affiliated with OBSBOT or Remo Tech.${reset}"
    echo
fi

if [[ -z "$channel" ]]; then
    if [[ -n "$source_dir" ]]; then channel=stable
    else
        case "$(ask "Follow normal releases or beta releases? [N/b]" n)" in
            b|B|beta) channel=beta ;;
            *) channel=stable ;;
        esac
    fi
fi

# ---------------------------------------------------------------- 1. tools

step 5 "Checking the tools Gimbot needs"
mapfile -t missing < <(pacman -T "${DEPS[@]}" || true)
if (( ${#missing[@]} )); then
    info "Installing: ${missing[*]}"
    as_root pacman -S --needed --noconfirm "${missing[@]}" \
        || die "couldn't install ${missing[*]}. If pacman couldn't reach its servers, $(net_problem)"
fi

# ---------------------------------------------------------------- 2. SDK

step 15 "Finding the OBSBOT SDK"
if [[ -z "$sdk" ]]; then sdk="$(find_sdk_zip || true)"; fi
while [[ -z "$sdk" || ! -f "$sdk" ]]; do
    if (( assume_yes )); then
        die "the OBSBOT SDK zip wasn't found. Put libdev_*.zip (emailed by OBSBOT, apply at https://obsbot.com/sdk) in your Downloads folder and try again." 3
    fi
    echo "    The OBSBOT SDK zip (libdev_*.zip) isn't in your Downloads folder."
    echo "    OBSBOT emails it to you when you apply at https://obsbot.com/sdk"
    sdk="$(ask "    Drag the zip here or type its path (empty to quit):" "")"
    sdk="${sdk//\'/}"; sdk="${sdk/#\~/$HOME}"; sdk="${sdk/#file:\/\//}"
    [[ -n "$sdk" ]] || die "no SDK, nothing installed" 3
done
mkdir -p "$SDK_CACHE"
if [[ "$(dirname "$(readlink -f "$sdk")")" != "$(readlink -f "$SDK_CACHE")" ]]; then
    # Move it out of Downloads (or wherever it was) into Gimbot's own folder.
    # Only the newest SDK is kept there.
    for old in "$SDK_CACHE"/libdev*.zip; do
        [[ -e "$old" && "$(basename "$old")" != "$(basename "$sdk")" ]] && rm -f "$old"
    done
    if mv -f "$sdk" "$SDK_CACHE/" 2>/dev/null; then
        info "Moved $(basename "$sdk") to $SDK_CACHE (Settings › Device in Gimbot shows it)"
    else
        cp -f "$sdk" "$SDK_CACHE/"
    fi
fi
sdk="$SDK_CACHE/$(basename "$sdk")"
info "Using $(basename "$sdk")"

# ---------------------------------------------------------------- 3. source

mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
work="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/gimbot-build.XXXXXX")"
trap 'rm -rf "$work"' EXIT

if [[ -n "$source_dir" ]]; then
    step 25 "Using the source in $source_dir"
    src="$(readlink -f "$source_dir")"
    tag="$(source_tag "$src")"
else
    if [[ -z "$version" ]]; then
        step 20 "Looking up the newest $channel release"
        version="$(latest_tag "$channel" || true)"
        if [[ -z "$version" && "$channel" == stable ]]; then
            # No normal release yet: install the newest beta and follow betas.
            version="$(latest_tag beta || true)"
            if [[ -n "$version" ]]; then
                channel=beta
                info "There's no normal release yet, so this installs the newest beta ($version) and follows beta updates."
                info "You can switch to normal releases later in Settings › App."
            fi
        fi
        if [[ -z "$version" ]]; then
            if net -fsS --max-time 20 -o /dev/null "https://api.github.com/repos/$REPO"; then
                die "github.com/$REPO has no published releases yet. Publish one on the Releases page first"
            fi
            die "couldn't reach GitHub: $(net_problem)"
        fi
    fi
    tag="$version"
    step 25 "Downloading Gimbot $tag"
    net -fsSL --max-time 300 "https://github.com/$REPO/archive/refs/tags/$tag.tar.gz" -o "$work/src.tar.gz" \
        || die "couldn't download $tag: $(net_problem)"
    mkdir -p "$work/src"
    tar -xzf "$work/src.tar.gz" -C "$work/src" --strip-components=1
    src="$work/src"
fi
pkgver="$(pkgver_from_tag "$tag")"
app_repo="$REPO"

# ---------------------------------------------------------------- 4. build

# Parallel compile jobs: one per CPU, but no more than free memory allows
# (about 1.5 GB each), so small machines don't run out of memory.
mem_kb="$(sed -nE 's/^MemAvailable: *([0-9]+).*/\1/p' /proc/meminfo 2>/dev/null || echo 4000000)"
jobs=$(( mem_kb / 1500000 ))
(( jobs < 1 )) && jobs=1
(( jobs > $(nproc) )) && jobs=$(nproc)

step 35 "Building Gimbot $tag (this takes a minute or two)"
mkdir -p "$work/pkg"
cat >"$work/pkg/PKGBUILD" <<EOF
pkgname=gimbot
pkgver=$pkgver
pkgrel=1
pkgdesc="Unofficial control app for OBSBOT cameras"
arch=('x86_64' 'aarch64')
url="https://github.com/$REPO"
license=('MIT')
depends=('qt6-base' 'qt6-declarative' 'qt6-multimedia' 'qt6-multimedia-ffmpeg' 'qt6-svg'
         'kcoreaddons' 'kcrash' 'kglobalaccel' 'kstatusnotifieritem')
provides=('gimbotctl' 'gimbot-beta')
conflicts=('gimbot-beta')
options=('!debug')

prepare() {
  rm -rf sdk && mkdir sdk
  bsdtar -xf "$sdk" -C sdk
}

build() {
  local sdkdir
  sdkdir="\$(dirname "\$(dirname "\$(dirname "\$(find "\$srcdir/sdk" -path '*/include/dev/devs.hpp' | head -n1)")")")"
  [[ -d "\$sdkdir" ]] || { echo "The SDK zip doesn't contain include/dev/devs.hpp"; return 1; }
  cmake -S "$src" -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \\
    -DBUILD_TESTING=OFF -DGIMBOT_REPO="$app_repo" -DOBSBOT_SDK_DIR="\$sdkdir" ${GIMBOT_CMAKE_ARGS:-}
  # Keep CMake's own log for bug reports (why KDE integration is off, etc.).
  cp -f build/CMakeFiles/CMakeConfigureLog.yaml "$LOG_DIR/cmake-configure.log" 2>/dev/null || true
  cmake --build build --parallel $jobs
}

package() {
  DESTDIR="\$pkgdir" cmake --install build
  install -Dm644 "$src/LICENSE" "\$pkgdir/usr/share/licenses/gimbot/LICENSE"
}
EOF

mkdir -p "$LOG_DIR"
build_log="$LOG_DIR/last-build.log"
(
    cd "$work/pkg"
    if (( gui )); then
        # Turn the compiler's [ 42%] lines into progress between 35 and 85.
        makepkg -f --noconfirm --nocheck 2>&1 | while IFS= read -r line; do
            if [[ "$line" =~ ^\[\ *([0-9]+)%\] ]]; then
                echo "::progress $(( 35 + BASH_REMATCH[1] / 2 )) Building Gimbot $tag"
            fi
            echo "$line"
        done
        exit "${PIPESTATUS[0]}"
    else
        makepkg -f --noconfirm --nocheck
    fi
) 2>&1 | tee "$build_log" && build_rc=0 || build_rc="${PIPESTATUS[0]}"
(( build_rc == 0 )) || die "the build failed. Run gimbot-update in a terminal to see why, or report it with the log above."

kde_line="$(grep -m1 'KDE Frameworks integration:' "$build_log" 2>/dev/null || true)"
if [[ "$kde_line" == *": OFF"* ]]; then
    info "Built without KDE integration: ${kde_line#*OFF }"
    info "The tray icon and shortcuts use the basic versions. Details: $build_log"
fi

pkgfile="$(cd "$work/pkg" && makepkg --packagelist | head -n1)"
[[ -f "$pkgfile" ]] || die "the build didn't produce a package"

# ---------------------------------------------------------------- 5. install

step 90 "Installing (you'll be asked for your password)"
# One password prompt for both: install the package, then apply the camera
# permission rule to a camera that's already plugged in.
as_root sh -c "pacman -U --noconfirm '$pkgfile' && udevadm control --reload && udevadm trigger --subsystem-match=usb --attr-match=idVendor=3564 && udevadm trigger --subsystem-match=video4linux" \
    || die "installing the package was cancelled or failed"

save_channel "$channel"
step 100 "Gimbot $tag is installed"

if (( ! gui )); then
    echo
    echo "  ${green}${bold}Done.${reset} Open Gimbot from your app menu, or run: gimbot"
    echo "  ${dim}Updates: Gimbot tells you when one is out and installs it with one click.${reset}"
    echo
    if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && [[ "$(ask "Open Gimbot now? [Y/n]" y)" =~ ^[Yy] ]]; then
        (setsid gimbot >/dev/null 2>&1 &)
    fi
fi
