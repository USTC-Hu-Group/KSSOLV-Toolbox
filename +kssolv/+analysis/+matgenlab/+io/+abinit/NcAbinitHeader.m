classdef NcAbinitHeader < kssolv.analysis.matgenlab.io.abinit.AbinitHeader
    methods
        function obj = NcAbinitHeader(summary, varargin)
            obj@kssolv.analysis.matgenlab.io.abinit.AbinitHeader(summary, varargin{:});
        end
    end
    methods (Static)
        function obj = fhi_header(filename, varargin), obj = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.parse(filename, "FHI"); end
        function obj = hgh_header(filename, varargin), obj = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.parse(filename, "HGH"); end
        function obj = gth_header(filename, varargin), obj = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.parse(filename, "GTH"); end
        function obj = oncvpsp_header(filename, varargin), obj = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.parse(filename, "ONCVPSP"); end
        function obj = tm_header(filename, varargin), obj = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.parse(filename, "TM"); end
    end
    methods (Static, Access = private)
        function obj = parse(filename, kind)
            lines = splitlines(string(fileread(filename)));
            if numel(lines) < 3
                error("KSSOLV:Matgenlab:Abinit:PseudoParse", ...
                    "Incomplete pseudopotential header in %s.", filename);
            end
            first = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.nums(lines(2));
            second = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.nums(lines(3));
            if numel(first) < 3 || numel(second) < 6
                error("KSSOLV:Matgenlab:Abinit:PseudoParse", ...
                    "Invalid ABINIT header in %s.", filename);
            end
            d = struct("zatom", first(1), "zion", first(2), "pspdat", first(3), ...
                "pspcod", second(1), "pspxc", second(2), "lmax", second(3), ...
                "lloc", second(4), "mmax", second(5), "r2well", second(6), ...
                "rchrg", 0, "fchrg", 0, "qchrg", 0);
            for i = 4:min(numel(lines), 20)
                lowerLine = lower(lines(i));
                if contains(lowerLine, "rchrg")
                    values = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.nums(lines(i));
                    if numel(values) >= 3
                        d.rchrg = values(1); d.fchrg = values(2); d.qchrg = values(3);
                    end
                    break
                end
            end
            if kind == "ONCVPSP"
                values = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader.nums(lines(6));
                if isempty(values), d.extension_switch = 0; else, d.extension_switch = values(1); end
            end
            obj = kssolv.analysis.matgenlab.io.abinit.NcAbinitHeader(lines(1), d);
        end
        function values = nums(line)
            tokens = regexp(char(line), ...
                '[-+]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][-+]?\d+)?', 'match');
            values = str2double(regexprep(tokens, '[Dd]', 'E'));
        end
    end
end
