classdef Stringify
    %STRINGIFY Mix-in providing pymatgen-style formatted strings.

    properties
        STRING_MODE (1,1) string = "SUBSCRIPT"
    end

    methods
        function text = to_pretty_string(obj)
            text = string(obj);
        end

        function text = toPrettyString(obj)
            text = obj.to_pretty_string();
        end

        function text = to_latex_string(obj)
            text = kssolv.analysis.matgenlab.util.Stringify.formatLatex( ...
                obj.to_pretty_string(), obj.STRING_MODE);
        end

        function text = toLatexString(obj)
            text = obj.to_latex_string();
        end

        function text = to_html_string(obj)
            text = obj.to_latex_string();
            text = regexprep(text, '\$_\{([^}]+)\}\$', '<sub>$1</sub>');
            text = regexprep(text, '\$\^\{([^}]+)\}\$', '<sup>$1</sup>');
            text = regexprep(text, '\$\\overline\{([^}]+)\}\$', ...
                '<span style="text-decoration:overline">$1</span>');
        end

        function text = toHtmlString(obj)
            text = obj.to_html_string();
        end

        function text = to_unicode_string(obj)
            text = obj.to_latex_string();
            subscript = ["₀","₁","₂","₃","₄","₅","₆","₇","₈","₉"];
            superscript = ["⁰","¹","²","³","⁴","⁵","⁶","⁷","⁸","⁹"];
            tokens = regexp(char(text), '\$_\{(\d+)\}\$', 'tokens');
            matches = regexp(char(text), '\$_\{(\d+)\}\$', 'match');
            for idx = 1:numel(matches)
                digits = char(tokens{idx}{1});
                replacement = "";
                for digit = digits
                    replacement = replacement + subscript(str2double(digit) + 1);
                end
                text = replace(text, string(matches{idx}), replacement);
            end
            tokens = regexp(char(text), '\$\^\{([\d\+\-]+)\}\$', 'tokens');
            matches = regexp(char(text), '\$\^\{([\d\+\-]+)\}\$', 'match');
            for idx = 1:numel(matches)
                chars = char(tokens{idx}{1});
                replacement = "";
                for value = chars
                    if value == '+', replacement = replacement + "⁺";
                    elseif value == '-', replacement = replacement + "⁻";
                    else, replacement = replacement + ...
                            superscript(str2double(value) + 1);
                    end
                end
                text = replace(text, string(matches{idx}), replacement);
            end
        end

        function text = toUnicodeString(obj)
            text = obj.to_unicode_string();
        end
    end

    methods (Static, Access = private)
        function text = formatLatex(input, mode)
            text = string(input);
            text = regexprep(text, '_(\d+)', '$_{$1}$');
            text = regexprep(text, '\^([\d\+\-]+)', '$^{$1}$');
            if mode == "SUBSCRIPT"
                text = regexprep(text, '([A-Za-z\(\)])([\d\+\-\.]+)', ...
                    '$1$_{$2}$');
            elseif mode == "SUPERSCRIPT"
                text = regexprep(text, '([A-Za-z\(\)])([\d\+\-\.]+)', ...
                    '$1$^{$2}$');
            end
        end
    end
end
