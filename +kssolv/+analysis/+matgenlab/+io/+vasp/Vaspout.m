classdef Vaspout < kssolv.analysis.matgenlab.io.vasp.Vasprun
    %VASPOUT Native reader for VASP vaspout.h5 result files.

    properties
        store_potcar (1,1) logical = true
        potcar = []
        poscar = []
        bandgap_props = []
    end

    properties (Access = private)
        h5Path_ (1,1) string = ""
        temporaryFolder_ (1,1) string = ""
    end

    methods
        function obj = Vaspout(filename, varargin)
            obj@kssolv.analysis.matgenlab.io.vasp.Vasprun();
            defaults=struct("occu_tol",1e-8,"parse_dos",true, ...
                "parse_eigen",true,"parse_projected_eigen",false, ...
                "separate_spins",false,"store_potcar",true);
            names=fieldnames(defaults);position=1;index=1;
            while index<=numel(varargin)
                current=varargin{index};
                if (ischar(current)||(isstring(current)&&isscalar(current)))&& ...
                        any(strcmpi(string(current),string(names)))
                    match=find(strcmpi(string(current),string(names)),1);
                    defaults.(names{match})=varargin{index+1};index=index+2;
                else
                    defaults.(names{position})=current;
                    position=position+1;index=index+1;
                end
            end
            obj.filename=string(filename);obj.occu_tol=defaults.occu_tol;
            obj.separate_spins=logical(defaults.separate_spins);
            obj.store_potcar=logical(defaults.store_potcar);
            obj.prepareFile(filename);
            obj.parseHdf5(logical(defaults.parse_dos), ...
                logical(defaults.parse_eigen));
        end

        function delete(obj)
            if strlength(obj.temporaryFolder_)>0&&isfolder(obj.temporaryFolder_)
                try
                    rmdir(obj.temporaryFolder_,"s");
                catch
                end
            end
        end

        function remove_potcar_and_write_file(obj,filename,fakePotcarString)
            if nargin<2||isempty(filename),filename=obj.filename;end
            if nargin<3,fakePotcarString=[];end
            filename=string(filename);
            folder=string(tempname);mkdir(folder);
            cleanup=onCleanup(@()rmdir(folder,"s"));
            uncompressed=fullfile(folder,"vaspout.h5");
            copyfile(obj.h5Path_,uncompressed);
            if isempty(fakePotcarString)
                file=H5F.open(uncompressed,"H5F_ACC_RDWR","H5P_DEFAULT");
                fileCleanup=onCleanup(@()H5F.close(file));
                try
                    H5L.delete(file,"/input/potcar/content","H5P_DEFAULT");
                catch
                end
                clear fileCleanup
            else
                content=char(string(fakePotcarString));
                try
                    h5write(uncompressed,"/input/potcar/content",content);
                catch exception
                    error("KSSOLV:Matgenlab:Vaspout:PotcarReplacement", ...
                        "Unable to replace POTCAR content: %s",exception.message);
                end
            end
            if endsWith(lower(filename),".gz")
                generated=gzip(uncompressed,folder);
                movefile(generated{1},filename,"f");
            elseif endsWith(lower(filename),".bz2")
                command="/usr/bin/bzip2 -c -- '"+uncompressed+ ...
                    "' > '"+replace(filename,"'","'\\''")+"'";
                [status,message]=system(command);
                if status~=0,error("KSSOLV:Matgenlab:Vaspout:Compress","%s",message);end
            else
                copyfile(uncompressed,filename,"f");
            end
            clear cleanup
        end
    end

    methods (Access = private)
        function prepareFile(obj,filename)
            source=string(filename);
            if endsWith(lower(source),".gz")
                folder=string(tempname);mkdir(folder);
                files=gunzip(source,folder);
                obj.temporaryFolder_=folder;obj.h5Path_=string(files{1});
            elseif endsWith(lower(source),".bz2")
                folder=string(tempname);mkdir(folder);
                target=fullfile(folder,"vaspout.h5");
                command="/usr/bin/bzip2 -dc -- '"+ ...
                    replace(source,"'","'\\''")+"' > '"+target+"'";
                [status,message]=system(command);
                if status~=0,error("KSSOLV:Matgenlab:Vaspout:Decompress","%s",message);end
                obj.temporaryFolder_=folder;obj.h5Path_=target;
            else,obj.h5Path_=source;
            end
        end

        function parseHdf5(obj,parseDos,parseEigen)
            version=zeros(1,3);
            versionNames=["major","minor","patch"];
            for index=1:3
                version(index)=double(h5read(obj.h5Path_, ...
                    "/version/"+versionNames(index)));
            end
            obj.vasp_version=strjoin(string(version),".");
            obj.generator=kssolv.analysis.matgenlab.io.vasp.Incar( ...
                struct("VERSION",obj.vasp_version));
            obj.incar=obj.readMapping("/input/incar");
            obj.parameters=obj.incar.copy();
            obj.initial_structure=obj.readStructure("/input/poscar");
            obj.final_structure=obj.readStructure("/results/positions");
            obj.atomic_symbols=cellstr(string( ...
                obj.initial_structure.species_and_occu));
            obj.poscar=kssolv.analysis.matgenlab.io.vasp.Poscar( ...
                obj.initial_structure);
            obj.parseH5Kpoints();
            obj.parsePotcar();
            obj.parseIonicSteps();
            obj.parseBandgapProps();
            obj.md_data={};
            obj.efermi=[];
            if parseDos,obj.parseH5Dos();end
            if parseEigen,obj.parseH5Eigen();end
            obj.projected_eigenvalues=[];
            obj.projected_magnetization=[];
        end

        function mapping=readMapping(obj,path)
            info=h5info(obj.h5Path_,path);values=struct();
            for index=1:numel(info.Datasets)
                name=info.Datasets(index).Name;
                value=h5read(obj.h5Path_,string(path)+"/"+name);
                if ischar(value)||isstring(value),value=char(strtrim(string(value)));
                elseif isnumeric(value)&&isscalar(value),value=double(value);
                else,value=double(value);
                end
                values.(matlab.lang.makeValidName(name))=value;
            end
            mapping=kssolv.analysis.matgenlab.io.vasp.Incar(values);
        end

        function structure=readStructure(obj,path)
            types=strtrim(string(h5read(obj.h5Path_,path+"/ion_types")));
            types=types(:).';counts=reshape(double( ...
                h5read(obj.h5Path_,path+"/number_ion_types")),1,[]);
            species=cell(1,sum(counts));cursor=1;
            for index=1:numel(counts)
                for repeat=1:counts(index)
                    species{cursor}=char(types(index));cursor=cursor+1;
                end
            end
            scale=double(h5read(obj.h5Path_,path+"/scale"));
            lattice=scale*double(h5read(obj.h5Path_,path+"/lattice_vectors"));
            positions=double(h5read(obj.h5Path_,path+"/position_ions")).';
            direct=double(h5read(obj.h5Path_,path+"/direct_coordinates"));
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,species,positions,coords_are_cartesian=(direct~=1));
        end

        function parseH5Kpoints(obj)
            path="/input/kpoints";
            mode=lower(strtrim(string(h5read(obj.h5Path_,path+"/mode"))));
            styleMap=struct("e","Reciprocal","a","Automatic", ...
                "g","Gamma","l","Line_mode","m","Monkhorst");
            key=matlab.lang.makeValidName(char(mode));
            if isfield(styleMap,key),style=styleMap.(key);else,style="Reciprocal";end
            if obj.exists(path+"/coordinates_kpoints")
                points=double(h5read(obj.h5Path_, ...
                    path+"/coordinates_kpoints")).';
                if obj.exists(path+"/weights_kpoints")
                    weights=reshape(double(h5read(obj.h5Path_, ...
                        path+"/weights_kpoints")),1,[]);
                else,weights=ones(1,size(points,1));
                end
                labels=strings(1,size(points,1));labels(:)=missing;
                if obj.exists(path+"/positions_labels_kpoints")
                    positions=reshape(double(h5read(obj.h5Path_, ...
                        path+"/positions_labels_kpoints")),1,[]);
                    rawLabels=reshape(strtrim(string(h5read(obj.h5Path_, ...
                        path+"/labels_kpoints"))),1,[]);
                    labels(positions)=rawLabels;
                end
                if style=="Line_mode"
                    obj.kpoints=kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                        comment="Kpoints from vaspout.h5",style=style, ...
                        num_kpts=size(points,1),kpts=points,labels=labels, ...
                        kpts_weights=weights);
                else
                    obj.kpoints=kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                        comment="Kpoints from vaspout.h5",style=style, ...
                        num_kpts=size(points,1),kpts=points, ...
                        kpts_weights=weights);
                end
                obj.actual_kpoints=points;
                obj.actual_kpoints_weights=weights;
            elseif obj.exists(path+"/nkpx")
                divisions=[double(h5read(obj.h5Path_,path+"/nkpx")), ...
                    double(h5read(obj.h5Path_,path+"/nkpy")), ...
                    double(h5read(obj.h5Path_,path+"/nkpz"))];
                obj.kpoints=kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                    comment="Kpoints from vaspout.h5",style=style, ...
                    kpts=divisions);
                obj.actual_kpoints=[];obj.actual_kpoints_weights=[];
            end
            if obj.exists("/input/kpoints_opt")
                props=kssolv.analysis.matgenlab.io.vasp.KpointOptProps();
                [props.kpoints,props.actual_kpoints, ...
                    props.actual_kpoints_weights]=obj.readOptKpoints();
                obj.kpoints_opt_props=props;
            end
        end

        function [kpoints,points,weights]=readOptKpoints(obj)
            path="/input/kpoints_opt";
            points=double(h5read(obj.h5Path_,path+"/coordinates_kpoints")).';
            if obj.exists(path+"/weights_kpoints")
                weights=reshape(double(h5read(obj.h5Path_, ...
                    path+"/weights_kpoints")),1,[]);
            else,weights=ones(1,size(points,1));
            end
            kpoints=kssolv.analysis.matgenlab.io.vasp.Kpoints( ...
                comment="KPOINTS_OPT from vaspout.h5",style="Reciprocal", ...
                num_kpts=size(points,1),kpts=points,kpts_weights=weights);
        end

        function parsePotcar(obj)
            obj.potcar=[];obj.potcar_symbols={};obj.potcar_spec={};
            if obj.exists("/input/potcar/content")
                content=char(h5read(obj.h5Path_,"/input/potcar/content"));
                parsed=kssolv.analysis.matgenlab.io.vasp.Potcar.from_str(content);
                if obj.store_potcar,obj.potcar=parsed;end
                obj.potcar_symbols=cell(1,parsed.count);
                for potcarIndex=1:parsed.count
                    obj.potcar_symbols{potcarIndex}= ...
                        char(parsed(potcarIndex).TITEL);
                end
                obj.potcar_spec=parsed.spec;
            elseif obj.exists("/input/potcar/spec")
                specs=jsondecode(char(h5read(obj.h5Path_,"/input/potcar/spec")));
                if isstruct(specs),specs=num2cell(specs);end
                obj.potcar_spec=specs;
                obj.potcar_symbols=cellfun(@(x)char(string(x.titel)), ...
                    specs,"UniformOutput",false);
            end
        end

        function parseIonicSteps(obj)
            path="/intermediate/ion_dynamics";
            energies=double(h5read(obj.h5Path_,path+"/energies"));
            tags=string(h5read(obj.h5Path_,path+"/energies_tags"));
            tags=reshape(strtrim(erase(tags,char(0))),1,[]);
            obj.nionic_steps=size(energies,2);
            lattices=double(h5read(obj.h5Path_,path+"/lattice_vectors"));
            positions=double(h5read(obj.h5Path_,path+"/position_ions"));
            forces=[];
            if obj.exists(path+"/forces"),forces=double(h5read(obj.h5Path_,path+"/forces"));end
            stresses=[];
            if obj.exists(path+"/stresses"),stresses=double(h5read(obj.h5Path_,path+"/stresses"));
            elseif obj.exists(path+"/stress"),stresses=double(h5read(obj.h5Path_,path+"/stress"));
            end
            keyMap=containers.Map( ...
                {'free energy    TOTEN','energy without entropy','energy(sigma->0)'}, ...
                {'e_fr_energy','e_wo_entrp','e_0_energy'});
            obj.ionic_steps=cell(1,obj.nionic_steps);
            species=obj.initial_structure.species_and_occu;
            for stepIndex=1:obj.nionic_steps
                step=struct();
                for valueIndex=1:numel(tags)
                    tag=char(tags(valueIndex));
                    if isKey(keyMap,tag),key=keyMap(tag);
                    else,key=matlab.lang.makeValidName(tag);
                    end
                    step.(key)=energies(valueIndex,stepIndex);
                end
                step.structure=kssolv.analysis.matgenlab.core.Structure( ...
                    lattices(:,:,stepIndex),species, ...
                    positions(:,:,stepIndex).');
                if ~isempty(forces),step.forces=forces(:,:,stepIndex).';end
                if ~isempty(stresses),step.stresses=stresses(:,:,stepIndex);end
                step.electronic_steps={};
                obj.ionic_steps{stepIndex}=step;
            end
        end

        function parseBandgapProps(obj)
            path="/intermediate/band";
            if ~obj.exists(path),obj.bandgap_props=[];return;end
            labels=string(h5read(obj.h5Path_,path+"/labels"));
            labels=reshape(strtrim(erase(labels,char(0))),1,[]);
            references=["gap_from_kpoint","gap_from_weight"];
            output=struct();
            for reference=references
                if ~obj.exists(path+"/"+reference),continue;end
                raw=double(h5read(obj.h5Path_,path+"/"+reference));
                spins=size(raw,2);
                if spins==1,spinNames="total";
                elseif spins==3,spinNames=["total","up","down"];
                else,continue
                end
                group=struct();
                for spinIndex=1:numel(spinNames)
                    values=reshape(raw(:,spinIndex,1),1,[]);
                    vbm=obj.labelValue(labels,values,"valence band maximum");
                    cbm=obj.labelValue(labels,values,"conduction band minimum");
                    bottom=obj.labelValue(labels,values,"direct gap bottom");
                    top=obj.labelValue(labels,values,"direct gap top");
                    vbmK=[obj.labelValue(labels,values,"kx (VBM)"), ...
                        obj.labelValue(labels,values,"ky (VBM)"), ...
                        obj.labelValue(labels,values,"kz (VBM)")];
                    cbmK=[obj.labelValue(labels,values,"kx (CBM)"), ...
                        obj.labelValue(labels,values,"ky (CBM)"), ...
                        obj.labelValue(labels,values,"kz (CBM)")];
                    directK=[obj.labelValue(labels,values,"kx (direct)"), ...
                        obj.labelValue(labels,values,"ky (direct)"), ...
                        obj.labelValue(labels,values,"kz (direct)")];
                    group.(spinNames(spinIndex))= ...
                        kssolv.analysis.matgenlab.io.vasp.BandgapProps( ...
                        vbm=vbm,cbm=cbm, ...
                        direct_gap_eigenvalues=[bottom,top], ...
                        vbm_k=vbmK,cbm_k=cbmK,direct_gap_k=directK);
                end
                output.(reference)=group;
            end
            obj.bandgap_props=output;
        end

        function parseH5Eigen(obj)
            obj.eigenvalues=obj.readEigen("/results/electron_eigenvalues");
            if ~isempty(obj.kpoints_opt_props)&& ...
                    obj.exists("/results/electron_eigenvalues_kpoints_opt")
                obj.kpoints_opt_props.eigenvalues=obj.readEigen( ...
                    "/results/electron_eigenvalues_kpoints_opt");
            end
        end

        function output=readEigen(obj,path)
            raw=double(h5read(obj.h5Path_,path+"/eigenvalues"));
            weights=double(h5read(obj.h5Path_,path+"/fermiweights"));
            if obj.exists(path+"/ispin")
                spins=round(double(h5read(obj.h5Path_,path+"/ispin")));
            else
                spins=max(1,size(raw,3));
            end
            output=struct();
            for spinIndex=1:spins
                energy=squeeze(raw(:,:,spinIndex)).';
                occupation=squeeze(weights(:,:,spinIndex)).';
                data=zeros(size(energy,1),size(energy,2),2);
                data(:,:,1)=energy;data(:,:,2)=occupation;
                if spinIndex==1,output.up=data;else,output.down=data;end
            end
        end

        function parseH5Dos(obj)
            obj.parseDosAt("/results/electron_dos",false);
            if ~isempty(obj.kpoints_opt_props)&& ...
                    obj.exists("/results/electron_dos_kpoints_opt")
                obj.parseDosAt("/results/electron_dos_kpoints_opt",true);
            end
        end

        function parseDosAt(obj,path,isOpt)
            energies=reshape(double(h5read(obj.h5Path_,path+"/energies")),1,[]);
            efermiValue=double(h5read(obj.h5Path_,path+"/efermi"));
            raw=double(h5read(obj.h5Path_,path+"/dos"));
            integrated=double(h5read(obj.h5Path_,path+"/dosi"));
            densities=struct("up",reshape(raw(:,1),1,[]));
            integratedDensities=struct("up",reshape(integrated(:,1),1,[]));
            if size(raw,2)>1
                densities.down=reshape(raw(:,2),1,[]);
                integratedDensities.down=reshape(integrated(:,2),1,[]);
            end
            total=kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                efermiValue,energies,densities);
            integratedDos=kssolv.analysis.matgenlab.electronic_structure.Dos( ...
                efermiValue,energies,integratedDensities);
            pdos={};
            if obj.exists(path+"/dospar")
                projected=double(h5read(obj.h5Path_,path+"/dospar"));
                labels=strtrim(string(h5read(obj.h5Path_, ...
                    "/results/projectors/lchar")));
                siteCount=obj.final_structure.num_sites;
                orbitalCount=size(projected,2);
                pdos=cell(1,siteCount);
                for site=1:siteCount
                    siteData=struct();
                    for orbital=1:orbitalCount
                        name=replace(labels(orbital),["x2-y2","z2-r2"],["dx2","dz2"]);
                        name=matlab.lang.makeValidName(char(name));
                        channel=struct();
                        if ndims(projected)==3
                            channel.up=reshape(projected(:,orbital,site),1,[]);
                        else
                            channel.up=reshape(projected(:,orbital,site,1),1,[]);
                            if size(projected,4)>1
                                channel.down=reshape(projected(:,orbital,site,2),1,[]);
                            end
                        end
                        siteData.(name)=channel;
                    end
                    pdos{site}=siteData;
                end
            end
            if isOpt
                obj.kpoints_opt_props.tdos=total;
                obj.kpoints_opt_props.idos=integratedDos;
                obj.kpoints_opt_props.pdos=pdos;
                obj.kpoints_opt_props.efermi=efermiValue;
            else
                obj.tdos=total;obj.idos=integratedDos;obj.pdos=pdos;
                obj.efermi=efermiValue;obj.dos_has_errors=false;
            end
        end

        function tf=exists(obj,path)
            try
                h5info(obj.h5Path_,path);
                tf=true;
            catch
                tf=false;
            end
        end

        function value=labelValue(~,labels,values,label)
            index=find(labels==label,1);
            if isempty(index),value=[];else,value=values(index);end
        end
    end
end
