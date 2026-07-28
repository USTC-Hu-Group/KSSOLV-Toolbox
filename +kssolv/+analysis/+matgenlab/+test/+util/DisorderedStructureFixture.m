classdef DisorderedStructureFixture
    properties
        sites cell
        composition
        is_ordered (1,1) logical
    end
    methods
        function obj = DisorderedStructureFixture(sites, composition)
            obj.sites = sites;
            obj.composition = composition;
            obj.is_ordered = all(cellfun(@(site) site.is_ordered, sites));
        end
    end
end
