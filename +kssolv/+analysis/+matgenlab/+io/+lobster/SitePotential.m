classdef SitePotential < ...
        kssolv.analysis.matgenlab.io.lobster.future.outputs.SitePotentials
    %#ok<*MCSCT,*ALIGN,*AGROW,*ISCL,*MCNPN,*STOUT,*UNRCH,*MCCBU,*MSNU>
    %SITEPOTENTIAL Legacy site-potential interface.
    properties (Dependent, SetAccess = private)
        sitepotentials_Mulliken
        sitepotentials_Loewdin
        madelungenergies_Mulliken
        madelungenergies_Loewdin
    end
    methods
        function obj = SitePotential(filename, varargin)
            blank = nargin == 0;
            if blank, filename = []; end
            if nargin < 1 || isempty(filename), filename = "SitePotentials.lobster"; end
            if blank, constructorArguments = {};
            else, constructorArguments = {filename, false}; end
            obj@kssolv.analysis.matgenlab.io.lobster.future.outputs. ...
                SitePotentials(constructorArguments{:});
            if blank, return; end
            if ~isempty(varargin)
                values = varargin;
                names = ["ewald_splitting", "centers", ...
                    "site_potentials_loewdin", "site_potentials_mulliken", ...
                    "madelung_energies_mulliken", "madelung_energies_loewdin"];
                for index = 1:min(numel(values), numel(names))
                    obj.(names(index)) = values{index};
                end
            else, obj.parse_file(); end
        end
        function structure = get_structure_with_site_potentials(obj, filename)
            structure = kssolv.analysis.matgenlab.core.Structure.from_file(filename);
            properties = structure.site_properties;
            properties.Mulliken_Site_Potentials = ...
                num2cell(obj.site_potentials_mulliken);
            properties.Loewdin_Site_Potentials = ...
                num2cell(obj.site_potentials_loewdin);
            structure = structure.copy(properties);
        end
        function value = get.sitepotentials_Mulliken(obj)
            value = obj.site_potentials_mulliken;
        end
        function value = get.sitepotentials_Loewdin(obj)
            value = obj.site_potentials_loewdin;
        end
        function value = get.madelungenergies_Mulliken(obj)
            value = obj.madelung_energies_mulliken;
        end
        function value = get.madelungenergies_Loewdin(obj)
            value = obj.madelung_energies_loewdin;
        end
    end
end
