classdef PotcarScrambler
    %POTCARSCRAMBLER Randomize restricted POTCAR numerical data.
    %
    % This is the MATLAB port of the frozen upstream development utility.
    % It retains the PSCTR metadata used in OUTCAR while replacing subsequent
    % numeric and logical values with type- and precision-compatible data.

    properties (SetAccess = private)
        PSP_list (1,:) cell = cell(1, 0)
        scrambled_potcars_str (1,1) string = ""
    end

    methods
        function obj = PotcarScrambler(potcars)
            if nargin == 0, return; end
            if isa(potcars, ...
                    "kssolv.analysis.matgenlab.io.vasp.PotcarSingle")
                obj.PSP_list = {potcars};
            elseif isa(potcars, ...
                    "kssolv.analysis.matgenlab.io.vasp.Potcar")
                obj.PSP_list = cell(1, potcars.count);
                for index = 1:potcars.count
                    obj.PSP_list{index} = potcars(index);
                end
            else
                error("KSSOLV:Matgenlab:PotcarScrambler:Input", ...
                    "Input must be Potcar or PotcarSingle.");
            end
            for index = 1:numel(obj.PSP_list)
                obj.scrambled_potcars_str = ...
                    obj.scrambled_potcars_str + ...
                    obj.scramble_single_potcar(obj.PSP_list{index});
            end
        end

        function output = scramble_single_potcar(obj, potcar)
            lines = splitlines(potcar.data);
            output = "";
            scramble = false;
            needsHash = false;
            hashPlaceholder = "SHA256 = None";
            for lineIndex = 1:numel(lines)
                line = lines(lineIndex);
                if lineIndex == numel(lines) && line == "", continue; end
                if contains(line, "SHA256")
                    output = output + hashPlaceholder + newline;
                    needsHash = true;
                    continue
                end
                if contains(line, "Error from kinetic energy argument (eV)") || ...
                        contains(line, "END of PSCTR-controll parameters")
                    scramble = true;
                end
                rows = split(line, ";");
                rendered = strings(size(rows));
                for rowIndex = 1:numel(rows)
                    if scramble
                        words = split(strtrim(rows(rowIndex)));
                        words(words == "") = [];
                        for wordIndex = 1:numel(words)
                            words(wordIndex) = string( ...
                                obj.read_fortran_str_and_scramble( ...
                                words(wordIndex)));
                        end
                        rendered(rowIndex) = strjoin(words, " ");
                    else
                        rendered(rowIndex) = rows(rowIndex);
                    end
                end
                combined = strjoin(rendered, "; ");
                if contains(line, "TITEL"), combined = combined + " ; FAKE"; end
                output = output + combined + newline;
            end
            if needsHash
                output = replace(output, hashPlaceholder, ...
                    "SHA256 = " + obj.sha256(output));
            end
        end

        function value = rand_float_from_str_with_prec(~, input, bloat)
            if nargin < 3, bloat = 1.5; end
            text = char(string(input));
            point = strfind(text, ".");
            if isempty(point), precision = 0;
            else
                exponent = regexp(text, "[Ee]", "once");
                if isempty(exponent), exponent = numel(text) + 1; end
                precision = max(exponent - point(1) - 1, 0);
            end
            bound = max(1, bloat * abs(str2double(text)));
            value = round(bound * rand(), precision);
        end

        function value = read_fortran_str_and_scramble(obj, input, bloat)
            if nargin < 3, bloat = 1.5; end
            text = strtrim(string(input));
            lowerText = lower(text);
            if any(lowerText == ["t", "f", "true", "false"])
                choices = ["True", "False"];
                value = choices(randi(2));
                return
            end
            numeric = str2double(text);
            if ~isnan(numeric)
                if contains(text, ".") || contains(lowerText, "e")
                    value = obj.rand_float_from_str_with_prec(text, bloat);
                else
                    signValue = sign(numeric);
                    if signValue == 0, signValue = 0; end
                    upper = max(1, ceil(abs(bloat * numeric)));
                    value = signValue * randi(upper) - signValue;
                end
            else
                value = text;
            end
        end

        function to_file(obj, filename)
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils.writeText( ...
                filename, obj.scrambled_potcars_str);
        end
    end

    methods (Static)
        function obj = from_file(input_filename, output_filename)
            potcar = kssolv.analysis.matgenlab.io.vasp.Potcar. ...
                from_file(input_filename);
            obj = kssolv.analysis.matgenlab.io.vasp.PotcarScrambler(potcar);
            if nargin >= 2 && strlength(string(output_filename)) > 0
                obj.to_file(output_filename);
            end
        end
    end

    methods (Static, Access = private)
        function output = sha256(text)
            digest = java.security.MessageDigest.getInstance("SHA-256");
            digest.update(uint8(unicode2native(char(text), "UTF-8")));
            bytes = typecast(digest.digest(), "uint8");
            output = lower(join(string(dec2hex(bytes, 2)), ""));
        end
    end
end
