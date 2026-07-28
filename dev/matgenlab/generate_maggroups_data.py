"""Freeze pymatgen's magnetic-space-group SQLite database as a MATLAB MAT file."""

from __future__ import annotations

import sqlite3
from pathlib import Path

import numpy as np
from scipy.io import savemat


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(
    "/tmp/matgenlab-plan.tMNeV8/pymatgen-core-2026.7.24/"
    "src/pymatgen/symmetry/symm_data_magnetic.sqlite"
)
TARGET = (
    ROOT
    / "+kssolv/+analysis/+matgenlab/+symmetry/+maggroups"
    / "magnetic_space_groups.mat"
)


def main() -> None:
    connection = sqlite3.connect(SOURCE)
    rows = connection.execute("SELECT * FROM space_groups ORDER BY OG3").fetchall()
    point_rows = connection.execute(
        "SELECT idx, hex, symbol, matrix FROM point_operators ORDER BY hex, idx"
    ).fetchall()
    connection.close()

    metadata = np.asarray(
        [[r[0], r[1], r[2], r[4], r[5], r[6]] for r in rows], dtype=np.int32
    )
    labels = np.empty((len(rows), 2), dtype=object)
    blobs = np.empty((len(rows), 7), dtype=object)
    for index, row in enumerate(rows):
        labels[index, :] = [row[3], row[7]]
        for column, value in enumerate(row[8:15]):
            blobs[index, column] = np.frombuffer(value, dtype=np.uint8).copy()

    point_metadata = np.asarray([[r[0], r[1]] for r in point_rows], dtype=np.int16)
    point_symbols = np.asarray([[r[2]] for r in point_rows], dtype=object)
    point_matrices = np.asarray(
        [[float(value) for value in r[3].split(",")] for r in point_rows],
        dtype=np.float64,
    )
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    savemat(
        TARGET,
        {
            "metadata": metadata,
            "labels": labels,
            "blobs": blobs,
            "point_metadata": point_metadata,
            "point_symbols": point_symbols,
            "point_matrices": point_matrices,
            "upstream_version": "pymatgen-core 2026.7.24",
        },
        do_compression=True,
    )
    print(f"Wrote {TARGET} ({TARGET.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
