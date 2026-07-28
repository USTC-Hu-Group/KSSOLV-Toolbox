classdef FakeVaspInputSet
    %FAKEVASPINPUTSET Deterministic test double for the VaspInputSet boundary.

    properties
        structure
    end

    methods
        function obj = FakeVaspInputSet(structure)
            obj.structure = structure;
        end

        function value = get_input_set(obj)
            value = containers.Map("KeyType", "char", "ValueType", "any");
            value("POSCAR") = ...
                kssolv.analysis.matgenlab.io.vasp.Poscar(obj.structure);
        end

        function write_input(obj, options)
            arguments
                obj
                options.output_dir (1,1) string = "."
                options.make_dir_if_not_present (1,1) logical = true
            end
            if ~isfolder(options.output_dir)
                if options.make_dir_if_not_present
                    mkdir(options.output_dir);
                else
                    error("KSSOLV:Matgenlab:FakeVaspInputSet:Directory", ...
                        "Output directory does not exist.");
                end
            end
            poscar = kssolv.analysis.matgenlab.io.vasp.Poscar(obj.structure);
            poscar.write_file(fullfile(options.output_dir, "POSCAR"));
        end
    end
end
