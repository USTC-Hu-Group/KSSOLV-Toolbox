classdef BWDF < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %BWDF Bond-weighted distribution-function reader.
    methods
        function obj = BWDF(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            rows = {};
            for index = 2:numel(linesValue)
                values = sscanf(linesValue{index}, "%f").';
                if ~isempty(values), rows{end + 1} = values; end
            end
            obj.data = vertcat(rows{:});
            if size(obj.data, 1) > 1
                obj.bin_width = mean(diff(obj.data(:, 1)));
            end
            obj.process_data_into_bwdf_centers();
        end
        function process_data_into_bwdf_centers(obj)
            obj.centers = num2cell(obj.data(:, 1).');
            obj.bwdf = struct("up", obj.data(:, 2));
            obj.spins = {"up"};
            if size(obj.data, 2) > 2
                obj.bwdf.down = obj.data(:, 3);
                obj.spins{end + 1} = "down";
            end
        end
        function name = get_default_filename(~), name = "BWDF.lobster"; end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value, "BWDF");
            obj.process_data_into_bwdf_centers();
        end
    end
end
