classdef LobsterOut < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTEROUT Run-summary parser for lobsterout.
    properties
        basis_functions cell = {}
        basis_type cell = {}
        charge_spilling double = []
        total_spilling double = []
        dft_program = []
        elements cell = {}
        number_of_spins (1,1) double = 1
        number_of_threads double = []
        timing (1,1) struct = struct()
        warning_lines cell = {}
        info_lines cell = {}
        info_orthonormalization cell = {}
        error_lines cell = {}
        is_restart_from_projection (1,1) logical = false
        has_error (1,1) logical = false
        has_charge (1,1) logical = false
        has_cohpcar (1,1) logical = false
        has_coopcar (1,1) logical = false
        has_cobicar (1,1) logical = false
        has_doscar (1,1) logical = false
        has_doscar_lso (1,1) logical = false
        has_projection (1,1) logical = false
        has_bandoverlaps (1,1) logical = false
        has_density_of_energies (1,1) logical = false
        has_fatbands (1,1) logical = false
        has_grosspopulation (1,1) logical = false
        has_madelung (1,1) logical = false
        has_polarization (1,1) logical = false
        has_mofecar (1,1) logical = false
        has_cobicar_lcfo (1,1) logical = false
        has_cohpcar_lcfo (1,1) logical = false
        has_coopcar_lcfo (1,1) logical = false
        has_doscar_lcfo (1,1) logical = false
    end
    methods
        function obj = LobsterOut(varargin)
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(varargin{:});
        end
        function process(obj)
            if ~isfile(obj.filename)
                error("KSSOLV:Matgenlab:Lobster:MissingFile", ...
                    "LOBSTER file '%s' does not exist.", obj.filename);
            end
            linesValue = obj.lines;
            obj.lobster_version = obj.get_lobster_version(linesValue);
            obj.is_restart_from_projection = any(strcmp(linesValue, ...
                "loading projection from projectionData.lobster..."));
            obj.has_error = any(startsWith(string(linesValue), "ERROR:"));
            obj.error_lines = obj.prefixed_lines(linesValue, "ERROR:");
            if obj.has_error
                error("KSSOLV:Matgenlab:Lobster:RunError", ...
                    "LOBSTER calculation ended with errors.");
            end
            text = string(linesValue);
            obj.number_of_spins = 1 + any(text == "spillings for spin channel 2");
            thread = regexp(strjoin(text, newline), ...
                "(?m)^.*?using\s+(\d+)\s+threads?", "tokens", "once");
            if isempty(thread)
                thread = regexp(strjoin(text, newline), ...
                    "(?m)^.*?with\s+(\d+)\s+threads?", "tokens", "once");
            end
            if ~isempty(thread), obj.number_of_threads = str2double(thread{1}); end
            program = regexp(strjoin(text, newline), ...
                "DFT program\.\.\.\s*(\S+)", "tokens", "once");
            if ~isempty(program), obj.dft_program = program{1}; end
            charge = regexp(strjoin(text, newline), ...
                "charge spilling:\s*([+-]?\d+(?:\.\d+)?)%", "tokens");
            total = regexp(strjoin(text, newline), ...
                "total spilling:\s*([+-]?\d+(?:\.\d+)?)%", "tokens");
            obj.charge_spilling = cellfun(@(x) str2double(x{1}) / 100, charge);
            obj.total_spilling = cellfun(@(x) str2double(x{1}) / 100, total);
            obj.warning_lines = obj.prefixed_lines(linesValue, "WARNING:");
            obj.info_lines = obj.prefixed_lines(linesValue, "INFO:");
            obj.info_orthonormalization = {};
            for index = 1:numel(linesValue)
                if contains(linesValue{index}, "orthonormalized")
                    parts = regexp(strtrim(linesValue{index}), "\s+", "split");
                    obj.info_orthonormalization{end + 1} = strjoin(parts(2:end), " ");
                end
            end
            obj.parse_basis(linesValue);
            obj.parse_timing(linesValue);
            obj.has_cohpcar = obj.was_written(text, "COHPCAR.lobster");
            obj.has_coopcar = obj.was_written(text, "COOPCAR.lobster");
            obj.has_cobicar = obj.was_written(text, "COBICAR.lobster");
            obj.has_doscar = obj.was_written(text, "DOSCAR.lobster");
            obj.has_doscar_lso = obj.was_written(text, "DOSCAR.LSO.lobster");
            obj.has_cobicar_lcfo = any(contains(text, "writing COBICAR.LCFO.lobster"));
            obj.has_cohpcar_lcfo = any(contains(text, "writing COHPCAR.LCFO.lobster"));
            obj.has_coopcar_lcfo = any(contains(text, "writing COOPCAR.LCFO.lobster"));
            obj.has_doscar_lcfo = any(contains(text, "writing DOSCAR.LCFO.lobster"));
            obj.has_polarization = any(contains(text, "POLARIZATION.lobster"));
            obj.has_charge = ~any(contains(text, "SKIPPING writing CHARGE.lobster"));
            obj.has_projection = any(contains(text, ...
                "saving projection to projectionData.lobster"));
            obj.has_bandoverlaps = any(contains(text, "bandOverlaps.lobster"));
            obj.has_fatbands = any(contains(text, "FatBand"));
            obj.has_grosspopulation = any(contains(text, "GROSSPOP.lobster"));
            obj.has_density_of_energies = any(contains(text, "DensityOfEnergy.lobster"));
            obj.has_madelung = any(contains(text, "MadelungEnergies.lobster")) && ...
                ~any(contains(lower(text), "skipping writing sitepotentials"));
            obj.has_mofecar = any(contains(text, "MOFECAR.lobster"));
        end
        function version = get_lobster_version(~, linesValue)
            token = regexp(strjoin(string(linesValue), newline), ...
                "(?i)LOBSTER\s+v(\d+\.\d+\.\d+)", "tokens", "once");
            if isempty(token), version = "5.1.1"; else, version = string(token{1}); end
        end
        function name = get_default_filename(~), name = "lobsterout"; end
    end
    methods (Access = private)
        function parse_basis(obj, linesValue)
            begin = false;
            for index = 1:numel(linesValue)
                line = strtrim(linesValue{index});
                if contains(line, "setting up local basis functions")
                    begin = true;
                    continue
                end
                if ~begin || isempty(line), continue; end
                parts = regexp(line, "\s+", "split");
                stop = ["INFO:", "WARNING:", "setting", "calculating", ...
                    "post-processing", "saving", "spillings", "writing"];
                if any(string(parts{1}) == stop), break; end
                if numel(parts) >= 3
                    obj.elements{end + 1} = parts{1};
                    obj.basis_type{end + 1} = erase(erase(parts{2}, "("), ")");
                    obj.basis_functions{end + 1} = parts(3:end);
                end
            end
        end
        function parse_timing(obj, linesValue)
            names = ["wall_time", "user_time", "sys_time"];
            needles = ["wall", "user", "sys"];
            result = struct();
            for item = 1:numel(names)
                result.(names(item)) = struct();
                for index = 1:numel(linesValue)
                    if contains(linesValue{index}, needles(item))
                        token = regexp(linesValue{index}, ...
                            "(\d+)\s*h\s+(\d+)\s*min\s+(\d+)\s*s\s+(\d+)\s*ms", ...
                            "tokens", "once");
                        if ~isempty(token)
                            result.(names(item)) = struct("h", token{1}, ...
                                "min", token{2}, "s", token{3}, "ms", token{4});
                        end
                    end
                end
            end
            obj.timing = result;
        end
    end
    methods (Static, Access = private)
        function values = prefixed_lines(linesValue, prefix)
            values = {};
            for index = 1:numel(linesValue)
                if startsWith(strtrim(linesValue{index}), prefix)
                    values{end + 1} = strtrim(extractAfter(linesValue{index}, prefix));
                end
            end
        end
        function value = was_written(linesValue, filename)
            value = any(contains(linesValue, "writing " + filename)) && ...
                ~any(contains(linesValue, "SKIPPING writing " + filename));
        end
    end
end
