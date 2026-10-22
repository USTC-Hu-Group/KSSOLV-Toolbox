"""Validate a Linux standalone payload and build a minimal Docker context."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
RUNTIME_FILES = ('serve.py', 'http_worker.py', 'resource_usage.py')


def stage_runtime(context):
    """Copy only production runtime helpers, never tests or local diagnostics."""
    destination = Path(context) / 'runtime'
    destination.mkdir()
    for name in RUNTIME_FILES:
        shutil.copy2(ROOT / 'server' / 'runtime' / name, destination / name)


def validate_payload(payload):
    metadata = json.loads((payload / "runtime-metadata.json").read_text())
    release = metadata["RuntimeRelease"]
    if release < "R2025b" or len(release) != 6 or release[0] != "R" or release[-1] not in "ab" or not release[1:5].isdigit():
        raise ValueError("Use R2025b or newer (official Runtime images without JRE).")
    if metadata["Architecture"] != "glnxa64" or metadata["JVMEnabled"] is not False:
        raise ValueError("A Linux x86-64 standalone payload built with -nojvm is required.")
    executable = payload / "KSSOLV_Toolbox"
    with executable.open("rb") as stream:
        header = stream.read(20)
    if len(header) < 20 or header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
        raise ValueError("KSSOLV_Toolbox must be a Linux x86-64 ELF executable.")
    if not (payload / "run_KSSOLV_Toolbox.sh").is_file():
        raise ValueError("Missing MATLAB Compiler launch script.")
    return release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--payload", type=Path, default=Path("Release/StandaloneDesktopApp/build"))
    parser.add_argument("--image", default="kssolv-toolbox:local")
    parser.add_argument("--runtime-image", help="Matching official Runtime tag, optionally pinned by digest")
    args = parser.parse_args()
    release = validate_payload(args.payload)
    metadata = json.loads((args.payload / "runtime-metadata.json").read_text())
    suffix = "-full" if metadata.get("IncludeGPU", False) else ""
    runtime_image = args.runtime_image or f"containers.mathworks.com/matlab-runtime:{release.lower()}{suffix}"
    with tempfile.TemporaryDirectory(prefix="kssolv-docker-") as directory:
        context = Path(directory)
        app = context / "app"
        app.mkdir()
        # Allowlist only distribution files. Never send repository secrets or
        # local Runtime installers, caches, or extracted sources to Docker.
        for name in ("KSSOLV_Toolbox", "run_KSSOLV_Toolbox.sh", "runtime-metadata.json", "buildresult.json"):
            shutil.copy2(args.payload / name, app / name)
        (app / "KSSOLV_Toolbox").chmod(0o755)
        (app / "run_KSSOLV_Toolbox.sh").chmod(0o755)
        shutil.copy2(Path(__file__).with_name('Dockerfile'), context / 'Dockerfile')
        stage_runtime(context)
        subprocess.run(["docker", "build", "--platform", "linux/amd64", "--build-arg",
                        f"RUNTIME_IMAGE={runtime_image}", "--tag", args.image, str(context)], check=True)


if __name__ == "__main__":
    main()
