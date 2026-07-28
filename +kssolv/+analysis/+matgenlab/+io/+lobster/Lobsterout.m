classdef Lobsterout < kssolv.analysis.matgenlab.io.lobster.future.outputs.LobsterOut
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %LOBSTEROUT Legacy lobsterout interface.
    methods
        function obj = Lobsterout(filename, varargin) %#ok<INUSD>
            if nargin == 0, constructorArguments = {};
            else, constructorArguments = {filename, true}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                LobsterOut(constructorArguments{:});
        end
        function value = get_doc(obj)
            value = obj.as_dict();
            metadata = fieldnames(value);
            for index = 1:numel(metadata)
                if startsWith(metadata{index}, "@"), value = rmfield(value, metadata{index}); end
            end
        end
        function value = as_dict(obj)
            value = as_dict@kssolv.analysis.matgenlab.io.lobster.future. ...
                LobsterFile(obj);
            value.x_module = "pymatgen.io.lobster.outputs";
            value.x_class = "Lobsterout";
        end
    end
end
