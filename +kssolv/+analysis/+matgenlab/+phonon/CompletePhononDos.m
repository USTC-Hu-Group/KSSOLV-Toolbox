classdef CompletePhononDos < kssolv.analysis.matgenlab.phonon.PhononDos
    %COMPLETEPHONONDOS Total and site-projected phonon DOS.

    properties (SetAccess=private)
        structure
        pdos cell
    end

    methods
        function obj=CompletePhononDos(structure,totalDos,phononDoses)
            obj@kssolv.analysis.matgenlab.phonon.PhononDos( ...
                totalDos.frequencies,totalDos.densities);
            obj.structure=structure;
            if iscell(phononDoses)
                obj.pdos=reshape(phononDoses,1,[]);
            elseif isnumeric(phononDoses) && ...
                    size(phononDoses,1)==structure.num_sites
                obj.pdos=mat2cell(double(phononDoses), ...
                    ones(structure.num_sites,1),size(phononDoses,2));
            elseif isa(phononDoses,"containers.Map")
                obj.pdos=cell(1,structure.num_sites);
                for index=1:structure.num_sites
                    if isKey(phononDoses,index)
                        obj.pdos{index}=phononDoses(index);
                    else
                        obj.pdos{index}=phononDoses(char(string(index)));
                    end
                end
            else
                error("KSSOLV:Matgenlab:CompletePhononDos:Pdos", ...
                    "ph_doses must be site-ordered cell or numeric data.");
            end
            if numel(obj.pdos)~=structure.num_sites
                error("KSSOLV:Matgenlab:CompletePhononDos:SiteCount", ...
                    "ph_doses must contain one density per site.");
            end
            obj.pdos=cellfun(@(value)reshape(double(value),[],1), ...
                obj.pdos,UniformOutput=false);
        end

        function value=get_site_dos(obj,site)
            index=obj.resolveSite(site);
            value=kssolv.analysis.matgenlab.phonon.PhononDos( ...
                obj.frequencies,obj.pdos{index});
        end

        function value=get_element_dos(obj)
            value=containers.Map("KeyType","char","ValueType","any");
            for index=1:obj.structure.num_sites
                symbol=char(obj.structure(index).specie.symbol);
                density=obj.pdos{index};
                if isKey(value,symbol)
                    density=value(symbol).densities+density;
                end
                value(symbol)=kssolv.analysis.matgenlab.phonon. ...
                    PhononDos(obj.frequencies,density);
            end
        end

        function value=as_dict(obj)
            value=struct( ...
                "x_module","pymatgen.phonon.dos", ...
                "x_class","CompletePhononDos", ...
                "structure",obj.structure.as_dict(), ...
                "frequencies",obj.frequencies, ...
                "densities",obj.densities, ...
                "pdos",{obj.pdos});
        end
        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function obj=from_dict(value)
            structure=kssolv.analysis.matgenlab.core.Structure. ...
                from_dict(value.structure);
            total=kssolv.analysis.matgenlab.phonon. ...
                PhononDos(value.frequencies,value.densities);
            obj=kssolv.analysis.matgenlab.phonon. ...
                CompletePhononDos(structure,total,value.pdos);
        end
    end

    methods (Access=private)
        function index=resolveSite(obj,site)
            if isnumeric(site)&&isscalar(site)
                index=double(site);
            else
                index=find(cellfun(@(candidate)candidate==site, ...
                    obj.structure.sites),1);
            end
            if isempty(index)||index<1||index>obj.structure.num_sites|| ...
                    index~=fix(index)
                error("KSSOLV:Matgenlab:CompletePhononDos:Site", ...
                    "The site is absent from the structure.");
            end
        end
    end
end
