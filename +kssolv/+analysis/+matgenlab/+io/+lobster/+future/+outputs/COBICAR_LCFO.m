classdef COBICAR_LCFO < kssolv.analysis.matgenlab.io.lobster.future.outputs.COBICAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COBICAR_LCFO LCFO COBICAR reader.
    methods
        function obj = COBICAR_LCFO(varargin)
            requested = ~isempty(varargin);
            argumentsValue = varargin;
            if requested
                if numel(argumentsValue) < 2, argumentsValue{2} = false;
                else, requested = logical(argumentsValue{2}); argumentsValue{2} = false; end
            end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.COBICAR( ...
                argumentsValue{:});
            obj.is_lcfo = true;
            if requested, obj.process(); end
        end
    end
end
