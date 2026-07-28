classdef CRESTInput
    %CRESTINPUT Container and writer for CREST coordinate/constraint inputs.

    properties (SetAccess = private)
        molecule
        working_dir string = "."
        coords_filename string = "crest_in.xyz"
        constraints = []
    end

    methods
        function obj = CRESTInput(molecule, options)
            arguments
                molecule
                options.working_dir string = "."
                options.coords_filename string = "crest_in.xyz"
                options.constraints = []
            end
            if ~isa(molecule, "kssolv.analysis.matgenlab.core.Molecule")
                error("KSSOLV:Matgenlab:XTB:CRESTInput:Molecule", ...
                    "molecule must be a matgenlab Molecule.");
            end
            if strlength(options.coords_filename) == 0
                error("KSSOLV:Matgenlab:XTB:CRESTInput:Filename", ...
                    "coords_filename cannot be empty.");
            end
            obj.molecule = molecule;
            obj.working_dir = options.working_dir;
            obj.coords_filename = options.coords_filename;
            obj.constraints = options.constraints;
        end

        function write_input_files(obj)
            if ~isfolder(obj.working_dir)
                [success, message] = mkdir(obj.working_dir);
                if ~success
                    error("KSSOLV:Matgenlab:XTB:CRESTInput:Directory", ...
                        "Cannot create working directory '%s': %s", ...
                        obj.working_dir, message);
                end
            end
            coordinatePath = fullfile(obj.working_dir, obj.coords_filename);
            xyz = kssolv.analysis.matgenlab.io.xyz.XYZ(obj.molecule);
            xyz.write_file(coordinatePath);
            if ~isempty(obj.constraints)
                contents = obj.constrains_template( ...
                    obj.molecule, obj.coords_filename, obj.constraints);
                constraintPath = fullfile(obj.working_dir, ".constrains");
                fid = fopen(constraintPath, "w", "n", "UTF-8");
                if fid < 0
                    error("KSSOLV:Matgenlab:XTB:CRESTInput:Open", ...
                        "Cannot open '%s' for writing.", constraintPath);
                end
                cleanup = onCleanup(@() fclose(fid));
                fwrite(fid, char(contents), "char");
                clear cleanup
            end
        end

        function value = as_dict(obj)
            value = struct( ...
                "@module", "pymatgen.io.xtb.inputs", ...
                "@class", "CRESTInput", ...
                "molecule", obj.molecule.as_dict(), ...
                "working_dir", obj.working_dir, ...
                "coords_filename", obj.coords_filename, ...
                "constraints", obj.constraints);
        end
    end

    methods (Static)
        function value = constrains_template(molecule, reference_fnm, constraints)
            atoms = kssolv.analysis.matgenlab.io.xtb.CRESTInput. ...
                constraintValue(constraints, "atoms");
            forceConstant = ...
                kssolv.analysis.matgenlab.io.xtb.CRESTInput. ...
                constraintValue(constraints, "force_constant");
            atoms = reshape(double(atoms), 1, []);
            if isempty(atoms) || any(atoms ~= fix(atoms)) || ...
                    any(atoms < 1) || any(atoms > molecule.num_sites) || ...
                    numel(unique(atoms)) ~= numel(atoms)
                error("KSSOLV:Matgenlab:XTB:CRESTInput:Constraints", ...
                    "Constraint atoms must be unique 1-based site indices.");
            end
            if ~isscalar(forceConstant) || ~isfinite(forceConstant)
                error("KSSOLV:Matgenlab:XTB:CRESTInput:ForceConstant", ...
                    "force_constant must be a finite scalar.");
            end
            allowed = setdiff(1:molecule.num_sites, atoms, "stable");
            if isempty(allowed)
                error("KSSOLV:Matgenlab:XTB:CRESTInput:Metadynamics", ...
                    "At least one atom must remain available to metadynamics.");
            end
            discontinuity = diff(allowed) > 1;
            rangeStarts = allowed([true, discontinuity]);
            rangeEnds = allowed([discontinuity, true]);
            ranges = string(rangeStarts) + "-" + string(rangeEnds);
            atomText = strjoin(string(atoms), ",");
            value = strjoin([ ...
                "$constrain"
                "  atoms: " + atomText
                "  force constant=" + string(forceConstant)
                "  reference=" + string(reference_fnm)
                "$metadyn"
                "  atoms: " + strjoin(ranges, ",")
                "$end"], newline);
        end

        function obj = from_dict(value)
            molecule = kssolv.analysis.matgenlab.util.decode(value.molecule);
            obj = kssolv.analysis.matgenlab.io.xtb.CRESTInput( ...
                molecule, working_dir = string(value.working_dir), ...
                coords_filename = string(value.coords_filename), ...
                constraints = value.constraints);
        end
    end

    methods (Static, Access = private)
        function value = constraintValue(constraints, name)
            if isstruct(constraints) && isfield(constraints, name)
                value = constraints.(name);
            elseif isa(constraints, "containers.Map") && ...
                    isKey(constraints, char(name))
                value = constraints(char(name));
            else
                error("KSSOLV:Matgenlab:XTB:CRESTInput:ConstraintKey", ...
                    "constraints must define '%s'.", name);
            end
        end
    end
end
