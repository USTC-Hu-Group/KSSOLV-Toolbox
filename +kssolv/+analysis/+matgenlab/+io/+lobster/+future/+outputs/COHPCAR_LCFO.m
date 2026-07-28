classdef COHPCAR_LCFO < kssolv.analysis.matgenlab.io.lobster.future.outputs.COHPCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COHPCAR_LCFO LCFO COHPCAR reader.
    methods
        function obj = COHPCAR_LCFO(varargin)
            requested = ~isempty(varargin);
            argumentsValue = varargin;
            if requested
                if numel(argumentsValue) < 2, argumentsValue{2} = false;
                else, requested = logical(argumentsValue{2}); argumentsValue{2} = false; end
            end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.COHPCAR( ...
                argumentsValue{:});
            obj.is_lcfo = true;
            if requested, obj.process(); end
        end
    end
end
