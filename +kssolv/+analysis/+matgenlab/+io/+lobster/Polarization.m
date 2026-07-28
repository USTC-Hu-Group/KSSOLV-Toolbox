classdef Polarization < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.POLARIZATION
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %POLARIZATION Legacy polarization-reader interface.
    methods
        function obj = Polarization(filename, mulliken, loewdin)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "POLARIZATION.lobster"; end
            useValues = nargin >= 2 && ~isempty(mulliken);
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                POLARIZATION(constructorArguments{:});
            if blank, return; end
            if useValues
                obj.rel_mulliken_pol_vector = mulliken;
                obj.rel_loewdin_pol_vector = loewdin;
            else, obj.parse_file(); end
        end
    end
end
