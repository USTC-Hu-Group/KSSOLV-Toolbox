classdef GROSSPOP < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %GROSSPOP Mulliken and Loewdin orbital-population reader.
    properties
        is_lcfo (1,1) logical = false
    end
    methods
        function obj = GROSSPOP(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file(obj)
            obj.populations = struct();
            obj.spins = {"up"};
            linesValue = obj.iterate_lines();
            header = linesValue{find(contains(lower(string(linesValue)), ...
                "basisfunction"), 1)};
            spinPolarized = numel(regexp(header, "(?i)Mulliken GP", "match")) > 1;
            if spinPolarized, obj.spins{end + 1} = "down"; end
            current = "";
            for index = 1:numel(linesValue)
                token = regexp(strtrim(linesValue{index}), "\s+", "split");
                if numel(token) < 3, continue; end
                if ~isnan(str2double(token{1}))
                    if numel(token) < 5, continue; end
                    current = string(token{2}) + string(token{1});
                    obj.populations.(matlab.lang.makeValidName(current)) = struct();
                    orbitalName = token{3};
                    numbers = str2double(token(4:end));
                else
                    orbitalName = token{1};
                    numbers = str2double(token(2:end));
                end
                if strcmpi(orbitalName, "total") || any(isnan(numbers)), continue; end
                value = struct("up", struct());
                if spinPolarized
                    value.up.mulliken = numbers(1);
                    value.down = struct("mulliken", numbers(2));
                    if numel(numbers) >= 4
                        value.up.loewdin = numbers(3);
                        value.down.loewdin = numbers(4);
                    end
                else
                    value.up.mulliken = numbers(1);
                    if numel(numbers) >= 2, value.up.loewdin = numbers(2); end
                end
                atom = matlab.lang.makeValidName(current);
                orbital = matlab.lang.makeValidName(orbitalName);
                obj.populations.(atom).(orbital) = value;
            end
        end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "GROSSPOP.LCFO.lobster";
            else, name = "GROSSPOP.lobster"; end
        end
    end
end
