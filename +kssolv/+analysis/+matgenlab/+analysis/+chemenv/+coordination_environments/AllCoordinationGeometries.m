%#ok<*AGROW,*ALIGN,*ISCL>
classdef AllCoordinationGeometries < handle
    %ALLCOORDINATIONGEOMETRIES Registry of pymatgen model geometries.
    properties (SetAccess=private)
        cg_list cell={}
        minpoints
        maxpoints
        maxpoints_inplane
        separations_cg
    end
    properties (Access=private)
        by_symbol
        by_iupac
        by_iucr
        by_name
    end
    methods
        function obj=AllCoordinationGeometries(varargin)
            opts=parseOptions(varargin{:});
            root=fullfile(fileparts(mfilename("fullpath")), ...
                "+coordination_geometries_files");
            if isempty(opts.only_symbols)
                lines=splitlines(string(fileread(fullfile(root,"allcg.txt"))));
                files=lines(strlength(strtrim(lines))>0);
                files=cellstr(erase(strtrim(files), ...
                    "coordination_geometries_files/"));
            else
                symbols=string(opts.only_symbols);
                files=cellstr(replace(symbols,":","#")+".json");
            end
            for ii=1:numel(files)
                data=jsondecode(fileread(fullfile(root,files{ii})));
                obj.cg_list{end+1}=kssolv.analysis.matgenlab.analysis. ...
                    chemenv.coordination_environments. ...
                    CoordinationGeometry.from_dict(data);
            end
            obj.cg_list{end+1}=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.CoordinationGeometry( ...
                "UNKNOWN","Unknown environment","deactivate",true);
            obj.cg_list{end+1}=kssolv.analysis.matgenlab.analysis. ...
                chemenv.coordination_environments.CoordinationGeometry( ...
                "UNCLEAR","Unclear environment","deactivate",true);
            if opts.permutations_safe_override
                for ii=1:numel(obj.cg_list)
                    obj.cg_list{ii}.permutations_safe_override=true;
                end
            end
            obj.buildMaps();
            obj.buildSeparations(opts.only_symbols);
        end
        function value=get_geometries(obj,varargin)
            opts=parseNamed(struct(coordination=[],returned="cg"),varargin{:});
            value=filterCg(obj.cg_list,opts.coordination,false,false);
            if string(opts.returned)~="cg"
                value=cellfun(@(x)x.mp_symbol,value,"UniformOutput",false);
            end
        end
        function value=get_symbol_name_mapping(obj,varargin)
            opts=parseNamed(struct(coordination=[]),varargin{:});
            cgs=filterCg(obj.cg_list,opts.coordination,false,false);
            value=containers.Map("KeyType","char","ValueType","char");
            for ii=1:numel(cgs),value(char(cgs{ii}.mp_symbol))=char(cgs{ii}.name);end
        end
        function value=get_symbol_cn_mapping(obj,varargin)
            opts=parseNamed(struct(coordination=[]),varargin{:});
            cgs=filterCg(obj.cg_list,opts.coordination,false,false);
            value=containers.Map("KeyType","char","ValueType","any");
            for ii=1:numel(cgs)
                value(char(cgs{ii}.mp_symbol))=cgs{ii}.coordination_number;
            end
        end
        function value=get_implemented_geometries(obj,varargin)
            opts=parseNamed(struct(coordination=[],returned="cg", ...
                include_deactivated=false),varargin{:});
            value={};
            for ii=1:numel(obj.cg_list)
                cg=obj.cg_list{ii};
                if ~cg.is_implemented()|| ...
                        (~opts.include_deactivated&&cg.deactivate),continue,end
                if ~isempty(opts.coordination)&& ...
                        cg.get_coordination_number()~=opts.coordination,continue,end
                value{end+1}=cg;
            end
            if string(opts.returned)~="cg"
                value=cellfun(@(x)x.mp_symbol,value,"UniformOutput",false);
            end
        end
        function value=get_not_implemented_geometries(obj,varargin)
            opts=parseNamed(struct(coordination=[],returned="mp_symbol"), ...
                varargin{:});
            value={};
            for ii=1:numel(obj.cg_list)
                cg=obj.cg_list{ii};
                if cg.is_implemented(),continue,end
                if ~isempty(opts.coordination)&& ...
                        cg.get_coordination_number()~=opts.coordination,continue,end
                value{end+1}=cg;
            end
            if string(opts.returned)~="cg"
                value=cellfun(@(x)x.mp_symbol,value,"UniformOutput",false);
            end
        end
        function value=get_geometry_from_name(obj,name)
            value=lookup(obj.by_name,name,"name");
        end
        function value=get_geometry_from_IUPAC_symbol(obj,symbol)
            value=lookup(obj.by_iupac,symbol,"IUPAC symbol");
        end
        function value=get_geometry_from_IUCr_symbol(obj,symbol)
            value=lookup(obj.by_iucr,symbol,"IUCr symbol");
        end
        function value=get_geometry_from_mp_symbol(obj,symbol)
            value=lookup(obj.by_symbol,symbol,"mp_symbol");
        end
        function value=is_a_valid_coordination_geometry(obj,varargin)
            opts=parseNamed(struct(mp_symbol=[],IUPAC_symbol=[], ...
                IUCr_symbol=[],name=[],cn=[]),varargin{:});
            if ~isempty(opts.name)
                error("KSSOLV:Matgenlab:NotImplemented", ...
                    "Validation by name is not implemented.");
            end
            if isempty(opts.mp_symbol)&&isempty(opts.IUPAC_symbol)&& ...
                    isempty(opts.IUCr_symbol)
                error("KSSOLV:Matgenlab:MissingArgument", ...
                    "At least one symbol must be supplied.");
            end
            if ~isempty(opts.mp_symbol)
                [found,cg]=tryLookup(obj.by_symbol,opts.mp_symbol);
            elseif ~isempty(opts.IUPAC_symbol)
                [found,cg]=tryLookup(obj.by_iupac,opts.IUPAC_symbol);
            else
                [found,cg]=tryLookup(obj.by_iucr,opts.IUCr_symbol);
                if ~found,value=true;return,end % preserve pymatgen behavior
            end
            if ~found,value=false;return,end
            value=true;
            if ~isempty(opts.IUPAC_symbol)
                value=value&&isequal(string(opts.IUPAC_symbol), ...
                    string(cg.IUPAC_symbol));
            end
            if ~isempty(opts.IUCr_symbol)
                value=value&&isequal(string(opts.IUCr_symbol), ...
                    string(cg.IUCr_symbol));
            end
            if ~isempty(opts.cn),value=value&&double(opts.cn)==cg.coordination_number;end
        end
        function value=pretty_print(obj,varargin)
            opts=parseNamed(struct(type="implemented_geometries", ...
                maxcn=8,additional_info=[]),varargin{:});
            kind=string(opts.type);chunks={};
            if kind=="all_geometries_latex_images"
                for cn=1:opts.maxcn
                    chunks{end+1}=sprintf('\\section*{Coordination %d}\n\n',cn);
                    cgs=obj.get_implemented_geometries("coordination",cn);
                    for ii=1:numel(cgs)
                        cg=cgs{ii};parts=split(cg.mp_symbol,":");
                        chunks{end+1}=sprintf([ ...
                            '\\subsubsection*{%s : %s}\n\nIUPAC : %s\n\n' ...
                            'IUCr : %s\n\n\\begin{center}\n' ...
                            '\\includegraphics[scale=0.15]{images/%s_%s.png}\n' ...
                            '\\end{center}\n\n'],cg.mp_symbol,cg.name, ...
                            pyString(cg.IUPAC_symbol),pyString(cg.IUCr_symbol), ...
                            parts(1),parts(2));
                    end
                end
                value=[chunks{:}];return
            end
            if kind=="all_geometries_latex"
                for cn=1:opts.maxcn
                    chunks{end+1}=sprintf([ ...
                        '\\subsection*{Coordination %d}\n\n' ...
                        '\\begin{itemize}\n'],cn);
                    cgs=[obj.get_implemented_geometries("coordination",cn), ...
                        obj.get_not_implemented_geometries( ...
                        "coordination",cn,"returned","cg")];
                    for ii=1:numel(cgs)
                        cg=cgs{ii};symbol=replace(cg.mp_symbol,"_","\\_");
                        iucr=replace(replace(cg.IUCr_symbol_str, ...
                            "[","$[$"),"]","$]$");
                        chunks{end+1}=sprintf([ ...
                            '\\item %s $\\rightarrow$ %s ' ...
                            '(IUPAC : %s - IUCr : %s)\n'], ...
                            symbol,cg.name,cg.IUPAC_symbol_str,iucr);
                    end
                    chunks{end+1}=sprintf('\\end{itemize}\n\n');
                end
                value=[chunks{:}];return
            end
            chunks={sprintf(['+-------------------------+\n' ...
                '| Coordination geometries |\n' ...
                '+-------------------------+\n\n'])};
            for cn=1:opts.maxcn
                chunks{end+1}=sprintf('==>> CN = %d <<==\n',cn);
                if kind=="implemented_geometries"
                    cgs=obj.get_implemented_geometries("coordination",cn);
                else,cgs=obj.get_geometries("coordination",cn);end
                for ii=1:numel(cgs)
                    addinfo="";
                    if ~isempty(opts.additional_info)&& ...
                            hasInfo(opts.additional_info,"nb_hints")&& ...
                            ~isempty(cgs{ii}.neighbors_sets_hints)
                        addinfo=" *";
                    end
                    chunks{end+1}=sprintf(' - %s : %s%s\n', ...
                        cgs{ii}.mp_symbol,cgs{ii}.name,addinfo);
                end
                chunks{end+1}=newline;
            end
            value=[chunks{:}];
        end
        function value=char(obj)
            chunks={sprintf(['\n#=======================================================#\n' ...
                '# List of coordination geometries currently implemented #\n' ...
                '#=======================================================#\n\n'])};
            cgs=obj.get_implemented_geometries();
            for ii=1:numel(cgs),chunks{end+1}=[char(cgs{ii}),newline];end
            value=[chunks{:}];
        end
        function value=string(obj),value=string(char(obj));end
        function varargout=subsref(obj,index)
            if index(1).type=="()"&&numel(index(1).subs)==1&& ...
                    (ischar(index(1).subs{1})||isstring(index(1).subs{1}))
                value=obj.get_geometry_from_mp_symbol(index(1).subs{1});
                if numel(index)>1,value=builtin("subsref",value,index(2:end));end
                varargout={value};return
            end
            [varargout{1:nargout}]=builtin("subsref",obj,index);
        end
    end
    methods (Access=private)
        function buildMaps(obj)
            obj.by_symbol=containers.Map("KeyType","char","ValueType","any");
            obj.by_iupac=containers.Map("KeyType","char","ValueType","any");
            obj.by_iucr=containers.Map("KeyType","char","ValueType","any");
            obj.by_name=containers.Map("KeyType","char","ValueType","any");
            for ii=1:numel(obj.cg_list)
                cg=obj.cg_list{ii};
                obj.by_symbol(char(cg.mp_symbol))=cg;
                obj.by_name(char(cg.name))=cg;
                if ~isempty(cg.IUPAC_symbol)
                    obj.by_iupac(char(cg.IUPAC_symbol))=cg;
                end
                if ~isempty(cg.IUCr_symbol)
                    obj.by_iucr(char(cg.IUCr_symbol))=cg;
                end
                for jj=1:numel(cg.alternative_names)
                    key=char(string(cg.alternative_names{jj}));
                    if ~isKey(obj.by_name,key),obj.by_name(key)=cg;end
                end
            end
        end
        function buildSeparations(obj,onlySymbols)
            obj.minpoints=containers.Map("KeyType","double","ValueType","double");
            obj.maxpoints=containers.Map("KeyType","double","ValueType","double");
            obj.maxpoints_inplane=containers.Map( ...
                "KeyType","double","ValueType","double");
            obj.separations_cg=containers.Map( ...
                "KeyType","double","ValueType","any");
            allowed=string(onlySymbols);
            for ii=1:numel(obj.cg_list)
                cg=obj.cg_list{ii};cn=cg.coordination_number;
                if ~cg.is_implemented()||cg.deactivate||isempty(cn)|| ...
                        cn<6||cn>20,continue,end
                if ~isempty(allowed)&&~ismember(cg.ce_symbol,allowed),continue,end
                if ~isKey(obj.separations_cg,cn)
                    obj.separations_cg(cn)=containers.Map( ...
                        "KeyType","char","ValueType","any");
                    obj.minpoints(cn)=1000;obj.maxpoints(cn)=0;
                    obj.maxpoints_inplane(cn)=0;
                end
                map=obj.separations_cg(cn);
                for jj=1:numel(cg.algorithms)
                    algo=cg.algorithms{jj};
                    if ~isa(algo,"kssolv.analysis.matgenlab.analysis."+ ...
                            "chemenv.coordination_environments.SeparationPlane")
                        continue
                    end
                    sep=algo.separation;key=sprintf('%d,%d,%d',sep);
                    if isKey(map,key),symbols=map(key);else,symbols={};end
                    symbols{end+1}=cg.mp_symbol;map(key)=symbols;
                    obj.minpoints(cn)=min(obj.minpoints(cn), ...
                        algo.minimum_number_of_points);
                    obj.maxpoints(cn)=max(obj.maxpoints(cn), ...
                        algo.maximum_number_of_points);
                    obj.maxpoints_inplane(cn)=max( ...
                        obj.maxpoints_inplane(cn),sep(2));
                end
                obj.separations_cg(cn)=map;
            end
        end
    end
end
function opts=parseOptions(varargin)
opts=struct(permutations_safe_override=false,only_symbols=[]);
if isempty(varargin),return,end
if ~(ischar(varargin{1})||isstring(varargin{1}))
    opts.permutations_safe_override=varargin{1};varargin(1)=[];
    if ~isempty(varargin)&&~(ischar(varargin{1})||isstring(varargin{1}))
        opts.only_symbols=varargin{1};varargin(1)=[];
    end
end
for ii=1:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function opts=parseNamed(defaults,varargin)
opts=defaults;
if ~isempty(varargin)&&~(ischar(varargin{1})||isstring(varargin{1}))
    names=fieldnames(defaults);opts.(names{1})=varargin{1};varargin(1)=[];
    if ~isempty(varargin)&&~(ischar(varargin{1})||isstring(varargin{1}))&&numel(names)>1
        opts.(names{2})=varargin{1};varargin(1)=[];
    end
end
for ii=1:2:numel(varargin),opts.(char(string(varargin{ii})))=varargin{ii+1};end
end
function value=filterCg(cgs,coordination,~,~)
value={};
for ii=1:numel(cgs)
    if isempty(coordination)||isequal(cgs{ii}.get_coordination_number(),coordination)
        value{end+1}=cgs{ii};
    end
end
end
function value=lookup(map,key,kind)
key=char(string(key));
if ~isKey(map,key)
    error("KSSOLV:Matgenlab:ChemEnv:Lookup", ...
        "No coordination geometry found with %s '%s'.",kind,key);
end
value=map(key);
end
function [found,value]=tryLookup(map,key)
key=char(string(key));found=isKey(map,key);
if found,value=map(key);else,value=[];end
end
function value=pyString(input)
if isempty(input),value="None";else,value=string(input);end
end
function value=hasInfo(info,key)
if isstruct(info),value=isfield(info,key);
elseif isa(info,"containers.Map"),value=isKey(info,key);
else,value=any(string(info)==key);end
end
