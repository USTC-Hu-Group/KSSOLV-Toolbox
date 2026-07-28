classdef Icohplist < kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOXXLIST
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %ICOHPLIST Legacy integrated interaction-list reader.
    properties
        are_coops (1,1) logical = false
        are_cobis (1,1) logical = false
        orbitalwise (1,1) logical = false
    end
    properties (Dependent, SetAccess = private)
        icohplist
        icohpcollection
    end
    methods
        function obj = Icohplist(is_lcfo, are_coops, are_cobis, filename, varargin)
            blank = nargin == 0;
            if blank, is_lcfo = false; end
            if nargin < 1 || isempty(is_lcfo), is_lcfo = false; end
            if nargin < 2 || isempty(are_coops), are_coops = false; end
            if nargin < 3 || isempty(are_cobis), are_cobis = false; end
            if nargin < 4 || isempty(filename)
                if are_coops, filename = "ICOOPLIST.lobster";
                elseif are_cobis, filename = "ICOBILIST.lobster";
                else, filename = "ICOHPLIST.lobster"; end
            end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.ICOXXLIST( ...
                constructorArguments{:});
            if blank, return; end
            obj.is_lcfo = is_lcfo;
            obj.are_coops = are_coops;
            obj.are_cobis = are_cobis;
            if ~isempty(varargin), obj.orbitalwise = logical(varargin{end}); end
            obj.parse_file();
        end
        function value = get.icohplist(obj)
            value = struct();
            for index = 1:numel(obj.interactions)
                name = matlab.lang.makeValidName("x" + ...
                    string(obj.interactions{index}.index));
                value.(name) = obj.interactions{index};
            end
        end
        function value = get.icohpcollection(obj), value = obj.interactions; end
        function name = get_default_filename(~), name = "ICOHPLIST.lobster"; end
    end
end
