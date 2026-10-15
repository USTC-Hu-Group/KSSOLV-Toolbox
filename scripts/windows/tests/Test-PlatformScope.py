"""Compare executed non-Windows MATLAB statements with a supplied Git baseline."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
baseline_ref = sys.argv[1] if len(sys.argv) > 1 else "HEAD"


def project_non_windows(source):
    source = re.sub(
        r"^function validateWindowsStandalonePayload\b.*?(?=^function |\Z)",
        "", source, flags=re.MULTILINE | re.DOTALL,
    )
    lines = source.splitlines()
    output = []
    i = 0
    while i < len(lines):
        if lines[i].strip() != "if ispc":
            output.append(lines[i])
            i += 1
            continue
        depth, alternate, end = 1, None, i + 1
        while end < len(lines):
            line = lines[end].strip()
            if re.match(r"^(if|for|while|switch|try|parfor)\b", line):
                depth += 1
            elif line == "end":
                depth -= 1
                if depth == 0:
                    break
            elif line == "else" and depth == 1:
                alternate = end
            end += 1
        assert depth == 0, "Unbalanced Windows branch"
        if alternate is not None:
            output.extend(lines[alternate + 1:end])
        i = end + 1
    return "\n".join(line.strip() for line in output if line.strip() and not line.lstrip().startswith("%"))


for filename in ("buildInstaller.m", "kssolvPrewarm.m"):
    baseline = subprocess.check_output(["git", "show", f"{baseline_ref}:{filename}"], cwd=root).decode("utf-8-sig")
    current = (root / filename).read_text(encoding="utf-8-sig")
    assert project_non_windows(current) == project_non_windows(baseline), f"Non-Windows statements changed: {filename}"
    print(f"PASS non-Windows statements unchanged: {filename}")

mac_diff = subprocess.check_output(["git", "diff", baseline_ref, "--", "scripts/macos", "kssolvStart.m"], cwd=root)
assert not mac_diff, "Mac scripts or shared startup entry were modified"
print("PASS Mac scripts and shared startup entry unchanged")
