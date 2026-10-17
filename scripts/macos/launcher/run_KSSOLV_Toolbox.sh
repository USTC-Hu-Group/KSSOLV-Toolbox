#!/bin/sh
# Public entry for the outer host. The original Compiler runner remains inside.
set -eu
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <MATLAB Runtime root> [application arguments]" >&2
    exit 2
fi
KSSOLV_RUNTIME_ROOT="$1"
export KSSOLV_RUNTIME_ROOT
shift
exe_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
# The native prewarm supervisor uses this PID as its dedicated process group.
exec "$exe_dir/KSSOLV_Toolbox.app/Contents/MacOS/KSSOLV_Toolbox" "$@"
