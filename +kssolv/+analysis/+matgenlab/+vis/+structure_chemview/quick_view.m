function viewer = quick_view(structure, bonds, conventional, transform, ...
    show_box, bond_tol, stick_radius)
%QUICK_VIEW Build a chemview-compatible native molecular viewer.
if nargin < 2 || isempty(bonds), bonds = true; end
if nargin < 3 || isempty(conventional), conventional = false; end
if nargin < 4, transform = []; end
if nargin < 5 || isempty(show_box), show_box = true; end
if nargin < 6 || isempty(bond_tol), bond_tol = 0.2; end
if nargin < 7 || isempty(stick_radius), stick_radius = 0.1; end

viewStructure = structure.copy();
if conventional
    analyzer = kssolv.analysis.matgenlab.symmetry.analyzer. ...
        SpacegroupAnalyzer(viewStructure);
    viewStructure = analyzer.get_conventional_standard_structure();
end
if ~isempty(transform)
    viewStructure = viewStructure.make_supercell(transform);
end
atomTypes = strings(1, viewStructure.num_sites);
for index = 1:viewStructure.num_sites
    atomTypes(index) = viewStructure.species{index}.symbol;
end

bondPairs = zeros(0, 2);
if bonds
    radii = kssolv.analysis.matgenlab.core.CovalentRadius.radius();
    for first = 1:viewStructure.num_sites - 1
        firstSymbol = char(atomTypes(first));
        for second = first + 1:viewStructure.num_sites
            secondSymbol = char(atomTypes(second));
            maximum = radii.(firstSymbol) + radii.(secondSymbol) + bond_tol;
            if viewStructure.get_distance(first, second, [0, 0, 0]) < maximum
                bondPairs(end + 1, :) = [first - 1, second - 1]; %#ok<AGROW>
            end
        end
    end
end
topology = struct("atom_types", atomTypes, "bonds", bondPairs);
viewer = kssolv.analysis.matgenlab.vis.structure_chemview. ...
    MolecularViewer(viewStructure.cart_coords, topology);
if ~isempty(bondPairs)
    viewer = viewer.ball_and_sticks(stick_radius);
end

radii = kssolv.analysis.matgenlab.core.CovalentRadius.radius();
colors = loadColors();
for index = 1:viewStructure.num_sites
    symbol = char(atomTypes(index));
    rgb = double(colors.(symbol));
    packedColor = bitshift(uint32(rgb(1)), 16) + ...
        bitshift(uint32(rgb(2)), 8) + uint32(rgb(3));
    options = struct("coordinates", ...
        double(viewStructure.cart_coords(index, :)), ...
        "colors", packedColor, "radii", radii.(symbol) * 0.5, ...
        "opacity", 1);
    viewer = viewer.add_representation("spheres", options);
end
if show_box
    origin = [0, 0, 0];
    matrix = viewStructure.lattice.matrix;
    a = matrix(1, :);
    b = matrix(2, :);
    c = matrix(3, :);
    starts = [origin; origin; origin; a; a; b; b; c; c; ...
        a + b; a + c; b + c];
    ends = [a; b; c; a + b; a + c; b + a; b + c; ...
        c + a; c + b; a + b + c; a + b + c; a + b + c];
    options = struct("startCoords", starts, "endCoords", ends, ...
        "startColors", repmat(uint32(hex2dec("FFFFFF")), 1, 12), ...
        "endColors", repmat(uint32(hex2dec("FFFFFF")), 1, 12));
    viewer = viewer.add_representation("lines", options);
end
end

function colors = loadColors()
persistent cached
if isempty(cached)
    root = fileparts(fileparts(mfilename("fullpath")));
    cached = jsondecode(fileread(fullfile(root, "ElementColorSchemes.json"))).Jmol;
end
colors = cached;
end
