%#ok<*ALIGN,*ISCL>
classdef SeparationPlane < ...
        kssolv.analysis.matgenlab.analysis.chemenv.coordination_environments.AbstractChemenvAlgorithm
    %SEPARATIONPLANE Plane-separation permutation algorithm.
    %
    % Public MATLAB indices are one-based. MSON dictionaries use pymatgen's
    % zero-based wire convention.
    properties
        mirror_plane (1,1) logical=false
        plane_points (1,:) double=[]
        point_groups (1,2) cell={{},{}}
        ordered_plane (1,1) logical=false
        ordered_point_groups (1,2) logical=[false false]
        explicit_permutations cell={}
        explicit_optimized_permutations cell={}
        multiplicity=[]
        other_plane_points cell={}
        minimum_number_of_points=[]
        maximum_number_of_points (1,1) double=0
        separation (1,3) double=[0 0 0]
    end
    properties (Dependent)
        permutations
        ref_separation_perm
        argsorted_ref_separation_perm
    end
    properties (Access=private)
        safe_permutations_cache cell={}
        safe_permutations_key=[]
    end
    methods
        function obj=SeparationPlane(planePoints,varargin)
            obj@kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractChemenvAlgorithm( ...
                "SEPARATION_PLANE");
            if nargin==0,return,end
            defaults=struct(mirror_plane=false,ordered_plane=false, ...
                point_groups={{[],[]}},ordered_point_groups=[false false], ...
                explicit_permutations={{}},minimum_number_of_points=[], ...
                explicit_optimized_permutations={{}},multiplicity=[], ...
                other_plane_points={{}});
            opts=parseOptions(defaults,varargin{:});
            obj.plane_points=row(planePoints);
            obj.mirror_plane=logical(opts.mirror_plane);
            obj.ordered_plane=logical(opts.ordered_plane);
            obj.point_groups=twoCells(opts.point_groups);
            if numel(obj.point_groups{1})>numel(obj.point_groups{2})
                error("KSSOLV:Matgenlab:ChemEnv:SeparationPlane", ...
                    "The first point group cannot exceed the second.");
            end
            obj.ordered_point_groups=reshape(logical(opts.ordered_point_groups),1,[]);
            obj.explicit_permutations=rowsToCells(opts.explicit_permutations);
            obj.explicit_optimized_permutations= ...
                rowsToCells(opts.explicit_optimized_permutations);
            obj.multiplicity=opts.multiplicity;
            obj.other_plane_points=rowsToCells(opts.other_plane_points);
            obj.minimum_number_of_points=opts.minimum_number_of_points;
            obj.maximum_number_of_points=numel(obj.plane_points);
            obj.separation=[numel(obj.point_groups{1}), ...
                numel(obj.plane_points),numel(obj.point_groups{2})];
        end
        function value=get.permutations(obj)
            if ~isempty(obj.explicit_optimized_permutations)
                value=obj.explicit_optimized_permutations;
            else,value=obj.explicit_permutations;end
        end
        function value=get.ref_separation_perm(obj)
            value=[obj.point_groups{1},obj.plane_points,obj.point_groups{2}];
        end
        function value=get.argsorted_ref_separation_perm(obj)
            [~,value]=sort(obj.ref_separation_perm);
        end
        function [value,obj]=safe_separation_permutations(obj,varargin)
            defaults=struct(ordered_plane=false, ...
                ordered_point_groups=[false false],add_opposite=false);
            opts=parseOptions(defaults,varargin{:});
            key=[logical(opts.ordered_plane), ...
                reshape(logical(opts.ordered_point_groups),1,[]), ...
                logical(opts.add_opposite)];
            if isequal(key,obj.safe_permutations_key)&& ...
                    ~isempty(obj.safe_permutations_cache)
                value=obj.safe_permutations_cache;return
            end
            n0=numel(obj.point_groups{1});np=numel(obj.plane_points);
            n1=numel(obj.point_groups{2});
            s0=1:n0;plane=n0+(1:np);s1=n0+np+(1:n1);
            if opts.ordered_plane&&obj.ordered_plane
                planePerms=cyclicPermutations(plane);
            else,planePerms=allPermutations(plane);end
            if opts.ordered_point_groups(1)&&obj.ordered_point_groups(1)
                side0Perms=cyclicPermutations(s0);
            else,side0Perms=allPermutations(s0);end
            if opts.ordered_point_groups(2)&&obj.ordered_point_groups(2)
                side1Perms=cyclicPermutations(s1);
            else,side1Perms=allPermutations(s1);end
            value=cell(0,1);
            for i0=1:numel(side0Perms)
                for ip=1:numel(planePerms)
                    for i1=1:numel(side1Perms)
                        value{end+1,1}=[side0Perms{i0},planePerms{ip}, ...
                            side1Perms{i1}]; %#ok<AGROW>
                        if opts.add_opposite
                            value{end+1,1}=[side1Perms{i1},planePerms{ip}, ...
                                side0Perms{i0}]; %#ok<AGROW>
                        end
                    end
                end
            end
            obj.safe_permutations_cache=value;
            obj.safe_permutations_key=key;
        end
        function value=as_dict(obj)
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.coordination_geometries", ...
                x_class="SeparationPlane", ...
                plane_points=obj.plane_points-1, ...
                mirror_plane=obj.mirror_plane, ...
                ordered_plane=obj.ordered_plane, ...
                point_groups={{obj.point_groups{1}-1,obj.point_groups{2}-1}}, ...
                ordered_point_groups=obj.ordered_point_groups, ...
                explicit_permutations={subtractOne(obj.explicit_permutations)}, ...
                explicit_optimized_permutations={subtractOne( ...
                obj.explicit_optimized_permutations)}, ...
                multiplicity=obj.multiplicity, ...
                other_plane_points={subtractOne(obj.other_plane_points)}, ...
                minimum_number_of_points=obj.minimum_number_of_points);
        end
        function value=char(obj)
            value=sprintf(['Separation plane algorithm with the following ' ...
                'reference separation :\\n[%s] | [%s] | [%s]'], ...
                pyList(obj.point_groups{1}-1),pyList(obj.plane_points-1), ...
                pyList(obj.point_groups{2}-1));
        end
        function value=string(obj),value=string(char(obj));end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.SeparationPlane( ...
                row(value.plane_points)+1, ...
                "mirror_plane",value.mirror_plane, ...
                "ordered_plane",value.ordered_plane, ...
                "point_groups",addOneNested(value.point_groups), ...
                "ordered_point_groups",value.ordered_point_groups, ...
                "explicit_permutations",addOneRows(fieldOr(value, ...
                "explicit_permutations",[])), ...
                "explicit_optimized_permutations",addOneRows(fieldOr(value, ...
                "explicit_optimized_permutations",[])), ...
                "multiplicity",fieldOr(value,"multiplicity",[]), ...
                "other_plane_points",addOneRows(fieldOr(value, ...
                "other_plane_points",[])), ...
                "minimum_number_of_points",value.minimum_number_of_points);
        end
    end
end
function opts=parseOptions(defaults,varargin)
opts=defaults;
if isempty(varargin),return,end
if isstruct(varargin{1})
    names=fieldnames(varargin{1});
    for ii=1:numel(names),opts.(names{ii})=varargin{1}.(names{ii});end
    varargin(1)=[];
end
for ii=1:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function out=twoCells(value)
if iscell(value),out=reshape(value,1,[]);else,out={value(1,:),value(2,:)};end
out={row(out{1}),row(out{2})};
end
function out=rowsToCells(value)
if isempty(value),out={};elseif iscell(value),out=value(:).'; ...
else,out=mat2cell(value,ones(1,size(value,1)),size(value,2));end
out=cellfun(@row,out,"UniformOutput",false);
end
function out=allPermutations(value)
if isempty(value),out={[]};elseif numel(value)==1,out={value};else
    p=perms(value);out=mat2cell(p,ones(1,size(p,1)),size(p,2));end
end
function out=cyclicPermutations(value)
if numel(value)<=1,out={value};return,end
out=cell(1,2*numel(value));rev=fliplr(value);
for ii=0:numel(value)-1
    out{ii+1}=circshift(value,[0 ii]);
    out{numel(value)+ii+1}=circshift(rev,[0 ii]);
end
end
function out=subtractOne(value),out=cellfun(@(x)x-1,value,"UniformOutput",false);end
function out=addOneRows(value),out=rowsToCells(value);out=cellfun(@(x)x+1,out,"UniformOutput",false);end
function out=addOneNested(value),out=twoCells(value);out={out{1}+1,out{2}+1};end
function out=fieldOr(value,name,default)
if isfield(value,name),out=value.(name);else,out=default;end
end
function value=row(value),value=reshape(double(value),1,[]);end
function text=pyList(value)
if isempty(value),text="[]";else,text="["+strjoin(string(value),", ")+"]";end
text=char(text);
end
