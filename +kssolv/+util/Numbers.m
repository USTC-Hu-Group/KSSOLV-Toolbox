classdef Numbers
    %NUMBERS Shortest round-trippable floating-point text for file formats.
    methods (Static)
        function value = pythonFloat(input)
            input = double(input);
            if isnan(input), value = "nan"; return; end
            if isinf(input)
                if input < 0, value = "-inf"; else, value = "inf"; end
                return
            end
            if input == 0
                if 1/input < 0, value = "-0.0"; else, value = "0.0"; end
                return
            end
            for precision = 1:17
                text = sprintf('%.*g',precision,input);
                if str2double(text) == input, break; end
            end
            tokens = regexp(text,'^([+-]?)(\d+(?:\.\d+)?)[eE]([+-]?\d+)$','tokens','once');
            if isempty(tokens)
                value = string(text);
                if ~contains(value,'.'), value = value + ".0"; end
                return
            end
            signText = string(tokens{1}); mantissa = string(tokens{2});
            exponent = str2double(tokens{3});
            digits = erase(mantissa,'.');
            if exponent >= -4 && exponent < 16
                position = 1 + exponent;
                if position <= 0
                    value = signText + "0." + string(repmat('0',1,-position)) + digits;
                elseif position >= strlength(digits)
                    value = signText + digits + string(repmat('0',1,position-strlength(digits))) + ".0";
                else
                    value = signText + extractBefore(digits,position+1) + "." + extractAfter(digits,position);
                end
            else
                value = signText + mantissa + "e" + string(sprintf('%+03d',exponent));
            end
        end
    end
end
