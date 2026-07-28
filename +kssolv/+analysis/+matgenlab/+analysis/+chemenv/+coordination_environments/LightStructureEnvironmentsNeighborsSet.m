classdef LightStructureEnvironmentsNeighborsSet < handle
    %LIGHTSTRUCTUREENVIRONMENTSNEIGHBORSSET Compact neighbor-image set.
    properties
        structure
        isite (1,1) double
        all_nbs_sites cell={}
        all_nbs_sites_indices_unsorted (1,:) double=[]
        all_nbs_sites_indices (1,:) double=[]
    end
    properties (Dependent)
        neighb_coords
        neighb_sites
        neighb_sites_and_indices
        neighb_indices_and_images
    end
    methods
        function obj=LightStructureEnvironmentsNeighborsSet( ...
                structure,isite,allSites,indices)
            indices=reshape(double(indices),1,[]);
            if numel(unique(indices))~=numel(indices)
                error("KSSOLV:Matgenlab:ChemEnv:DuplicateNeighbors", ...
                    "Neighbor set contains duplicates.");
            end
            obj.structure=structure;obj.isite=double(isite);
            obj.all_nbs_sites=allSites;
            obj.all_nbs_sites_indices_unsorted=indices;
            obj.all_nbs_sites_indices=sort(indices);
        end
        function value=get.neighb_coords(obj)
            value=cell2mat(cellfun(@(i)obj.all_nbs_sites{i}.site.coords, ...
                num2cell(obj.all_nbs_sites_indices_unsorted), ...
                "UniformOutput",false).');
        end
        function value=get.neighb_sites(obj)
            value=cellfun(@(i)obj.all_nbs_sites{i}.site, ...
                num2cell(obj.all_nbs_sites_indices_unsorted), ...
                "UniformOutput",false);
        end
        function value=get.neighb_sites_and_indices(obj)
            value=cellfun(@(i)struct(site=obj.all_nbs_sites{i}.site, ...
                index=obj.all_nbs_sites{i}.index), ...
                num2cell(obj.all_nbs_sites_indices_unsorted), ...
                "UniformOutput",false);
        end
        function value=get.neighb_indices_and_images(obj)
            value=cellfun(@(i)struct(index=obj.all_nbs_sites{i}.index, ...
                image_cell=obj.all_nbs_sites{i}.image_cell), ...
                num2cell(obj.all_nbs_sites_indices_unsorted), ...
                "UniformOutput",false);
        end
        function value=length(obj),value=numel(obj.all_nbs_sites_indices);end
        function value=char(obj)
            value=sprintf(['Neighbors Set for site #%d :\n' ...
                ' - Coordination number : %d\n' ...
                ' - Neighbors sites indices : %s\n'],obj.isite, ...
                length(obj),strjoin(string( ...
                obj.all_nbs_sites_indices),", "));
        end
        function value=string(obj),value=string(char(obj));end
        function value=as_dict(obj)
            value=struct(isite=obj.isite-1, ...
                all_nbs_sites_indices= ...
                obj.all_nbs_sites_indices_unsorted-1);
        end
    end
    methods (Static)
        function obj=from_dict(value,structure,allSites)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments. ...
                LightStructureEnvironmentsNeighborsSet(structure, ...
                double(value.isite)+1,allSites, ...
                reshape(double(value.all_nbs_sites_indices),1,[])+1);
        end
    end
end
