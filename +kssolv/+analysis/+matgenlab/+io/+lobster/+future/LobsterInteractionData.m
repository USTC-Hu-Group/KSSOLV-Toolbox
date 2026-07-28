classdef LobsterInteractionData < ...
        kssolv.analysis.matgenlab.io.lobster.future.LobsterInteraction
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTERINTERACTIONDATA Interaction metadata plus COXX/ICOXX values.
    properties
        coxx (1,1) struct = struct()
        icoxx (1,1) struct = struct()
    end
    methods
        function obj = LobsterInteractionData(value)
            if nargin == 0, value = struct(); end
            obj@kssolv.analysis.matgenlab.io.lobster.future.LobsterInteraction(value);
            if nargin > 0 && isfield(value, "coxx"), obj.coxx = value.coxx; end
            if nargin > 0 && isfield(value, "icoxx"), obj.icoxx = value.icoxx; end
        end
        function value = as_dict(obj)
            value = as_dict@kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterInteraction(obj);
            value.coxx = obj.coxx;
            value.icoxx = obj.icoxx;
        end
    end
end
