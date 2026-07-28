classdef AnimatedXSF
    %ANIMATEDXSF XCrySDen animated XSF trajectory adapter.

    properties
        data cell = cell(1, 0)
    end

    methods
        function obj = AnimatedXSF(data)
            if nargin > 0, obj.data = reshape(data, 1, []); end
        end

        function value = length(obj)
            value = numel(obj.data);
        end

        function trajectory = as_trajectory(obj)
            if isempty(obj.data)
                error("KSSOLV:Matgenlab:AnimatedXSF:Empty", ...
                    "Cannot convert an empty AnimatedXSF to a Trajectory.");
            end
            structures = cell(1, numel(obj.data));
            for index = 1:numel(obj.data)
                frame = obj.data{index};
                if ~isa(frame.structure, ...
                        "kssolv.analysis.matgenlab.core.Structure")
                    error("KSSOLV:Matgenlab:AnimatedXSF:PeriodicRequired", ...
                        "Conversion to Trajectory requires periodic XSF frames.");
                end
                structures{index} = frame.structure;
                if index > 1 && ...
                        structures{index}.num_sites ~= structures{1}.num_sites
                    error("KSSOLV:Matgenlab:AnimatedXSF:SiteCount", ...
                        "All AXSF frames must have the same number of sites.");
                end
            end
            constant = true;
            reference = structures{1}.lattice.matrix;
            for index = 2:numel(structures)
                constant = constant && all(abs( ...
                    structures{index}.lattice.matrix - reference) < 1e-12, ...
                    "all");
            end
            trajectory = ...
                kssolv.analysis.matgenlab.core.Trajectory.from_structures( ...
                structures, constant);
        end

        function varargout = subsref(obj, reference)
            if strcmp(reference(1).type, "()") && ...
                    isscalar(reference(1).subs)
                selection = reference(1).subs{1};
                if isscalar(selection)
                    value = obj.data{selection};
                else
                    value = kssolv.analysis.matgenlab.io.xcrysden. ...
                        AnimatedXSF(obj.data(selection));
                end
                if numel(reference) > 1
                    value = builtin("subsref", value, reference(2:end));
                end
                varargout{1} = value;
            else
                [varargout{1:nargout}] = builtin("subsref", obj, reference);
            end
        end
    end

    methods (Static)
        function obj = from_file(filename)
            text = kssolv.analysis.matgenlab.io.xcrysden.XSFTransport. ...
                read_text(filename);
            obj = kssolv.analysis.matgenlab.io.xcrysden.AnimatedXSF. ...
                from_str(text);
        end

        function obj = from_str(input_string)
            obj = parseAnimated(string(input_string));
        end

        function obj = parse_file(stream)
            text = kssolv.analysis.matgenlab.io.xcrysden.XSFTransport. ...
                read_stream(stream);
            obj = parseAnimated(text);
        end
    end
end

function animated = parseAnimated(text)
lines = splitlines(replace(string(text), compose("\r\n"), newline));
content = strings(0, 1);
for index = 1:numel(lines)
    line = strtrim(lines(index));
    if strlength(line) > 0 && ~startsWith(line, "#")
        content(end + 1) = line; %#ok<AGROW>
    end
end
if isempty(content) || ~startsWith(upper(content(1)), "ANIMSTEPS ")
    error("KSSOLV:Matgenlab:AnimatedXSF:Header", ...
        "AXSF data must begin with ANIMSTEPS.");
end
header = split(content(1));
nFrames = str2double(header(2));
if ~isfinite(nFrames) || nFrames < 1 || nFrames ~= fix(nFrames)
    error("KSSOLV:Matgenlab:AnimatedXSF:FrameCount", ...
        "ANIMSTEPS must declare a positive integer frame count.");
end
if numel(content) < 2 || ...
        ~any(upper(content(2)) == ["MOLECULE", "POLYMER", "SLAB", "CRYSTAL"])
    error("KSSOLV:Matgenlab:AnimatedXSF:Kind", ...
        "ANIMSTEPS must be followed by an XSF structure family keyword.");
end
kind = upper(content(2));
index = 3;
commonLattice = [];
frameLattices = cell(1, nFrames);
frames = cell(1, nFrames);
nextSequential = 1;
while index <= numel(content)
    line = content(index);
    tokens = split(line);
    keyword = upper(tokens(1));
    if keyword == "PRIMVEC"
        frameIndex = [];
        if numel(tokens) > 1, frameIndex = parseFrame(tokens(2), nFrames); end
        if index + 3 > numel(content)
            error("KSSOLV:Matgenlab:AnimatedXSF:TruncatedLattice", ...
                "AXSF PRIMVEC section is truncated.");
        end
        lattice = zeros(3);
        for row = 1:3
            values = sscanf(char(content(index + row)), "%f").';
            if numel(values) ~= 3
                error("KSSOLV:Matgenlab:AnimatedXSF:LatticeShape", ...
                    "AXSF lattice rows must contain three values.");
            end
            lattice(row, :) = values;
        end
        if isempty(frameIndex), commonLattice = lattice;
        else, frameLattices{frameIndex} = lattice;
        end
        index = index + 4;
    elseif keyword == "PRIMCOORD"
        frameIndex = nextSequential;
        if numel(tokens) > 1, frameIndex = parseFrame(tokens(2), nFrames); end
        if index + 1 > numel(content)
            error("KSSOLV:Matgenlab:AnimatedXSF:TruncatedCoordinates", ...
                "AXSF PRIMCOORD header is truncated.");
        end
        atomHeader = sscanf(char(content(index + 1)), "%d").';
        if numel(atomHeader) ~= 2 || atomHeader(2) ~= 1
            error("KSSOLV:Matgenlab:AnimatedXSF:PrimcoordHeader", ...
                "PRIMCOORD header second value must be 1");
        end
        stop = index + 1 + atomHeader(1);
        if stop > numel(content)
            error("KSSOLV:Matgenlab:AnimatedXSF:TruncatedCoordinates", ...
                "AXSF PRIMCOORD atom rows are truncated.");
        end
        lattice = frameLattices{frameIndex};
        if isempty(lattice), lattice = commonLattice; end
        if isempty(lattice)
            error("KSSOLV:Matgenlab:AnimatedXSF:MissingLattice", ...
                "PRIMCOORD encountered before an applicable PRIMVEC.");
        end
        atomLines = reshape(content(index + 1:stop), [], 1);
        frameText = join([kind; "PRIMVEC"; ...
            compose("%.16g %.16g %.16g", lattice(:, 1), ...
            lattice(:, 2), lattice(:, 3)); "PRIMCOORD"; ...
            atomLines], newline);
        frames{frameIndex} = ...
            kssolv.analysis.matgenlab.io.xcrysden.XSF.from_str(frameText);
        nextSequential = max(nextSequential, frameIndex + 1);
        index = stop + 1;
    elseif keyword == "ATOMS"
        if kind ~= "MOLECULE"
            error("KSSOLV:Matgenlab:AnimatedXSF:AtomsKind", ...
                "ATOMS is only valid in MOLECULE animations.");
        end
        frameIndex = nextSequential;
        if numel(tokens) > 1, frameIndex = parseFrame(tokens(2), nFrames); end
        stop = index + 1;
        while stop <= numel(content)
            nextKeyword = upper(split(content(stop)));
            if any(nextKeyword(1) == ["ATOMS", "PRIMVEC", "PRIMCOORD"])
                break
            end
            stop = stop + 1;
        end
        atomLines = reshape(content(index + 1:stop - 1), [], 1);
        frameText = join(["MOLECULE"; "ATOMS"; atomLines], newline);
        frames{frameIndex} = ...
            kssolv.analysis.matgenlab.io.xcrysden.XSF.from_str(frameText);
        nextSequential = max(nextSequential, frameIndex + 1);
        index = stop;
    else
        error("KSSOLV:Matgenlab:AnimatedXSF:Keyword", ...
            "Unsupported or misplaced AXSF keyword: %s", line);
    end
end
parsed = find(~cellfun(@isempty, frames));
if numel(parsed) ~= nFrames
    error("KSSOLV:Matgenlab:AnimatedXSF:FrameCountMismatch", ...
        "ANIMSTEPS declares %d frames but %d were parsed.", ...
        nFrames, numel(parsed));
end
animated = ...
    kssolv.analysis.matgenlab.io.xcrysden.AnimatedXSF(frames);
end

function index = parseFrame(token, count)
index = str2double(token);
if ~isfinite(index) || index < 1 || index > count || index ~= fix(index)
    error("KSSOLV:Matgenlab:AnimatedXSF:FrameIndex", ...
        "AXSF frame index is outside the ANIMSTEPS range.");
end
end
