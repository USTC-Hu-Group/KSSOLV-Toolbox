classdef Bandoverlaps < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.BandOverlaps
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %BANDOVERLAPS Legacy band-overlap reader and quality API.
    properties (Dependent, SetAccess = private)
        bandoverlapsdict
    end
    methods
        function obj = Bandoverlaps(filename, band_overlaps_dict, max_deviation)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "bandOverlaps.lobster"; end
            useDictionary = nargin >= 2 && ~isempty(band_overlaps_dict);
            if blank || useDictionary, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                BandOverlaps(constructorArguments{:});
            if blank, return; end
            if useDictionary
                obj.band_overlaps = band_overlaps_dict;
                if nargin >= 3
                    obj.band_overlaps.max_deviations = max_deviation;
                end
            else, obj.parse_file(); end
        end
        function value = has_good_quality_maxDeviation(obj, limit)
            if nargin < 2, limit = []; end
            value = obj.has_good_quality_max_deviation(limit);
        end
        function value = get.bandoverlapsdict(obj), value = obj.band_overlaps; end
    end
end
