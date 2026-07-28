classdef CHARGE_LCFO < kssolv.analysis.matgenlab.io.lobster.future.outputs.CHARGE
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %CHARGE_LCFO LCFO Loewdin charge reader.
    methods
        function obj = CHARGE_LCFO(varargin)
            requested = ~isempty(varargin);
            argumentsValue = varargin;
            if requested
                if numel(argumentsValue) < 2
                    argumentsValue{2} = false;
                else
                    requested = logical(argumentsValue{2});
                    argumentsValue{2} = false;
                end
            end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.CHARGE( ...
                argumentsValue{:});
            obj.is_lcfo = true;
            if requested, obj.process(); end
        end
    end
end
