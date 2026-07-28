classdef PawAbinitHeader < kssolv.analysis.matgenlab.io.abinit.AbinitHeader
    methods
        function obj = PawAbinitHeader(summary, varargin)
            obj@kssolv.analysis.matgenlab.io.abinit.AbinitHeader(summary, varargin{:});
        end
    end
    methods (Static)
        function obj = paw_header(filename, varargin)
            lines = splitlines(string(fileread(filename)));
            nums = @(line) str2double(regexprep(regexp(char(line), ...
                '[-+]?(?:\d+\.?\d*|\.\d+)(?:[EeDd][-+]?\d+)?', 'match'), '[Dd]', 'E'));
            a = nums(lines(2)); b = nums(lines(3)); c = split(strtrim(extractBefore(lines(4), ":")));
            d = struct("zatom", a(1), "zion", a(2), "pspdat", a(3), ...
                "pspcod", b(1), "pspxc", b(2), "lmax", b(3), "lloc", b(4), ...
                "mmax", b(5), "r2well", b(6), "pspfmt", c(1));
            meshCount = nums(lines(7)); meshCount = meshCount(1);
            cut = nums(lines(8 + meshCount)); d.r_cut = cut(1);
            obj = kssolv.analysis.matgenlab.io.abinit.PawAbinitHeader(lines(1), d);
        end
    end
end
