# Structure I/O API

`kssolv.services.fileparser.StructureIO` imports and exports structures through
the registered format providers. Periodic inputs become KSSOLV `Crystal`
objects; molecular inputs become `Molecule` objects.

## Read a structure

Use the static `read` method when only the KSSOLV object is needed:

```matlab
crystal = kssolv.services.fileparser.StructureIO.read("Si.cif");
molecule = kssolv.services.fileparser.StructureIO.read("water.xyz");
```

Use a stateful I/O object when raw content and both KSSOLV and matgenlab
representations are needed:

```matlab
io = kssolv.services.fileparser.StructureIO("Si.cif");
crystal = io.KSSOLVObject;
matgenStructure = io.MatgenlabObject;
```

matgenlab structures use angstroms and KSSOLV structures use bohr. Conversion
between the representations applies the unit change automatically.

## Write a structure

The output format can be inferred from the filename or supplied explicitly:

```matlab
kssolv.services.fileparser.StructureIO.write(crystal, "Si.vasp");
kssolv.services.fileparser.StructureIO.write( ...
    molecule, "water.cif", "cif");
```

Before overwriting a file, confirm that the chosen format can represent the
required periodicity, species, coordinates, and connectivity.

## Convert representations

```matlab
matgenStructure = ...
    kssolv.services.fileparser.StructureIO.toMatgenlab(crystal);
crystalAgain = ...
    kssolv.services.fileparser.StructureIO.fromMatgenlab(matgenStructure);
```

Use `supportedFormats()` to inspect the readable and writable formats available
in the current installation:

```matlab
formats = ...
    kssolv.services.fileparser.StructureIO.supportedFormats();
```

Some formats depend on optional adaptors such as Open Babel. A format may be
listed differently across installations when its runtime dependency is not
available.
