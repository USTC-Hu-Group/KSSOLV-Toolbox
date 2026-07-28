function test_phase_diagram_matlab()
%TEST_PHASE_DIAGRAM_MATLAB Frozen pymatgen phase-diagram parity regression.
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(root);
fixtureRoot = phaseFixtureRoot();
assert(isfolder(fixtureRoot), "Frozen pymatgen analysis fixtures unavailable.");
import kssolv.analysis.matgenlab.analysis.*
import kssolv.analysis.matgenlab.core.*

% Entry variants and MSON-style reconstruction.
entry = PDEntry("LiFeO2", 53, "name", "mp-757614");
assert(entry.energy == 53 && entry.energy_per_atom == 53/4);
assert(entry.name == "mp-757614" && ~entry.is_element);
assert(strcmp(char(entry), ...
    "PDEntry : Li1 Fe1 O2 (mp-757614) with energy = 53.0000"));
assert(isequaln(entry.as_dict(), PDEntry.from_dict(entry.as_dict()).as_dict()));
anonymous = entry.as_dict();
anonymous = rmfield(anonymous, "name");
assert(PDEntry.from_dict(anonymous).name == "LiFeO2");

grandEntry = GrandPotPDEntry(entry, {"O", 1.5});
assert(grandEntry.chemical_energy == 3 && grandEntry.energy == 50);
assert(grandEntry.energy_per_atom == 25);
assert(grandEntry.composition == Composition("LiFe"));
assert(isequaln(grandEntry.as_dict(), ...
    GrandPotPDEntry.from_dict(grandEntry.as_dict()).as_dict()));

terminals = {Composition("Li2O"), Composition("FeO"), Composition("LiO8")};
mapping = cell(3, 2);
for index = 1:3
    mapping(index, :) = {terminals{index}, ...
        DummySpecies("X" + string(char(double('e') + index)))};
end
transformed = TransformedPDEntry(PDEntry("LiFeO2", 53), mapping);
assert(abs(transformed.energy_per_atom - 53/(23/15)) < 1e-12);
expectedTransformed = Composition({DummySpecies("Xf"), 14/30; ...
    DummySpecies("Xg"), 1; DummySpecies("Xh"), 2/30});
assert(transformed.composition == expectedTransformed);
normalized = transformed.normalize("atom");
expectedNormalized = Composition({DummySpecies("Xf"), 7/23; ...
    DummySpecies("Xg"), 15/23; DummySpecies("Xh"), 1/23});
assert(normalized.composition == expectedNormalized);
assert(isequaln(transformed.as_dict(), ...
    TransformedPDEntry.from_dict(transformed.as_dict()).as_dict()));
assert(isa(TransformedPDEntryError("bad"), "MException"));
assert(isa(PhaseDiagramError("bad"), "MException"));

% Official 490-entry Li-Fe-O fixture and upstream numerical assertions.
entries = EntrySet.from_csv(fullfile(fixtureRoot, "pd_entries_test.csv"));
assert(numel(entries.entries) == 490);
phase = PhaseDiagram(entries);
assert(phase.dim == 3);
assert(numel(phase.all_entries) == 490);
assert(numel(phase.qhull_entries) == 143);
assert(numel(phase.facets) == 12);
assert(numel(phase.stable_entries) == 11);
assert(size(phase.all_entries_hulldata, 1) == 490);
assert(numel(phase.unstable_entries) == 479);
assert(max(abs(phase.pd_coords(Composition("LiFeO2")) - [.25, .5])) < 1e-12);

li5feo4 = findEntry(phase.stable_entries, "Li5FeO4");
assert(abs(phase.get_reference_energy(li5feo4.composition) + ...
    265.5546721) < 1e-7);
assert(abs(phase.get_reference_energy_per_atom(li5feo4.composition) - ...
    phase.get_reference_energy(li5feo4.composition) / ...
    li5feo4.composition.num_atoms) < 1e-12);
assert(abs(phase.get_form_energy(li5feo4) + 164.8117344) < 1e-7);
assert(abs(phase.get_form_energy_per_atom(li5feo4) - ...
    phase.get_form_energy(li5feo4) / ...
    li5feo4.composition.num_atoms) < 1e-12);

target = Composition("Li3Fe7O11");
decomposition = phase.get_decomposition(target);
assert(size(decomposition, 1) == 3);
verifyDecomposition(decomposition, ...
    ["FeO", "LiFeO2", "Fe3O4"], [2/21, 4/7, 1/3]);
[decomposition2, hullPerAtom] = ...
    phase.get_decomp_and_hull_energy_per_atom(target);
assert(size(decomposition2, 1) == 3);
assert(abs(phase.get_hull_energy_per_atom(target) - hullPerAtom) < 1e-12);
assert(abs(phase.get_hull_energy(target) - ...
    target.num_atoms*hullPerAtom) < 1e-12);
[stableDecomposition, eAbove] = ...
    phase.get_decomp_and_e_above_hull(li5feo4);
assert(size(stableDecomposition, 1) == 1 && abs(eAbove) < 1e-12);
assert(abs(phase.get_e_above_hull(li5feo4)) < 1e-12);
assert(phase.get_equilibrium_reaction_energy(li5feo4) <= 0);
assert(phase.get_phase_separation_energy(li5feo4) <= 0);
[~, separation] = phase.get_decomp_and_phase_separation_energy( ...
    li5feo4, "stable_only", true);
assert(abs(separation - ...
    phase.get_equilibrium_reaction_energy(li5feo4)) < 1e-7);

% Regression for small negative endpoint roundoff in critical compositions.
critical = phase.get_critical_compositions( ...
    Composition("Fe2O3"), Composition("Li2O"));
expectedCritical = {Composition("Fe2O3"), Composition("LiFeO2"), ...
    Composition("Li5FeO4")/3, Composition("Li2O")};
assert(numel(critical) == numel(expectedCritical));
for index = 1:numel(critical)
    assert(critical{index}.almost_equals(expectedCritical{index}, 0, 1e-5));
end
sameCritical = phase.get_critical_compositions( ...
    Composition("Fe2O3"), Composition("Fe4O6"));
assert(numel(sameCritical) == 2);

% Chemical potentials, profiles and stability domains.
chempots = phase.get_composition_chempots(Composition("Fe3.1O4"));
assert(abs(getPot(chempots, "Li") + 4.077061954) < 1e-8);
allChempots = phase.get_all_chempots(Composition("FeO"));
row = find(arrayfun(@(item)contains(item.name, "FeO") && ...
    contains(item.name, "LiFeO2") && contains(item.name, "Fe"), ...
    allChempots), 1);
assert(~isempty(row));
assert(abs(getPot(allChempots(row).chempots, "O") + 7.11535414) < 1e-8);
transitions = phase.get_transition_chempots("O");
assert(issorted(transitions, "descend"));
profile = phase.get_element_profile("O", Composition("Li2O"));
assert(numel(profile) == 3);
assert(max(abs([profile.evolution] - [1, 0, -1])) < 1e-8);
assert(max(abs([profile.chempot] - ...
    [-4.258278141666667, -5.08859066, -10.48758201])) < 1e-8);
ranges = phase.get_chempot_range_map({"Li", "O"});
assert(size(ranges, 1) == 10);
vertices = phase.getmu_vertices_stability_phase(Composition("LiFeO2"), "O");
assert(numel(vertices) == 6);
stabilityRange = phase.get_chempot_range_stability_phase( ...
    Composition("LiFeO2"), "O");
assert(abs(getRange(stabilityRange, "O", 2) + 4.450181225) < 1e-8);
assert(abs(getRange(stabilityRange, "Fe", 1) + 10.45183356) < 1e-8);

% Error policy and phase-separation polymorph semantics.
tooNegative = PDEntry("Li", -1e6);
[ignoredDecomp, ignoredEnergy] = phase.get_decomp_and_e_above_hull( ...
    tooNegative, "on_error", "ignore");
assert(isempty(ignoredDecomp) && isempty(ignoredEnergy));
outside = PDEntry("LiU", -10);
assert(isempty(phase.get_phase_separation_energy( ...
    outside, "on_error", "ignore")));
toy = PhaseDiagram({PDEntry("Li", 0), PDEntry("Li2O", -5), ...
    PDEntry("LiO2", -4), PDEntry("O2", 0)});
assert(abs(toy.get_phase_separation_energy(PDEntry("Li2O", -5)) + 1) < 1e-12);
assert(abs(toy.get_phase_separation_energy(PDEntry("Li2O", -4)) + 2/3) < 1e-12);

% Serialization, grand-potential and compound phase diagrams.
phaseRoundtrip = PhaseDiagram.from_dict(phase.as_dict());
assert(isequaln(phase.as_dict(), phaseRoundtrip.as_dict()));
grand = GrandPotentialPhaseDiagram(entries, {"O", -5});
assert(numel(grand.stable_entries) == 5);
assertFormation(grand, "Li5FeO4", -5.30551504, true);
assertFormation(grand, "LiFeO2", -0.4302639625, true);
assert(isequaln(grand.as_dict(), ...
    GrandPotentialPhaseDiagram.from_dict(grand.as_dict()).as_dict()));
compound = CompoundPhaseDiagram(entries, ...
    {Composition("Li2O"), Composition("Fe2O3")});
assert(numel(compound.stable_entries) == 4);
assertFormation(compound, "Li5FeO4", -7.07732844, false);
assertFormation(compound, "LiFeO2", -0.4745592975, false);
[transformedEntries, speciesMapping] = compound.transform_entries( ...
    entries, compound.terminal_compositions);
assert(~isempty(transformedEntries) && size(speciesMapping, 1) == 2);
assert(CompoundPhaseDiagram.num2str(0) == "f");
assert(CompoundPhaseDiagram.num2str(21) == "ff");
assert(isequaln(compound.as_dict(), ...
    CompoundPhaseDiagram.from_dict(compound.as_dict()).as_dict()));

% Patched and reaction phase diagrams from the frozen reaction fixture.
reactionEntries = EntrySet.from_csv( ...
    fullfile(fixtureRoot, "reaction_entries_test.csv"));
reactionEntries.add(PDEntry("He", -1.23));
patched = PatchedPhaseDiagram(reactionEntries);
fullPhase = PhaseDiagram(reactionEntries);
assert(patched.length() == 4);
assert(numel(patched.stable_entries) == numel(fullPhase.stable_entries));
candidate = reactionEntries.entries{find(cellfun(@(item) ...
    item.reduced_formula ~= "He", reactionEntries.entries), 1)};
assert(isa(patched.get_pd_for_entry(candidate), ...
    "kssolv.analysis.matgenlab.analysis.PhaseDiagram"));
assert(isequaln(patched.as_dict(), ...
    PatchedPhaseDiagram.from_dict(patched.as_dict()).as_dict()));
updated = patched.update(PDEntry("V2O5", -500));
assert(updated ~= patched);
[updated2, info] = patched.update(PDEntry("V2O5", -500), ...
    "return_info", true);
assert(~isempty(info.new_stable_entries));
assert(any(cellfun(@(item)item.reduced_formula == "V2O5", ...
    updated2.stable_entries)));
assert(patched.update({}) == patched);
verifyPatchedUnsupported(patched);

rawReaction = reactionEntries.entries(~cellfun(@(item) ...
    item.reduced_formula == "He", reactionEntries.entries));
first = findEntry(rawReaction, "VPO5");
second = findEntry(rawReaction, "H4(CO)3");
reaction = ReactionDiagram(first, second, rawReaction(3:end));
assert(numel(reaction.rxn_entries) == 9);
assert(isa(reaction.get_compound_pd(), ...
    "kssolv.analysis.matgenlab.analysis.CompoundPhaseDiagram"));

% Utility functions and all plotting adapters.
facets = get_facets([0, 0; 1, 0; 0, 1; 1, 1], true);
assert(~isempty(facets));
assert(isequal(uniquelines({[1, 2, 3], [2, 3, 4]}), ...
    [1, 2; 1, 3; 2, 3; 2, 4; 3, 4]));
assert(max(abs(triangular_coord([.5, .5]) - ...
    [.75, sqrt(3)/4])) < 1e-8);
assert(max(abs(tet_coord([.5, .5, .5]) - ...
    [1, sqrt(3)/3, sqrt(6)/6])) < 1e-8);
plotter = PDPlotter(phase, "backend", "matplotlib");
plotData = plotter.pd_plot_data;
assert(numel(plotData{1}) == 22 && size(plotData{2}, 1) == 11 && ...
    size(plotData{3}, 1) == 479);
[plotLines, stablePlot, unstablePlot] = plotter.get_pd_plot_data();
cornerNames = currentCornerNames(stablePlot);
[orderedLines, orderedStable, orderedUnstable] = order_phase_diagram( ...
    plotLines, stablePlot, unstablePlot, cornerNames([2, 3, 1]));
assert(numel(orderedLines) == numel(plotLines));
assert(size(orderedStable, 1) == size(stablePlot, 1));
assert(size(orderedUnstable, 1) == size(unstablePlot, 1));
axesHandle = phase.get_plot("backend", "matplotlib");
assert(isgraphics(axesHandle, "axes"));
close(axesHandle.Parent);
axesHandle = plotter.get_plot();
assert(isgraphics(axesHandle, "axes"));
close(axesHandle.Parent);
profileAxes = plotter.plot_element_profile("O", Composition("Li2O"));
assert(isgraphics(profileAxes, "axes"));
close(profileAxes.Parent);
rangeAxes = plotter.get_chempot_range_map_plot({"Li", "O"});
assert(isgraphics(rangeAxes, "axes"));
close(rangeAxes.Parent);
contourAxes = plotter.get_contour_pd_plot();
assert(isgraphics(contourAxes, "axes"));
close(contourAxes.Parent);
imagePath = string(tempname) + ".png";
imageCleanup = onCleanup(@()deleteIfFile(imagePath));
plotter.write_image(imagePath, "png");
assert(isfile(imagePath));
close all force

% Frozen Python oracle checks the same compact hull independently when present.
if kssolv.analysis.matgenlab.test.support.PymatgenOracle.isAvailable()
    verifyFrozenOracle();
end

% Every production file contributing an inventory API passes checkcode.
production = ["PDEntry", "GrandPotPDEntry", "TransformedPDEntry", ...
    "TransformedPDEntryError", "PhaseDiagram", ...
    "GrandPotentialPhaseDiagram", "CompoundPhaseDiagram", ...
    "PatchedPhaseDiagram", "ReactionDiagram", "PhaseDiagramError", ...
    "PDPlotter", "get_facets", "uniquelines", "triangular_coord", ...
    "tet_coord", "order_phase_diagram"];
analysisRoot = fullfile(root, "+kssolv", "+analysis", "+matgenlab", "+analysis");
issues = 0;
for index = 1:numel(production)
    issues = issues + numel(checkcode( ...
        fullfile(analysisRoot, production(index) + ".m"), "-id"));
end
assert(issues == 0);
clear imageCleanup
end

function root = phaseFixtureRoot()
roots = [string(getenv("MATGENLAB_PYMATGEN_CORE")), ...
    "/tmp/matgenlab-pymatgen-core-v2026.7.24", ...
    "/tmp/pymatgen-core-upstream"];
root = "";
for candidate = roots
    path = fullfile(candidate, "test-files", "analysis");
    if isfolder(path)
        root = path;
        return
    end
end
end

function entry = findEntry(entries, formula)
row = find(cellfun(@(item)item.reduced_formula == string(formula), entries), 1);
assert(~isempty(row), "Expected phase '%s' is absent.", formula);
entry = entries{row};
end

function verifyDecomposition(decomposition, formulas, amounts)
for index = 1:numel(formulas)
    row = find(cellfun(@(item)item.reduced_formula == formulas(index), ...
        decomposition(:, 1)), 1);
    assert(~isempty(row));
    assert(abs(decomposition{row, 2} - amounts(index)) < 1e-10);
end
end

function value = getPot(potentials, symbol)
row = find(cellfun(@(item)item.symbol == string(symbol), potentials(:, 1)), 1);
assert(~isempty(row));
value = potentials{row, 2};
end

function value = getRange(ranges, symbol, endpoint)
row = find(cellfun(@(item)item.symbol == string(symbol), ranges(:, 1)), 1);
assert(~isempty(row));
value = ranges{row, 2}(endpoint);
end

function assertFormation(diagram, formula, expected, original)
if original
    row = find(cellfun(@(item)item.original_entry.reduced_formula == ...
        string(formula), diagram.stable_entries), 1);
else
    row = find(cellfun(@(item)item.name == string(formula), ...
        diagram.stable_entries), 1);
end
assert(~isempty(row));
assert(abs(diagram.get_form_energy(diagram.stable_entries{row}) - expected) < 1e-8);
end

function verifyPatchedUnsupported(diagram)
methods = ["get_composition_chempots", "get_all_chempots", ...
    "get_transition_chempots", "get_critical_compositions", ...
    "get_element_profile", "get_chempot_range_map", ...
    "getmu_vertices_stability_phase", ...
    "get_chempot_range_stability_phase"];
for name = methods
    failed = false;
    try
        diagram.(name)();
    catch exception
        failed = exception.identifier == ...
            "KSSOLV:Matgenlab:PatchedPhaseDiagram:NotImplemented";
    end
    assert(failed, "%s must preserve upstream NotImplemented behavior.", name);
end
end

function names = currentCornerNames(stable)
coordinates = cell2mat(stable(:, 1));
[~, up] = max(coordinates(:, 2));
[~, left] = min(coordinates(:, 1));
[~, right] = max(coordinates(:, 1));
names = [stable{up, 2}.name, stable{left, 2}.name, stable{right, 2}.name];
end

function verifyFrozenOracle()
entry = @(formula, energy)struct( ...
    "x_module", "pymatgen.analysis.phase_diagram", ...
    "x_class", "PDEntry", "composition", formula, "energy", energy);
composition = struct("x_module", "pymatgen.core.composition", ...
    "x_class", "Composition", "Li", 1, "O", 1);
request = struct(module="pymatgen.analysis.phase_diagram", ...
    symbol="PhaseDiagram", construct=struct(args={{ ...
    {entry("Li", 0), entry("O2", 0), ...
    entry("Li2O", -5), entry("LiO2", -4)}}}), ...
    operations={{struct(kind="call", name="get_hull_energy_per_atom", ...
    args={{composition}}), struct(kind="call", ...
    name="get_transition_chempots", args={{struct( ...
    "x_module", "pymatgen.core.periodic_table", ...
    "x_class", "Element", "element", "Li")}})}});
reference = kssolv.analysis.matgenlab.test.support. ...
    PymatgenOracle.execute(request);
diagram = kssolv.analysis.matgenlab.analysis.PhaseDiagram({ ...
    kssolv.analysis.matgenlab.analysis.PDEntry("Li", 0), ...
    kssolv.analysis.matgenlab.analysis.PDEntry("O2", 0), ...
    kssolv.analysis.matgenlab.analysis.PDEntry("Li2O", -5), ...
    kssolv.analysis.matgenlab.analysis.PDEntry("LiO2", -4)});
assert(abs(diagram.get_hull_energy_per_atom( ...
    kssolv.analysis.matgenlab.core.Composition("LiO")) - ...
    reference.results{1}) < 1e-12);
assert(max(abs(diagram.get_transition_chempots("Li") - ...
    reshape(reference.results{2}, 1, []))) < 1e-12);
end

function deleteIfFile(path)
if isfile(path)
    delete(path);
end
end
