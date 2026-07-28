classdef BSVasprun < kssolv.analysis.matgenlab.io.vasp.Vasprun
    %BSVASPRUN Band-structure-focused Vasprun compatibility class.
    %
    % The XML is parsed by the shared native MATLAB engine while DOS and
    % ionic-step downsampling are disabled.

    methods
        function obj = BSVasprun(filename, varargin)
            options = struct("parse_projected_eigen", false, ...
                "parse_potcar_file", false, "occu_tol", 1e-8, ...
                "separate_spins", false);
            names = fieldnames(options);
            positional = 1; index = 1;
            while index <= numel(varargin)
                current = varargin{index};
                if (ischar(current) || (isstring(current) && isscalar(current))) ...
                        && any(strcmpi(string(current), string(names)))
                    match = find(strcmpi(string(current), string(names)), 1);
                    options.(names{match}) = varargin{index + 1};
                    index = index + 2;
                else
                    options.(names{positional}) = current;
                    positional = positional + 1;
                    index = index + 1;
                end
            end
            obj@kssolv.analysis.matgenlab.io.vasp.Vasprun( ...
                filename, "parse_dos", false, ...
                "parse_eigen", true, ...
                "parse_projected_eigen", options.parse_projected_eigen, ...
                "parse_potcar_file", options.parse_potcar_file, ...
                "occu_tol", options.occu_tol, ...
                "separate_spins", options.separate_spins);
        end

        function output = as_dict(obj)
            output = as_dict@kssolv.analysis.matgenlab.io.vasp.Vasprun(obj);
            output.has_vasp_completed = true;
            if isfield(output, "input") && isfield(output.input, "crystal")
                output.input.crystal = obj.final_structure.as_dict();
            end
        end
    end
end
