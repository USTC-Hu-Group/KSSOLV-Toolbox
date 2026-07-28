# matgenlab upstream inventory

This directory freezes and inventories the Python projects used as the
compatibility oracle for `kssolv.analysis.matgenlab`.

The baseline is declared in `upstream_baseline.json`. The generated inventory
contains:

- `inventory/upstream_inventory.json`: canonical complete inventory;
- `inventory/sources.csv`: immutable repository/tag/commit provenance;
- `inventory/modules.csv`: Python modules, hashes, parse status, and API counts;
- `inventory/api.csv`: public classes, functions, methods, properties, re-exports,
  signatures, bases, decorators, and source locations;
- `inventory/tests.csv`: test modules, hashes, and discovered test counts;
- `inventory/fixtures.csv`: every declared upstream fixture with size and SHA-256.

Generate from fresh official clones:

```sh
python3 dev/matgenlab/generate_upstream_inventory.py
```

Generate without network access from verified local checkouts:

```sh
python3 dev/matgenlab/generate_upstream_inventory.py \
  --source pymatgen=/path/to/pymatgen \
  --source pymatgen-core=/path/to/pymatgen-core
```

Verify that committed outputs are byte-for-byte current:

```sh
python3 dev/matgenlab/generate_upstream_inventory.py \
  --source pymatgen=/path/to/pymatgen \
  --source pymatgen-core=/path/to/pymatgen-core \
  --check
```

Run the generator unit tests:

```sh
python3 -m unittest discover \
  -s dev/matgenlab -p 'test_generate_upstream_inventory.py' -v
```

The generator uses only Python's standard library and refuses a checkout whose
`HEAD` is not the full frozen commit. It emits no wall-clock timestamps or local
paths, so the same source bytes produce identical JSON and CSV on every machine.

The inventory is a coverage ledger, not a claim that every underscore-free
Python name is a stable upstream API. `__all__` is honored when it is a literal
list/tuple; otherwise the conventional leading-underscore rule is used.

## Electronic-structure compatibility

The frozen `pymatgen.electronic_structure` denominator contains 279 API rows
across `core`, `dos`, `bandstructure`, `cohp`, `plotter`, `boltztrap`, and
`boltztrap2`. The MATLAB package implements all rows natively. Classic
BoltzTraP parsing and analysis are independent of the external program;
`BoltztrapRunner.run` is the explicit `x_trans` process boundary and reports a
stable error when no executable is configured. BoltzTraP2 interpolation, DOS,
transport integration, serialization, and plotting use MATLAB numerical
kernels and do not import Python or call a Python runtime.

Coverage is enforced dynamically by
`ElectronicStructureInventoryTest.m`, while `BoltztrapTest.m` and
`Boltztrap2Test.m` exercise the frozen official transport, DOS, band, cube,
Vasprun, projection, and serialized fixtures.
