%#ok<*ALIGN,*ISCL>
classdef ChemicalEnvironments < handle
    %CHEMICALENVIRONMENTS CSM results for one site/neighbors set.
    properties (SetAccess=private)
        coord_geoms
    end
    methods
        function obj=ChemicalEnvironments(coordGeoms)
            obj.coord_geoms=containers.Map("KeyType","char","ValueType","any");
            if nargin>0&&~isempty(coordGeoms)
                error("KSSOLV:Matgenlab:NotImplemented", ...
                    "Construction with coord_geoms is not supported upstream.");
            end
        end
        function value=minimum_geometry(obj,varargin)
            opts=parseOptions(struct(symmetry_measure_type=[],max_csm=[]), ...
                varargin{:});
            values=obj.minimum_geometries("n",1, ...
                "symmetry_measure_type",opts.symmetry_measure_type, ...
                "max_csm",opts.max_csm);
            if isempty(values),value=[];else,value=values{1};end
        end
        function value=minimum_geometries(obj,varargin)
            opts=parseOptions(struct(n=[],symmetry_measure_type=[], ...
                max_csm=[]),varargin{:});
            symbols=obj.coord_geoms.keys;
            if isempty(symbols),value={};return,end
            metric=string(opts.symmetry_measure_type);
            if isempty(metric)||all(strlength(metric)==0)
                metric="csm_wcs_ctwcc";
            end
            measures=zeros(1,numel(symbols));
            for ii=1:numel(symbols)
                data=obj.coord_geoms(symbols{ii});
                measures(ii)=data.other_symmetry_measures.(char(metric));
            end
            [measures,order]=sort(measures);
            if ~isempty(opts.max_csm),order=order(measures<=opts.max_csm);end
            if ~isempty(opts.n),order=order(1:min(double(opts.n),numel(order)));end
            value=cell(1,numel(order));
            for ii=1:numel(order)
                symbol=symbols{order(ii)};
                value{ii}={string(symbol),obj.coord_geoms(symbol)};
            end
        end
        function add_coord_geom(obj,mpSymbol,symmetryMeasure,varargin)
            opts=parseOptions(struct(algo="UNKNOWN",permutation=[], ...
                override=false,local2perfect_map=[],perfect2local_map=[], ...
                detailed_voronoi_index=[],other_symmetry_measures=[], ...
                rotation_matrix=[],scaling_factor=[]),varargin{:});
            symbol=char(string(mpSymbol));
            persistent allCg
            if isempty(allCg)
                allCg=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    coordination_environments.AllCoordinationGeometries();
            end
            if ~allCg.is_a_valid_coordination_geometry("mp_symbol",symbol)
                error("KSSOLV:Matgenlab:ChemEnv:InvalidGeometry", ...
                    "Coordination geometry '%s' is not valid.",symbol);
            end
            if isKey(obj.coord_geoms,symbol)&&~opts.override
                error("KSSOLV:Matgenlab:ChemEnv:DuplicateGeometry", ...
                    "Geometry is already present and override is false.");
            end
            permutation=reshape(double(opts.permutation),1,[]);
            data=struct(symmetry_measure=double(symmetryMeasure), ...
                algo=string(opts.algo),permutation=permutation, ...
                local2perfect_map=opts.local2perfect_map, ...
                perfect2local_map=opts.perfect2local_map, ...
                detailed_voronoi_index=opts.detailed_voronoi_index, ...
                other_symmetry_measures=opts.other_symmetry_measures, ...
                rotation_matrix=opts.rotation_matrix, ...
                scaling_factor=opts.scaling_factor);
            obj.coord_geoms(symbol)=data;
        end
        function value=is_close_to(obj,other,varargin)
            opts=parseOptions(struct(rtol=0,atol=1e-8),varargin{:});
            if ~isequal(sort(string(obj.coord_geoms.keys)), ...
                    sort(string(other.coord_geoms.keys)))
                value=false;return
            end
            names=["csm_wcs_ctwcc","csm_wcs_ctwocc","csm_wcs_csc", ...
                "csm_wocs_ctwcc","csm_wocs_ctwocc","csm_wocs_csc"];
            value=true;
            for key=obj.coord_geoms.keys
                first=obj.coord_geoms(key{1}).other_symmetry_measures;
                second=other.coord_geoms(key{1}).other_symmetry_measures;
                for name=names
                    a=first.(name);b=second.(name);
                    if abs(a-b)>opts.atol+opts.rtol*abs(b)
                        value=false;return
                    end
                end
            end
        end
        function value=as_dict(obj)
            values=struct();
            for key=obj.coord_geoms.keys
                data=obj.coord_geoms(key{1});
                wire=data;wire.permutation=data.permutation-1;
                wire.local2perfect_map=mapToWire(data.local2perfect_map);
                wire.perfect2local_map=mapToWire(data.perfect2local_map);
                values.(matlab.lang.makeValidName(key{1}))=wire;
            end
            value=struct(x_module="pymatgen.analysis.chemenv."+ ...
                "coordination_environments.structure_environments", ...
                x_class="ChemicalEnvironments",coord_geoms=values);
        end
        function value=char(obj)
            if obj.coord_geoms.Count==0
                value=sprintf(['Chemical environments object :\n' ...
                    ' => No coordination in it <=\n']);return
            end
            symbols=obj.coord_geoms.keys;
            first=symbols{1};parts=split(first,":");
            value=sprintf(['Chemical environments object :\n' ...
                ' => Coordination %s <=\n'],char(string(parts(end))));
            ranked=obj.minimum_geometries();
            for ii=1:numel(ranked)
                symbol=char(ranked{ii}{1});data=ranked{ii}{2};
                other=data.other_symmetry_measures;
                value=[value,sprintf(['   - %s\n' ...
                    '      csm1 (with central site) : %s' ...
                    '      csm2 (without central site) : %s' ...
                    '     algo : %s     perm : %s\n' ...
                    '       local2perfect : %s\n' ...
                    '       perfect2local : %s\n'],symbol, ...
                    numberText(other.csm_wcs_ctwcc), ...
                    numberText(other.csm_wocs_ctwocc),data.algo, ...
                    mat2str(data.permutation-1), ...
                    mapText(data.local2perfect_map), ...
                    mapText(data.perfect2local_map))]; %#ok<AGROW>
            end
        end
        function value=string(obj),value=string(char(obj));end
        function value=length(obj),value=obj.coord_geoms.Count;end
        function varargout=subsref(obj,index)
            if index(1).type=="()"&&numel(index(1).subs)==1&& ...
                    (ischar(index(1).subs{1})||isstring(index(1).subs{1}))
                value=obj.coord_geoms(char(string(index(1).subs{1})));
                if numel(index)>1,value=builtin("subsref",value,index(2:end));end
                varargout={value};return
            end
            [varargout{1:nargout}]=builtin("subsref",obj,index);
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.ChemicalEnvironments();
            raw=value.coord_geoms;
            if isa(raw,"containers.Map"),fields=raw.keys;
            else,fields=fieldnames(raw).';end
            for ii=1:numel(fields)
                field=fields{ii};
                if isa(raw,"containers.Map"),data=raw(field);
                else,data=raw.(field);end
                symbol=restoreSymbol(field);
                obj.add_coord_geom(symbol,data.symmetry_measure, ...
                    "algo",data.algo,"permutation", ...
                    reshape(double(data.permutation),1,[])+1, ...
                    "local2perfect_map",wireToMap(data.local2perfect_map), ...
                    "perfect2local_map",wireToMap(data.perfect2local_map), ...
                    "detailed_voronoi_index",data.detailed_voronoi_index, ...
                    "other_symmetry_measures", ...
                    fieldOr(data,"other_symmetry_measures",[]), ...
                    "rotation_matrix",data.rotation_matrix, ...
                    "scaling_factor",data.scaling_factor);
            end
        end
    end
end
function opts=parseOptions(defaults,varargin)
opts=defaults;
names=fieldnames(defaults);position=1;
while position<=numel(varargin)&& ...
        ~(ischar(varargin{position})||isstring(varargin{position}))
    opts.(names{position})=varargin{position};position=position+1;
end
for ii=position:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
function symbol=restoreSymbol(field)
symbol=string(field);
if ~contains(symbol,":")
    known=["UNKNOWN","UNCLEAR"];
    if ~ismember(symbol,known)
        index=find(char(symbol)=='_',1,"last");
        chars=char(symbol);
        if ~isempty(index),chars(index)=':';symbol=string(chars);end
    end
end
end
function value=fieldOr(data,name,default)
if isfield(data,name),value=data.(name);else,value=default;end
end
function value=wireToMap(input)
if isempty(input)||isa(input,"containers.Map"),value=input;return,end
value=containers.Map("KeyType","double","ValueType","double");
fields=fieldnames(input);
for ii=1:numel(fields)
    token=regexp(fields{ii},'\d+','match','once');
    value(str2double(token))=double(input.(fields{ii}));
end
end
function value=mapToWire(input)
if isempty(input)||isstruct(input),value=input;return,end
value=struct();
if isa(input,"containers.Map")
    for key=input.keys
        value.("x"+string(key{1}))=input(key{1});
    end
end
end
function value=numberText(input),value=char(string(input));end
function value=mapText(input)
if isempty(input),value="None";elseif isa(input,"containers.Map")
    pairs=strings(1,input.Count);keys=input.keys;
    for ii=1:numel(keys),pairs(ii)=keys{ii}+": "+input(keys{ii});end
    value="{"+strjoin(pairs,", ")+"}";
else,value=string(jsonencode(input));end
value=char(value);
end
