#!/bin/bash
# Shared by installation preflight and installed-user prewarm. No target code is
# executed to discover or validate an existing MATLAB Runtime.
KSSOLV_SUPPORT='/Library/Application Support/KSSOLV Toolbox'

kssolv_plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null; }

kssolv_runtime_usable() {
    local root="$1" requirements="$2" release version minimum actual index product
    release=$(kssolv_plist "$requirements" RuntimeRelease) || return 1
    version=$(kssolv_plist "$requirements" RuntimeVersion) || return 1
    [[ -r "$root/VersionInfo.xml" && -x "$root/bin/maca64/MATLABWindow.app/Contents/MacOS/MATLABWindow" ]] || return 1
    [[ "$(/usr/bin/xmllint --nonet --xpath 'string(/MathWorks_version_info/release)' "$root/VersionInfo.xml" 2>/dev/null)" == "$release" ]] || return 1
    actual=$(/usr/bin/xmllint --nonet --xpath 'string(/MathWorks_version_info/version)' "$root/VersionInfo.xml" 2>/dev/null) || return 1
    [[ "$actual" == "$version".* ]] || return 1
    minimum=$(kssolv_plist "$requirements" RuntimeBuildVersion || true)
    if [[ -n "$minimum" ]]; then
        /usr/bin/awk -v actual="$actual" -v required="$minimum" 'BEGIN {
            split(actual,a,"."); split(required,b,".");
            for(i=1;i<=4;i++) { if(a[i]+0>b[i]+0) exit 0; if(a[i]+0<b[i]+0) exit 1 }
        }' || return 1
    fi
    /usr/bin/lipo "$root/runtime/maca64/libmwmclmcrrt.$version.dylib" -verify_arch arm64 >/dev/null 2>&1 || return 1
    index=0
    while product=$(kssolv_plist "$requirements" "RequiredProductFiles:$index"); do
        [[ "$product" != */* && -r "$root/appdata/products/$product" ]] || return 1
        index=$((index + 1))
    done
    [[ "$index" -gt 0 ]]
}

kssolv_find_runtime() {
    local requirements="$1" user_home="${2:-$HOME}" release saved candidate
    release=$(kssolv_plist "$requirements" RuntimeRelease) || return 1
    if [[ -n "${KSSOLV_RUNTIME_ROOT:-}" ]]; then
        kssolv_runtime_usable "$KSSOLV_RUNTIME_ROOT" "$requirements" || return 1
        echo "$KSSOLV_RUNTIME_ROOT"; return 0
    fi
    saved=$(kssolv_plist "$KSSOLV_SUPPORT/runtime.plist" RuntimeRoot || true)
    for candidate in "$saved" \
        "/Applications/MATLAB/MATLAB_Runtime/$release" \
        "/Applications/MATLAB/MATLABRuntime/$release" \
        "/Applications/MATLAB/MATLAB Runtime/$release" \
        "/Applications/MATLAB_Runtime/$release" \
        "$user_home/Applications/MATLAB/MATLAB_Runtime/$release" \
        "$user_home/Applications/MATLAB/MATLABRuntime/$release" \
        "$user_home/Applications/MATLAB_Runtime/$release"; do
        [[ -n "$candidate" ]] || continue
        if kssolv_runtime_usable "$candidate" "$requirements"; then echo "$candidate"; return 0; fi
    done
    return 1
}
