classdef LobsterMatrices < kssolv.analysis.matgenlab.io.lobster.future.LobsterFile
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERMATRICES Complex Hamilton, overlap and transfer matrix reader.
    properties (Dependent)
        efermi
    end
    methods
        function obj = LobsterMatrices(filename, matrix_type, efermi, ...
                process_immediately, lobster_version)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "hamiltonMatrices.lobster"; end
            if nargin < 2, matrix_type = []; end
            if nargin < 3, efermi = []; end
            if nargin < 4 || isempty(process_immediately), process_immediately = true; end
            if nargin < 5, lobster_version = []; end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false, lobster_version}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile( ...
                constructorArguments{:});
            if blank, return; end
            obj.efermi_value = efermi;
            if isempty(matrix_type), obj.matrix_type = obj.get_matrix_type();
            else, obj.matrix_type = string(matrix_type); end
            if obj.matrix_type == "hamilton" && isempty(efermi)
                error("KSSOLV:Matgenlab:Lobster:MatrixFermi", ...
                    "Hamilton matrices require the Fermi energy.");
            end
            if process_immediately, obj.parse_file(); end
        end
        function value = get.efermi(obj), value = obj.efermi_value; end
        function set.efermi(obj, value), obj.efermi_value = value; end
        function value = get_matrix_type(obj)
            name = lower(obj.filename);
            types = ["hamilton", "coefficient", "transfer", "overlap"];
            index = find(contains(name, types), 1);
            if isempty(index)
                error("KSSOLV:Matgenlab:Lobster:MatrixType", ...
                    "Cannot infer matrix type from '%s'.", obj.filename);
            end
            value = types(index);
        end
        function parse_file(obj)
            linesValue = obj.iterate_lines();
            obj.centers = {};
            obj.orbitals = {};
            obj.matrices = struct();
            currentKpoint = "";
            currentSpin = "none";
            multiplier = 1;
            index = 1;
            while index <= numel(linesValue)
                line = linesValue{index};
                if obj.matrix_type == "overlap"
                    token = regexp(line, "kpoint\s+(\d+)", "tokens", "once");
                else
                    token = regexp(line, "(\d+)\s+kpoint\s+(\d+)", ...
                        "tokens", "once");
                end
                if ~isempty(token)
                    currentKpoint = "k" + string(token{end});
                    if obj.matrix_type ~= "overlap"
                        if str2double(token{1}) == 1, currentSpin = "up";
                        else, currentSpin = "down"; end
                    end
                elseif contains(lower(line), "real parts")
                    multiplier = 1;
                elseif contains(lower(line), "imag parts")
                    multiplier = 1i;
                elseif startsWith(lower(line), "basisfunction")
                    columns = regexp(line, "\s+", "split");
                    columns = columns(~cellfun(@isempty, columns));
                    count = numel(columns) - 1;
                    values = zeros(count);
                    localCenters = cell(1, count);
                    localOrbitals = cell(1, count);
                    for row = 1:count
                        index = index + 1;
                        parts = regexp(strtrim(linesValue{index}), "\s+", "split");
                        values(row, :) = str2double(parts(2:end)) * multiplier;
                        centerToken = regexp(parts{1}, "^([^_]+)", "tokens", "once");
                        raw = centerToken{1};
                        localCenters{row} = [upper(raw(1)), lower(raw(2:end))];
                        localOrbitals{row} = char( ...
                            kssolv.analysis.matgenlab.io.lobster.future.utils. ...
                            parse_orbital_from_text(parts{1}));
                    end
                    if isempty(obj.centers)
                        obj.centers = localCenters;
                        obj.orbitals = localOrbitals;
                    end
                    if ~isfield(obj.matrices, currentKpoint)
                        obj.matrices.(currentKpoint) = struct();
                    end
                    if ~isfield(obj.matrices.(currentKpoint), currentSpin)
                        obj.matrices.(currentKpoint).(currentSpin) = zeros(count);
                    end
                    obj.matrices.(currentKpoint).(currentSpin) = ...
                        obj.matrices.(currentKpoint).(currentSpin) + values;
                end
                index = index + 1;
            end
        end
        function result = get_onsite_values(obj, center, orbital)
            if nargin < 2, center = []; end
            if nargin < 3, orbital = []; end
            result = struct();
            shift = 0;
            if obj.matrix_type == "hamilton", shift = obj.efermi; end
            kpoints = fieldnames(obj.matrices);
            for index = 1:numel(obj.centers)
                if ~isempty(center) && string(obj.centers{index}) ~= string(center)
                    continue
                end
                if ~isempty(orbital) && string(obj.orbitals{index}) ~= string(orbital)
                    continue
                end
                values = [];
                for kpoint = 1:numel(kpoints)
                    spins = fieldnames(obj.matrices.(kpoints{kpoint}));
                    for spin = 1:numel(spins)
                        matrix = obj.matrices.(kpoints{kpoint}).(spins{spin});
                        values(end + 1) = real(matrix(index, index)) - shift;
                    end
                end
                average = mean(values);
                if ~isempty(center) && ~isempty(orbital)
                    result = average;
                    return
                end
                name = matlab.lang.makeValidName( ...
                    string(obj.centers{index}) + "_" + string(obj.orbitals{index}));
                result.(name) = average;
            end
        end
        function value = as_dict(obj)
            value = as_dict@kssolv.analysis.matgenlab.io.lobster.future.LobsterFile(obj);
            kpoints = fieldnames(value.matrices);
            for kpoint = 1:numel(kpoints)
                spins = fieldnames(value.matrices.(kpoints{kpoint}));
                for spin = 1:numel(spins)
                    matrix = value.matrices.(kpoints{kpoint}).(spins{spin});
                    value.matrices.(kpoints{kpoint}).(spins{spin}) = ...
                        struct("real", real(matrix), "imag", imag(matrix));
                end
            end
        end
        function name = get_default_filename(~), name = "hamiltonMatrices.lobster"; end
    end
    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.lobster.future.LobsterFile. ...
                from_dict(value, "LobsterMatrices");
            kpoints = fieldnames(obj.matrices);
            for kpoint = 1:numel(kpoints)
                spins = fieldnames(obj.matrices.(kpoints{kpoint}));
                for spin = 1:numel(spins)
                    matrix = obj.matrices.(kpoints{kpoint}).(spins{spin});
                    if isstruct(matrix) && isfield(matrix, "real")
                        obj.matrices.(kpoints{kpoint}).(spins{spin}) = ...
                            matrix.real + 1i * matrix.imag;
                    end
                end
            end
        end
    end
end
