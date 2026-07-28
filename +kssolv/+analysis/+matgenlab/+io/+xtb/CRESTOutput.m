classdef CRESTOutput
    %CRESTOUTPUT Parse a CREST output and its associated XYZ files.

    properties (SetAccess = private)
        path string = "."
        filename string
        cmd_options struct = struct()
        sorted_structures_energies cell = cell(1, 0)
        properly_terminated (1,1) logical = false
        coord_file string = ""
        input_structure = []
        lowest_energy_structure = []
    end

    methods
        function obj = CRESTOutput(output_filename, path)
            if nargin < 2, path = "."; end
            obj.path = string(path);
            obj.filename = string(output_filename);
            obj = obj.parseCrestOutput();
        end

        function value = as_dict(obj)
            groups = cell(size(obj.sorted_structures_energies));
            for groupIndex = 1:numel(groups)
                group = obj.sorted_structures_energies{groupIndex};
                encoded = cell(size(group));
                for row = 1:size(group, 1)
                    encoded{row, 1} = group{row, 1}.as_dict();
                    encoded{row, 2} = group{row, 2};
                end
                groups{groupIndex} = encoded;
            end
            value = struct( ...
                "@module", "pymatgen.io.xtb.outputs", ...
                "@class", "CRESTOutput", ...
                "path", obj.path, ...
                "filename", obj.filename, ...
                "cmd_options", obj.cmd_options, ...
                "sorted_structures_energies", {groups}, ...
                "properly_terminated", obj.properly_terminated);
        end
    end

    methods (Access = private)
        function obj = parseCrestOutput(obj)
            outputPath = fullfile(obj.path, obj.filename);
            if ~isfile(outputPath)
                error("KSSOLV:Matgenlab:XTB:CRESTOutput:MissingOutput", ...
                    "CREST output file '%s' does not exist.", outputPath);
            end
            contents = string(fileread(outputPath));
            lines = splitlines(contents);
            command = "";
            for line = reshape(lines, 1, [])
                match = regexp(line, ">\s*crest\s+(.+)$", "tokens", "once");
                if ~isempty(match)
                    command = strtrim(string(match{1}));
                    break
                end
            end
            if command == ""
                error("KSSOLV:Matgenlab:XTB:CRESTOutput:Command", ...
                    "No CREST command line was found in '%s'.", outputPath);
            end
            [coordinateName, obj.cmd_options] = ...
                obj.parseCommand(command);
            obj.coord_file = fullfile(obj.path, coordinateName);
            if isfile(obj.coord_file)
                obj.input_structure = ...
                    kssolv.analysis.matgenlab.core.Molecule.from_file( ...
                        obj.coord_file);
            end
            charge = obj.commandCharge();
            nonblank = lines(strlength(strtrim(lines)) > 0);
            obj.properly_terminated = ~isempty(nonblank) && ...
                contains(nonblank(end), "CREST terminated normally.");
            if obj.properly_terminated
                [degeneracies, energies] = obj.parseEnergyTable(lines);
                rotamerPath = obj.finalRotamerPath();
                if strlength(rotamerPath) > 0 && isfile(rotamerPath)
                    xyz = ...
                        kssolv.analysis.matgenlab.io.xyz.XYZ.from_file( ...
                            rotamerPath);
                    structures = xyz.all_molecules;
                    expected = sum(degeneracies);
                    if numel(structures) < expected || numel(energies) < expected
                        error("KSSOLV:Matgenlab:XTB:CRESTOutput:Rotamers", ...
                            "CREST table describes %d rotamers, but only " + ...
                            "%d structures and %d energies were parsed.", ...
                            expected, numel(structures), numel(energies));
                    end
                    obj.sorted_structures_energies = ...
                        cell(1, numel(degeneracies));
                    startIndex = 1;
                    for groupIndex = 1:numel(degeneracies)
                        count = degeneracies(groupIndex);
                        group = cell(count, 2);
                        for localIndex = 1:count
                            absoluteIndex = startIndex + localIndex - 1;
                            structure = structures{absoluteIndex};
                            structure = ...
                                structure.set_charge_and_spin(charge);
                            group{localIndex, 1} = structure;
                            group{localIndex, 2} = energies(absoluteIndex);
                        end
                        obj.sorted_structures_energies{groupIndex} = group;
                        startIndex = startIndex + count;
                    end
                end
            end
            bestPath = fullfile(obj.path, "crest_best.xyz");
            if isfile(bestPath)
                best = ...
                    kssolv.analysis.matgenlab.core.Molecule.from_file( ...
                        bestPath);
                obj.lowest_energy_structure = ...
                    best.set_charge_and_spin(charge);
            end
        end

        function charge = commandCharge(obj)
            charge = 0;
            if isfield(obj.cmd_options, "chrg")
                value = obj.cmd_options.chrg;
            elseif isfield(obj.cmd_options, "c")
                value = obj.cmd_options.c;
            else
                return
            end
            charge = str2double(string(value));
            if isnan(charge) || charge ~= fix(charge)
                error("KSSOLV:Matgenlab:XTB:CRESTOutput:Charge", ...
                    "CREST charge option must be an integer.");
            end
        end

        function path = finalRotamerPath(obj)
            preferred = fullfile(obj.path, "crest_rotamers.xyz");
            if isfile(preferred)
                path = string(preferred);
                return
            end
            listing = dir(fullfile(obj.path, "crest_rotamers_*.xyz"));
            if isempty(listing)
                path = "";
                return
            end
            suffixes = nan(1, numel(listing));
            for index = 1:numel(listing)
                token = regexp(listing(index).name, ...
                    "crest_rotamers_(\d+)\.xyz$", "tokens", "once");
                if ~isempty(token), suffixes(index) = str2double(token{1}); end
            end
            [~, index] = max(suffixes);
            path = string(fullfile(obj.path, listing(index).name));
        end
    end

    methods (Static, Access = private)
        function [coordinateName, options] = parseCommand(command)
            tokens = regexp(strtrim(command), "\s+", "split");
            coordinateName = string(tokens{1});
            options = struct();
            index = 2;
            while index <= numel(tokens)
                token = string(tokens{index});
                if startsWith(token, "-")
                    name = matlab.lang.makeValidName( ...
                        char(extractAfter(token, 1)));
                    value = [];
                    nextToken = "";
                    if index < numel(tokens)
                        nextToken = string(tokens{index + 1});
                    end
                    isSignedNumber = ~isnan(str2double(nextToken));
                    if index < numel(tokens) && ...
                            (~startsWith(nextToken, "-") || isSignedNumber)
                        value = string(tokens{index + 1});
                        index = index + 1;
                    end
                    options.(name) = value;
                end
                index = index + 1;
            end
        end

        function [degeneracies, energies] = parseEnergyTable(lines)
            conformerPattern = ...
                "^\s*\d+\s+\d*\.\d*\s+(-?\d+\.\d+)\s+" + ...
                "-?\d+\.\d+\s+-?\d+\.\d+\s+\d+\s+(\d+)\s+\w+\s*$";
            rotamerPattern = ...
                "^\s*\d+\s+\d*\.\d*\s+(-?\d+\.\d+)\s+" + ...
                "-?\d+\.\d+\s+\w+\s*$";
            degeneracies = zeros(1, numel(lines));
            energies = strings(1, numel(lines));
            conformerCount = 0;
            energyCount = 0;
            for line = reshape(lines, 1, [])
                conformer = regexp(line, conformerPattern, ...
                    "tokens", "once");
                if ~isempty(conformer)
                    conformerCount = conformerCount + 1;
                    energyCount = energyCount + 1;
                    degeneracies(conformerCount) = ...
                        str2double(conformer{2});
                    energies(energyCount) = string(conformer{1});
                    continue
                end
                rotamer = regexp(line, rotamerPattern, "tokens", "once");
                if ~isempty(rotamer)
                    energyCount = energyCount + 1;
                    energies(energyCount) = string(rotamer{1});
                end
            end
            degeneracies = degeneracies(1:conformerCount);
            energies = energies(1:energyCount);
        end
    end
end
