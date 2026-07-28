classdef SiteOrderedIStructure < kssolv.analysis.matgenlab.core.IStructure
    %SITEORDEREDISTRUCTURE Immutable structure with order-sensitive equality.

    methods
        function obj = SiteOrderedIStructure(varargin)
            obj@kssolv.analysis.matgenlab.core.IStructure(varargin{:});
        end
    end

    methods (Static)
        function obj = from_sites(sites)
            if ~iscell(sites), sites = sites.sites; end
            if isempty(sites)
                error("KSSOLV:Matgenlab:SiteOrderedIStructure:Empty", ...
                    "At least one periodic site is required.");
            end
            lattice = sites{1}.lattice;
            species = cellfun(@(site) site.species, sites, ...
                "UniformOutput", false);
            coordinates = cell2mat(cellfun(@(site) site.frac_coords, ...
                sites, "UniformOutput", false).');
            obj = kssolv.analysis.matgenlab.core.SiteOrderedIStructure( ...
                lattice, species, coordinates, to_unit_cell = false);
        end
    end
end
