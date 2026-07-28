classdef GruneisenPhononBandStructureSymmLine < ...
        kssolv.analysis.matgenlab.phonon.GruneisenPhononBandStructure
    %GRUNEISENPHONONBANDSTRUCTURESYMMLINE Symmetry-line Gruneisen bands.

    properties (SetAccess=private)
        distance (1,:) double
        branches cell
    end

    methods
        function obj=GruneisenPhononBandStructureSymmLine( ...
                qpoints,frequencies,gruneisenParameters,lattice, ...
                eigendisplacements,labelsDict,coordsAreCartesian,structure)
            if nargin<5,eigendisplacements=[];end
            if nargin<6,labelsDict=[];end
            if nargin<7,coordsAreCartesian=false;end
            if nargin<8,structure=[];end
            obj@kssolv.analysis.matgenlab.phonon. ...
                GruneisenPhononBandStructure( ...
                qpoints,frequencies,gruneisenParameters,lattice, ...
                eigendisplacements,labelsDict,coordsAreCartesian,structure);
            [obj.distance,obj.branches]=initializeSymmetryLine(obj);
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
                GruneisenPhononBandStructureSymmLine( ...
                value.qpoints,value.bands,value.gruneisen,lattice, ...
                eigen,value.labels_dict,false,structure);
        end
    end
end

function [distance,branches]=initializeSymmetryLine(obj)
distance=zeros(1,obj.nb_qpoints);
groups=cell(1,0);
currentGroup=zeros(1,0);
previous=obj.qpoints{1};
previousLabel=previous.label;
for index=1:obj.nb_qpoints
    point=obj.qpoints{index};
    if ~isempty(point.label) && ~isempty(previousLabel)
        if index>1,distance(index)=distance(index-1);end
    else
        prior=0;
        if index>1,prior=distance(index-1);end
        distance(index)=prior+norm(point.cart_coords-previous.cart_coords);
    end
    if ~isempty(point.label) && ~isempty(previousLabel) && ...
            ~isempty(currentGroup)
        groups{end+1}=currentGroup; %#ok<AGROW>
        currentGroup=zeros(1,0);
    end
    currentGroup(end+1)=index; %#ok<AGROW>
    previous=point;
    previousLabel=point.label;
end
if ~isempty(currentGroup),groups{end+1}=currentGroup;end
branches=cell(1,numel(groups));
for index=1:numel(groups)
    group=groups{index};
    branches{index}=makeBranch(group(1),group(end), ...
        obj.qpoints{group(1)}.label,obj.qpoints{group(end)}.label);
end
end

function value=makeBranch(startIndex,endIndex,startLabel,endLabel)
if isempty(startLabel),startLabel="";end
if isempty(endLabel),endLabel="";end
value=struct( ...
    "start_index",startIndex, ...
    "end_index",endIndex, ...
    "name",string(startLabel)+"-"+string(endLabel));
end
