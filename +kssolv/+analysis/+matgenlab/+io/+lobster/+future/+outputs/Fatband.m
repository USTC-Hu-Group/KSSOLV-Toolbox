classdef Fatband < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %FATBAND Parser for one orbital-resolved FATBAND file.
    properties
        center (1,1) string = ""
        orbital (1,1) string = ""
        nbands (1,1) double = 0
    end
    methods
        function obj = Fatband(filename, process_immediately, lobster_version)
            if nargin == 0
                filename = [];
            end
            if nargin < 2 || isempty(process_immediately), process_immediately = true; end
            if nargin < 3, lobster_version = []; end
            if isempty(filename), constructorArguments = {};
            else, constructorArguments = {filename, false, lobster_version}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile( ...
                constructorArguments{:});
            if isempty(filename), return; end
            name = string(java.io.File(char(string(filename))).getName());
            pieces = split(name, "_");
            rawCenter = char(pieces(2));
            obj.center = string([upper(rawCenter(1)), lower(rawCenter(2:end))]);
            value = kssolv.analysis.matgenlab.io.lobster.future.utils. ...
                parse_orbital_from_text(name);
            if isempty(value)
                error("KSSOLV:Matgenlab:Lobster:FatbandName", ...
                    "Cannot parse orbital from '%s'.", name);
            end
            obj.orbital = value;
            if process_immediately, obj.parse_file(); end
        end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            values = regexp(linesValue{1}, "(\d+)\s*$", "tokens", "once");
            obj.nbands = str2double(values{1});
            energy = struct("up", {{}});
            projection = struct("up", {{}});
            obj.spins = {"up"};
            current = "up";
            kpoint = 0;
            band = 0;
            for index = 2:numel(linesValue)
                line = linesValue{index};
                if startsWith(line, "#")
                    current = "up";
                    kpoint = kpoint + 1;
                    band = 0;
                    energy.up{kpoint} = [];
                    projection.up{kpoint} = [];
                    continue
                end
                if band == obj.nbands
                    current = "down";
                    band = 0;
                    if ~isfield(energy, "down")
                        obj.spins{end + 1} = "down";
                        energy.down = {};
                        projection.down = {};
                    end
                    energy.down{kpoint} = [];
                    projection.down{kpoint} = [];
                end
                numbers = sscanf(line, "%f").';
                if numel(numbers) >= 3
                    band = band + 1;
                    energy.(current){kpoint}(end + 1) = numbers(2);
                    projection.(current){kpoint}(end + 1) = numbers(end);
                end
            end
            obj.fatband = struct("center", obj.center, ...
                "orbital", obj.orbital, "energies", energy, ...
                "projections", projection);
            obj.convert_to_numpy_arrays();
        end
        function convert_to_numpy_arrays(obj)
            for spin = string(obj.spins)
                if iscell(obj.fatband.energies.(spin))
                    obj.fatband.energies.(spin) = ...
                        vertcat(obj.fatband.energies.(spin){:});
                    obj.fatband.projections.(spin) = ...
                        vertcat(obj.fatband.projections.(spin){:});
                end
            end
        end
        function name = get_default_filename(~), name = "FATBAND_*.lobster"; end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value, "Fatband");
            obj.convert_to_numpy_arrays();
        end
    end
end
