classdef Xdatcar < handle
    %XDATCAR Reader and writer for VASP molecular-dynamics trajectories.
    properties
        structures cell = cell(1,0)
        comment (1,1) string = ""
    end
    properties (Dependent, SetAccess = private)
        site_symbols
        natoms
    end
    methods
        function obj = Xdatcar(filename, ionicstep_start, ...
                ionicstep_end, comment)
            if nargin == 0, return; end
            if nargin < 2 || isempty(ionicstep_start), ionicstep_start = 1; end
            if nargin < 3, ionicstep_end = []; end
            if nargin < 4, comment = ""; end
            obj.structures = obj.parseStructures(filename, ...
                ionicstep_start,ionicstep_end);
            if isempty(obj.structures)
                error("KSSOLV:Matgenlab:Xdatcar:Empty", ...
                    "XDATCAR selection contains no structures.");
            end
            if string(comment) == ""
                obj.comment = obj.structures{1}.formula;
            else
                obj.comment = string(comment);
            end
        end
        function value = get.site_symbols(obj)
            symbols = strings(1,obj.structures{1}.num_sites);
            for index = 1:numel(symbols)
                symbols(index) = ...
                    obj.structures{1}(index).specie.symbol;
            end
            value = symbols([true,symbols(2:end) ~= symbols(1:end-1)]);
        end
        function value = get.natoms(obj)
            symbols = strings(1,obj.structures{1}.num_sites);
            for index = 1:numel(symbols)
                symbols(index) = ...
                    obj.structures{1}(index).specie.symbol;
            end
            starts = find([true,symbols(2:end) ~= symbols(1:end-1)]);
            value = diff([starts,numel(symbols)+1]);
        end
        function obj = concatenate(obj, filename, ionicstep_start, ...
                ionicstep_end)
            if nargin < 3 || isempty(ionicstep_start), ionicstep_start = 1; end
            if nargin < 4, ionicstep_end = []; end
            more = obj.parseStructures(filename,ionicstep_start, ...
                ionicstep_end);
            obj.structures = [obj.structures,more];
        end
        function text = get_str(obj, ionicstep_start, ...
                ionicstep_end, significant_figures)
            if nargin < 2 || isempty(ionicstep_start), ionicstep_start = 1; end
            if nargin < 3, ionicstep_end = []; end
            if nargin < 4, significant_figures = 8; end
            obj.validateRange(ionicstep_start,ionicstep_end);
            lattice = obj.structures{1}.lattice.matrix;
            if det(lattice) < 0, lattice = -lattice; end
            lines = strings(0,1);
            lines(end + 1) = obj.comment;
            lines(end + 1) = "1.0";
            for row = 1:3
                lines(end + 1) = sprintf( ...
                    "%16.10f %16.10f %16.10f", ...
                    lattice(row,:)); %#ok<AGROW>
            end
            lines(end + 1) = strjoin(obj.site_symbols," ");
            lines(end + 1) = strjoin(string(obj.natoms)," ");
            outputIndex = 1;
            last = numel(obj.structures) + 1;
            if ~isempty(ionicstep_end), last = min(last,ionicstep_end); end
            format = "%." + string(significant_figures) + "f";
            for frame = ionicstep_start:last-1
                lines(end + 1) = sprintf( ...
                    "Direct configuration=%8d", ...
                    outputIndex); %#ok<AGROW>
                coordinates = obj.structures{frame}.frac_coords;
                for site = 1:size(coordinates,1)
                    rendered = compose(format,coordinates(site,:));
                    lines(end + 1) = strjoin(rendered," "); %#ok<AGROW>
                end
                outputIndex = outputIndex + 1;
            end
            text = strjoin(lines,newline) + newline;
        end
        function write_file(obj, filename, varargin)
            text = obj.get_str(varargin{:});
            kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                writeText(filename,text);
        end
        function value = length(obj), value = numel(obj.structures); end
    end
    methods (Static, Access = private)
        function structures = parseStructures(filename,startIndex,endIndex)
            kssolv.analysis.matgenlab.io.vasp.Xdatcar. ...
                validateRange(startIndex,endIndex);
            lines = splitlines(string( ...
                kssolv.analysis.matgenlab.io.vasp.VaspIOUtils. ...
                readText(filename)));
            structures = cell(1,0);
            if ~any(contains(lines,"Direct configuration="))
                nonempty = lines(strlength(strtrim(lines)) > 0);
                countLine = 0;
                numberSites = 0;
                for index = 6:numel(nonempty)
                    if ~isempty(regexp(strtrim(nonempty(index)), ...
                            '^\d+(?:\s+\d+)*$',"once"))
                        countLine = index;
                        numberSites = sum(sscanf(nonempty(index),"%d"));
                        break
                    end
                end
                if countLine == 0 || numberSites < 1
                    error("KSSOLV:Matgenlab:Xdatcar:Counts", ...
                        "Could not determine the XDATCAR site count.");
                end
                header = nonempty(1:countLine);
                payload = nonempty(countLine+1:end);
                frameCount = floor(numel(payload)/numberSites);
                for frameIndex = 1:frameCount
                    first = (frameIndex-1)*numberSites+1;
                    coordinates = payload(first:first+numberSites-1);
                    coordinates = regexprep(coordinates, ...
                        '(?<=[0-9])-(?=[0-9])',' -');
                    parsed = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                        from_str(strjoin([header;"Direct";coordinates], ...
                        newline),read_velocities=false);
                    if frameIndex >= startIndex && ...
                            (isempty(endIndex) || frameIndex < endIndex)
                        structures{end + 1} = ...
                            parsed.structure; %#ok<AGROW>
                    end
                end
                return
            end
            pointer = 1;
            cachedHeader = strings(0,1);
            frame = 0;
            while pointer <= numel(lines)
                relative = find(contains(lines(pointer:end), ...
                    "Direct configuration="),1);
                if isempty(relative), break; end
                configLine = pointer + relative - 1;
                candidate = lines(pointer:configLine-1);
                candidate = candidate(strlength(strtrim(candidate)) > 0);
                if ~isempty(candidate), cachedHeader = candidate; end
                if isempty(cachedHeader)
                    error("KSSOLV:Matgenlab:Xdatcar:Preamble", ...
                        "XDATCAR configuration has no POSCAR preamble.");
                end
                countLine = 0;
                numberSites = 0;
                for index = 1:numel(cachedHeader)
                    if ~isempty(regexp(strtrim(cachedHeader(index)), ...
                            '^\d+(?:\s+\d+)*$',"once"))
                        countLine = index;
                        numberSites = sum(sscanf( ...
                            cachedHeader(index),"%d"));
                    end
                end
                if countLine == 0 || numberSites < 1
                    error("KSSOLV:Matgenlab:Xdatcar:Counts", ...
                        "Could not determine the XDATCAR site count.");
                end
                firstCoord = configLine + 1;
                lastCoord = firstCoord + numberSites - 1;
                if lastCoord > numel(lines)
                    error("KSSOLV:Matgenlab:Xdatcar:Truncated", ...
                        "XDATCAR ends inside a coordinate block.");
                end
                coordinates = lines(firstCoord:lastCoord);
                coordinates = regexprep(coordinates, ...
                    '(?<=[0-9])-(?=[0-9])',' -');
                parsed = [];
                for headerStart = 1:max(1,countLine-5)
                    header = cachedHeader(headerStart:countLine);
                    try
                        parsed = kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                            from_str(strjoin([header;"Direct";coordinates], ...
                            newline),read_velocities=false);
                        cachedHeader = header;
                        break
                    catch
                    end
                end
                if isempty(parsed)
                    error("KSSOLV:Matgenlab:Xdatcar:Poscar", ...
                        "Could not parse an XDATCAR configuration.");
                end
                frame = frame + 1;
                if frame >= startIndex && ...
                        (isempty(endIndex) || frame < endIndex)
                    structures{end + 1} = parsed.structure; %#ok<AGROW>
                end
                if ~isempty(endIndex) && frame >= endIndex, break; end
                pointer = lastCoord + 1;
            end
        end
        function validateRange(startIndex,endIndex)
            if startIndex < 1 || startIndex ~= fix(startIndex)
                error("KSSOLV:Matgenlab:Xdatcar:Start", ...
                    "Start ionic step cannot be less than 1.");
            end
            if ~isempty(endIndex) && ...
                    (endIndex < 1 || endIndex ~= fix(endIndex))
                error("KSSOLV:Matgenlab:Xdatcar:End", ...
                    "End ionic step cannot be less than 1.");
            end
        end
    end
end
