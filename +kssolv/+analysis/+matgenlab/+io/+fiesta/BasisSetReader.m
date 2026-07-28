classdef BasisSetReader < handle
    %BASISSETREADER Reader for localized FIESTA auxiliary basis sets.

    properties (SetAccess = private)
        filename (1,1) string
        data
    end

    methods
        function obj = BasisSetReader(filename)
            obj.filename = string(filename);
            text = kssolv.analysis.matgenlab.io.fiesta.FiestaIOUtils. ...
                read_text(filename);
            obj.data = parseFile(text);
            obj.data("n_nlmo") = obj.set_n_nlmo();
        end

        function value = set_n_nlmo(obj)
            % Frozen upstream mutates data by removing its header entries.
            if ~all(isKey(obj.data, {'lmax', 'n_nlo', 'preamble'}))
                error("KSSOLV:Matgenlab:Fiesta:BasisHeaderDiscarded", ...
                    "Frozen set_n_nlmo already removed its header keys.");
            end
            remove(obj.data, {'lmax', 'n_nlo', 'preamble'});
            count = 0;
            names = obj.data.keys();
            for index = 1:numel(names)
                fields = split(string(names{index}), "_");
                angularMomentum = str2double(fields(1));
                if isnan(angularMomentum)
                    error("KSSOLV:Matgenlab:Fiesta:BasisAngularMomentum", ...
                        "Basis key '%s' has no numeric angular momentum.", ...
                        names{index});
                end
                count = count + 2 * angularMomentum + 1;
            end
            value = string(count);
        end

        function value = infos_on_basis_set(obj)
            if ~isKey(obj.data, "lmax")
                error("KSSOLV:Matgenlab:Fiesta:BasisHeaderDiscarded", ...
                    "Frozen set_n_nlmo removed lmax/n_nlo/preamble.");
            end
            value = "=========================================" + newline + ...
                "Reading basis set:" + newline + newline + ...
                "Basis set for " + obj.filename + " atom " + newline + ...
                "Maximum angular momentum = " + obj.data("lmax") + newline + ...
                "Number of atomics orbitals = " + obj.data("n_nlo") + newline + ...
                "Number of nlm orbitals = " + obj.data("n_nlmo") + newline + ...
                "=========================================";
        end
    end
end

function basisSet = parseFile(text)
basisSet = containers.Map("KeyType", "char", "ValueType", "any");
preamble = strings(1, 0);
parsePreamble = false;
parseHeader = false;
parseOrbitals = false;
currentKey = "";
lines = splitlines(string(text));
for index = 1:numel(lines)
    line = lines(index);
    if parseOrbitals
        orbital = regexp(char(line), ...
            '^\s*(\d+)\s+(\d+)\s+(\d+)\s+\#.*$', ...
            "tokens", "once");
        if ~isempty(orbital)
            currentKey = strjoin(string(orbital), "_");
            basisSet(char(currentKey)) = cell(0, 2);
        else
            values = regexp(char(line), ...
                '^\s*(\S+)\s+(\S+)\s*$', "tokens", "once");
            if ~isempty(values)
                if strlength(currentKey) == 0
                    error("KSSOLV:Matgenlab:Fiesta:BasisOrbital", ...
                        "A coefficient appears before an orbital header.");
                end
                rows = basisSet(char(currentKey));
                rows(end + 1, :) = values; %#ok<AGROW>
                basisSet(char(currentKey)) = rows;
            end
        end
    elseif parseHeader
        header = regexp(char(line), ...
            '^\s*(\d+)\s+(\d+)\s+\#.*$', "tokens", "once");
        if ~isempty(header)
            basisSet("lmax") = string(header{1});
            basisSet("n_nlo") = string(header{2});
            parseHeader = false;
            parseOrbitals = true;
        end
    elseif parsePreamble
        preamble(end + 1) = strtrim(line); %#ok<AGROW>
    end

    if contains(line, "</preamble>")
        parsePreamble = false;
        parseHeader = true;
    elseif contains(line, "<preamble>")
        parsePreamble = true;
    end
end
if ~isKey(basisSet, "lmax")
    basisSet("lmax") = [];
    basisSet("n_nlo") = [];
end
basisSet("preamble") = preamble;
end
