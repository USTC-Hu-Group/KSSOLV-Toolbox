classdef PWOutput < handle
    %PWOUTPUT Parser for Quantum ESPRESSO pw.x output.
    properties (Constant)
        patterns = struct( ...
            "energies", "total energy\s+=\s+([\d\.\-]+)\sRy", ...
            "ecut", "kinetic\-energy cutoff\s+=\s+([\d\.\-]+)\s+Ry", ...
            "lattice_type", "bravais\-lattice index\s+=\s+(\d+)", ...
            "celldm1", "celldm\(1\)=\s+([\d\.]+)\s", ...
            "celldm2", "celldm\(2\)=\s+([\d\.]+)\s", ...
            "celldm3", "celldm\(3\)=\s+([\d\.]+)\s", ...
            "celldm4", "celldm\(4\)=\s+([\d\.]+)\s", ...
            "celldm5", "celldm\(5\)=\s+([\d\.]+)\s", ...
            "celldm6", "celldm\(6\)=\s+([\d\.]+)\s", ...
            "nkpts", "number of k points=\s+([\d]+)")
    end

    properties
        filename (1,1) string
        data (1,1) struct = struct()
    end

    properties (Dependent, SetAccess = private)
        final_energy
        lattice_type
    end

    methods
        function obj = PWOutput(filename)
            obj.filename = string(filename);
            obj.read_pattern(obj.patterns);
            names = fieldnames(obj.data);
            for index = 1:numel(names)
                name = names{index};
                values = obj.data.(name);
                numeric = cellfun(@str2double, values);
                if strcmp(name, "energies")
                    obj.data.(name) = numeric;
                elseif any(string(name) == ["lattice_type", "nkpts"])
                    obj.data.(name) = fix(numeric(1));
                else
                    obj.data.(name) = numeric(1);
                end
            end
        end

        function matches = read_pattern(obj, patterns, reverse, ...
                terminateOnMatch, postprocess)
            if nargin < 3, reverse = false; end
            if nargin < 4, terminateOnMatch = false; end
            if nargin < 5, postprocess = @(value) value; end
            text = fileread(obj.filename);
            if isa(patterns, "containers.Map")
                names = string(patterns.keys);
                patternAt = @(name) patterns(char(name));
            else
                names = string(fieldnames(patterns));
                patternAt = @(name) patterns.(name);
            end
            matches = struct();
            for name = reshape(names, 1, [])
                tokens = regexp(text, char(patternAt(name)), "tokens");
                values = cellfun(@(token) token{1}, tokens, ...
                    "UniformOutput", false);
                if reverse, values = flip(values); end
                if terminateOnMatch && ~isempty(values)
                    values = values(1);
                end
                if ~isempty(postprocess)
                    values = cellfun(postprocess, values, ...
                        "UniformOutput", false);
                end
                matches.(name) = values;
                obj.data.(name) = values;
            end
        end

        function value = get_celldm(obj, index)
            value = obj.data.("celldm" + string(index));
        end

        function value = get.final_energy(obj)
            value = obj.data.energies(end);
        end

        function value = get.lattice_type(obj)
            value = obj.data.lattice_type;
        end
    end
end
