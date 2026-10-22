"""Expose deployed service modules and operational entry points to tests."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / 'server' / 'admin'), str(ROOT / 'server' / 'portal'),
               str(ROOT / 'scripts' / 'k8s')]
