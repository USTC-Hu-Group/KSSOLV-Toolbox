classdef IcohpCollection < kssolv.analysis.matgenlab.util.MSONable
    %ICOHPCOLLECTION Searchable collection of integrated bond populations.
    properties (SetAccess=private)
        list_labels string
        list_atom1 string
        list_atom2 string
        list_length double
        list_translation cell
        list_num double
        list_icohp cell
        list_orb_icohp cell
        values
    end
    properties (Access=private)
        is_spin_polarized_ logical
        are_coops_ logical
        are_cobis_ logical
    end
    properties (Dependent)
        is_spin_polarized
        are_coops
        are_cobis
    end
    methods
        function obj=IcohpCollection(labels,atom1,atom2,lengths,translations, ...
                nums,icohps,isSpinPolarized,varargin)
            if nargin==0,labels=strings(1,0);atom1=strings(1,0);atom2=strings(1,0);lengths=[];translations={};nums=[];icohps={};isSpinPolarized=false;end
            options=struct(list_orb_icohp=[],are_coops=false,are_cobis=false);
            options=parseOptions(options,varargin);
            if options.are_coops&&options.are_cobis,error("KSSOLV:Matgenlab:IcohpCollection:PopulationType","COOP and COBI flags are exclusive.");end
            obj.list_labels=reshape(string(labels),1,[]);obj.list_atom1=reshape(string(atom1),1,[]);
            obj.list_atom2=reshape(string(atom2),1,[]);obj.list_length=reshape(double(lengths),1,[]);
            obj.list_translation=normalizeTranslations(translations);obj.list_num=reshape(double(nums),1,[]);
            obj.list_icohp=normalizeIcohpList(icohps);
            if isempty(options.list_orb_icohp),obj.list_orb_icohp=repmat({[]},size(obj.list_icohp));
            else,obj.list_orb_icohp=asCell(options.list_orb_icohp);end
            n=numel(obj.list_labels);
            if any([numel(obj.list_atom1),numel(obj.list_atom2),numel(obj.list_length), ...
                    numel(obj.list_translation),numel(obj.list_num),numel(obj.list_icohp)]~=n)
                error("KSSOLV:Matgenlab:IcohpCollection:Length","All input lists must have equal length.");
            end
            obj.is_spin_polarized_=logical(isSpinPolarized);obj.are_coops_=logical(options.are_coops);obj.are_cobis_=logical(options.are_cobis);
            obj.values=containers.Map("KeyType","char","ValueType","any");
            for ii=1:n
                obj.values(char(obj.list_labels(ii)))=kssolv.analysis.matgenlab. ...
                    electronic_structure.IcohpValue(obj.list_labels(ii), ...
                    obj.list_atom1(ii),obj.list_atom2(ii),obj.list_length(ii), ...
                    obj.list_translation{ii},obj.list_num(ii),obj.list_icohp{ii}, ...
                    "are_coops",obj.are_coops_,"are_cobis",obj.are_cobis_, ...
                    "orbitals",obj.list_orb_icohp{ii});
            end
        end
        function value=get.is_spin_polarized(obj),value=obj.is_spin_polarized_;end
        function value=get.are_coops(obj),value=obj.are_coops_;end
        function value=get.are_cobis(obj),value=obj.are_cobis_;end
        function value=get_icohp_by_label(obj,label,summed,spin,orbitals)
            if nargin<3||isempty(summed),summed=true;end
            if nargin<4||isempty(spin),spin="up";end
            if nargin<5,orbitals=[];end
            item=obj.values(char(string(label)));
            if isempty(orbitals)
                if summed
                    value=item.summed_icohp;
                else
                    value=item.icohpvalue(spin);
                end
            elseif summed
                map=item.summed_orbital_icohp;
                if iscell(orbitals),key=char(string(orbitals{1})+"-"+string(orbitals{2}));else,key=char(string(orbitals));end
                value=map(key);
            else
                value=item.icohpvalue_orbital(orbitals,spin);
            end
        end
        function value=get_summed_icohp_by_label_list(obj,labels,divisor,summed,spin)
            if nargin<3||isempty(divisor),divisor=1;end
            if nargin<4||isempty(summed),summed=true;end
            if nargin<5||isempty(spin),spin="up";end
            labels=cellstr(string(labels));value=0;
            for ii=1:numel(labels)
                item=obj.values(labels{ii});
                if item.num_bonds~=1
                    warning("KSSOLV:Matgenlab:IcohpCollection:AveragedBond", ...
                        "An ICOHP value is an average over bonds.");
                end
                if summed,value=value+item.summed_icohp;else,value=value+item.icohpvalue(spin);end
            end
            value=value/divisor;
        end
        function value=get_icohp_dict_by_bondlengths(obj,minLength,maxLength)
            if nargin<2||isempty(minLength),minLength=0;end
            if nargin<3||isempty(maxLength),maxLength=8;end
            value=containers.Map("KeyType","char","ValueType","any");keys=obj.values.keys;
            for ii=1:numel(keys)
                item=obj.values(keys{ii});if item.length>=minLength&&item.length<=maxLength,value(keys{ii})=item;end
            end
        end
        function value=get_icohp_dict_of_site(obj,site,varargin)
            options=struct(minsummedicohp=[],maxsummedicohp=[],minbondlength=0, ...
                maxbondlength=8,only_bonds_to=[]);options=parseOptions(options,varargin);
            site=double(site);value=containers.Map("KeyType","char","ValueType","any");
            keys=obj.values.keys;
            for ii=1:numel(keys)
                item=obj.values(keys{ii});a=atomIndex(item.atom1);b=atomIndex(item.atom2);
                if site~=a&&site~=b,continue,end
                partner=item.atom2;if site==b,partner=item.atom1;end
                species=regexprep(char(partner),'\d+$','');
                if ~isempty(options.only_bonds_to)&&~any(string(options.only_bonds_to)==species),continue,end
                if item.length<options.minbondlength||item.length>options.maxbondlength,continue,end
                total=item.summed_icohp;
                if ~isempty(options.minsummedicohp)&&total<options.minsummedicohp,continue,end
                if ~isempty(options.maxsummedicohp)&&total>options.maxsummedicohp,continue,end
                value(keys{ii})=item;
            end
        end
        function value=extremum_icohpvalue(obj,summed,spin)
            if nargin<2||isempty(summed),summed=true;end
            if nargin<3||isempty(spin),spin="up";end
            keys=obj.values.keys;numbers=zeros(1,numel(keys));
            for ii=1:numel(keys)
                item=obj.values(keys{ii});
                if summed&&item.is_spin_polarized,numbers(ii)=item.summed_icohp;
                else
                    if ~item.is_spin_polarized&&strcmp(spinField(spin),"down"),spin="up";end
                    numbers(ii)=item.icohpvalue(spin);
                end
            end
            if obj.are_coops||obj.are_cobis,value=max(numbers);else,value=min(numbers);end
        end
        function data=as_dict(obj)
            list=cellfun(@spinWire,obj.list_icohp,"UniformOutput",false);
            orbitalList=cell(size(obj.list_orb_icohp));
            for ii=1:numel(orbitalList)
                item=obj.values(char(obj.list_labels(ii)));
                if isempty(item.orbitals),orbitalList{ii}=[];
                else,orbitalList{ii}=orbitalWire(item.orbitals);end
            end
            data=struct(x_module="pymatgen.electronic_structure.cohp", ...
                x_class="IcohpCollection",are_coops=obj.are_coops, ...
                are_cobis=obj.are_cobis,list_labels=obj.list_labels, ...
                list_atom1=obj.list_atom1,list_atom2=obj.list_atom2, ...
                list_length=obj.list_length,list_translation={obj.list_translation}, ...
                list_num=obj.list_num,list_icohp={list}, ...
                is_spin_polarized=obj.is_spin_polarized, ...
                list_orb_icohp={orbitalList});
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            keys=obj.values.keys;lines=cellfun(@(k)char(obj.values(k)),keys,"UniformOutput",false);
            text=strjoin(lines,newline);
        end
    end
    methods (Static)
        function obj=from_dict(data)
            orbitals=[];if isfield(data,"list_orb_icohp"),orbitals=data.list_orb_icohp;end
            obj=kssolv.analysis.matgenlab.electronic_structure.IcohpCollection( ...
                data.list_labels,data.list_atom1,data.list_atom2,data.list_length, ...
                data.list_translation,data.list_num,data.list_icohp, ...
                data.is_spin_polarized,"list_orb_icohp",orbitals, ...
                "are_coops",fieldOr(data,"are_coops",false), ...
                "are_cobis",fieldOr(data,"are_cobis",false));
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.electronic_structure.IcohpCollection.from_dict(data);end
    end
end

function value=normalizeIcohpList(input)
input=asCell(input);value=cell(size(input));
for ii=1:numel(input)
    raw=input{ii};if isa(raw,"containers.Map"),keys=raw.keys;getter=@(k)raw(k);else,keys=fieldnames(raw);getter=@(k)raw.(k);end
    item=struct();for jj=1:numel(keys),item.(spinField(keys{jj}))=double(getter(keys{jj}));end
    value{ii}=item;
end
end
function value=normalizeTranslations(input)
if iscell(input),value=input;elseif ismatrix(input)&&size(input,2)==3,value=mat2cell(double(input),ones(1,size(input,1)),3);else,value=asCell(input);end
end
function value=asCell(input),if iscell(input),value=input;elseif isstruct(input),value=num2cell(input);else,value=num2cell(input);end,end
function value=spinWire(input),keys={'1'};vals={input.up};if isfield(input,"down"),keys{2}='-1';vals{2}=input.down;end,value=containers.Map(keys,vals);end
function value=orbitalWire(input)
value=containers.Map("KeyType","char","ValueType","any");keys=input.keys;
for ii=1:numel(keys)
    item=input(keys{ii});item.icohp=spinWire(item.icohp);
    if isfield(item,"orbitals"),item.orbitals=orbitalListWire(item.orbitals);end
    value(keys{ii})=item;
end
end
function value=orbitalListWire(input)
if isnumeric(input),value=input;return,end
if ~iscell(input),value=input;return,end
value=input;
for ii=1:numel(input)
    item=input{ii};
    if iscell(item)&&numel(item)==2
        orbital=item{2};
        if isa(orbital,"kssolv.analysis.matgenlab.electronic_structure.Orbital")
            orbital=double(orbital);
        end
        value{ii}={item{1},orbital};
    end
end
end
function field=spinField(spin),if isa(spin,"kssolv.analysis.matgenlab.electronic_structure.Spin"),spin=double(spin);end,if any(lower(string(spin))==["-1","down","x_1"]),field="down";else,field="up";end,field=char(field);end
function value=atomIndex(text),token=regexp(char(text),'(\d+)$','tokens','once');value=str2double(token{1})-1;end
function value=fieldOr(data,name,default),if isfield(data,name),value=data.(name);else,value=default;end,end
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
