classdef AbstractMolAtomMapper < kssolv.analysis.matgenlab.util.MSONable
    %ABSTRACTMOLATOMMAPPER Interface for topology-based atom labeling.

    methods
        function varargout = uniform_labels(varargin) %#ok<STOUT>
            error("KSSOLV:Matgenlab:MoleculeMatcher:Abstract", ...
                "uniform_labels must be implemented by a concrete mapper.");
        end

        function value = get_molecule_hash(varargin) %#ok<STOUT>
            error("KSSOLV:Matgenlab:MoleculeMatcher:Abstract", ...
                "get_molecule_hash must be implemented by a concrete mapper.");
        end

        function value = asDict(obj)
            value = struct("x_module", ...
                "pymatgen.core.molecule_matcher", ...
                "x_class", className(obj));
            function name = className(item)
                pieces = split(string(class(item)), ".");
                name = pieces(end);
            end
        end

        function value = as_dict(obj), value = obj.asDict(); end
    end

    methods (Static)
        function obj = from_dict(value)
            name = "";
            if isfield(value, "x_class"), name = string(value.x_class);
            elseif isfield(value, "class"), name = string(value.class);
            end
            switch name
                case "IsomorphismMolAtomMapper"
                    obj = kssolv.analysis.matgenlab.core. ...
                        IsomorphismMolAtomMapper.from_dict(value);
                case "InchiMolAtomMapper"
                    obj = kssolv.analysis.matgenlab.core. ...
                        InchiMolAtomMapper.from_dict(value);
                otherwise
                    error("KSSOLV:Matgenlab:MoleculeMatcher:MapperDict", ...
                        "Invalid molecular atom mapper dictionary.");
            end
        end
    end
end
