classdef Grosspop < kssolv.analysis.matgenlab.io.lobster.future.outputs.GROSSPOP
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %GROSSPOP Legacy gross-population reader.
    methods
        function obj = Grosspop(filename, is_lcfo, populations)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "GROSSPOP.lobster"; end
            if nargin < 2 || isempty(is_lcfo), is_lcfo = false; end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs.GROSSPOP( ...
                constructorArguments{:});
            if blank, return; end
            obj.is_lcfo = is_lcfo;
            if nargin >= 3 && ~isempty(populations), obj.populations = populations;
            else, obj.parse_file(); end
        end
        function structure = get_structure_with_total_grosspop(obj, filename)
            structure = kssolv.analysis.matgenlab.core.Structure.from_file(filename);
            properties = structure.site_properties;
            atoms = fieldnames(obj.populations);
            mulliken = zeros(1, numel(atoms));
            loewdin = zeros(1, numel(atoms));
            for index = 1:numel(atoms)
                orbitalsValue = fieldnames(obj.populations.(atoms{index}));
                for orbital = 1:numel(orbitalsValue)
                    value = obj.populations.(atoms{index}).(orbitalsValue{orbital}).up;
                    if isfield(value, "mulliken"), mulliken(index) = ...
                            mulliken(index) + value.mulliken; end
                    if isfield(value, "loewdin"), loewdin(index) = ...
                            loewdin(index) + value.loewdin; end
                end
            end
            properties.Total_Mulliken_GP = num2cell(mulliken);
            properties.Total_Loewdin_GP = num2cell(loewdin);
            structure = structure.copy(properties);
        end
    end
end
