classdef Charge < kssolv.analysis.matgenlab.io.lobster.future.outputs.CHARGE
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %CHARGE Legacy charge reader.
    properties (Dependent, SetAccess = private)
        Mulliken
        Loewdin
    end
    methods
        function obj = Charge(filename, is_lcfo, varargin)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "CHARGE.lobster"; end
            if nargin < 2 || isempty(is_lcfo), is_lcfo = false; end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.CHARGE( ...
                constructorArguments{:});
            if blank, return; end
            obj.is_lcfo = is_lcfo;
            if ~isempty(varargin)
                obj.centers = varargin{1};
                if numel(varargin) >= 3, obj.mulliken = varargin{3}; end
                if numel(varargin) >= 4, obj.loewdin = varargin{4}; end
            else, obj.parse_file(); end
        end
        function value = get.Mulliken(obj), value = obj.mulliken; end
        function value = get.Loewdin(obj), value = obj.loewdin; end
        function structure = get_structure_with_charges(obj, filename)
            structure = kssolv.analysis.matgenlab.core.Structure.from_file(filename);
            properties = structure.site_properties;
            properties.Mulliken_Charges = num2cell(obj.mulliken);
            properties.Loewdin_Charges = num2cell(obj.loewdin);
            structure = structure.copy(properties);
        end
    end
end
