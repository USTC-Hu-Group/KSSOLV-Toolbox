classdef VasprunLoader < ...
        kssolv.analysis.matgenlab.electronic_structure.VasprunBSLoader
    %VASPRUNLOADER Backward-compatible single-spin BoltzTraP2 loader.

    methods
        function obj = VasprunLoader(run)
            obj@kssolv.analysis.matgenlab.electronic_structure. ...
                VasprunBSLoader();
            if nargin == 0, return; end
            loaded = kssolv.analysis.matgenlab.electronic_structure. ...
                VasprunBSLoader(run);
            names = properties(loaded);
            for index = 1:numel(names)
                obj.(names{index}) = loaded.(names{index});
            end
            if obj.is_spin_polarized
                error("KSSOLV:Matgenlab:Boltztrap2:SpinVasprunLoader", ...
                    "VasprunLoader supports one spin channel; use VasprunBSLoader.");
            end
        end
    end

    methods (Static)
        function obj = from_file(filename)
            run = kssolv.analysis.matgenlab.io.vasp.Vasprun(filename, ...
                "parse_projected_eigen", true);
            obj = kssolv.analysis.matgenlab.electronic_structure. ...
                VasprunLoader(run);
        end
    end
end
