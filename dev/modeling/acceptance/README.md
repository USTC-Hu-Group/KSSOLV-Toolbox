# Modeling acceptance evidence

This directory contains executable acceptance scenarios and generated evidence
for the P1-P10 modeling program documented in
[`docs/modeling-development-plan.zh-CN.md`](../../../docs/modeling-development-plan.zh-CN.md).

## Rules

- `scenarios/` is versioned and must remain executable from a clean MATLAB
  R2026b session with the repository root as the current directory.
- `baselines/` contains small, reviewable scientific inputs and oracle data.
- `reports/` is generated locally. JSON reports and intentionally captured UI
  screenshots may be attached to a release candidate; transient build files
  must not be committed.
- A browser-only test is supporting evidence, not a substitute for a scenario
  that constructs a real `AppContainer` and `uihtml` document.
- Every scenario calls `workingTreeRoot` before loading KSSOLV. The helper
  derives the repository from the scenario file, puts it first on the MATLAB
  path, and fails if `KSSOLV_Toolbox` still resolves to an installed Add-On.
  An older installed UI/runtime must never silently become production QA.

## P1

```matlab
cd('/Users/liu/Documents/GitHub/KSSOLV-Toolbox');
addpath(fullfile(pwd, '+kssolv', '+core', 'kssolv-3o'));
KSSOLV.startup();
addpath(fullfile(pwd, 'dev', 'modeling', 'acceptance', 'scenarios'));
report = runP1MoleculeEditingAcceptance();
assert(report.passed);
```

The scenario opens the production atomic viewer in a real AppContainer, applies
replace/move/translate/delete through revision-guarded transactions, verifies
undo/redo and project persistence, exports five molecule formats, and records a
screenshot plus a JSON report.

### P1 production shell parity gate

Run this gate in a clean MATLAB session. Unlike the historical reduced
AppContainer scenarios, it starts the complete production `kssolv()` shell,
verifies the CrystalViewer build manifest/SHA, creates the QA molecule through
the production Project service, and confirms that the real document is
registered by the production modeling session registry.

```matlab
report = runP1ProductionParityAcceptance();
assert(report.passed);
```

Real keyboard/mouse actions and visual screenshots are indexed under
`reports/p1-production-parity-*`; command-level checks do not replace that
evidence.

### P1 production shortcut-layout matrix

```matlab
report = runP1ShortcutLayoutAcceptance();
assert(report.passed && report.captureCount == 16);
```

This gate creates a molecule through the production Project service, opens the
actual `MoleculeDisplay`, and asks its production MATLAB/HTML bridge to show the
shortcut guide. It captures common and advanced tabs in `en_US` and `zh_CN`
at requested 1200x800, 1440x900, and 1920x1080 window sizes, plus both tabs at
200% content zoom in the 1200x800 production window. Both requested and
OS-clamped window dimensions plus actual exported image dimensions are recorded;
a requested size is never misreported as the physical result. The common tab
keeps frequent controls first in two compact columns. The advanced tab is
separate, places less-used modeling controls after the common tab, and gives
every long modeling instruction a full row. Independent physical-display
sign-off remains mandatory.

## P2

```matlab
report = runP2DirectManipulationAcceptance();
assert(report.passed);
```

The scenario opens the production viewer and Modeling tab, persists a named
source-site selection, commits one translation and one rotation per simulated
pointer drag, proves that each drag creates exactly one history record, checks
undo/redo to `1e-10 Å`, saves/reopens the project model, and captures GUI
evidence. Browser tests separately enforce the 10,000-atom selection budget and
the focus-safe keymap.

`p2-escape-water-pointer-20260812-052026` is the corresponding real desktop
regression. It preserves the failed native-select focus iterations, verifies
the final one-Escape cancellation after a palette choice, confirms a short
O–O drag cannot mutate the model, and builds H2O through the production Add
Hydrogens dialog. The same correction is guarded at the MATLAB command boundary
and by 191 CrystalViewer tests; exact molecular headings use document atom
counts rather than elemental-reference reduced formulas.

`p2-six-molecule-pointer-20260812-125404` closes the full reference-molecule
matrix in the complete production shell. Real pointer and keyboard input builds
Water, Ethanol, Formaldehyde, Benzene, Pyridine, and Benzamide and records the
visible formula plus atom/bond counts for every final scene. The fail-closed
gate below validates all six screenshots, their SHA-256 values, and the exact
embedded runtime identity:

```matlab
report = runP2ReferenceMoleculePointerEvidenceAcceptance();
assert(report.passed && report.moleculeCount == 6);
```

The Benzamide path also exercises Clean and the explicit KSSOLV molecular-
mechanics optimizer. A collision exposed by the first Clean pass was retained
as a diagnostic iteration and was not accepted as final evidence; the saved
final scene is the warning-free, centered post-optimization result.

## P3 Fragment Sketcher

```matlab
report = runP3FragmentSketcherAcceptance();
assert(report.passed);
```

This gate starts the complete production `kssolv()` shell, attaches COOH to a
production molecule through the actual display transaction, verifies undo and
redo, exercises the Surface-C, monodentate O and bidentate O,O ports, performs
100 duplicate-bond assembly regressions, round-trips a user-defined port, and
exports the COOH browser and assembled structure. Direct mouse gesture evidence
is recorded separately and remains mandatory before P3 can close. Host-valence
and post-assembly collision checks run before commit, so an invalid attachment
never mutates the production model.

## P4 Force field and geometry optimization

```matlab
report = runP4ForceFieldAcceptance();
assert(report.passed);
```

This gate starts the complete production shell and keeps rule-based Clean
separate from an explicit molecular-mechanics minimization. It verifies lower
final energy, maximum-force convergence, fixed-atom immobility, unchanged
composition/topology, transactional undo/redo, and exports the optimized MOL
plus production document screenshot. The report always includes its parameter
set, source, term energies, convergence reason, and declared limitations; an
unconverged run is never labeled successful.

## P4 independent 200-molecule hydrogen/valence oracle

```matlab
report = runP4StandardMoleculeOracleAcceptance();
assert(report.passed && report.moleculeCount == 200);
```

This gate covers twenty chemical families with ten unique molecular graphs
per family. Expected formulae use independent homologous-series identities,
not the production target-valence implementation. The CSV records expected
and actual formulae, hydrogen counts, atom-issue counts, heavy-atom topology,
hydrogen degree, and remove-hydrogen round trips for every molecule.

## P5 Exact editing and geometry monitoring

```matlab
report = runP5ExactGeometryAcceptance();
assert(report.passed);
```

This production-shell gate verifies exact Cartesian movement and axis rotation,
then commits distance, angle, dihedral, bond-order and hybridization edits
through the actual display transaction. It enforces the P5 numerical error
limits, checks undo/redo and MOL/SDF bond-order round trips, and exports the
edited structure and production document screenshot. Real pointer and visible
measurement-readout evidence remains a separate production GUI gate.

The separate fail-closed pointer gate is now:

```matlab
report = runP5PointerEvidenceAcceptance();
assert(report.passed);
```

`p5-periodic-pointer-20260812-145945` uses the production Si crystal and the
current production runtime. Physical pointer input verifies the live measurement
card and full-width editor layout; visible MATLAB keyboard input targets the
active production `MoleculeDisplay` transaction API for exact source-site
selection. It verifies 2.35126→2.40000 Å distance editing,
Undo/Redo, 109.471→112.250° angle editing and 0→15.000° dihedral editing. The
measurement editor was visually repaired to give the target field a full row.
After a periodic edit, the viewer now resolves the corresponding rendered
image and restores the exact live readout automatically. Repeated periodic
images of the same source site are rejected before submission with a specific
explanation. The gate also requires the physical evidence runtime SHA-256 to
match the currently synchronized production runtime.

## P6 Generic interactive adsorbates

```matlab
report = runP6GenericAdsorbateAcceptance();
assert(report.passed);
```

This gate starts the complete production shell and verifies seven generic
species/coordinates/bonds fragments, including O-H, COOH, NH2, CH3, CO, CO2
and H2O. It commits COOH through the actual display transaction, verifies
metadata schema v2 and undo/redo, exercises a two-host/two-guest-anchor
placement, and exports the committed CIF and production screenshot. Real
pointer QA separately verifies the fragment selector, two left-drag stages,
whole-group right-drag rotation and Enter commit. A temporary user Formyl
fragment also passes the production scene transport, selector, port anchor and
orientation gate without touching the real user store. Multi-component direct
placement as one interactive draft remains separate from Locator mixture search.

Adsorbate metadata has one current-only schema. Both placement paths store
`schemaVersion=2`, `placementMode`, the full ordered `species`, `coordinates`,
`bonds`, `anchorAtomIndices`, and `guestFormula`. Direct manipulation adds
`hostAnchorSites`, `hostAnchorLabels`, and `hostBondLengths`; catalog-site
placement instead adds nested `siteDescriptor` and `orientationDescriptor`
records. Production tests enforce these two exact field allowlists, so no
additional compatibility metadata can be introduced silently.

## P6 Adsorption Locator candidate and UFF interaction search

```matlab
report = runP6AdsorptionLocatorAcceptance();
assert(report.passed);
```

This gate runs in the complete production shell, resolves a project COOH
adsorbate through the same input resolver used by the Modeling command, and
enumerates atop/bridge/hollow positions over explicit heights and rotations.
It verifies periodic minimum-image contact checks, deterministic ordering,
collision filtering, cancellation semantics and the production result table.
The built-in `kssolv-geometric-contact-v1` score is deliberately labeled as a
geometric contact score with `isEnergyModel=false`; it must never be reported
as adsorption energy. The same production path also selects the built-in
`kssolv-uff-vdw-surface-v1` scorer, evaluates periodic rigid host–guest UFF
12-6 cross interactions in eV, verifies deterministic sorting and the embedded
source/validation contract, and persists that complete contract when applying a
candidate. The result window previews a selected candidate without changing the
document revision, applies it as one history entry, and verifies Undo/Redo plus
CIF export. The gate resolves a comma-separated COOH+H2O project mixture as one
disconnected rigid adsorbate and exercises the strict external scorer contract
against a frozen analytic energy oracle. A custom energy scorer cannot claim
energy without a unit, source, version and validation reference.

The report exports the real scoring-model parameter dialog, geometric/external/
UFF result windows and three candidate CSV files. The UFF result is labeled
“interaction energy,” with an explicit notice that electrostatics, bonding,
charge transfer, solvent and relaxation are absent. Independent unit tests cover
all H–Lr parameters, the analytic pair minimum, smooth cutoff, skew-cell periodic
images and lattice-translation invariance.

## P6 external predictive adsorption benchmark

```matlab
report = runP6PredictiveAdsorptionAcceptance();
assert(report.passed);
```

This gate runs the unmodified production UFF scorer against the frozen
Rybolt–Pierotti low-coverage Ne/Ar/Kr/Xe–graphite experiment (J. Chem. Phys.
70, 4413–4419, DOI `10.1063/1.438015`). It requires exact experimental binding
order, energy MAE at most 0.012 eV, potential-minimum distance MAE at most
0.10 Å, and an explicit `parameterFittedToReference=false` record. The report
contains JSON, CSV and an energy/distance comparison plot. Passing this gate
validates only rigid graphitic rare-gas physisorption; full physical pointer and
independent-user sign-off remain open P6 gates.

## P1-P6 aggregate automated release gate

```matlab
report = runP1P6ReleaseAcceptance();
assert(report.passed);
```

This runner executes all 16 current P1-P6 production, scientific-oracle and
icon-visual scenarios against one worktree revision and writes a single JSON
report plus Markdown summary. `passed` only means that every automated gate
passed. `releaseReady` deliberately remains false while the remaining physical
pointer and independent-user visual sign-off gates are open;
the aggregate report lists those closure gates explicitly so an automated callback can never be mistaken
for human or physical-input evidence.

Final unified evidence `p1-p6-release-20260812-174800` passed 16/16 automated
gates after removing the obsolete O-H-specific fragment identifier. The final
runtime SHA-256 is
`bb8eb628a3f7d2ce8b9802742135033aa8b7be1903fc6c0a480b01ef048955d0`;
the P2 six-molecule and P5 periodic-geometry evidence was re-bound after
confirming that the change was identifier-only, then passed the fail-closed SHA
checks. P1 independent
A1-A5, B1-B5, and C1-C5 sign-off and P6 verified
physical mouse-button-2 axis drag plus independent visual sign-off also remain
open, so `releaseReady=false` is expected. Copy
`P1-P6-external-closure-template.json`, fill it only from the signed physical
audit, and pass the resulting path as the second argument to
`runP1P6ReleaseAcceptance`. `auditP1P6ExternalClosure` independently checks the
current runtime hash, exact audit IDs, button-2 gesture metadata, Rodrigues
rotation coordinates, internal-distance invariance, and screenshot hashes.

For the P6 closure run, select a non-collinear adsorbate such as COOH, complete
the two left-drag placement stages, save the ready-state screenshot and full
draft coordinates, then rotate it with a physical mouse right-button drag of at
least 2 px (the auditor requires at least 1 degree). Save the post-drag
screenshot and coordinates before pressing Enter. Record `pointerType=mouse`,
`button=2`, `gesture=adsorbate-host-axis-rotation`, the Host and Anchor
coordinates, and the displayed angle in the closure JSON. Compute both image
hashes from the files actually supplied. A callback, synthetic transaction,
left drag, or two screenshots without matching rigid-axis coordinates cannot
close this gate. The independent visual auditor must then confirm that the
whole group—not the camera—rotated and sign the P6 fields.

## P1-P6 physical pointer evidence

Physical desktop runs live under a timestamped
`p1-p6-physical-pointer-*` report directory. The report must name the input
mechanism and list screenshot evidence for each individual action; callback or
programmatic transaction evidence is not accepted in this directory. The
20260812-030247 run used Computer Use against MATLAB R2026b and the complete
production `kssolv()` shell. It physically exercised shortcut help, atom
selection, exact Move/Rotate with inspector verification, Undo/Redo, 3D Sketch,
the generic eight-entry adsorbate palette and a two-left-drag COOH placement workflow.
It also records the Rotate Atoms bottom-row defect and the physical post-fix
retest. The six-molecule pointer matrix is now closed by
`p2-six-molecule-pointer-20260812-125404`. Unsupported right-button drag and
independent-user gates remain `false` rather than being inferred.

The physical display follow-up is recorded in
`p1-200-percent-physical-20260812-085000`. The built-in 3024×1964 Retina panel
was verified at 1512×982 logical resolution (2.0 system scale). Physical input
checked the Modeling Tab, common/advanced shortcuts, Build Supercell, Add
Solvent Layer, and Fragment Sketcher without overlap or bottom clipping. Because
MATLAB's embedded Chromium does not provide reliable native page zoom, the
viewer now supplies layout-aware `Command/Ctrl-plus`, minus and zero shortcuts.
The main view and common/advanced shortcut sections were physically inspected
at 200%, then restored to 100%. The report remains failed only because the
signed P1–P6 A1–A5, B1–B5, and C1–C5 audit is external.

The `p3-fragment-sketcher-20260812-043415` run then used the production 3D
Sketch and Fragment Sketcher with physical pointer input. It placed and selected
an isolated carbon, chose Carboxyl/Surface-C from the searchable library, and
attached COOH as one transaction. The five-/nine-atom undo/redo states and the
post-commit camera fit are captured. A saturated-oxygen attachment was also
physically rejected before commit without clearing the browser. Benzene and
surface pointer tasks were subsequently closed by
`p3-benzene-cooh-pointer-20260812-045749` and
`p3-surface-cooh-pointer-20260812-050239`. The first starts from a zero-atom
production molecule and finishes C7H6O2 through Sketch Ring, Fragment Sketcher,
and Add Hydrogens. The second uses the generic adsorbate palette, two physical
left drags, an exact 2.1 Å host bond and Enter on the production Cu slab. Both
record physical undo/redo evidence.

## Historical P3-P4 builder baseline

```matlab
report = runP3P4MoleculeBuilderAcceptance();
assert(report.passed);
```

The scenario opens a production AppContainer and uihtml molecular document,
builds N-methylbenzamide from a blank molecule through revision-guarded sketch
and fragment transactions, adds explicit hydrogens only after the valid
nitrogen attachment, performs exact geometry edits, exercises undo/redo,
exports MOL/SDF, and captures a GUI screenshot. The paired functional suite
covers six reference molecules, fifty hydrogen-rule samples, and one hundred
fragment assemblies.

## Historical P5-P6 crystal/surface baseline

```matlab
report = runP5P6CrystalSurfaceAcceptance();
assert(report.passed);
```

The scenario rebuilds Fm-3m Pt from an asymmetric unit, verifies space group
225 and defect degeneracy, constructs a supercell/vacancy and Pt(111) slab,
adds measured vacuum, enumerates adsorption sites, checks a moiré candidate,
and exports CIF plus GUI evidence.

## P7-P8

```matlab
report = runP7P8PolymerPackingAcceptance();
assert(report.passed);
```

This covers polymer and amorphous menus in a production document, exact block
and random compositions, density/contact/confinement invariants, and the
9,998/9,999-atom performance gates. Functional tests add mass/mole/count
composition, ring-piercing detection, deterministic seeds and clean cancel.

## P9

```matlab
report = runP9AutomationAcceptance();
assert(report.passed);
```

The GUI recorder captures ten transactions and verifies all parent/result
hashes during replay. The same run processes 100 isolated structures, tests
progress and cancellation, and writes a recipe plus batch summary.

## P10 automated gate

```matlab
report = runP10ModelingReleaseAcceptance();
assert(report.passed);
```

The real GUI performs 500 preview/render/commit/autosave edits and injects
stale revision, backend, renderer-limit and project-save failures. It verifies
zero model corruption, recoverable SHA-256 snapshots, normal-save cleanup,
zero recovery temp files and zero timer growth. This automated gate does not
replace the required four-hour run or ten-person licensed Materials Studio
study. Use `P10-usability-study-protocol.zh-CN.md`, complete the CSV template,
and run `analyzeP10UsabilityStudy`; incomplete evidence must remain failed.
Use `P10-accessibility-audit.zh-CN.md` for the separate 200% zoom and
keyboard-only human sign-off. Automated ARIA and focus tests cannot mark that
form passed. Copy `P10-accessibility-results-template.json` into the final
candidate report directory and fill it only after the signed audit.

`auditP10Candidate` is the final fail-closed aggregator. It independently
requires a `candidateStatus=ready` manifest and independently checks the
package hash and required archive contents, raw MATLAB test-result arrays,
coverage XML, exact GUI reports, qualified soak, usability CSV, and
accessibility JSON. P1-P10 may be closed only when its returned `passed` field
is true. A runtime defect must immediately supersede the affected candidate.

## P10 four-hour qualification

```matlab
report = runP10FourHourSoak();
assert(report.passed && report.qualified);
```

The default cannot be shortened: it keeps a production AppContainer/uihtml
document alive for at least 14,400 seconds, spreads 500 transactional edits
across the run, samples process RSS, discards the first ten minutes as runtime
warm-up, and compares the median of the first/last five stable samples. It
rejects stable memory growth above 10%, timer, temporary-file or Modeling
session growth, and accidental parallel-pool creation. Developers may
exercise the harness with `durationSeconds` and `requireQualification=false`,
but such a report is explicitly marked `qualified=false` and is not release
evidence.

The 2026-08-09 package candidate is superseded after the long-lived GUI run
exposed a Modeling Guide callback defect. Its artifacts remain in `reports/`
for traceability, but they are historical evidence and cannot close P10:

- `current-candidate.json`: immutable package hash plus the exact test and GUI
  report paths, with `candidateStatus=superseded-after-runtime-defect`;
- `modeling-current-results.mat` and `p10-modeling-ui-current-results.mat`:
  raw `matlab.unittest.TestResult` arrays for the 117 modeling and 53
  modeling/scene-UI tests; the final auditor reconciles their three result
  counts instead of trusting summary numbers alone;
- `modeling-coverage.xml`: 117/117 modeling tests passed while producing a
  Cobertura line rate of 85.309%;
- `p10-20260809-084210/report.json`: 500/500 production GUI edits plus stale,
  backend, renderer, save, and loading-close fault injection passed with zero
  timer and recovery-temp-file growth;
- `Release/KSSOLV_Toolbox_V0.3.1.mltbx`: the 50 MB production package produced
  by the five-task `buildtool` chain after a 0-error/0-warning Code Analyzer
  gate;
- the frontend recursive run passed 249 Vitest tests and every TypeScript/Vue
  typecheck target;
- `p10-matgenlab-full-results.mat`: 869 passed, 7 failed, 100 incomplete;
- `p10-head-baseline-failures.mat`: the same seven failures reproduced from an
  isolated detached `HEAD` worktree (0/7 passed), proving that they predate the
  modeling candidate. The 100 incomplete tests require optional frozen
  pymatgen environments or fixtures and are not silently counted as passes.

The latest source, including the Modeling Guide callback and persistence/UI
hardening fixes, is verified by 120/120 modeling tests, 61/61
modeling/scene/UI tests, a real MATLAB R2026b macOS default-app open, and a
1,928-file Code Analyzer run with zero errors and zero warnings. Do not rebuild
or promote a new candidate until the remaining planned adjustments are ready.
