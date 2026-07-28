classdef HighSymmetryPoint < kssolv.analysis.matgenlab.util.MSONable
    %HIGHSYMMETRYPOINT PWmat HIGH_SYMMETRY_POINTS representation.

    properties (SetAccess = private)
        reciprocal_lattice (3,3) double
        kpath (1,1) struct
        density (1,1) double
    end

    methods
        function obj = HighSymmetryPoint( ...
                reciprocalLattice, points, path, density)
            generated = kssolv.analysis.matgenlab.io.pwmat.GenKpt( ...
                reciprocalLattice, points, path, density);
            obj.reciprocal_lattice = generated.reciprocal_lattice;
            obj.kpath = generated.kpath;
            obj.density = double(density);
        end

        function value = get_str(obj)
            paths = obj.kpath.path;
            discontinuities = strings(max(0, numel(paths) - 1), 2);
            for pathIndex = 1:numel(paths) - 1
                discontinuities(pathIndex, :) = ...
                    [string(paths{pathIndex}{end}), ...
                    string(paths{pathIndex + 1}{1})];
            end
            flattened = [paths{:}];
            index = 1;
            coordinate = 0;
            value = "Label       Index       Coordinate" + newline;
            value = value + rowString(flattened{1}, index, coordinate);
            for pointIndex = 2:numel(flattened)
                pair = string(flattened(pointIndex - 1:pointIndex));
                if any(all(discontinuities == pair, 2))
                    index = index + 1;
                else
                    first = obj.kpath.kpoints(char(pair(1)));
                    second = obj.kpath.kpoints(char(pair(2)));
                    distance = norm((second - first) * ...
                        obj.reciprocal_lattice);
                    coordinate = coordinate + distance / (2 * pi);
                    index = index + ceil(distance / obj.density + 1);
                end
                value = value + rowString( ...
                    flattened{pointIndex}, index, coordinate);
            end
            value = string(value);
        end

        function write_file(obj, filename)
            kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                write_text(filename, obj.get_str());
        end

        function value = asDict(obj)
            value = struct("x_module", "pymatgen.io.pwmat.inputs", ...
                "x_class", "HighSymmetryPoint", ...
                "reciprocal_lattice", obj.reciprocal_lattice, ...
                "kpts", obj.kpath.kpoints, ...
                "path", {obj.kpath.path}, "density", obj.density);
        end
    end

    methods (Static)
        function obj = from_structure(structure, dimension, density)
            if nargin < 3, density = .01; end
            generated = kssolv.analysis.matgenlab.io.pwmat.GenKpt. ...
                from_structure(structure, dimension, density);
            obj = kssolv.analysis.matgenlab.io.pwmat. ...
                HighSymmetryPoint(generated.reciprocal_lattice, ...
                generated.kpath.kpoints, generated.kpath.path, ...
                density * 2 * pi);
        end

        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat. ...
                HighSymmetryPoint(value.reciprocal_lattice, ...
                value.kpts, value.path, value.density);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat. ...
                HighSymmetryPoint.from_dict(value);
        end
    end
end

function value = rowString(label, index, coordinate)
label = string(label);
if label == "GAMMA", label = "G"; end
value = sprintf("%s            %4d         %.6f\n", ...
    label, index, coordinate);
end
