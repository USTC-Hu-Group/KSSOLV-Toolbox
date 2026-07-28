classdef PhononBandStructure
    %PHONONBANDSTRUCTURE Generic reciprocal-space phonon bands.

    properties (SetAccess=protected)
        lattice_rec
        qpoints cell
        structure=[]
        eigendisplacements
        labels_dict
        bands double
        nb_bands (1,1) double
        nb_qpoints (1,1) double
        nac_frequencies cell
        nac_eigendisplacements cell
    end

    properties (Dependent,SetAccess=private)
        has_nac
        has_eigendisplacements
    end

    methods
        function obj=PhononBandStructure( ...
                qpoints,frequencies,lattice,nacFrequencies, ...
                eigendisplacements,nacEigendisplacements, ...
                labelsDict,coordsAreCartesian,structure)
            if nargin<4,nacFrequencies=[];end
            if nargin<5 || isempty(eigendisplacements)
                eigendisplacements=[];
            end
            if nargin<6,nacEigendisplacements=[];end
            if nargin<7 || isempty(labelsDict)
                labelsDict=containers.Map("KeyType","char","ValueType","any");
            end
            if nargin<8,coordsAreCartesian=false;end
            if nargin<9,structure=[];end
            obj.lattice_rec=lattice;
            obj.structure=structure;
            obj.eigendisplacements=eigendisplacements;
            labels=normalizePhononLabels(labelsDict);
            coordinates=normalizeQpoints(qpoints);
            obj.labels_dict=containers.Map( ...
                "KeyType","char","ValueType","any");
            obj.qpoints=cell(1,size(coordinates,1));
            labelKeys=labels.keys;
            for index=1:size(coordinates,1)
                label=[];
                for keyIndex=1:numel(labelKeys)
                    key=labelKeys{keyIndex};
                    target=labels(key);
                    if isa(target, ...
                            "kssolv.analysis.matgenlab.electronic_structure.Kpoint")
                        if coordsAreCartesian
                            target=target.cart_coords;
                        else
                            target=target.frac_coords;
                        end
                    end
                    if norm(coordinates(index,:)-reshape(target,1,3))<1e-4
                        label=string(key);
                        point=kssolv.analysis.matgenlab. ...
                            electronic_structure.Kpoint( ...
                            coordinates(index,:),lattice, ...
                            false,coordsAreCartesian,label);
                        obj.labels_dict(key)=point;
                    end
                end
                obj.qpoints{index}=kssolv.analysis.matgenlab. ...
                    electronic_structure.Kpoint( ...
                    coordinates(index,:),lattice, ...
                    false,coordsAreCartesian,label);
            end
            obj.bands=double(frequencies);
            obj.nb_bands=size(obj.bands,1);
            obj.nb_qpoints=numel(obj.qpoints);
            % The upstream force-constant mesh adapter historically returns
            % a qpoint-by-mode matrix. Preserve that accepted wire shape even
            % though most constructors use mode-by-qpoint data.
            obj.nac_frequencies=normalizeNacPairs(nacFrequencies);
            obj.nac_eigendisplacements= ...
                normalizeNacPairs(nacEigendisplacements);
        end

        function value=get.has_nac(obj),value=~isempty(obj.nac_frequencies);end
        function value=get.has_eigendisplacements(obj)
            value=~isempty(obj.eigendisplacements);
        end

        function value=get_gamma_point(obj)
            value=[];
            for index=1:obj.nb_qpoints
                if all(abs(obj.qpoints{index}.frac_coords)<1e-8)
                    value=obj.qpoints{index};return
                end
            end
        end

        function [qpoint,value]=min_freq(obj)
            [value,linear]=min(obj.bands,[],"all");
            [~,index]=ind2sub(size(obj.bands),linear);
            qpoint=obj.qpoints{index};
        end

        function [qpoint,value]=max_freq(obj)
            [value,linear]=max(obj.bands,[],"all");
            [~,index]=ind2sub(size(obj.bands),linear);
            qpoint=obj.qpoints{index};
        end

        function value=width(obj,withImaginary)
            if nargin<2,withImaginary=false;end
            if withImaginary
                value=max(obj.bands,[],"all")-min(obj.bands,[],"all");
            else
                selected=obj.bands(obj.bands>=0);
                value=max(selected)-min(selected);
            end
        end

        function value=has_imaginary_freq(obj,tolerance)
            if nargin<2,tolerance=0.01;end
            [~,minimum]=obj.min_freq();
            value=minimum+tolerance<0;
        end

        function value=has_imaginary_gamma_freq(obj,tolerance)
            if nargin<2,tolerance=0.01;end
            value=false;
            for index=1:obj.nb_qpoints
                if norm(obj.qpoints{index}.frac_coords)<tolerance && ...
                        any(obj.bands(:,index)<-tolerance)
                    value=true;return
                end
            end
        end

        function value=get_nac_frequencies_along_dir(obj,direction)
            value=nacAlongDirection(obj.nac_frequencies,direction);
        end

        function value=get_nac_eigendisplacements_along_dir(obj,direction)
            value=nacAlongDirection(obj.nac_eigendisplacements,direction);
        end

        function value=asr_breaking(obj,tolerance)
            if nargin<2,tolerance=1e-5;end
            value=[];
            for pointIndex=1:obj.nb_qpoints
                if all(abs(obj.qpoints{pointIndex}.frac_coords)<1e-8)
                    modes=1:min(3,obj.nb_bands);
                    if obj.has_eigendisplacements
                        identified=zeros(1,0);
                        for bandIndex=1:obj.nb_bands
                            eigen=squeeze(obj.eigendisplacements( ...
                                bandIndex,pointIndex,:,:));
                            if size(eigen,1)<=1 || ...
                                    max(abs(eigen(2:end,:)-eigen(1,:)), ...
                                    [],"all")<tolerance
                                identified(end+1)=bandIndex; %#ok<AGROW>
                            end
                        end
                        if numel(identified)==3,modes=identified;end
                    end
                    value=obj.bands(modes,pointIndex);
                    return
                end
            end
        end

        function value=as_dict(obj)
            points=cellfun(@(point)point.frac_coords,obj.qpoints, ...
                UniformOutput=false);
            labels=containers.Map("KeyType","char","ValueType","any");
            keys=obj.labels_dict.keys;
            for index=1:numel(keys)
                labels(keys{index})=obj.labels_dict(keys{index}).frac_coords;
            end
            nacFrequencies=cell(size(obj.nac_frequencies,1),1);
            for index=1:size(obj.nac_frequencies,1)
                nacFrequencies{index}={obj.nac_frequencies{index,1}, ...
                    obj.nac_frequencies{index,2}};
            end
            nacEigen=cell(size(obj.nac_eigendisplacements,1),1);
            for index=1:size(obj.nac_eigendisplacements,1)
                eigen=obj.nac_eigendisplacements{index,2};
                nacEigen{index}={obj.nac_eigendisplacements{index,1}, ...
                    struct("real",real(eigen),"imag",imag(eigen))};
            end
            value=struct( ...
                "x_module","pymatgen.phonon.bandstructure", ...
                "x_class",phononBandClassName(obj), ...
                "lattice_rec",obj.lattice_rec.as_dict(), ...
                "qpoints",{points}, ...
                "bands",obj.bands, ...
                "labels_dict",labels, ...
                "eigendisplacements",struct( ...
                    "real",real(obj.eigendisplacements), ...
                    "imag",imag(obj.eigendisplacements)), ...
                "nac_eigendisplacements",{nacEigen}, ...
                "nac_frequencies",{nacFrequencies});
            if ~isempty(obj.structure)
                value.structure=obj.structure.as_dict();
            end
        end
        function value=asDict(obj),value=obj.as_dict();end
    end

    methods (Static)
        function obj=from_dict(value)
            lattice=kssolv.analysis.matgenlab.core.Lattice. ...
                from_dict(value.lattice_rec);
            eigen=value.eigendisplacements.real+ ...
                1i*value.eigendisplacements.imag;
            nacEigen=decodeNacEigen(value.nac_eigendisplacements);
            nacFreq=decodeNacFrequency(value.nac_frequencies);
            structure=[];
            if isfield(value,"structure")
                structure=kssolv.analysis.matgenlab.core.Structure. ...
                    from_dict(value.structure);
            end
            obj=kssolv.analysis.matgenlab.phonon.PhononBandStructure( ...
                value.qpoints,value.bands,lattice,nacFreq,eigen, ...
                nacEigen,value.labels_dict,false,structure);
        end
    end
end

function value=normalizeQpoints(input)
if isnumeric(input),value=double(input);
elseif iscell(input),value=cell2mat(reshape(input,[],1));
else,error("KSSOLV:Matgenlab:PhononBandStructure:Qpoints", ...
        "qpoints must be numeric or a cell array.");
end
value=reshape(value,[],3);
end

function value=normalizePhononLabels(input)
if isa(input,"containers.Map"),value=input;
elseif isstruct(input)
    names=fieldnames(input);
    values=cellfun(@(name)input.(name),names,UniformOutput=false);
    value=containers.Map(names,values,UniformValues=false);
else,error("KSSOLV:Matgenlab:PhononBandStructure:Labels", ...
        "labels_dict must be a struct or containers.Map.");
end
end

function value=normalizeNacPairs(input)
if isempty(input),value=cell(0,2);return,end
if iscell(input) && size(input,2)==2 && ...
        ~iscell(input{1,1})
    rows=input;
elseif iscell(input)
    rows=cell(numel(input),2);
    for index=1:numel(input)
        pair=input{index};
        if iscell(pair),rows(index,:)=pair;
        else,rows(index,:)={pair(1,:),pair(2,:)};
        end
    end
else
    error("KSSOLV:Matgenlab:PhononBandStructure:Nac", ...
        "NAC data must be supplied as direction/value pairs.");
end
value=cell(size(rows));
for index=1:size(rows,1)
    direction=reshape(double(rows{index,1}),1,[]);
    value{index,1}=direction/norm(direction);
    value{index,2}=rows{index,2};
end
end

function value=nacAlongDirection(pairs,direction)
direction=reshape(double(direction),1,[]);
direction=direction/norm(direction);
value=[];
for index=1:size(pairs,1)
    if all(abs(direction-pairs{index,1})<=1e-8+ ...
            1e-5*abs(pairs{index,1}))
        value=pairs{index,2};return
    end
end
end

function value=decodeNacFrequency(input)
if isempty(input),value=cell(0,2);return,end
value=cell(numel(input),2);
for index=1:numel(input)
    pair=input{index};
    value(index,:)={pair{1},pair{2}};
end
end

function value=decodeNacEigen(input)
if isempty(input),value=cell(0,2);return,end
value=cell(numel(input),2);
for index=1:numel(input)
    pair=input{index};
    value(index,:)={pair{1},pair{2}.real+1i*pair{2}.imag};
end
end

function value=phononBandClassName(obj)
parts=split(string(class(obj)),".");
value=parts(end);
end
