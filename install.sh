#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Gimbot installer and updater for CachyOS, Arch and other Arch-based systems.
#
# Install:   curl -fsSL https://raw.githubusercontent.com/Matt-B-007/Gimbot/main/install.sh | sh
# Update:    gimbot-update            (the app's "Update now" button runs this)
# Go back:   gimbot-update --rollback (reinstalls the version you had before)
# From zip:  bash install.sh         (run inside the unzipped folder)
# Uninstall: gimbot-update --uninstall
#            curl -fsSL https://raw.githubusercontent.com/Matt-B-007/Gimbot/main/install.sh | sh -s -- --uninstall
#
# It downloads a signed Gimbot release, checks its checksum and signature,
# builds it on this computer with your own copy of the OBSBOT SDK (OBSBOT
# emails it to you; the script finds it in ~/Downloads), checks the new build
# with its self-test, packages it for pacman and installs it.
#
# Why it asks for your password: Gimbot is installed as a system package
# (pacman), because the OBSBOT SDK can't be shared and has to be built into
# Gimbot on your computer, and the camera permission rule (udev) and app menu
# entry need system folders. It never runs as root otherwise.
#
# Options:
#   --channel stable|beta   Which releases to follow (default: stable, or your saved choice)
#   --beta                  Same as --channel beta
#   --version TAG           Install this release tag instead of the newest
#   --from-source           Build the latest uploaded files instead of a release
#                           (NOT verified: no checksum or signature)
#   --rollback              Go back to the version installed before the last update
#   --sdk FILE              Use this SDK zip
#   --source DIR            Build from a local source folder instead of downloading
#   --check                 Print the newest version for the channel and exit
#   --uninstall             Remove Gimbot (asks whether to delete settings too)
#   --purge                 With --uninstall: also delete settings, logs and the saved SDK
#   --keep-data             With --uninstall: keep them
#   --no-launch             Don't offer to open Gimbot afterwards
#   --yes                   Don't ask questions
#   --self-test             Test this script's own logic and exit (old name: --selftest)
#   --gui                   Machine-readable progress for the Gimbot app (implies --yes)

# Started with sh (for example `curl … | sh`)? Run again with bash, which the
# rest of this script needs and every Arch-based system has. This part is
# plain POSIX sh on purpose.
if [ -z "${BASH_VERSION:-}" ]; then
    case "${0##*/}" in
        sh | dash | ash | busybox) ;;
        *) [ -f "$0" ] && exec bash "$0" "$@" ;;
    esac
    exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/Matt-B-007/Gimbot/main/install.sh)" install.sh "$@"
fi

set -euo pipefail

DEFAULT_REPO="Matt-B-007/Gimbot" # GitHub owner/repo
REPO="${GIMBOT_REPO:-$DEFAULT_REPO}"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/gimbot"
PKG_KEEP="${XDG_DATA_HOME:-$HOME/.local/share}/gimbot/packages" # current/ and previous/ for Go back
SDK_CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/gimbot/sdk"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gimbot/gimbot.conf"
DEPS=(cmake extra-cmake-modules base-devel unzip curl minisign
      qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg qt6-svg
      kcoreaddons kcrash kglobalaccel kstatusnotifieritem)

# Releases are signed with minisign. Either key is accepted: the primary one
# signs releases; the backup is kept offline in case the primary is lost.
PUBKEYS=("RWQcs3jtP2jTiAMafwQX8UwciSjOH4o9tQcCVvYl2NkdnOeVupKPlhvC"  # primary, key id 88D3683FED78B31C
         "RWRObC9qlP598z1kmTFw7W+TKYKk3w2/63qWyRWkvRSkqGwGEgjmOlGe") # backup,  key id F37DFE946A2F6C4E

channel=""
no_launch=0
version=""
from_source=0
rollback=0
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
    if curl "$@"; then return 0; else rc=$?; fi
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

# Is tag $1 newer than tag $2? Empty counts as oldest. Betas come before the
# release they lead to (v0.1.0-beta.7 < v0.1.0 < v0.1.1-beta.1), as in the app.
newer_tag() {
    [[ -n "$1" ]] || return 1
    [[ -n "$2" ]] || return 0
    local a="${1#v}" b="${2#v}" ca cb pa pb i x y
    ca="${a%%-*}"; cb="${b%%-*}"
    pa=""; pb=""
    if [[ "$a" == *-* ]]; then pa="${a#*-}"; fi
    if [[ "$b" == *-* ]]; then pb="${b#*-}"; fi
    local -a na nb
    IFS=. read -ra na <<<"$ca"; IFS=. read -ra nb <<<"$cb"
    for (( i = 0; i < 4; i++ )); do
        x="${na[i]:-0}"; y="${nb[i]:-0}"
        (( 10#$x > 10#$y )) && return 0
        (( 10#$x < 10#$y )) && return 1
    done
    [[ "$pa" == "$pb" ]] && return 1
    [[ -z "$pa" ]] && return 0   # release beats its betas
    [[ -z "$pb" ]] && return 1
    IFS=. read -ra na <<<"$pa"; IFS=. read -ra nb <<<"$pb"
    for (( i = 0; i < 6; i++ )); do
        x="${na[i]:-}"; y="${nb[i]:-}"
        [[ "$x" == "$y" ]] && continue
        [[ -z "$x" ]] && return 1
        [[ -z "$y" ]] && return 0
        if [[ "$x" =~ ^[0-9]+$ && "$y" =~ ^[0-9]+$ ]]; then (( 10#$x > 10#$y )); return; fi
        [[ "$x" > "$y" ]]; return
    done
    return 1
}

# Check a downloaded release: SHA256SUMS must carry a valid signature from
# one of PUBKEYS, and list the source file with a matching checksum.
# verify_release DIR VERSION -> prints which key signed it; fails otherwise.
verify_release() {
    local dir="$1" ver="$2" file sums key name="" i expected actual
    file="Gimbot-$ver-source.tar.gz"
    sums="$dir/SHA256SUMS"
    command -v minisign >/dev/null || { echo "minisign isn't installed"; return 1; }
    for i in "${!PUBKEYS[@]}"; do
        key="${PUBKEYS[$i]}"
        if minisign -Vm "$sums" -x "$sums.minisig" -P "$key" -q >/dev/null 2>&1; then
            if (( i == 0 )); then name="primary"; else name="backup"; fi
            break
        fi
    done
    if [[ -z "$name" ]]; then
        echo "the signature doesn't match Gimbot's signing keys"
        return 1
    fi
    expected="$(awk -v f="$file" '{ n = $2; sub(/^\*/, "", n) } n == f { print $1; exit }' "$sums")"
    if [[ -z "$expected" ]]; then
        echo "SHA256SUMS doesn't list $file"
        return 1
    fi
    actual="$(sha256sum "$dir/$file" | cut -d' ' -f1)"
    if [[ "$actual" != "$expected" ]]; then
        echo "the checksum doesn't match (the download is damaged or was changed)"
        return 1
    fi
    echo "signed with the $name key"
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
    local n=1
    if [[ "$1" == beta ]]; then n=2; fi
    printf '[settings]\nupdateChannel=%s\n' "$n" >"$CONFIG"
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
    nt() { if newer_tag "$1" "$2"; then echo yes; else echo no; fi; }
    t "beta older"    "$(nt v0.1.0-beta.7 v0.1.0)" "no"
    t "release newer" "$(nt v0.1.0 v0.1.0-beta.7)" "yes"
    t "next beta"     "$(nt v0.1.1-beta.1 v0.1.0)" "yes"
    t "beta 10 > 9"   "$(nt v0.1.0-beta.10 v0.1.0-beta.9)" "yes"
    t "same"          "$(nt v0.1.0-beta.7 v0.1.0-beta.7)" "no"
    t "minor"         "$(nt v0.2.0 v0.10.0)" "no"
    t "empty oldest"  "$(nt v0.1.0 "")" "yes"
    t "empty newer"   "$(nt "" v0.1.0)" "no"
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
        --beta) channel=beta; shift ;;
        --no-launch) no_launch=1; shift ;;
        --version) version="${2:-}"; shift 2 ;;
        --sdk) sdk="${2:-}"; shift 2 ;;
        --source) source_dir="${2:-}"; shift 2 ;;
        --check) check_only=1; shift ;;
        --from-source) from_source=1; shift ;;
        --rollback) rollback=1; shift ;;
        --uninstall) uninstall=1; shift ;;
        --purge) purge=yes; shift ;;
        --keep-data) purge=no; shift ;;
        --yes|-y) assume_yes=1; shift ;;
        --gui) gui=1; assume_yes=1; shift ;;
        --self-test | --selftest) selftest ;;
        -h|--help)
            if [[ -f "$0" ]]; then sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            else echo "Options: --channel stable|beta, --version TAG, --from-source, --rollback, --uninstall, --check, --yes"; fi
            exit 0 ;;
        *) die "unknown option: $1 (see --help)" 2 ;;
    esac
done

# ---------------------------------------------------------------- uninstall

if (( uninstall )); then
    (( EUID != 0 )) || die "run this as your normal user, not root (it asks for your password when needed)"
    command -v pacman >/dev/null || die "this uninstaller is for Arch-based systems"
    data_dirs=("${XDG_CONFIG_HOME:-$HOME/.config}/gimbot" "${XDG_DATA_HOME:-$HOME/.local/share}/gimbot"
               "${XDG_STATE_HOME:-$HOME/.local/state}/gimbot"
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

# ---------------------------------------------------------------- go back

if (( rollback )); then
    (( EUID != 0 )) || die "run this as your normal user, not root (it asks for your password when needed)"
    prev=""
    if [[ -d "$PKG_KEEP/previous" ]]; then
        prev="$(find "$PKG_KEEP/previous" -maxdepth 1 -name '*.pkg.tar*' | head -n1)"
    fi
    [[ -n "$prev" && -f "$prev" ]] || die "there's no previous version saved yet. One is kept from your next update on."
    prev_ver="$(cat "$PKG_KEEP/previous/version" 2>/dev/null || echo "the previous version")"
    step 20 "Going back to Gimbot $prev_ver (you'll be asked for your password)"
    as_root pacman -U --noconfirm "$prev" || die "going back was cancelled or failed"
    # Swap, so going back again returns to where you were.
    rm -rf "$PKG_KEEP/swap"
    mv "$PKG_KEEP/previous" "$PKG_KEEP/swap"
    if [[ -d "$PKG_KEEP/current" ]]; then mv "$PKG_KEEP/current" "$PKG_KEEP/previous"; fi
    mv "$PKG_KEEP/swap" "$PKG_KEEP/current"
    step 100 "Gimbot $prev_ver is installed again"
    exit 0
fi

# Running inside the source folder (unzipped or cloned)? Build that.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || script_dir=""
if [[ -z "$source_dir" && -n "$script_dir" && -f "$script_dir/CMakeLists.txt" ]] \
   && grep -q 'project(gimbot' "$script_dir/CMakeLists.txt"; then
    source_dir="$script_dir"
fi

[[ -n "$channel" ]] || channel="$(saved_channel)"
[[ "$channel" == beta || "$channel" == stable || -z "$channel" ]] || die "--channel must be stable or beta" 2

if (( check_only )); then
    rel="$(latest_tag "${channel:-stable}" || true)"
    if [[ -z "$rel" && "${channel:-stable}" == stable ]]; then rel="$(latest_tag beta || true)"; fi
    [[ -n "$rel" ]] || die "couldn't reach GitHub: $(net_problem)"
    echo "$rel"
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
    echo "  It will ask for your password once: Gimbot is installed as a system package"
    echo "  because the OBSBOT SDK has to be built into it on this computer, and the"
    echo "  camera permission rule needs a system folder."
    echo
fi

if [[ -z "$channel" ]]; then
    if [[ -n "$source_dir" ]] || (( from_source )); then channel=stable
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
if [[ -z "$sdk" || ! -f "$sdk" ]] && { (( assume_yes )) || [[ ! -r /dev/tty ]]; }; then
    die "the OBSBOT SDK zip wasn't found. Put libdev_*.zip (emailed by OBSBOT, apply at https://obsbot.com/sdk) in your Downloads folder and try again." 3
fi
shown_help=0
while [[ -z "$sdk" || ! -f "$sdk" ]]; do
    # Wait for it instead of giving up, so the one-line install finishes in one go.
    if (( ! shown_help )); then
        echo
        echo "    ${bold}Gimbot needs the OBSBOT SDK${reset}, a zip named like libdev_v2.1.0_8.zip."
        echo "    OBSBOT emails it to you when you apply at https://obsbot.com/sdk"
        echo "    (it can't be shared on GitHub). Save it to your Downloads folder."
        echo
        shown_help=1
    fi
    answer="$(ask "    Press Enter once it's in Downloads (or drag the zip here, or type q to quit):" "")"
    answer="${answer//\'/}"; answer="${answer/#\~/$HOME}"; answer="${answer/#file:\/\//}"
    case "$answer" in
        q|Q|quit) die "no SDK, nothing installed. Run the same command again once you have it." 3 ;;
        "") sdk="$(find_sdk_zip || true)"
            [[ -n "$sdk" ]] || echo "    Not found in $HOME/Downloads yet." ;;
        *) sdk="$answer"
           [[ -f "$sdk" ]] || echo "    There's no file at $sdk" ;;
    esac
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
elif (( from_source )); then
    # The latest uploaded files, straight from the main branch. There's no
    # checksum or signature for these, so say so plainly.
    step 25 "Downloading the latest uploaded files (NOT verified)"
    info "--from-source builds files that have no checksum or signature. Use it only if you trust them."
    net -fsSL --max-time 300 "https://github.com/$REPO/archive/refs/heads/main.tar.gz" -o "$work/src.tar.gz" \
        || die "couldn't download Gimbot: $(net_problem)"
    mkdir -p "$work/src"
    tar -xzf "$work/src.tar.gz" -C "$work/src" --strip-components=1
    src="$work/src"
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
                info "You can switch to normal releases later in Settings › Updates."
            fi
        fi
        if [[ -z "$version" ]]; then
            if net -fsS --max-time 20 -o /dev/null "https://api.github.com/repos/$REPO"; then
                die "github.com/$REPO has no published releases yet"
            fi
            die "couldn't reach GitHub: $(net_problem)"
        fi
    fi
    tag="$version"
    ver="${tag#v}"
    step 25 "Downloading Gimbot $tag"
    base="https://github.com/$REPO/releases/download/$tag"
    mkdir -p "$work/dl"
    if ! net -fsSL --max-time 60 "$base/SHA256SUMS.minisig" -o "$work/dl/SHA256SUMS.minisig" 2>/dev/null; then
        die "Gimbot $tag has no signature (it's from before releases were signed, or isn't finished publishing). Install the newest version instead."
    fi
    net -fsSL --max-time 60 "$base/SHA256SUMS" -o "$work/dl/SHA256SUMS" || die "couldn't download the checksums: $(net_problem)"
    net -fsSL --max-time 300 "$base/Gimbot-$ver-source.tar.gz" -o "$work/dl/Gimbot-$ver-source.tar.gz" \
        || die "couldn't download Gimbot $tag: $(net_problem)"
    step 30 "Checking the download (checksum and signature)"
    if ! how="$(verify_release "$work/dl" "$ver")"; then
        die "the download didn't pass its check: $how. Nothing was installed." 4
    fi
    info "Verified: checksum OK, $how"
    mkdir -p "$work/src"
    tar -xzf "$work/dl/Gimbot-$ver-source.tar.gz" -C "$work/src" --strip-components=1
    src="$work/src"
fi
pkgver="$(pkgver_from_tag "$tag")"
app_repo="$REPO"

# ---------------------------------------------------------------- 4. build

# Parallel compile jobs: one per CPU, but no more than free memory allows
# (about 1.5 GB each), so small machines don't run out of memory.
mem_kb="$(sed -nE 's/^MemAvailable: *([0-9]+).*/\1/p' /proc/meminfo 2>/dev/null || echo 4000000)"
jobs=$(( mem_kb / 1500000 ))
if (( jobs < 1 )); then jobs=1; fi
if (( jobs > $(nproc) )); then jobs=$(nproc); fi

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
  # Tells the app it was installed by this script (so it can update itself).
  install -dm755 "\$pkgdir/usr/lib/gimbot"
  echo script > "\$pkgdir/usr/lib/gimbot/install-type"
}
EOF

mkdir -p "$LOG_DIR"
build_log="$LOG_DIR/last-build.log"
build_rc=0
if (
    cd "$work/pkg" || exit 1
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
) 2>&1 | tee "$build_log"; then build_rc=0; else build_rc="${PIPESTATUS[0]}"; fi
(( build_rc == 0 )) || die "the build failed. Run gimbot-update in a terminal to see why, or report it with the log above."

kde_line="$(grep -m1 'KDE Frameworks integration:' "$build_log" 2>/dev/null || true)"
if [[ "$kde_line" == *": OFF"* ]]; then
    info "Built without KDE integration: ${kde_line#*OFF }"
    info "The tray icon and shortcuts use the basic versions. Details: $build_log"
fi

pkgfile="$(cd "$work/pkg" && makepkg --packagelist | head -n1)" || pkgfile=""
[[ -f "$pkgfile" ]] || die "the build didn't produce a package"

# Try the new build before it replaces the installed one.
step 88 "Checking the new build (self-test)"
newroot="$work/pkg/pkg/gimbot"
if ! LD_LIBRARY_PATH="$newroot/usr/lib/gimbot" QT_QPA_PLATFORM=offscreen \
        timeout 120 "$newroot/usr/bin/gimbot" --self-test --quick >>"$build_log" 2>&1; then
    die "the new build failed its self-test, so it wasn't installed. Your current Gimbot is unchanged. Details: $build_log"
fi

# ---------------------------------------------------------------- 5. install

step 90 "Installing (you'll be asked for your password)"
# One password prompt for both: install the package, then apply the camera
# permission rule to a camera that's already plugged in.
as_root sh -c "pacman -U --noconfirm '$pkgfile' && udevadm control --reload && udevadm trigger --subsystem-match=usb --attr-match=idVendor=3564 && udevadm trigger --subsystem-match=video4linux" \
    || die "installing the package was cancelled or failed"

save_channel "$channel"

# Keep this package (and the one before it) so Go back can reinstall it.
new_ver="${tag#v}"
old_ver="$(cat "$PKG_KEEP/current/version" 2>/dev/null || true)"
if [[ -d "$PKG_KEEP/current" && "$old_ver" != "$new_ver" ]]; then
    rm -rf "$PKG_KEEP/previous"
    mv "$PKG_KEEP/current" "$PKG_KEEP/previous"
fi
rm -rf "$PKG_KEEP/current"
mkdir -p "$PKG_KEEP/current"
cp -f "$pkgfile" "$PKG_KEEP/current/"
echo "$new_ver" > "$PKG_KEEP/current/version"

step 100 "Gimbot $tag is installed"

if (( ! gui )); then
    echo
    echo "  ${green}${bold}Done.${reset} Open Gimbot from your app menu, or run: gimbot"
    echo "  ${dim}Updates: Gimbot tells you when one is out and installs it with one click.${reset}"
    echo
    if (( ! no_launch )) && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && [[ "$(ask "Open Gimbot now? [Y/n]" y)" =~ ^[Yy] ]]; then
        (setsid gimbot >/dev/null 2>&1 &)
    fi
fi
