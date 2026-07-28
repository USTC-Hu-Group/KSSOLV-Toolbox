classdef HeisenbergModel < kssolv.analysis.matgenlab.util.MSONable
    %HEISENBERGMODEL Serializable fitted Heisenberg model.
    %#ok<*PROP>
    properties
        formula
        structures
        energies
        cutoff
        tol
        sgraphs
        unique_site_ids
        wyckoff_ids
        nn_interactions
        dists
        ex_mat
        ex_params
        javg
        igraph
    end
    methods
        function obj=HeisenbergModel(formula,structures,energies,cutoff,tol, ...
                sgraphs,uniqueSiteIds,wyckoffIds,nnInteractions,dists, ...
                exMat,exParams,javg,igraph)
            if nargin==0,return,end
            if nargin<2,structures={};end
            if nargin<3,energies=[];end
            if nargin<4,cutoff=[];end
            if nargin<5,tol=[];end
            if nargin<6,sgraphs={};end
            if nargin<7,uniqueSiteIds=[];end
            if nargin<8,wyckoffIds=[];end
            if nargin<9,nnInteractions=struct();end
            if nargin<10,dists=struct();end
            if nargin<11,exMat=table();end
            if nargin<12,exParams=[];end
            if nargin<13,javg=[];end
            if nargin<14,igraph=[];end
            obj.formula=formula;obj.structures=structures;obj.energies=energies;
            obj.cutoff=cutoff;obj.tol=tol;obj.sgraphs=sgraphs;
            obj.unique_site_ids=uniqueSiteIds;obj.wyckoff_ids=wyckoffIds;
            obj.nn_interactions=nnInteractions;obj.dists=dists;
            obj.ex_mat=exMat;obj.ex_params=exParams;obj.javg=javg;
            obj.igraph=igraph;
        end
        function value=asDict(obj)
            structures=cellfun(@(item)item.as_dict(),obj.structures, ...
                "UniformOutput",false);
            graphs=cellfun(@(item)item.as_dict(),obj.sgraphs, ...
                "UniformOutput",false);
            value=struct();
            value.x_module="pymatgen.analysis.magnetism.heisenberg";
            value.x_class="HeisenbergModel";value.x_version="0.1";
            value.formula=obj.formula;value.structures=structures;
            value.energies=obj.energies;value.cutoff=obj.cutoff;
            value.tol=obj.tol;value.sgraphs=graphs;value.dists=obj.dists;
            value.ex_params=mapEntries(obj.ex_params);value.javg=obj.javg;
            value.igraph=obj.igraph.as_dict();
            value.ex_mat=tableStruct(obj.ex_mat);
            value.nn_interactions=interactionStruct(obj.nn_interactions);
            value.unique_site_ids=mapEntries(obj.unique_site_ids);
            value.wyckoff_ids=mapEntries(obj.wyckoff_ids);
        end
        function value=as_dict(obj),value=obj.asDict();end
    end
    methods (Static)
        function obj=from_dict(value)
            structures=cell(1,numel(value.structures));
            for index=1:numel(structures)
                structures{index}=kssolv.analysis.matgenlab.core. ...
                    Structure.from_dict(value.structures{index});
            end
            graphs=cell(1,numel(value.sgraphs));
            for index=1:numel(graphs)
                graphs{index}=kssolv.analysis.matgenlab.core. ...
                    StructureGraph.from_dict(value.sgraphs{index});
            end
            interactions=struct();
            labels=fieldnames(value.nn_interactions);
            for index=1:numel(labels)
                interactions.(labels{index})=entriesMap( ...
                    value.nn_interactions.(labels{index}),"double","double");
            end
            obj=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergModel(value.formula,structures,value.energies, ...
                value.cutoff,value.tol,graphs, ...
                entriesMap(value.unique_site_ids,"char","double"), ...
                entriesMap(value.wyckoff_ids,"double","char"),interactions, ...
                value.dists,structTable(value.ex_mat), ...
                entriesMap(value.ex_params,"char","double"),value.javg, ...
                kssolv.analysis.matgenlab.core.StructureGraph.from_dict( ...
                value.igraph));
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.analysis.magnetism. ...
                HeisenbergModel.from_dict(value);
        end
    end
end

function value=mapEntries(map)
if isempty(map),value=cell(0,2);return,end
names=map.keys();value=cell(numel(names),2);
for index=1:numel(names),value(index,:)={names{index},map(names{index})};end
end
function map=entriesMap(entries,keyType,valueType)
map=containers.Map("KeyType",keyType,"ValueType",valueType);
if isempty(entries),return,end
if isstruct(entries)&&isfield(entries,"keys")
    entries=[entries.keys(:),entries.values(:)];
end
for index=1:size(entries,1)
    key=entries{index,1};value=entries{index,2};
    if keyType=="double",key=double(key);else,key=char(string(key));end
    if valueType=="double",value=double(value);else,value=char(string(value));end
    map(key)=value;
end
end
function value=interactionStruct(input)
value=struct();names=fieldnames(input);
for index=1:numel(names)
    value.(names{index})=mapEntries(input.(names{index}));
end
end
function value=tableStruct(input)
value=struct(variable_names=string(input.Properties.VariableNames), ...
    data=input{:,:});
end
function value=structTable(input)
if istable(input),value=input;return,end
value=array2table(input.data,"VariableNames",cellstr(input.variable_names));
end
