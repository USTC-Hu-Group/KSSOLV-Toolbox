classdef LMTOCopl
    %LMTOCOPL Parse LMTO COPL energy-resolved COHP data.

    properties (SetAccess = private)
        cohp_data
        efermi (1,1) double
        energies (:,1) double
        is_spin_polarized (1,1) logical
    end

    methods
        function obj = LMTOCopl(filename, to_eV)
            if nargin < 1, filename = "COPL"; end
            if nargin < 2, to_eV = false; end
            text = string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename));
            lines = splitlines(text);
            lines = lines(strlength(strtrim(lines)) > 0);
            if numel(lines) < 3
                error("KSSOLV:Matgenlab:LMTOCopl:Truncated", ...
                    "COPL file is truncated.");
            end
            parameters = sscanf(lines(2), "%f").';
            numberBonds = round(parameters(1));
            numberSpins = round(parameters(2));
            obj.is_spin_polarized = numberSpins == 2;
            numberColumns = 1 + 2 * numberBonds * numberSpins;
            dataLines = lines(numberBonds + 3:end);
            data = zeros(numel(dataLines), numberColumns);
            for index = 1:numel(dataLines)
                row = sscanf(dataLines(index), "%f").';
                if numel(row) ~= numberColumns
                    error("KSSOLV:Matgenlab:LMTOCopl:Columns", ...
                        "COPL data row %d has %d instead of %d columns.", ...
                        index, numel(row), numberColumns);
                end
                data(index, :) = row;
            end
            conversion = ...
                kssolv.analysis.matgenlab.core.Ry_to_eV();
            if to_eV
                obj.energies = arrayfun(@(value) ...
                    kssolv.analysis.matgenlab.util. ...
                    round_to_sigfigs(value, 5), ...
                    data(:, 1) * conversion);
                obj.efermi = ...
                    kssolv.analysis.matgenlab.util. ...
                    round_to_sigfigs(parameters(end) * conversion, 5);
            else
                obj.energies = data(:, 1);
                obj.efermi = parameters(end);
            end
            obj.cohp_data = containers.Map( ...
                "KeyType", "char", "ValueType", "any");
            spinNames = "up";
            if obj.is_spin_polarized, spinNames = ["up", "down"]; end
            for bondIndex = 1:numberBonds
                [label, lengthValue, sites] = ...
                    obj.bondData(lines(2 + bondIndex));
                cohp = struct();
                icohp = struct();
                for spinIndex = 1:numel(spinNames)
                    offset = bondIndex + ...
                        (spinIndex - 1) * numberBonds;
                    cohp.(spinNames(spinIndex)) = ...
                        data(:, 2 * offset);
                    integrated = data(:, 2 * offset + 1);
                    if to_eV
                        integrated = ...
                            arrayfun(@(value) ...
                            kssolv.analysis.matgenlab.util. ...
                            round_to_sigfigs(value, 5), ...
                            integrated * conversion);
                    end
                    icohp.(spinNames(spinIndex)) = integrated;
                end
                baseLabel = label;
                suffix = 1;
                while isKey(obj.cohp_data, char(label))
                    label = baseLabel + "-" + suffix;
                    suffix = suffix + 1;
                end
                obj.cohp_data(char(label)) = struct( ...
                    "COHP", cohp, "ICOHP", icohp, ...
                    "length", lengthValue, "sites", sites);
            end
        end
    end

    methods (Static, Access = private)
        function [label, lengthValue, sites] = bondData(line)
            tokens = split(strtrim(line));
            lengthValue = str2double(tokens(3));
            parts = split(replace(tokens(1), "/", "-"), "-");
            firstIndex = str2double(parts(2)) - 1;
            secondIndex = str2double(parts(4)) - 1;
            firstSpecies = regexprep(parts(1), "\d+", "");
            secondSpecies = regexprep(parts(3), "\d+", "");
            label = firstSpecies + (firstIndex + 1) + "-" + ...
                secondSpecies + (secondIndex + 1);
            sites = [firstIndex, secondIndex];
        end
    end
end
