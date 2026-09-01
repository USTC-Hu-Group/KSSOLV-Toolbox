# Modeling User Guide

The modeling workspace edits molecular and periodic structures without changing
the saved project until you confirm and save an operation. Commands shown in
the modeling tab depend on the active document and current selection.

[简体中文](modeling-user-guide.zh-CN.md)

## Start a modeling session

1. Create a Structure or Molecule document, or import a supported structure
   file.
2. Activate its 3D view. The **Crystal Modeling** or **Molecular Modeling** tab
   appears automatically.
3. Select atoms or bonds, then choose a command from the modeling tab or the
   context menu.
4. Review the preview and diagnostics before applying the change.
5. Save the project when the edited structure is ready.

Undo and redo treat each confirmed operation as one step. Canceling a preview
leaves the structure unchanged.

## View and selection

- Click to select; use Shift-click to extend the selection.
- Press `B` for box selection and `L` for lasso selection.
- Press `G` to move and `R` to rotate; press `X`, `Y`, or `Z` to constrain an
  active transform.
- Press `Ctrl/Cmd+Z` to undo and `Shift+Ctrl/Cmd+Z` to redo.
- Press `Esc` to cancel the current tool and `?` to open the shortcut panel.

Selection sets are useful when the same sites will be edited repeatedly. In a
periodic view, a selection remains associated with the underlying site even
when display repeats change.

See the [modeling shortcut chart](images/modeling-shortcuts.svg) for a compact
bilingual reference.

## Molecules

### Sketch and edit connectivity

Press `S` to start 3D Sketch. Click empty space to place an atom, or drag from
an existing atom to add a bonded atom. Dragging onto another existing atom
creates a bond when the geometry is valid. The sketch toolbar selects the
element, bond order, and common ring size.

Select a bond to change its order or remove it. **Set Atom Chemistry** changes
the element, formal charge, and hybridization hint. **Add Hydrogens** and
**Remove Hydrogens** follow the explicit molecular connectivity; run
**Diagnose Molecule** after substantial topology edits.

Red collision or short-bond warnings prevent invalid sketch operations. They
do not replace a full chemical validation of the final model.

### Geometry

Use **Set Distance**, **Set Angle**, and **Set Dihedral** for exact changes.
Selecting two, three, or four atoms displays the corresponding measurement in
selection order. Measurement tools can also collect atoms interactively and
apply a target value to an atom, subtree, or fragment.

**Clean Geometry** improves obvious local geometry. **Optimize Geometry** uses
the generic molecular model identified in the result report. It is intended
for preparing an initial structure, not for predicting a final equilibrium
geometry. Relax important structures with a method appropriate to the system.

Fragments can be attached through defined connection sites. User fragments
and modeling presets are available from the library browser.

## Crystals, surfaces, and interfaces

Crystal commands preserve periodic information unless a command explicitly
creates a derived structure.

- **Crystal Builder** creates a structure from lattice, space-group, species,
  and asymmetric-site input.
- **Make P1** removes symmetry constraints while preserving Cartesian geometry.
- **Build Supercell** changes the model; **Display Repeat** changes only the
  view.
- **Point Defect Enumeration** proposes symmetry-distinct defect structures.
- **Surface Builder** creates slabs and can identify geometric layers.
- **Add Vacuum**, adsorption-site tools, and heterostructure tools prepare
  surfaces and interfaces for later relaxation.

Periodic distance, angle, and dihedral tools use nearby periodic images. Check
the resulting cell and atomic positions before starting a calculation.

### Add an adsorbate

Use **Adsorption Locator** when you want candidate top, bridge, or hollow
sites. Its geometric score is a screening measure, not an adsorption energy.
The optional rigid UFF interaction score omits relaxation, electrostatics,
bond formation, solvent, and temperature effects; use it only to rank starting
configurations.

Press `O` to place a fragment directly in the 3D view:

1. Choose a built-in, project, or user fragment.
2. Drag from a surface atom to place the fragment anchor.
3. Adjust orientation and anchor distance while checking contact warnings.
4. Press `Enter` or choose **Apply** to create one undoable operation.

An interactively placed adsorbate is an initial configuration. Relax the host
and adsorbate with a suitable physical model before interpreting stability.

## Polymers and amorphous structures

The polymer tools build chains from predefined or user-supplied repeat units.
They support multiple chains, sequence choices, end groups, and reproducible
random construction. Review the estimated atom count before building a large
model.

Amorphous packing can use molecule counts or composition targets, density,
minimum-contact constraints, and restricted regions. A packed structure is not
an equilibrated structure. Perform suitable minimization, thermal treatment,
and NVT/NPT equilibration before using it as a physical model.

If packing fails, reduce the target density or molecule count, enlarge the
region, or try another random seed. Do not use a result that reports unresolved
close contacts, ring piercing, or chain interlocking.

## History, batch work, and recovery

The history controls provide undo, redo, and reset for the active document.
Presets and templates store frequently used command parameters. Modeling Jobs
can run longer file-based operations and report progress independently of the
active view.

Recovery data may be offered after an interrupted session. Inspect the
recovered structure before saving it over an existing project. For scripted
and reproducible operations, see [Modeling API v1](modeling-api.md).

## Troubleshooting

| Problem | What to check |
| --- | --- |
| A command is disabled | Activate the correct document and select the required number and type of objects. |
| A preview is stale | Reopen the command; the structure changed after the preview was created. |
| Packing fails | Lower density or molecule count, enlarge the region, or change the random seed. |
| A model exceeds the atom limit | Reduce chain length, supercell size, or the search range. |
| A viewer command fails | Confirm that the original model is intact, then record the file format and steps needed to reproduce the problem. |
