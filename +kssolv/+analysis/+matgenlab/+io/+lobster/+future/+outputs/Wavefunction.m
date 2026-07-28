classdef Wavefunction < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %WAVEFUNCTION LOBSTER real-space wave-function reader.
    methods
        function obj = Wavefunction(filename, structure, process_immediately, lobster_version)
            blank = nargin == 0;
            if blank, filename = []; structure = []; end
            if nargin < 3 || isempty(process_immediately), process_immediately = true; end
            if nargin < 4, lobster_version = []; end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false, lobster_version}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile( ...
                constructorArguments{:});
            if blank, return; end
            obj.structure = structure;
            if process_immediately, obj.parse_file(); end
        end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            parts = regexp(linesValue{1}, "\s+", "split");
            parts = parts(~cellfun(@isempty, parts));
            obj.grid = str2double(parts(8:10));
            count = prod(obj.grid);
            table = zeros(count, 6);
            row = 0;
            for index = 2:numel(linesValue)
                values = sscanf(linesValue{index}, "%f").';
                if numel(values) >= 6
                    row = row + 1;
                    if row > count
                        error("KSSOLV:Matgenlab:Lobster:Wavefunction", ...
                            "Wave-function file contains too many grid points.");
                    end
                    table(row, :) = values(1:6);
                end
            end
            if row ~= count
                error("KSSOLV:Matgenlab:Lobster:Wavefunction", ...
                    "Wave-function grid is incomplete.");
            end
            obj.points = table(:, 1:3);
            obj.distances = table(:, 4);
            obj.reals = table(:, 5);
            obj.imaginaries = table(:, 6);
        end
        function set_volumetric_data(obj, grid, structure)
            dimensions = grid - 1;
            keep = true(prod(grid), 1);
            linear = 0;
            for x = 0:grid(1)-1
                for y = 0:grid(2)-1
                    for z = 0:grid(3)-1
                        linear = linear + 1;
                        if x == grid(1)-1 || y == grid(2)-1 || z == grid(3)-1
                            keep(linear) = false;
                        end
                    end
                end
            end
            realValues = obj.reals(keep);
            imaginaryValues = obj.imaginaries(keep);
            obj.final_real = permute(reshape(realValues, ...
                dimensions(3), dimensions(2), dimensions(1)), [3, 2, 1]);
            obj.final_imaginary = permute(reshape(imaginaryValues, ...
                dimensions(3), dimensions(2), dimensions(1)), [3, 2, 1]);
            obj.final_density = obj.final_real .^ 2 + obj.final_imaginary .^ 2;
            Volume = @kssolv.analysis.matgenlab.io.vasp.VolumetricData;
            obj.volumetricdata_real = Volume(structure, ...
                struct("total", obj.final_real));
            obj.volumetricdata_imaginary = Volume(structure, ...
                struct("total", obj.final_imaginary));
            obj.volumetricdata_density = Volume(structure, ...
                struct("total", obj.final_density));
        end
        function value = get_volumetricdata_real(obj)
            if isempty(obj.volumetricdata_real)
                obj.set_volumetric_data(obj.grid, obj.structure);
            end
            value = obj.volumetricdata_real;
        end
        function value = get_volumetricdata_imaginary(obj)
            if isempty(obj.volumetricdata_imaginary)
                obj.set_volumetric_data(obj.grid, obj.structure);
            end
            value = obj.volumetricdata_imaginary;
        end
        function value = get_volumetricdata_density(obj)
            if isempty(obj.volumetricdata_density)
                obj.set_volumetric_data(obj.grid, obj.structure);
            end
            value = obj.volumetricdata_density;
        end
        function write_file(obj, filename, part)
            if nargin < 2 || isempty(filename), filename = "WAVECAR.vasp"; end
            if nargin < 3 || isempty(part), part = "real"; end
            switch lower(string(part))
                case "real", value = obj.get_volumetricdata_real();
                case "imaginary", value = obj.get_volumetricdata_imaginary();
                case "density", value = obj.get_volumetricdata_density();
                otherwise
                    error("KSSOLV:Matgenlab:Lobster:WavefunctionPart", ...
                        "part must be real, imaginary, or density.");
            end
            value.write_file(filename);
        end
        function name = get_default_filename(~), name = "wavefunction.lobster"; end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value, "Wavefunction");
        end
    end
end
