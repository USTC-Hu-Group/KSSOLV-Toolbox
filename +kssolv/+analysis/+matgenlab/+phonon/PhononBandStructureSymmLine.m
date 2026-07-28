classdef PhononBandStructureSymmLine < ...
        kssolv.analysis.matgenlab.phonon.PhononBandStructure
    %PHONONBANDSTRUCTURESYMMLINE Phonon bands along symmetry lines.

    properties (SetAccess=private)
        distance (1,:) double
        branches cell
    end

    methods
        function obj=PhononBandStructureSymmLine( ...
                qpoints,frequencies,lattice,hasNac,eigendisplacements, ...
                labelsDict,coordsAreCartesian,structure)
            if nargin<4,hasNac=false;end
            if nargin<5,eigendisplacements=[];end
            if nargin<6,labelsDict=[];end
            if nargin<7,coordsAreCartesian=false;end
            if nargin<8,structure=[];end
            obj@kssolv.analysis.matgenlab.phonon.PhononBandStructure( ...
                qpoints,frequencies,lattice,[],eigendisplacements,[], ...
                labelsDict,coordsAreCartesian,structure);
            obj=obj.initializeLine(qpoints,frequencies, ...
                logical(hasNac),eigendisplacements);
        end

        function value=get_equivalent_qpoints(obj,index)
            if isempty(obj.qpoints{index}.label)
                value=index;
            else
                label=obj.qpoints{index}.label;
                value=find(cellfun(@(point) ...
                    isequal(point.label,label),obj.qpoints));
            end
        end

        function value=get_branch(obj,index)
            equivalents=obj.get_equivalent_qpoints(index);
            value=cell(1,0);
            for pointIndex=equivalents
                for branchIndex=1:numel(obj.branches)
                    branch=obj.branches{branchIndex};
                    if pointIndex>=branch.start_index && ...
                            pointIndex<=branch.end_index
                        record=branch;record.index=pointIndex;
                        value{end+1}=record; %#ok<AGROW>
                    end
                end
            end
        end

        function write_phononwebsite(obj,filename)
            payload=obj.as_phononwebsite();
            fid=fopen(filename,"w","n","UTF-8");
            if fid<0
                error("KSSOLV:Matgenlab:PhononBandStructure:Write", ...
                    "Cannot write '%s'.",filename);
            end
            cleanup=onCleanup(@()fclose(fid));
            fwrite(fid,jsonencode(payload),"char");
            clear cleanup
        end

        function value=as_phononwebsite(obj)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:PhononBandStructure:Structure", ...
                    "Structure is required for as_phononwebsite.");
            end
            count=obj.structure.num_sites;
            atomCartesian=zeros(count,3);atomReduced=zeros(count,3);
            atomTypes=strings(count,1);
            for index=1:count
                atomCartesian(index,:)=obj.structure(index).coords;
                atomReduced(index,:)=obj.structure(index).frac_coords;
                atomTypes(index)=obj.structure(index).species_string;
            end
            qpoints=cell2mat(cellfun(@(point)point.frac_coords, ...
                obj.qpoints,UniformOutput=false).');
            distances=zeros(obj.nb_qpoints,1);
            highKeys=zeros(0,1);highValues=strings(0,1);
            for index=1:obj.nb_qpoints
                if ~isempty(obj.qpoints{index}.label)
                    highKeys(end+1,1)=index-1; %#ok<AGROW>
                    highValues(end+1,1)=string(obj.qpoints{index}.label); %#ok<AGROW>
                end
            end
            startIndex=0;lineBreaks=zeros(0,2);pathDistance=0;
            keepHigh=true(numel(highKeys),1);
            for index=2:obj.nb_qpoints
                previous=find(highKeys==index-2,1);
                current=find(highKeys==index-1,1);
                if ~isempty(previous)&&~isempty(current)
                    if highValues(previous)~=highValues(current)
                        highValues(previous)=highValues(previous)+"|"+ ...
                            highValues(current);
                    end
                    keepHigh(current)=false;
                    lineBreaks(end+1,:)=[startIndex,index]; %#ok<AGROW>
                    startIndex=index-1;
                else
                    pathDistance=pathDistance+norm(qpoints(index,:)- ...
                        qpoints(index-1,:));
                end
                distances(index)=pathDistance;
            end
            lineBreaks(end+1,:)=[startIndex,obj.nb_qpoints];
            highSym=cell(sum(keepHigh),2);
            highSym(:,1)=num2cell(highKeys(keepHigh));
            highSym(:,2)=cellstr(highValues(keepHigh));
            eigen=obj.eigendisplacements;
            eigen=eigen/norm(squeeze(eigen(1,1,:,:)),"fro");
            vectors=permute(cat(5,real(eigen),imag(eigen)),[2,1,3,4,5]);
            value=struct( ...
                "lattice",obj.structure.lattice.matrix, ...
                "atom_pos_car",atomCartesian, ...
                "atom_pos_red",atomReduced, ...
                "atom_types",atomTypes, ...
                "repetitions", ...
                kssolv.analysis.matgenlab.phonon. ...
                get_reasonable_repetitions(count), ...
                "natoms",count, ...
                "atom_numbers",obj.structure.atomic_numbers, ...
                "formula",obj.structure.formula, ...
                "name",obj.structure.formula, ...
                "qpoints",qpoints, ...
                "distances",distances, ...
                "line_breaks",lineBreaks, ...
                "highsym_qpts",{highSym}, ...
                "eigenvalues",obj.bands.'*33.35641, ...
                "vectors",vectors);
        end

        function obj=band_reorder(obj)
            if isempty(obj.structure)
                error("KSSOLV:Matgenlab:PhononBandStructure:Structure", ...
                    "Structure is required for band_reorder.");
            end
            order=zeros(obj.nb_qpoints,obj.nb_bands);
            order(1,:)=1:obj.nb_bands;
            masses=zeros(1,obj.structure.num_sites);
            for index=1:numel(masses)
                masses(index)=obj.structure(index).specie.atomic_mass;
            end
            for qpointIndex=2:obj.nb_qpoints
                previous=kssolv.analysis.matgenlab.phonon. ...
                    eigenvectors_from_displacements( ...
                    squeeze(obj.eigendisplacements(:, ...
                    qpointIndex-1,:,:)),masses);
                current=kssolv.analysis.matgenlab.phonon. ...
                    eigenvectors_from_displacements( ...
                    squeeze(obj.eigendisplacements(:, ...
                    qpointIndex,:,:)),masses);
                previous=reshape(previous,obj.nb_bands,obj.nb_bands).';
                current=reshape(current,obj.nb_bands,obj.nb_bands).';
                order(qpointIndex,:)= ...
                    kssolv.analysis.matgenlab.phonon. ...
                    estimate_band_connection( ...
                    previous,current,order(qpointIndex-1,:));
            end
            for qpointIndex=2:obj.nb_qpoints
                obj.eigendisplacements(:,qpointIndex,:,:)= ...
                    obj.eigendisplacements(order(qpointIndex,:), ...
                    qpointIndex,:,:);
                obj.bands(:,qpointIndex)= ...
                    obj.bands(order(qpointIndex,:),qpointIndex);
            end
        end

        function value=as_dict(obj)
            value=as_dict@kssolv.analysis.matgenlab.phonon. ...
                PhononBandStructure(obj);
            value=rmfield(value, ...
                {'nac_frequencies','nac_eigendisplacements'});
            value.has_nac=obj.has_nac;
        end

        function value=eq(first,second)
            value=isa(second, ...
                "kssolv.analysis.matgenlab.phonon." + ...
                "PhononBandStructureSymmLine") && ...
                isequal(size(first.bands),size(second.bands)) && ...
                all(abs(first.bands-second.bands)<= ...
                1e-8+1e-5*abs(second.bands),"all") && ...
                first.lattice_rec==second.lattice_rec && ...
                isequal(first.labels_dict.keys,second.labels_dict.keys) && ...
                isequal(first.structure,second.structure);
        end
        function value=ne(first,second),value=~eq(first,second);end
    end

    methods (Static)
        function obj=from_dict(value)
            lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                from_dict(value.lattice_rec);
            eigen=value.eigendisplacements.real+ ...
                1i*value.eigendisplacements.imag;
            structure=[];
            if isfield(value,"structure")
                structure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
            end
            obj=kssolv.analysis.matgenlab.phonon. ...
                PhononBandStructureSymmLine( ...
                value.qpoints,value.bands,lattice,value.has_nac, ...
                eigen,value.labels_dict,false,structure);
        end
    end

    methods (Access=private)
        function obj=initializeLine( ...
                obj,rawQpoints,frequencies,hasNac,eigen)
            obj.distance=zeros(1,obj.nb_qpoints);
            groups=cell(1,0);current=zeros(1,0);
            previous=obj.qpoints{1};previousLabel=previous.label;
            for index=1:obj.nb_qpoints
                point=obj.qpoints{index};
                if ~isempty(point.label)&&~isempty(previousLabel)
                    if index>1,obj.distance(index)=obj.distance(index-1);end
                else
                    prior=0;if index>1,prior=obj.distance(index-1);end
                    obj.distance(index)=prior+ ...
                        norm(point.cart_coords-previous.cart_coords);
                end
                if ~isempty(point.label)&&~isempty(previousLabel)&& ...
                        ~isempty(current)
                    groups{end+1}=current; %#ok<AGROW>
                    current=zeros(1,0);
                end
                current(end+1)=index; %#ok<AGROW>
                previous=point;previousLabel=point.label;
            end
            if ~isempty(current),groups{end+1}=current;end
            obj.branches=cell(1,numel(groups));
            for index=1:numel(groups)
                group=groups{index};
                obj.branches{index}=struct( ...
                    "start_index",group(1), ...
                    "end_index",group(end), ...
                    "name",string(obj.qpoints{group(1)}.label)+"-"+ ...
                    string(obj.qpoints{group(end)}.label));
            end
            if ~hasNac,return,end
            coordinates=normalizeLineQpoints(rawQpoints);
            frequenciesPairs=cell(0,2);eigenPairs=cell(0,2);
            for index=1:obj.nb_qpoints
                if all(abs(coordinates(index,:))<1e-8)
                    neighbors=[index-1,index+1];
                    for neighbor=neighbors
                        if neighbor>=1&&neighbor<=obj.nb_qpoints&& ...
                                any(abs(coordinates(neighbor,:))>=1e-8)
                            direction=coordinates(neighbor,:)/ ...
                                norm(coordinates(neighbor,:));
                            frequenciesPairs(end+1,:)={direction, ...
                                frequencies(:,index)}; %#ok<AGROW>
                            if obj.has_eigendisplacements
                                eigenPairs(end+1,:)={direction, ...
                                    squeeze(eigen(:,index,:,:))}; %#ok<AGROW>
                            end
                        end
                    end
                end
            end
            obj.nac_frequencies=frequenciesPairs;
            obj.nac_eigendisplacements=eigenPairs;
        end
    end
end

function value=normalizeLineQpoints(input)
if isnumeric(input),value=double(input);
else,value=cell2mat(reshape(input,[],1));
end
value=reshape(value,[],3);
end
