"""Resolve production and fixture imports independently of the caller's cwd."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
DOCKER = ROOT / 'scripts' / 'docker'
RUNTIME = ROOT / 'server' / 'runtime'
sys.path[:0] = [str(RUNTIME), str(DOCKER)]
