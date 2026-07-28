classdef CHARGE < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %CHARGE Mulliken and Loewdin charge reader.
    properties
        is_lcfo (1,1) logical = false
    end
    methods
        function obj = CHARGE(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file(obj)
            obj.centers = {};
            obj.mulliken = [];
            obj.loewdin = [];
            linesValue = obj.iterate_lines();
            for index = 1:numel(linesValue)
                token = regexp(strtrim(linesValue{index}), "\s+", "split");
                if numel(token) < 3 || isnan(str2double(token{1})) || ...
                        isempty(regexp(token{2}, "^[A-Za-z]+$", "once"))
                    continue
                end
                obj.centers{end + 1} = [token{2}, token{1}];
                if obj.is_lcfo
                    obj.loewdin(end + 1) = str2double(token{3});
                else
                    if numel(token) < 4, continue; end
                    obj.mulliken(end + 1) = str2double(token{3});
                    obj.loewdin(end + 1) = str2double(token{4});
                end
            end
        end
        function name = get_default_filename(obj)
            if obj.is_lcfo, name = "CHARGE.LCFO.lobster";
            else, name = "CHARGE.lobster"; end
        end
    end
end
