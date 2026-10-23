#!/bin/bash
# Source this file after packaging or signing; hash only final release artifacts.
write_release_checksums() (
    set -euo pipefail
    local artifact="$1" name version file
    name=$(basename "$artifact")
    [[ "$name" =~ ^KSSOLV_Toolbox_V([0-9]+(\.[0-9]+){1,3})\.(pkg|dmg)$ ]] || return 0
    version="${BASH_REMATCH[1]}"
    cd "$(dirname "$artifact")"
    local files=()
    for file in "KSSOLV_Toolbox_V$version.pkg" "KSSOLV_Toolbox_V$version.dmg" "KSSOLV_Toolbox_V$version.mltbx"; do
        [[ ! -f "$file" ]] || files+=("$file")
    done
    /usr/bin/shasum -a 256 "${files[@]}" > "SHA256SUMS-V$version-macOS.txt"
)
