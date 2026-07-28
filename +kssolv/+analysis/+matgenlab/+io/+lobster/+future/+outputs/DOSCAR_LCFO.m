classdef DOSCAR_LCFO < kssolv.analysis.matgenlab.io.lobster.future.outputs.DOSCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %DOSCAR_LCFO LCFO-projected density-of-states reader.
    methods
        function obj = DOSCAR_LCFO(varargin)
            requested = ~isempty(varargin);
            argumentsValue = varargin;
            if requested
                if numel(argumentsValue) < 2, argumentsValue{2} = false;
                else, requested = logical(argumentsValue{2}); argumentsValue{2} = false; end
            end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.DOSCAR( ...
                argumentsValue{:});
            obj.is_lcfo = true;
            if requested, obj.process(); end
        end
    end
end
