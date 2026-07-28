classdef InchiMolAtomMapper < ...
        kssolv.analysis.matgenlab.core.AbstractMolAtomMapper
    %INCHIMOLATOMMAPPER OpenBabel InChI canonical-label mapper.

    properties (SetAccess = private)
        angle_tolerance (1,1) double = 10
    end

    methods
        function obj = InchiMolAtomMapper(angle_tolerance)
            if nargin < 1, angle_tolerance = 10; end
            obj.angle_tolerance = double(angle_tolerance);
        end

        function varargout = uniform_labels(obj, varargin)
            obj.requireOpenBabel();
            varargout = {[], []};
        end

        function value = get_molecule_hash(obj, varargin) %#ok<STOUT>
            obj.requireOpenBabel();
        end

        function value = asDict(obj)
            value = struct("x_module", ...
                "pymatgen.core.molecule_matcher", ...
                "x_class", "InchiMolAtomMapper", ...
                "angle_tolerance", obj.angle_tolerance);
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.core.InchiMolAtomMapper( ...
                value.angle_tolerance);
        end
    end

    methods (Static, Access = private)
        function requireOpenBabel()
            error("KSSOLV:Matgenlab:MoleculeMatcher:OpenBabelRequired", ...
                "BabelMolAdaptor requires OpenBabel with native MATLAB " + ...
                "bindings. Install OpenBabel >= 3.0 to use InChI mapping.");
        end
    end
end
