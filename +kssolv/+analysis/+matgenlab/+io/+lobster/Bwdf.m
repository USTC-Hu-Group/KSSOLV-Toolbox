classdef Bwdf < kssolv.analysis.matgenlab.io.lobster.future.outputs.BWDF
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %BWDF Legacy bond-weighted distribution interface.
    methods
        function obj = Bwdf(filename, centers, bwdf, bin_width)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "BWDF.lobster"; end
            useValues = nargin >= 2 && ~isempty(centers);
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                BWDF(constructorArguments{:});
            if blank, return; end
            if useValues
                obj.centers = num2cell(centers);
                obj.bwdf = bwdf;
                obj.bin_width = bin_width;
            else, obj.parse_file(); end
        end
    end
end
