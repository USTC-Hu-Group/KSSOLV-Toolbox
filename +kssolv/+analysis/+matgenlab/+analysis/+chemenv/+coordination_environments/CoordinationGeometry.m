%#ok<*ALIGN,*ISCL>
classdef CoordinationGeometry < handle
    %COORDINATIONGEOMETRY Ideal local coordination environment.
    properties (Constant)
        CSM_SKIP_SEPARATION_PLANE_ALGO=10.0
    end
    properties
        name (1,1) string=""
        alternative_names cell={}
        IUPACsymbol=[]
        IUCrsymbol=[]
        coordination=[]
        central_site (1,3) double=[0 0 0]
        points=[]
        permutations_safe_override (1,1) logical=false
        deactivate (1,1) logical=false
        centroid=[]
        equivalent_indices cell={}
        neighbors_sets_hints cell={}
    end
    properties (Dependent)
        distfactor_max
        coordination_number
        pauling_stability_ratio
        mp_symbol
        ce_symbol
        IUPAC_symbol
        IUPAC_symbol_str
        IUCr_symbol
        IUCr_symbol_str
        number_of_permutations
        algorithms
        permutations
    end
    properties (Access=private)
        mp_symbol_value (1,1) string=""
        solid_angles_value=[]
        faces_value cell={}
        edges_value cell={}
        algorithms_value cell={}
        pauling_stability_ratio_value=[]
    end
    methods
        function obj=CoordinationGeometry(mpSymbol,name,varargin)
            if nargin==0,return,end
            defaults=struct(alternative_names={{}},IUPAC_symbol=[], ...
                IUCr_symbol=[],coordination=[],central_site=[0 0 0], ...
                points=[],solid_angles=[],permutations_safe_override=false, ...
                deactivate=false,faces={{}},edges={{}},algorithms={{}}, ...
                equivalent_indices={{}},neighbors_sets_hints={{}});
            order=["alternative_names","IUPAC_symbol","IUCr_symbol", ...
                "coordination","central_site","points","solid_angles", ...
                "permutations_safe_override","deactivate","faces","edges", ...
                "algorithms","equivalent_indices","neighbors_sets_hints"];
            opts=parseOptions(defaults,order,varargin{:});
            obj.mp_symbol_value=string(mpSymbol);obj.name=string(name);
            obj.alternative_names=toCell(opts.alternative_names);
            obj.IUPACsymbol=nullableString(opts.IUPAC_symbol);
            obj.IUCrsymbol=nullableString(opts.IUCr_symbol);
            obj.coordination=opts.coordination;
            if ~isempty(opts.central_site)
                obj.central_site=reshape(double(opts.central_site),1,3);
            end
            if ~isempty(opts.points),obj.points=double(opts.points);end
            obj.solid_angles_value=reshape(double(opts.solid_angles),1,[]);
            obj.permutations_safe_override=logical(opts.permutations_safe_override);
            obj.deactivate=logical(opts.deactivate);
            obj.faces_value=rowsToCells(opts.faces);
            obj.edges_value=rowsToCells(opts.edges);
            obj.algorithms_value=toCell(opts.algorithms);
            obj.equivalent_indices=rowsToCells(opts.equivalent_indices);
            obj.neighbors_sets_hints=toCell(opts.neighbors_sets_hints);
            if ~isempty(obj.points),obj.centroid=mean(obj.points,1);end
        end
        function value=get.distfactor_max(obj)
            distances=vecnorm(obj.points-obj.central_site,2,2);
            value=max(distances)/min(distances);
        end
        function value=get.coordination_number(obj),value=obj.coordination;end
        function value=get.pauling_stability_ratio(obj)
            if isempty(obj.pauling_stability_ratio_value)
                if ismember(obj.ce_symbol,["S:1","L:2"])
                    obj.pauling_stability_ratio_value=0;
                else
                    dca=min(vecnorm(obj.points-obj.central_site,2,2));
                    delta=permute(obj.points,[1 3 2])- ...
                        permute(obj.points,[3 1 2]);
                    distances=sqrt(sum(delta.^2,3));
                    distances(1:size(distances,1)+1:end)=Inf;
                    anionRadius=min(distances,[],"all")/2;
                    obj.pauling_stability_ratio_value= ...
                        (dca-anionRadius)/anionRadius;
                end
            end
            value=obj.pauling_stability_ratio_value;
        end
        function value=get.mp_symbol(obj),value=obj.mp_symbol_value;end
        function value=get.ce_symbol(obj),value=obj.mp_symbol_value;end
        function value=get.IUPAC_symbol(obj),value=obj.IUPACsymbol;end
        function value=get.IUPAC_symbol_str(obj),value=pythonString(obj.IUPACsymbol);end
        function value=get.IUCr_symbol(obj),value=obj.IUCrsymbol;end
        function value=get.IUCr_symbol_str(obj),value=pythonString(obj.IUCrsymbol);end
        function value=get.algorithms(obj),value=obj.algorithms_value;end
        function value=get.permutations(obj)
            value={};
            if ~isempty(obj.algorithms_value)
                for ii=1:numel(obj.algorithms_value)
                    candidate=obj.algorithms_value{ii}.permutations;
                    if ~isempty(candidate),value=[value,candidate];end %#ok<AGROW>
                end
            end
        end
        function value=get.number_of_permutations(obj)
            if obj.permutations_safe_override||isempty(obj.permutations)
                value=factorial(obj.coordination);
            else,value=numel(obj.permutations);end
        end
        function value=get_coordination_number(obj),value=obj.coordination;end
        function value=is_implemented(obj),value=~isempty(obj.points);end
        function value=get_name(obj),value=obj.name;end
        function value=get_central_site(obj),value=obj.central_site;end
        function value=ref_permutation(obj,permutation)
            permutation=reshape(double(permutation),1,[]);
            % MATLAB callers use one-based permutations. Accept zero-based
            % vectors as a compatibility boundary and preserve their base.
            zeroBased=any(permutation==0);
            eq=obj.equivalent_indices;
            candidates=zeros(numel(eq),numel(permutation));
            for ii=1:numel(eq)
                indices=eq{ii};
                if zeroBased,indices=indices-1;candidates(ii,:)= ...
                        permutation(indices+1);
                else,candidates(ii,:)=permutation(indices);end
            end
            [~,order]=sortrows(candidates);
            value=candidates(order(1),:);
        end
        function value=faces(obj,sites,varargin)
            opts=parseNameValue(struct(permutation=[]),varargin{:});
            coords=siteCoordinates(sites);
            if ~isempty(opts.permutation)
                perm=normalizePermutation(opts.permutation,size(coords,1));
                coords=coords(perm,:);
            end
            value=cellfun(@(face)coords(face,:),obj.faces_value, ...
                "UniformOutput",false);
        end
        function value=edges(obj,sites,varargin)
            opts=parseNameValue(struct(permutation=[],input="sites"),varargin{:});
            if string(opts.input)=="sites",coords=siteCoordinates(sites);
            elseif string(opts.input)=="coords",coords=double(sites);
            else,error("KSSOLV:Matgenlab:ChemEnv:EdgesInput", ...
                    "Invalid input for edges.");end
            if ~isempty(opts.permutation)
                perm=normalizePermutation(opts.permutation,size(coords,1));
                coords=coords(perm,:);
            end
            value=cellfun(@(edge)coords(edge,:),obj.edges_value, ...
                "UniformOutput",false);
        end
        function value=solid_angles(obj,varargin)
            opts=parseNameValue(struct(permutation=[]),varargin{:});
            if isempty(opts.permutation),value=obj.solid_angles_value;
            else
                perm=normalizePermutation(opts.permutation, ...
                    numel(obj.solid_angles_value));
                value=obj.solid_angles_value(perm);
            end
        end
        function value=get_pmeshes(obj,sites,varargin)
            opts=parseNameValue(struct(permutation=[]),varargin{:});
            coords=siteCoordinates(sites);
            if ~isempty(opts.permutation)
                coords=coords(normalizePermutation(opts.permutation, ...
                    size(coords,1)),:);
            end
            centers=cellfun(@(face)mean(coords(face,:),1), ...
                obj.faces_value,"UniformOutput",false);
            nfaces=0;
            for ii=1:numel(obj.faces_value)
                nv=numel(obj.faces_value{ii});
                if nv==3||nv==4,nfaces=nfaces+1;else,nfaces=nfaces+nv;end
            end
            chunks={sprintf('%d\n',size(coords,1)+numel(centers))};
            for ii=1:size(coords,1)
                chunks{end+1}=sprintf('%15.8f %15.8f %15.8f\n', ...
                    coords(ii,:)); %#ok<AGROW>
            end
            for ii=1:numel(centers)
                chunks{end+1}=sprintf('%15.8f %15.8f %15.8f\n', ...
                    centers{ii}); %#ok<AGROW>
            end
            chunks{end+1}=sprintf('%d\n',nfaces);
            nvertices=size(coords,1);
            for iface=1:numel(obj.faces_value)
                face=obj.faces_value{iface};
                if numel(face)==3||numel(face)==4
                    chunks{end+1}=sprintf('%d\n',numel(face)+1); %#ok<AGROW>
                    wire=face-1;
                    chunks{end+1}=sprintf('%d\n',wire); %#ok<AGROW>
                    chunks{end+1}=sprintf('%d\n',wire(1)); %#ok<AGROW>
                else
                    for jj=1:numel(face)
                        next=mod(jj,numel(face))+1;
                        chunks{end+1}=sprintf('4\n%d\n%d\n%d\n%d\n', ...
                            nvertices+iface-1,face(jj)-1,face(next)-1, ...
                            nvertices+iface-1); %#ok<AGROW>
                    end
                end
            end
            value={struct(pmesh_string=string([chunks{:}]))};
        end
        function value=as_dict(obj)
            algos=cellfun(@(x)x.as_dict(),obj.algorithms_value, ...
                "UniformOutput",false);
            hints=cellfun(@(x)x.as_dict(),obj.neighbors_sets_hints, ...
                "UniformOutput",false);
            value=struct(mp_symbol=obj.mp_symbol_value,name=obj.name, ...
                alternative_names={obj.alternative_names}, ...
                IUPAC_symbol=obj.IUPACsymbol,IUCr_symbol=obj.IUCrsymbol, ...
                coordination=obj.coordination,central_site=obj.central_site, ...
                points=obj.points,solid_angles=obj.solid_angles_value, ...
                deactivate=obj.deactivate,x_faces={subtractOne(obj.faces_value)}, ...
                x_edges={subtractOne(obj.edges_value)},x_algorithms={algos}, ...
                equivalent_indices={subtractOne(obj.equivalent_indices)}, ...
                neighbors_sets_hints={hints});
        end
        function value=char(obj)
            symbol="";
            if ~isempty(obj.IUPACsymbol)
                symbol=" (IUPAC: "+string(obj.IUPACsymbol);
                if ~isempty(obj.IUCrsymbol)
                    symbol=symbol+" || IUCr: "+string(obj.IUCrsymbol)+")";
                else,symbol=symbol+")";end
            elseif ~isempty(obj.IUCrsymbol)
                symbol=" (IUCr: "+string(obj.IUCrsymbol)+")";
            end
            value=sprintf('Coordination geometry type : %s%s\n\n', ...
                obj.name,symbol);
            value=[value,sprintf('  - coordination number : %s\n', ...
                pythonString(obj.coordination))];
            if isempty(obj.points)
                value=[value,'... not yet implemented',newline];
            else
                value=[value,'  - list of points :',newline];
                for ii=1:size(obj.points,1)
                    value=[value,'    - ',formatList(obj.points(ii,:)), ...
                        newline]; %#ok<AGROW>
                end
            end
            value=[value,'------------------------------------------------------------', ...
                newline];
        end
        function value=string(obj),value=string(char(obj));end
    end
    methods (Static)
        function obj=from_dict(value)
            algorithms={};
            raw=fieldOr(value,"x_algorithms",fieldOr(value,"_algorithms",[]));
            for item=toCell(raw)
                data=item{1};className=string(fieldOr(data,"x_class",""));
                if className=="ExplicitPermutationsAlgorithm"
                    algorithms{end+1}=kssolv.analysis.matgenlab.analysis. ...
                        chemenv.coordination_environments. ...
                        ExplicitPermutationsAlgorithm.from_dictWire(data); %#ok<AGROW>
                else
                    algorithms{end+1}=kssolv.analysis.matgenlab.analysis. ...
                        chemenv.coordination_environments. ...
                        SeparationPlane.from_dict(data); %#ok<AGROW>
                end
            end
            hints={};
            for item=toCell(fieldOr(value,"neighbors_sets_hints",[]))
                hints{end+1}=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments. ...
                    CoordinationGeometryNeighborsSetsHints.from_dict(item{1}); %#ok<AGROW>
            end
            faces=addOneRows(fieldOr(value,"x_faces", ...
                fieldOr(value,"_faces",[])));
            edges=addOneRows(fieldOr(value,"x_edges", ...
                fieldOr(value,"_edges",[])));
            eq=addOneRows(fieldOr(value,"equivalent_indices",[]));
            solidAngles=fieldOr(value,"solid_angles",[]);
            if isempty(solidAngles)&&~isempty(value.coordination)
                solidAngles=repmat(4*pi/value.coordination, ...
                    1,value.coordination);
            end
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.CoordinationGeometry( ...
                value.mp_symbol,value.name, ...
                "alternative_names",fieldOr(value,"alternative_names",{}), ...
                "IUPAC_symbol",fieldOr(value,"IUPAC_symbol",[]), ...
                "IUCr_symbol",fieldOr(value,"IUCr_symbol",[]), ...
                "coordination",fieldOr(value,"coordination",[]), ...
                "central_site",fieldOr(value,"central_site",[0 0 0]), ...
                "points",fieldOr(value,"points",[]), ...
                "solid_angles",solidAngles, ...
                "deactivate",fieldOr(value,"deactivate",false), ...
                "faces",faces,"edges",edges,"algorithms",algorithms, ...
                "equivalent_indices",eq,"neighbors_sets_hints",hints);
        end
    end
end
function opts=parseOptions(defaults,order,varargin)
opts=defaults;if isempty(varargin),return,end
firstName=find(cellfun(@(x)ischar(x)||isstring(x),varargin),1);
if isempty(firstName),firstName=numel(varargin)+1;end
for ii=1:min(firstName-1,numel(order)),opts.(order(ii))=varargin{ii};end
for ii=firstName:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function opts=parseNameValue(defaults,varargin)
opts=defaults;
if numel(varargin)==1&&~(ischar(varargin{1})||isstring(varargin{1}))
    opts.permutation=varargin{1};return
end
for ii=1:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function out=rowsToCells(value)
if isempty(value),out={};elseif iscell(value),out=value(:).'; ...
else,out=mat2cell(double(value),ones(1,size(value,1)),size(value,2));end
out=cellfun(@(x)reshape(double(x),1,[]),out,"UniformOutput",false);
end
function out=toCell(value)
if isempty(value),out={};elseif iscell(value),out=value(:).'; ...
elseif isstruct(value),out=num2cell(value(:)).';else,out=num2cell(value(:)).';end
end
function out=fieldOr(value,name,default)
if isfield(value,name),out=value.(name);else,out=default;end
end
function out=nullableString(value)
if isempty(value),out=[];else,out=string(value);end
end
function out=pythonString(value)
if isempty(value),out="None";elseif isstring(value)||ischar(value),out=string(value);
elseif isnumeric(value)&&isscalar(value)&&value==fix(value),out=string(value);
else,out=string(value);end
end
function value=formatList(row)
parts=strings(1,numel(row));
for ii=1:numel(row)
    if row(ii)==fix(row(ii)),parts(ii)=sprintf('%.1f',row(ii));
    else,parts(ii)=sprintf('%.15g',row(ii));end
end
value=char("["+strjoin(parts,", ")+"]");
end
function coords=siteCoordinates(sites)
if isnumeric(sites),coords=double(sites);return,end
if iscell(sites)
    coords=zeros(numel(sites),3);
    for ii=1:numel(sites),coords(ii,:)=reshape(double(sites{ii}.coords),1,3);end
else
    coords=zeros(numel(sites),3);
    for ii=1:numel(sites),coords(ii,:)=reshape(double(sites(ii).coords),1,3);end
end
end
function perm=normalizePermutation(value,n)
perm=reshape(double(value),1,[]);
if any(perm==0),perm=perm+1;end
if numel(perm)~=n||any(sort(perm)~=(1:n))
    error("KSSOLV:Matgenlab:ChemEnv:Permutation","Invalid permutation.");
end
end
function out=subtractOne(value),out=cellfun(@(x)x-1,value,"UniformOutput",false);end
function out=addOneRows(value),out=rowsToCells(value);out=cellfun(@(x)x+1,out,"UniformOutput",false);end
