classdef POLARIZATION < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %POLARIZATION Relative Mulliken and Loewdin polarization reader.
    methods
        function obj = POLARIZATION(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file(obj)
            obj.rel_mulliken_pol_vector = struct();
            obj.rel_loewdin_pol_vector = struct();
            linesValue = obj.iterate_lines();
            for index = 4:numel(linesValue)
                parts = regexp(strtrim(linesValue{index}), "\s+", "split");
                if numel(parts) == 3
                    name = matlab.lang.makeValidName(parts{1});
                    obj.rel_mulliken_pol_vector.(name) = str2double(parts{2});
                    obj.rel_loewdin_pol_vector.(name) = str2double(parts{3});
                elseif numel(parts) == 4
                    first = matlab.lang.makeValidName(erase(parts{1}, ":"));
                    second = matlab.lang.makeValidName(erase(parts{3}, ":"));
                    obj.rel_mulliken_pol_vector.(first) = strrep(parts{2}, "μ", "u");
                    obj.rel_loewdin_pol_vector.(second) = strrep(parts{4}, "μ", "u");
                end
            end
        end
        function name = get_default_filename(~), name = "POLARIZATION.lobster"; end
    end
end
