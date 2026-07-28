classdef GROSSPOP_LCFO < kssolv.analysis.matgenlab.io.lobster.future.outputs.GROSSPOP
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %GROSSPOP_LCFO LCFO gross-population reader.
    methods
        function obj = GROSSPOP_LCFO(varargin)
            requested = ~isempty(varargin);
            argumentsValue = varargin;
            if requested
                if numel(argumentsValue) < 2, argumentsValue{2} = false;
                else, requested = logical(argumentsValue{2}); argumentsValue{2} = false; end
            end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.GROSSPOP( ...
                argumentsValue{:});
            obj.is_lcfo = true;
            if requested, obj.process(); end
        end
    end
end
