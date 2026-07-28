classdef FiestaIOUtils
    %FIESTAIOUTILS Pure-MATLAB text and executor boundaries for FIESTA.

    methods (Static)
        function value = read_text(filename)
            filename = string(filename);
            extension = lower(kssolv.analysis.matgenlab.io.fiesta. ...
                FiestaIOUtils.extension(filename));
            if extension == ".gz"
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                files = gunzip(filename, folder);
                value = string(fileread(files{1}));
                clear cleanup
            elseif any(extension == [".bz2", ".xz", ".lzma", ".z"])
                error("KSSOLV:Matgenlab:Fiesta:CompressionUnsupported", ...
                    "Compression '%s' has no pure-MATLAB codec. " + ...
                    "Decompress the file explicitly before reading it.", ...
                    extension);
            else
                value = string(fileread(filename));
            end
        end

        function write_text(filename, text)
            filename = string(filename);
            extension = lower(kssolv.analysis.matgenlab.io.fiesta. ...
                FiestaIOUtils.extension(filename));
            if extension == ".gz"
                folder = string(tempname);
                mkdir(folder);
                cleanup = onCleanup(@() rmdir(folder, "s"));
                [~, base] = fileparts(filename);
                temporary = fullfile(folder, base);
                kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                    write_plain(temporary, text);
                generated = gzip(temporary, folder);
                movefile(generated{1}, filename, "f");
                clear cleanup
            elseif any(extension == [".bz2", ".xz", ".lzma", ".z"])
                error("KSSOLV:Matgenlab:Fiesta:CompressionUnsupported", ...
                    "Compression '%s' has no pure-MATLAB codec. " + ...
                    "Write an uncompressed or gzip file instead.", extension);
            else
                kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                    write_plain(filename, text);
            end
        end

        function output = invoke(executor, program, commandArguments, folder)
            if isempty(executor) || ~isa(executor, "function_handle")
                error("KSSOLV:Matgenlab:Fiesta:ExecutorRequired", ...
                    "Running '%s' requires an explicit MATLAB executor " + ...
                    "callback: executor(program, arguments, folder).", ...
                    program);
            end
            result = executor(string(program), ...
                reshape(string(commandArguments), 1, []), string(folder));
            status = 0;
            if isstruct(result)
                if ~isfield(result, "stdout")
                    error("KSSOLV:Matgenlab:Fiesta:ExecutorResult", ...
                        "Executor structs must contain a stdout field.");
                end
                output = string(result.stdout);
                if isfield(result, "status"), status = double(result.status); end
            elseif ischar(result) || (isstring(result) && isscalar(result))
                output = string(result);
            else
                error("KSSOLV:Matgenlab:Fiesta:ExecutorResult", ...
                    "Executor must return text or a struct with stdout/status.");
            end
            if ~isscalar(status) || ~isfinite(status) || status ~= 0
                error("KSSOLV:Matgenlab:Fiesta:ExecutorFailed", ...
                    "Executor for '%s' returned status %s.", ...
                    program, string(status));
            end
        end

        function value = python_float(input)
            input = double(input);
            if isnan(input)
                value = "nan";
                return
            elseif isinf(input)
                if input < 0, value = "-inf"; else, value = "inf"; end
                return
            end
            javaText = string(javaMethod( ...
                "toString", "java.lang.Double", input));
            match = regexp(javaText, ...
                '^([+-]?)(\d(?:\.\d+)?)[Ee]([+-]?\d+)$', ...
                "tokens", "once");
            if isempty(match)
                value = javaText;
                return
            end
            signText = string(match{1});
            parts = split(string(match{2}), ".");
            fraction = "";
            if numel(parts) > 1, fraction = parts(2); end
            if fraction == "0", fraction = ""; end
            digits = parts(1) + fraction;
            exponent = str2double(match{3});
            if exponent >= -4 && exponent < 16
                position = 1 + exponent;
                if position <= 0
                    value = signText + "0." + ...
                        string(repmat('0', 1, -position)) + digits;
                elseif position >= strlength(digits)
                    value = signText + digits + ...
                        string(repmat('0', 1, ...
                        position - strlength(digits))) + ".0";
                else
                    value = signText + extractBefore(digits, ...
                        position + 1) + "." + ...
                        extractAfter(digits, position);
                end
            else
                mantissa = erase(string(match{2}), ...
                    regexpPattern('\.0$'));
                exponentSign = "+";
                if exponent < 0, exponentSign = "-"; end
                value = signText + mantissa + "e" + exponentSign + ...
                    compose("%02d", abs(exponent));
            end
        end

        function value = absolute_path(folder, filename)
            filename = string(filename);
            if ispc
                absolute = ~isempty(regexp(filename, ...
                    '^[A-Za-z]:[\\/]|^\\\\', "once"));
            else
                absolute = startsWith(filename, "/");
            end
            if absolute, value = filename; else, value = fullfile(folder, filename); end
        end
    end

    methods (Static, Access = private)
        function value = extension(path)
            [~, ~, value] = fileparts(path);
            value = string(value);
        end

        function write_plain(path, content)
            [identifier, message] = fopen(path, "w", "n", "UTF-8");
            if identifier < 0
                error("KSSOLV:Matgenlab:Fiesta:Write", "%s", message);
            end
            cleanup = onCleanup(@() fclose(identifier));
            fwrite(identifier, char(string(content)), "char");
            clear cleanup
        end
    end
end
