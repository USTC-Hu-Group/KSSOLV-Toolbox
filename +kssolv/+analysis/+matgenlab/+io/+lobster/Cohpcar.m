classdef Cohpcar < kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %COHPCAR Legacy configurable COXXCAR reader.
    properties
        are_coops (1,1) logical = false
        are_cobis (1,1) logical = false
        are_multi_center_cobis (1,1) logical = false
        is_lcfo (1,1) logical = false
    end
    methods
        function obj = Cohpcar(are_coops, are_cobis, are_multi, is_lcfo, filename)
            blank = nargin == 0;
            if blank, are_coops = false; end
            if nargin < 1 || isempty(are_coops), are_coops = false; end
            if nargin < 2 || isempty(are_cobis), are_cobis = false; end
            if nargin < 3 || isempty(are_multi), are_multi = false; end
            if nargin < 4 || isempty(is_lcfo), is_lcfo = false; end
            if nargin < 5 || isempty(filename)
                if are_coops, filename = "COOPCAR.lobster";
                elseif are_cobis, filename = "COBICAR.lobster";
                else, filename = "COHPCAR.lobster"; end
            end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.COXXCAR( ...
                constructorArguments{:});
            if blank, return; end
            obj.are_coops = are_coops;
            obj.are_cobis = are_cobis;
            obj.are_multi_center_cobis = are_multi;
            obj.is_lcfo = is_lcfo;
            obj.process();
        end
        function name = get_default_filename(~), name = "COHPCAR.lobster"; end
    end
end
