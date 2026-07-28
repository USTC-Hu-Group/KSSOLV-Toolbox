classdef Cohp < kssolv.analysis.matgenlab.util.MSONable
    %COHP Spin-resolved crystal-orbital population curve.
    properties (SetAccess=private)
        efermi (1,1) double
        energies (1,:) double
        cohp (1,1) struct
        icohp = []
        are_coops (1,1) logical=false
        are_cobis (1,1) logical=false
        are_multi_center_cobis (1,1) logical=false
    end
    methods
        function obj=Cohp(efermi,energies,cohp,varargin)
            if nargin==0,efermi=0;energies=0;cohp=struct("up",0);end
            options=struct(are_coops=false,are_cobis=false, ...
                are_multi_center_cobis=false,icohp=[]);
            options=parseOptions(options,varargin);
            if sum([options.are_coops,options.are_cobis, ...
                    options.are_multi_center_cobis])>1
                error("KSSOLV:Matgenlab:Cohp:PopulationType", ...
                    "COOP, COBI and multi-center COBI flags are exclusive.");
            end
            obj.efermi=double(efermi);
            obj.energies=reshape(double(energies),1,[]);
            obj.cohp=normalizeSpinMap(cohp);
            if ~isempty(options.icohp),obj.icohp=normalizeSpinMap(options.icohp);end
            obj.are_coops=logical(options.are_coops);
            obj.are_cobis=logical(options.are_cobis);
            obj.are_multi_center_cobis=logical(options.are_multi_center_cobis);
            validateCurve(obj.cohp,obj.energies);
            if ~isempty(obj.icohp),validateCurve(obj.icohp,obj.energies);end
        end
        function value=get_cohp(obj,spin,integrated)
            if nargin<2,spin=[];end
            if nargin<3||isempty(integrated),integrated=false;end
            if integrated,value=obj.icohp;else,value=obj.cohp;end
            if isempty(value)||isempty(spin),return,end
            field=spinField(spin);
            if ~isfield(value,field)
                error("KSSOLV:Matgenlab:Cohp:MissingSpin", ...
                    "The requested spin channel is absent.");
            end
            value=struct(field,value.(field));
        end
        function value=get_icohp(obj,spin)
            if nargin<2,spin=[];end
            value=obj.get_cohp(spin,true);
        end
        function value=get_interpolated_value(obj,energy,integrated)
            if nargin<3||isempty(integrated),integrated=false;end
            population=obj.cohp;
            if integrated
                population=obj.icohp;
                if isempty(population)
                    error("KSSOLV:Matgenlab:Cohp:MissingIcohp","ICOHP is empty.");
                end
            end
            value=struct();names=fieldnames(population);
            for ii=1:numel(names)
                value.(names{ii})=interp1(obj.energies, ...
                    population.(names{ii}),double(energy),"linear");
            end
        end
        function value=has_antibnd_states_below_efermi(obj,spin,limit)
            if nargin<2,spin=[];end
            if nargin<3||isempty(limit),limit=.01;end
            value=struct();last=find(obj.energies<=obj.efermi,1,"last");
            if isempty(last),last=0;end
            if isempty(spin),names=fieldnames(obj.cohp);
            else,names={spinField(spin)};end
            for ii=1:numel(names)
                if last==0,value.(names{ii})=false;
                else,value.(names{ii})=max(obj.cohp.(names{ii})(1:last))>limit;end
            end
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.electronic_structure.cohp", ...
                x_class="Cohp",are_coops=obj.are_coops, ...
                are_cobis=obj.are_cobis, ...
                are_multi_center_cobis=obj.are_multi_center_cobis, ...
                efermi=obj.efermi,energies=obj.energies, ...
                COHP=spinMapToWire(obj.cohp));
            if ~isempty(obj.icohp),data.ICOHP=spinMapToWire(obj.icohp);end
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            if obj.are_coops
                label="COOP";
            elseif obj.are_cobis||obj.are_multi_center_cobis
                label="COBI";
            else
                label="COHP";
            end
            names=fieldnames(obj.cohp);header="Energy";
            values=obj.energies(:);
            for ii=1:numel(names)
                header=header+" "+label+upperFirst(names{ii});
                values(:,end+1)=obj.cohp.(names{ii})(:); %#ok<AGROW>
            end
            if ~isempty(obj.icohp)
                for ii=1:numel(names)
                    header=header+" I"+label+upperFirst(names{ii});
                    values(:,end+1)=obj.icohp.(names{ii})(:); %#ok<AGROW>
                end
            end
            format=strjoin(repmat("%.5f",1,size(values,2))," ");
            rows=strings(size(values,1),1);
            for ii=1:size(values,1)
                rows(ii)=sprintf(format,values(ii,:));
            end
            text=char("#"+header+newline+strjoin(rows,newline));
        end
    end
    methods (Static)
        function obj=from_dict(data)
            options={"are_coops",logical(fieldOr(data,"are_coops",false)), ...
                "are_cobis",logical(fieldOr(data,"are_cobis",false)), ...
                "are_multi_center_cobis",logical(fieldOr(data, ...
                "are_multi_center_cobis",false))};
            if isfield(data,"ICOHP"),options=[options,{"icohp",data.ICOHP}];end
            obj=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                data.efermi,data.energies,data.COHP,options{:});
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.electronic_structure.Cohp.from_dict(data);end
    end
end

function validateCurve(mapping,energies)
names=fieldnames(mapping);
if ~isfield(mapping,"up")
    error("KSSOLV:Matgenlab:Cohp:MissingSpinUp","Spin-up data are required.");
end
for ii=1:numel(names)
    mapping.(names{ii})=reshape(mapping.(names{ii}),1,[]);
    if numel(mapping.(names{ii}))~=numel(energies)
        error("KSSOLV:Matgenlab:Cohp:SizeMismatch", ...
            "Every population channel must match energies.");
    end
end
end
function value=normalizeSpinMap(input)
if isa(input,"containers.Map")
    value=struct();keys=input.keys;
    for ii=1:numel(keys),value.(spinField(keys{ii}))=reshape(double(input(keys{ii})),1,[]);end
elseif isstruct(input)
    value=struct();names=fieldnames(input);
    for ii=1:numel(names),value.(spinField(names{ii}))=reshape(double(input.(names{ii})),1,[]);end
else
    value=struct("up",reshape(double(input),1,[]));
end
end
function field=spinField(spin)
if isa(spin,"kssolv.analysis.matgenlab.electronic_structure.Spin"),spin=double(spin);end
text=lower(string(spin));
if any(text==["-1","down","x_1"])
    field="down";
elseif any(text==["1","+1","up","x1"])
    field="up";
else
    error("KSSOLV:Matgenlab:Cohp:Spin","Unknown spin channel '%s'.",text);
end
field=char(field);
end
function value=spinMapToWire(input)
keys={'1'};values={input.up};
if isfield(input,"down"),keys{end+1}='-1';values{end+1}=input.down;end
value=containers.Map(keys,values,"UniformValues",false);
end
function value=fieldOr(data,name,default)
if isfield(data,name),value=data.(name);else,value=default;end
end
function output=parseOptions(output,input)
names=fieldnames(output);pos=1;ii=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&&any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;
    else
        output.(names{pos})=input{ii};pos=pos+1;ii=ii+1;
    end
end
end
function value=upperFirst(text),value=upper(extractBefore(string(text),2))+extractAfter(string(text),1);end
