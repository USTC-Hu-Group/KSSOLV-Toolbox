classdef HeisenbergScreener
    %HEISENBERGSCREENER Clean, deduplicate and rank magnetic orderings.
    properties (SetAccess=private)
        screened_structures cell
        screened_energies double
    end
    methods
        function obj=HeisenbergScreener(structures,energies,screen)
            if nargin<3,screen=false;end
            if ~iscell(structures),structures=num2cell(structures);end
            if numel(structures)~=numel(energies)
                error("KSSOLV:Matgenlab:Heisenberg:Length", ...
                    "Structures and energies must have equal lengths.");
            end
            cleaned=cell(1,numel(structures));perIon=zeros(1,numel(energies));
            for index=1:numel(structures)
                analyzer=kssolv.analysis.matgenlab.analysis.magnetism. ...
                    CollinearMagneticStructureAnalyzer(structures{index}, ...
                    "make_primitive",false,"threshold",0);
                cleaned{index}=analyzer. ...
                    get_structure_with_only_magnetic_atoms(false);
                perIon(index)=energies(index)/cleaned{index}.num_sites;
            end
            keep=true(1,numel(perIon));rounded=round(perIon,6);
            for index=1:numel(perIon)
                if ~keep(index),continue,end
                duplicates=find(rounded==rounded(index));
                duplicates=duplicates(duplicates>index);keep(duplicates)=false;
            end
            cleaned=cleaned(keep);perIon=perIon(keep);
            [perIon,order]=sort(perIon);cleaned=cleaned(order);
            if screen&&numel(cleaned)>2
                weak=zeros(1,numel(cleaned));
                for index=1:numel(cleaned)
                    raw=cleaned{index}.site_properties.magmom;
                    moments=cellfun(@double,raw);
                    weak(index)=nnz(abs(moments)<1);
                end
                [~,tail]=sort(weak(3:end),"ascend");
                order=[1,2,tail+2];cleaned=cleaned(order);perIon=perIon(order);
            end
            obj.screened_structures=cleaned;obj.screened_energies=perIon;
        end
    end
end
