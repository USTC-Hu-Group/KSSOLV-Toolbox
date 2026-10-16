"""Verify shared startup edits leave the non-deployed MATLAB path unchanged."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
baseline_ref = sys.argv[1] if len(sys.argv) > 1 else "HEAD"


def baseline(filename):
    return subprocess.check_output(
        ["git", "show", f"{baseline_ref}:{filename}"], cwd=root
    ).decode("utf-8-sig")


def non_deployed(source):
    lines = source.splitlines()
    output = []
    index = 0
    while index < len(lines):
        if not re.match(r"\s*if isdeployed\b", lines[index]):
            output.append(lines[index])
            index += 1
            continue
        depth, alternate, end = 1, None, index + 1
        while end < len(lines):
            line = lines[end].split("%", 1)[0].strip()
            if re.match(r"^(if|for|while|switch|try|parfor)\b", line):
                depth += 1
            elif line == "end":
                depth -= 1
                if depth == 0:
                    break
            elif line == "else" and depth == 1:
                alternate = end
            end += 1
        assert depth == 0, "Unbalanced deployment branch"
        if alternate is not None:
            output.extend(lines[alternate + 1:end])
        index = end + 1
    return "\n".join(line.strip() for line in output if line.strip() and not line.lstrip().startswith("%"))


def show_method(source):
    return re.search(
        r"(?ms)^\s*function show\(this\).*?(?=^\s*function waitUntilReady\(this\))", source
    ).group()


def without_startup_adapter(source):
    # tryShow is independently tested to return false without touching the app
    # outside deployment. Ignore only this exact early-return adapter.
    return re.sub(
        r"(?m)^ *if kssolv\.ui\.util\.StartupSplash\.tryShow\(this\)\r?\n"
        r" *return\r?\n *end\r?\n", "", source
    )


for filename in ("kssolvPrewarm.m", "kssolv.m"):
    assert baseline(filename).replace("\r\n", "\n") == (root / filename).read_text(encoding="utf-8-sig"), filename
    print(f"PASS unchanged: {filename}")

for filename in ("kssolvStart.m", "+kssolv/+settings/Settings.m"):
    assert non_deployed(baseline(filename)) == non_deployed((root / filename).read_text(encoding="utf-8-sig")), filename
    print(f"PASS non-deployed startup entry unchanged: {filename}")
filename = "+kssolv/KSSOLVToolbox.m"
constructor = lambda source: re.search(r"(?ms)^\s*function this = KSSOLVToolbox\(\).*?(?=^\s*function delete\(this\))", source).group()
current = (root / filename).read_text(encoding="utf-8-sig")
assert constructor(baseline(filename)).replace("\r\n", "\n") == constructor(current)
print("PASS Toolbox constructor unchanged")
assert non_deployed(without_startup_adapter(show_method(baseline(filename)))) == non_deployed(without_startup_adapter(show_method(current)))
print("PASS non-deployed Toolbox show path unchanged")
readiness = lambda source: re.search(r"(?ms)^\s*function waitUntilReady\(this\).*?(?=^\s*function close\(this\))", source).group()
assert readiness(baseline(filename)).replace("\r\n", "\n") == readiness(current)
print("PASS Toolbox readiness unchanged")
assert "StartupSplash.progress" not in current
assert "StartupSplash.progress" not in (root / "kssolv.m").read_text(encoding="utf-8-sig")
print("PASS no fine-grained splash instrumentation in business startup code")
