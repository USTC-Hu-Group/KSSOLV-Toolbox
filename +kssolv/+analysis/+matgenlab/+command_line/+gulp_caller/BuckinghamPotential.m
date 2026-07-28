classdef BuckinghamPotential
    %BUCKINGHAMPOTENTIAL Parse Bush or Lewis GULP potential libraries.

    properties (SetAccess = private)
        species_dict
        pot_dict
        spring_dict
    end

    methods
        function obj = BuckinghamPotential(bush_lewis_flag, pot_file)
            flag = lower(string(bush_lewis_flag));
            if ~any(flag == ["bush", "lewis"])
                error("KSSOLV:Matgenlab:GULP:PotentialFlag", ...
                    "bush_lewis_flag should be bush or lewis, got %s", flag);
            end
            if nargin < 2 || strlength(string(pot_file)) == 0
                pot_file = defaultPotentialFile(flag);
            end
            if ~isfile(pot_file)
                error("KSSOLV:Matgenlab:GULP:PotentialFile", ...
                    "Potential file '%s' does not exist.", string(pot_file));
            end
            obj.species_dict = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            obj.pot_dict = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            obj.spring_dict = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            lines = splitlines(string(fileread(pot_file)));
            section = "";
            for index = 1:numel(lines)
                row = lines(index);
                trimmed = strtrim(row);
                if strlength(trimmed) == 0 || startsWith(trimmed, "#")
                    continue
                end
                fields = split(trimmed);
                header = lower(fields(1));
                if any(header == ["species", "buckingham", "spring"])
                    section = header;
                    continue
                end
                element = char(fields(1));
                rowText = char(row + newline);
                if section == "species"
                    if flag == "bush"
                        if obj.species_dict.isKey(element)
                            entry = obj.species_dict(element);
                        else
                            entry = struct("inp_str", "", "oxi", 0);
                        end
                        entry.inp_str = entry.inp_str + string(rowText);
                        entry.oxi = entry.oxi + str2double(fields(3));
                        obj.species_dict(element) = entry;
                    elseif element == "O"
                        obj.species_dict(char("O_" + lower(fields(2)))) = ...
                            rowText;
                    else
                        metal = extractBefore(string(element) + "_", "_");
                        obj.species_dict(element) = sprintf( ...
                            "%s core %s\n", metal, fields(3));
                    end
                elseif section == "buckingham"
                    if flag == "bush"
                        obj.pot_dict(element) = rowText;
                    elseif element == "O"
                        obj.pot_dict("O") = rowText;
                    else
                        metal = extractBefore(string(element) + "_", "_");
                        obj.pot_dict(element) = sprintf("%s %s\n", ...
                            metal, join(fields(2:end), " "));
                    end
                elseif section == "spring"
                    obj.spring_dict(element) = rowText;
                end
            end
            if flag == "bush"
                keys = obj.pot_dict.keys();
                for index = 1:numel(keys)
                    if ~obj.spring_dict.isKey(keys{index})
                        obj.spring_dict(keys{index}) = "";
                    end
                end
            end
        end
    end
end

function path = defaultPotentialFile(flag)
folder = fileparts(mfilename("fullpath"));
path = fullfile(folder, "+data", flag + ".lib");
end
