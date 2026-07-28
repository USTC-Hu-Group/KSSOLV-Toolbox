classdef Oszicar
    %OSZICAR Parser for VASP electronic and ionic energy summaries.
    properties (SetAccess = private)
        electronic_steps cell = cell(0,1)
        ionic_steps struct = struct([])
    end
    properties (Dependent, SetAccess = private)
        all_energies
        final_energy
    end
    methods
        function obj = Oszicar(filename)
            if nargin == 0, return; end
            lines = splitlines(string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename)));
            header = strings(1,0);
            electronic = cell(0,1);
            ionic = struct([]);
            for line = lines.'
                trimmed = strtrim(line);
                if trimmed == "", continue; end
                if ~isempty(regexp(trimmed, '^\s*N\s+E\s*', "once"))
                    header = split(strrep(trimmed, "d eps", "deps")).';
                    continue
                end
                match = regexp(trimmed, '^\w+\s*:\s*(.*)$', ...
                    "tokens", "once");
                if ~isempty(match)
                    tokens = split(strtrim(match{1})).';
                    step = struct();
                    for index = 1:min(numel(tokens),numel(header))
                        value = str2double(tokens(index));
                        if isnan(value), value = "--"; end
                        step.(matlab.lang.makeValidName(header(index))) = value;
                    end
                    if str2double(tokens(1)) == 1
                        electronic{end + 1,1} = {step}; %#ok<AGROW>
                    else
                        electronic{end}{end + 1} = step;
                    end
                    continue
                end
                normalized = regexprep(line, 'd E ', 'dE');
                pairs = regexp(normalized, ...
                    '(\w+)=\s*(\S+)', "tokens");
                if ~isempty(pairs)
                    step = struct();
                    for index = 1:numel(pairs)
                        step.(pairs{index}{1}) = ...
                            str2double(pairs{index}{2});
                    end
                    if isempty(ionic), ionic = step;
                    else, ionic(end + 1) = step; %#ok<AGROW>
                    end
                end
            end
            obj.electronic_steps = electronic;
            obj.ionic_steps = ionic;
        end
        function value = get.all_energies(obj)
            value = cell(numel(obj.electronic_steps),1);
            for ionicIndex = 1:numel(value)
                steps = obj.electronic_steps{ionicIndex};
                energies = cellfun(@(step)step.E, steps);
                value{ionicIndex} = [energies, ...
                    obj.ionic_steps(ionicIndex).F];
            end
        end
        function value = get.final_energy(obj)
            if isempty(obj.ionic_steps)
                error("KSSOLV:Matgenlab:Oszicar:MissingIonicStep", ...
                    "OSZICAR contains no ionic energy summary.");
            end
            value = obj.ionic_steps(end).E0;
        end
        function value = as_dict(obj)
            value = struct("electronic_steps", {obj.electronic_steps}, ...
                "ionic_steps", obj.ionic_steps);
        end
    end
end
