#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Fails if the source contains a web address outside the expected hosts, so a
# mistyped or mirror domain (which once broke updates and the installer)
# can't slip back in.
set -euo pipefail
root="${1:-$(dirname "$0")/..}"
allowed='^(github\.com|api\.github\.com|raw\.githubusercontent\.com|obsbot\.com|www\.obsbot\.com|1\.1\.1\.1|8\.8\.8\.8|www\.w3\.org|scripts\.sil\.org|example\.org|example\.invalid|specifications\.freedesktop\.org|www\.freedesktop\.org|freedesktop\.org|creativecommons\.org|opensource\.org|spdx\.org|rsms\.me|keepachangelog\.com|semver\.org|localhost)$'
bad=0
while IFS= read -r hit; do
    host="${hit#*://}"
    if ! [[ "$host" =~ $allowed ]]; then
        echo "unexpected web address host: $host" >&2
        bad=1
    fi
done < <(grep -rIhoE 'https?://[A-Za-z0-9.-]+' "$root" \
            --include='*.cpp' --include='*.hpp' --include='*.qml' --include='*.sh' \
            --include='*.md' --include='*.xml' --include='*.desktop' --include='PKGBUILD' \
            --include='*.yml' --include='*.txt' --exclude-dir=build --exclude-dir=.git | sort -u)
exit $bad
