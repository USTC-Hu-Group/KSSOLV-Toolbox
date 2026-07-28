classdef Vaspwave < kssolv.analysis.matgenlab.io.vasp.Vasprun
    %VASPWAVE Native reader for VASP vaspwave.h5 files.

    properties
        version (1,1) struct = struct()
        structure = []
        spin (1,1) double = 0
        nk (1,1) double = 0
        nb (1,1) double = 0
        encut (1,1) double = 0
        a double = zeros(3)
        b double = zeros(3)
        vol (1,1) double = 0
        band_energy cell = cell(0)
        num_planewaves double = zeros(1,0)
        Gpoints cell = cell(0)
        ng (1,3) double = [0,0,0]
        vasp_type = []
    end

    properties (Access = private)
        h5Path_ (1,1) string = ""
        temporaryFolder_ (1,1) string = ""
        hasWave_ (1,1) logical = false
        gammaOnly_ (1,1) logical = false
        gammaExtraIndices_ cell = cell(0)
        nbmax_ (1,3) double = [0,0,0]
        C_ (1,1) double = 0.262465831
    end

    methods
        function obj = Vaspwave(filename)
            obj@kssolv.analysis.matgenlab.io.vasp.Vasprun();
            obj.filename = string(filename);
            obj.prepareFile(filename);
            obj.parseHdf5();
        end

        function delete(obj)
            if strlength(obj.temporaryFolder_) > 0 && ...
                    isfolder(obj.temporaryFolder_)
                try
                    rmdir(obj.temporaryFolder_, "s");
                catch
                end
            end
        end

        function coefficients = get_band_coeffs(obj, spinIndex, ...
                kpointIndex, bandIndex)
            obj.requireWave();
            spinIndex = obj.index(spinIndex, obj.spin, "spin");
            kpointIndex = obj.index(kpointIndex, obj.nk, "kpoint");
            bandIndex = obj.index(bandIndex, obj.nb, "band");
            path = sprintf("/wave/spin_%d/kpoint_%d/wave", ...
                spinIndex, kpointIndex);
            raw = h5read(obj.h5Path_, path);
            if ndims(raw) ~= 3 || size(raw,1) ~= 2
                error("KSSOLV:Matgenlab:Vaspwave:CoefficientShape", ...
                    "Wave dataset must decode to 2-by-nplane-by-nband.");
            end
            coefficients = complex(double(raw(1,:,bandIndex)), ...
                double(raw(2,:,bandIndex))).';
            if startsWith(string(obj.vasp_type), "n")
                pointCount = size(obj.Gpoints{kpointIndex}, 1);
                if numel(coefficients) ~= 2 * pointCount
                    error("KSSOLV:Matgenlab:Vaspwave:NclShape", ...
                        "Packed NCL coefficients have an invalid length.");
                end
                coefficients = [coefficients(1:pointCount).'; ...
                    coefficients(pointCount+1:end).'];
            elseif obj.gammaOnly_
                indices = obj.gammaExtraIndices_{kpointIndex};
                coefficients(indices) = coefficients(indices) / sqrt(2);
                coefficients = [coefficients; ...
                    conj(coefficients(indices))];
            end
        end

        function mesh = fft_mesh(obj, kpoint, band, spin, spinor, shift)
            if nargin < 4 || isempty(spin), spin = 1; end
            if nargin < 5 || isempty(spinor), spinor = 1; end
            if nargin < 6 || isempty(shift), shift = true; end
            obj.requireWave();
            kpoint = obj.index(kpoint, obj.nk, "kpoint");
            band = obj.index(band, obj.nb, "band");
            spin = obj.index(spin, obj.spin, "spin");
            coefficients = obj.get_band_coeffs(spin, kpoint, band);
            if startsWith(string(obj.vasp_type), "n")
                spinor = obj.index(spinor, 2, "spinor");
                coefficients = coefficients(spinor, :).';
            elseif spinor ~= 1
                error("KSSOLV:Matgenlab:Vaspwave:Spinor", ...
                    "Spinor selection is only valid for NCL data.");
            end
            mesh = obj.meshFromCoefficients(kpoint, coefficients, shift);
        end

        function value = evaluate_wavefunc(obj, kpoint, band, r, spin, spinor)
            if nargin < 5 || isempty(spin), spin = 1; end
            if nargin < 6 || isempty(spinor), spinor = 1; end
            kpoint = obj.index(kpoint, obj.nk, "kpoint");
            band = obj.index(band, obj.nb, "band");
            spin = obj.index(spin, obj.spin, "spin");
            coefficients = obj.get_band_coeffs(spin, kpoint, band);
            if startsWith(string(obj.vasp_type), "n")
                spinor = obj.index(spinor, 2, "spinor");
                coefficients = coefficients(spinor, :).';
            end
            vectors = obj.Gpoints{kpoint} + obj.kpoints(kpoint,:);
            phase = (vectors * obj.b) * reshape(double(r), 3, 1);
            value = sum(coefficients(:) .* exp(1i*phase(:))) / sqrt(obj.vol);
        end

        function output = get_parchg(obj, poscar, kpoint, band, varargin)
            obj.requireWave();
            options = struct("spin", [], "spinor", [], ...
                "phase", false, "scale", 2);
            names = fieldnames(options); index = 1;
            while index <= numel(varargin)
                match = find(strcmpi(string(varargin{index}),string(names)),1);
                if isempty(match)
                    error("KSSOLV:Matgenlab:Vaspwave:Arguments", ...
                        "Unknown get_parchg option.");
                end
                options.(names{match}) = varargin{index+1};
                index = index + 2;
            end
            kpoint = obj.index(kpoint, obj.nk, "kpoint");
            band = obj.index(band, obj.nb, "band");
            if options.phase && any(abs(obj.kpoints(kpoint,:)) > 1e-8)
                warning("KSSOLV:Matgenlab:Vaspwave:NonGammaPhase", ...
                    "phase=true is normally meaningful only at Gamma.");
            end
            original = obj.ng;
            cleanup = onCleanup(@() obj.restoreGrid(original));
            obj.ng = obj.ng * options.scale;
            count = prod(obj.ng); data = struct();
            if obj.spin == 2
                if ~isempty(options.spin)
                    selectedSpin = obj.index(options.spin, obj.spin, "spin");
                    wave = ifftn(obj.fft_mesh( ...
                        kpoint,band,selectedSpin,1))*count;
                    density = abs(conj(wave).*wave);
                    if options.phase, density=sign(real(wave)).*density; end
                    data.total = density;
                else
                    up=ifftn(obj.fft_mesh(kpoint,band,1,1))*count;
                    down=ifftn(obj.fft_mesh(kpoint,band,2,1))*count;
                    upDensity=abs(conj(up).*up);
                    downDensity=abs(conj(down).*down);
                    data.total=upDensity+downDensity;
                    data.diff=upDensity-downDensity;
                end
            elseif startsWith(string(obj.vasp_type), "n")
                if ~isempty(options.spin) && options.spin ~= 1
                    error("KSSOLV:Matgenlab:Vaspwave:NclSpin", ...
                        "NCL data do not support collinear spin selection.");
                end
                if ~isempty(options.spinor)
                    spinor=obj.index(options.spinor,2,"spinor");
                    wave=ifftn(obj.fft_mesh(kpoint,band,1,spinor))*count;
                    density=abs(conj(wave).*wave);
                else
                    wave=ifftn(obj.fft_mesh(kpoint,band,1,1))*count;
                    other=ifftn(obj.fft_mesh(kpoint,band,1,2))*count;
                    density=abs(conj(wave).*wave)+abs(conj(other).*other);
                end
                if options.phase && ~isempty(options.spinor)
                    density=sign(real(wave)).*density;
                end
                data.total=density;
            else
                wave=ifftn(obj.fft_mesh(kpoint,band,1,1))*count;
                density=abs(conj(wave).*wave);
                if isempty(options.spinor), density=density+density; end
                if options.phase, density=sign(real(wave)).*density; end
                data.total=density;
            end
            clear cleanup
            obj.ng=original;
            output=kssolv.analysis.matgenlab.io.vasp.Chgcar(poscar,data);
        end

        function output = get_chgcar(obj)
            structureValue = obj.requireStructure();
            raw = double(h5read(obj.h5Path_, "/charge/charge"));
            data = obj.volumetricData(raw, "/charge/charge");
            augmentation = obj.readAugmentation(size(raw,4));
            output = kssolv.analysis.matgenlab.io.vasp.Chgcar( ...
                structureValue, data, augmentation);
        end

        function output = get_locpot(obj)
            structureValue = obj.requireStructure();
            raw = double(h5read(obj.h5Path_, "/locpot/total"));
            data = obj.volumetricData(raw, "/locpot/total");
            output = kssolv.analysis.matgenlab.io.vasp.Locpot( ...
                structureValue, data);
        end

        function write_unks(obj, directory)
            obj.requireWave();
            directory=string(directory);
            if isfile(directory)
                error("KSSOLV:Matgenlab:Vaspwave:UnkDirectory", ...
                    "UNK destination must be a directory.");
            end
            if ~isfolder(directory), mkdir(directory); end
            count=prod(obj.ng);
            for point=1:obj.nk
                if startsWith(string(obj.vasp_type),"n")
                    outputFile=fullfile(directory,sprintf("UNK%05d.NC",point));
                    obj.writeUnkHeader(outputFile,point);
                    identifier=fopen(outputFile,"a","ieee-le");
                    cleanup=onCleanup(@()fclose(identifier));
                    for band=1:obj.nb
                        for spinor=1:2
                            wave=ifftn(obj.fft_mesh(point,band,1,spinor))*count;
                            obj.writeComplexRecord(identifier,wave);
                        end
                    end
                    clear cleanup
                else
                    for spinIndex=1:obj.spin
                        outputFile=fullfile(directory, ...
                            sprintf("UNK%05d.%d",point,spinIndex));
                        obj.writeUnkHeader(outputFile,point);
                        identifier=fopen(outputFile,"a","ieee-le");
                        cleanup=onCleanup(@()fclose(identifier));
                        for band=1:obj.nb
                            wave=ifftn(obj.fft_mesh( ...
                                point,band,spinIndex,1))*count;
                            obj.writeComplexRecord(identifier,wave);
                        end
                        clear cleanup
                    end
                end
            end
        end
    end

    methods (Access = private)
        function prepareFile(obj, filename)
            source=string(filename);
            if endsWith(lower(source),".gz")
                folder=string(tempname); mkdir(folder);
                files=gunzip(source,folder);
                obj.temporaryFolder_=folder; obj.h5Path_=string(files{1});
            elseif endsWith(lower(source),".bz2")
                folder=string(tempname); mkdir(folder);
                target=fullfile(folder,"vaspwave.h5");
                command="/usr/bin/bzip2 -dc -- '" + ...
                    replace(source,"'","'\\''") + "' > '" + target + "'";
                [status,message]=system(command);
                if status~=0
                    error("KSSOLV:Matgenlab:Vaspwave:Decompress","%s",message);
                end
                obj.temporaryFolder_=folder; obj.h5Path_=target;
            else
                obj.h5Path_=source;
            end
        end

        function parseHdf5(obj)
            obj.version=struct();
            for name=["major","minor","patch"]
                path="/version/"+name;
                if obj.exists(path), obj.version.(name)=double(h5read(obj.h5Path_,path)); end
            end
            obj.vasp_version=string(obj.version.major)+"."+ ...
                string(obj.version.minor)+"."+string(obj.version.patch);
            obj.structure=obj.readStructure();
            obj.initial_structure=obj.structure;
            obj.final_structure=obj.structure;
            obj.hasWave_=obj.exists("/wave");
            if ~obj.hasWave_, return; end
            obj.spin=round(double(h5read(obj.h5Path_,"/wave/rispin")));
            obj.nk=round(double(h5read(obj.h5Path_,"/wave/rnkpts")));
            obj.nb=round(double(h5read(obj.h5Path_,"/wave/rnb_tot")));
            obj.encut=double(h5read(obj.h5Path_,"/wave/enmax"));
            obj.efermi=double(h5read(obj.h5Path_,"/wave/efermi"));
            obj.a=double(h5read(obj.h5Path_,"/wave/amat"));
            obj.vol=dot(obj.a(1,:),cross(obj.a(2,:),obj.a(3,:)));
            obj.b=2*pi*[cross(obj.a(2,:),obj.a(3,:)); ...
                cross(obj.a(3,:),obj.a(1,:)); ...
                cross(obj.a(1,:),obj.a(2,:))]/obj.vol;
            obj.kpoints=zeros(obj.nk,3);
            obj.num_planewaves=zeros(1,obj.nk);
            if obj.spin==2
                obj.band_energy=cell(obj.spin,obj.nk);
            else
                obj.band_energy=cell(1,obj.nk);
            end
            for point=1:obj.nk
                base=sprintf("/wave/spin_1/kpoint_%d",point);
                obj.kpoints(point,:)=reshape(double( ...
                    h5read(obj.h5Path_,base+"/vkpt")),1,3);
                obj.num_planewaves(point)=round(double( ...
                    h5read(obj.h5Path_,base+"/num_planewaves")));
                for spinIndex=1:obj.spin
                    spinBase=sprintf( ...
                        "/wave/spin_%d/kpoint_%d",spinIndex,point);
                    celtot=double(h5read(obj.h5Path_,spinBase+"/celtot")).';
                    fertot=double(h5read(obj.h5Path_,spinBase+"/fertot"));
                    obj.band_energy{spinIndex,point}=[celtot,fertot(:)];
                end
            end
            obj.generateNbmax();
            obj.ng=obj.nbmax_*3;
            [gammaPoints,~,~]=obj.generateGpoints(obj.kpoints(1,:),true);
            obj.gammaOnly_=obj.spin==1 && obj.nk==1 && ...
                all(abs(obj.kpoints(1,:))<1e-8) && ...
                obj.num_planewaves(1)==size(gammaPoints,1);
            obj.Gpoints=cell(1,obj.nk);
            obj.gammaExtraIndices_=cell(1,obj.nk);
            for point=1:obj.nk
                if obj.gammaOnly_
                    [base,extra,indices]= ...
                        obj.generateGpoints(obj.kpoints(point,:),true);
                    obj.Gpoints{point}=[base;extra];
                    obj.gammaExtraIndices_{point}=indices;
                else
                    [base,~,~]=obj.generateGpoints(obj.kpoints(point,:),false);
                    obj.Gpoints{point}=base;
                end
            end
            if obj.gammaOnly_, obj.vasp_type="gam";
            elseif all(2*cellfun(@(x)size(x,1),obj.Gpoints)== ...
                    obj.num_planewaves), obj.vasp_type="ncl";
            else, obj.vasp_type="std";
            end
        end

        function structureValue = readStructure(obj)
            paths=["/structure/positions","/locpot/position"];
            found=cell(1,0);
            for path=paths
                if ~obj.exists(path), continue; end
                types=string(h5read(obj.h5Path_,path+"/ion_types"));
                types=strtrim(types(:).');
                counts=reshape(double(h5read(obj.h5Path_, ...
                    path+"/number_ion_types")),1,[]);
                species=cell(1,sum(counts));
                cursor=1;
                for index=1:numel(counts)
                    for repeat=1:counts(index)
                        species{cursor}=char(types(index)); cursor=cursor+1;
                    end
                end
                scale=double(h5read(obj.h5Path_,path+"/scale"));
                lattice=scale*double(h5read(obj.h5Path_, ...
                    path+"/lattice_vectors"));
                positions=double(h5read(obj.h5Path_,path+"/position_ions")).';
                direct=double(h5read(obj.h5Path_,path+"/direct_coordinates"));
                found{end+1}=kssolv.analysis.matgenlab.core.Structure( ...
                    lattice,species,positions, ...
                    coords_are_cartesian=(direct~=1)); %#ok<AGROW>
            end
            if isempty(found), structureValue=[]; return; end
            structureValue=found{1};
            for index=2:numel(found)
                if structureValue~=found{index}
                    error("KSSOLV:Matgenlab:Vaspwave:StructureMismatch", ...
                        "vaspwave.h5 contains inconsistent structures.");
                end
            end
        end

        function value = volumetricData(obj, raw, dataset)
            [parentPath,~]=fileparts(char(dataset));
            gridPath=string(parentPath)+"/grid";
            grid=reshape(double(h5read(obj.h5Path_,gridPath)),1,[]);
            if ndims(raw)~=4 || ~isequal(size(raw,1:3),grid)
                error("KSSOLV:Matgenlab:Vaspwave:Grid", ...
                    "Volumetric grid metadata does not match dataset.");
            end
            components=size(raw,4); value=struct();
            value.total=raw(:,:,:,1);
            if components==2
                value.diff=raw(:,:,:,2);
            elseif components==4
                value.diff_x=raw(:,:,:,2); value.diff_y=raw(:,:,:,3);
                value.diff_z=raw(:,:,:,4);
                signValue=sign(value.diff_x*1.01+ ...
                    value.diff_y*1.02+value.diff_z*1.03);
                value.diff=sqrt(value.diff_x.^2+value.diff_y.^2+ ...
                    value.diff_z.^2).*signValue;
            elseif components~=1
                error("KSSOLV:Matgenlab:Vaspwave:Components", ...
                    "Unsupported volumetric component count.");
            end
        end

        function augmentation = readAugmentation(obj, components)
            augmentation=struct();
            names=["total","diff","diff_x","diff_y","diff_z"];
            if components==4, names=["total","diff_x","diff_y","diff_z"];
            else, names=names(1:components);
            end
            for index=1:numel(names)
                ions=sprintf("/charge/aug_occupancies_ions_s%02d",index);
                values=sprintf("/charge/aug_occupancies_s%02d",index);
                if ~obj.exists(ions)||~obj.exists(values), continue; end
                lengths=reshape(double(h5read(obj.h5Path_,ions)),1,[]);
                raw=double(h5read(obj.h5Path_,values)).';
                map=containers.Map("KeyType","double","ValueType","any");
                for ion=1:numel(lengths)
                    if lengths(ion)>0
                        map(ion)=raw(ion,1:lengths(ion));
                    end
                end
                augmentation.(names(index))=map;
            end
        end

        function value = requireStructure(obj)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:Vaspwave:MissingStructure", ...
                    "vaspwave.h5 contains no structure.");
            end
            value=obj.structure;
        end

        function requireWave(obj)
            if ~obj.hasWave_
                error("KSSOLV:Matgenlab:Vaspwave:MissingWave", ...
                    "vaspwave.h5 contains no wavefunction data.");
            end
        end

        function tf = exists(obj,path)
            try
                h5info(obj.h5Path_,path);
                tf=true;
            catch
                tf=false;
            end
        end

        function generateNbmax(obj)
            magnitude=vecnorm(obj.b,2,2).'; b=obj.b;
            phi12=acos(dot(b(1,:),b(2,:))/(magnitude(1)*magnitude(2)));
            triple=dot(b(3,:),cross(b(1,:),b(2,:)))/ ...
                (magnitude(3)*norm(cross(b(1,:),b(2,:))));
            first=sqrt(obj.encut*obj.C_)./magnitude;
            first(1:2)=first(1:2)/abs(sin(phi12)); first(3)=first(3)/abs(triple);
            phi13=acos(dot(b(1,:),b(3,:))/(magnitude(1)*magnitude(3)));
            triple=dot(b(2,:),cross(b(1,:),b(3,:)))/ ...
                (magnitude(2)*norm(cross(b(1,:),b(3,:))));
            second=sqrt(obj.encut*obj.C_)./magnitude;
            second([1,3])=second([1,3])/abs(sin(phi13));second(2)=second(2)/abs(triple);
            phi23=acos(dot(b(2,:),b(3,:))/(magnitude(2)*magnitude(3)));
            triple=dot(b(1,:),cross(b(2,:),b(3,:)))/ ...
                (magnitude(1)*norm(cross(b(2,:),b(3,:))));
            third=sqrt(obj.encut*obj.C_)./magnitude;
            third([2,3])=third([2,3])/abs(sin(phi23));third(1)=third(1)/abs(triple);
            obj.nbmax_=floor(max([first+1;second+1;third+1],[],1));
        end

        function [points,extra,indices]=generateGpoints(obj,kpoint,gamma)
            maximum=obj.nbmax_;
            if gamma,kmax=maximum(1);else,kmax=2*maximum(1);end
            points=zeros(0,3);extra=zeros(0,3);indices=zeros(1,0);
            for i=0:2*maximum(3)
                if i>maximum(3),i3=i-2*maximum(3)-1;else,i3=i;end
                for j=0:2*maximum(2)
                    if j>maximum(2),j2=j-2*maximum(2)-1;else,j2=j;end
                    for k=0:kmax
                        if k>maximum(1),k1=k-2*maximum(1)-1;else,k1=k;end
                        if gamma&&(k1==0&&j2<0||k1==0&&j2==0&&i3<0),continue,end
                        point=[k1,j2,i3]; reciprocal=(kpoint+point)*obj.b;
                        if obj.encut>dot(reciprocal,reciprocal)/obj.C_
                            points(end+1,:)=point; %#ok<AGROW>
                            if gamma&&any(point~=0)
                                extra(end+1,:)=-point; %#ok<AGROW>
                                indices(end+1)=size(points,1); %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        end

        function mesh=meshFromCoefficients(obj,kpoint,coefficients,shift)
            points=obj.Gpoints{kpoint};
            if numel(coefficients)~=size(points,1)
                error("KSSOLV:Matgenlab:Vaspwave:CoefficientCount", ...
                    "Coefficient and G-point counts differ.");
            end
            mesh=complex(zeros(obj.ng));center=floor(obj.ng/2)+1;
            for index=1:size(points,1)
                location=points(index,:)+center;
                mesh(location(1),location(2),location(3))=coefficients(index);
            end
            if shift,mesh=ifftshift(mesh);end
        end

        function value=index(~,value,count,name)
            if value<0,value=count+value+1;end
            validateattributes(value,{'numeric'}, ...
                {'scalar','integer','>=',1,'<=',count},"",name);
        end

        function restoreGrid(obj,value),obj.ng=value;end

        function writeUnkHeader(obj,filename,point)
            identifier=fopen(filename,"w","ieee-le");
            cleanup=onCleanup(@()fclose(identifier));
            fwrite(identifier,int32(20),"int32");
            fwrite(identifier,int32([obj.ng,point,obj.nb]),"int32");
            fwrite(identifier,int32(20),"int32");clear cleanup
        end

        function writeComplexRecord(~,identifier,values)
            flat=values(:);raw=zeros(2*numel(flat),1);
            raw(1:2:end)=real(flat);raw(2:2:end)=imag(flat);
            marker=int32(8*numel(raw));fwrite(identifier,marker,"int32");
            fwrite(identifier,raw,"double");fwrite(identifier,marker,"int32");
        end
    end
end
