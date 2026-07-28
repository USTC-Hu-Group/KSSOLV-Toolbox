classdef IsomorphismMolAtomMapper < ...
        kssolv.analysis.matgenlab.core.AbstractMolAtomMapper
    %ISOMORPHISMMOLATOMMAPPER OpenBabel graph-isomorphism mapper.

    methods
        function varargout = uniform_labels(obj, varargin)
            obj.requireOpenBabel();
            varargout = {[], []};
        end

        function value = get_molecule_hash(obj, varargin) %#ok<STOUT>
            obj.requireOpenBabel();
        end

        function value = asDict(obj) %#ok<MANU>
            value = struct("x_module", ...
                "pymatgen.core.molecule_matcher", ...
                "x_class", "IsomorphismMolAtomMapper");
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end

    methods (Static)
        function obj = from_dict(varargin)
            obj = kssolv.analysis.matgenlab.core.IsomorphismMolAtomMapper();
        end
    end

    methods (Static, Access = private)
        function requireOpenBabel()
            error("KSSOLV:Matgenlab:MoleculeMatcher:OpenBabelRequired", ...
                "BabelMolAdaptor requires OpenBabel with native MATLAB " + ...
                "bindings. Install OpenBabel >= 3.0 to use topology mappers.");
        end
    end
end
