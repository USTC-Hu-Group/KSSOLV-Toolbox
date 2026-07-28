classdef ICOBILIST_LCFO < kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOBILIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %ICOBILIST_LCFO LCFO integrated COBI list reader.
    methods
        function obj = ICOBILIST_LCFO(varargin)
            requested = ~isempty(varargin);
            argumentsValue = varargin;
            if requested
                if numel(argumentsValue) < 2, argumentsValue{2} = false;
                else, requested = logical(argumentsValue{2}); argumentsValue{2} = false; end
            end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                ICOBILIST(argumentsValue{:});
            obj.is_lcfo = true;
            if requested, obj.process(); end
        end
    end
end
