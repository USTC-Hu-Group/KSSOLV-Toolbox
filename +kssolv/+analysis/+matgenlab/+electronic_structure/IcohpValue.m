classdef IcohpValue < kssolv.analysis.matgenlab.util.MSONable
    %ICOHPVALUE One bond's integrated COHP/COOP/COBI metadata.
    properties (SetAccess=private)
        label (1,1) string
        atom1 (1,1) string
        atom2 (1,1) string
        length (1,1) double
        orbitals
    end
    properties (Access=private)
        num_ (1,1) double
        translation_ (1,3) double
        icohp_ (1,1) struct
        are_coops_ (1,1) logical
        are_cobis_ (1,1) logical
    end
    properties (Dependent)
        num_bonds
        are_coops
        are_cobis
        is_spin_polarized
        translation
        icohp
        summed_icohp
        summed_orbital_icohp
    end
    methods
        function obj=IcohpValue(label,atom1,atom2,length,translation,num,icohp,varargin)
            if nargin==0,label="";atom1="";atom2="";length=0;translation=[0,0,0];num=1;icohp=struct("up",0);end
            options=struct(are_coops=false,are_cobis=false,orbitals=[]);
            options=parseOptions(options,varargin);
            if options.are_coops&&options.are_cobis
                error("KSSOLV:Matgenlab:IcohpValue:PopulationType", ...
                    "COOP and COBI flags are exclusive.");
            end
            obj.label=string(label);obj.atom1=string(atom1);obj.atom2=string(atom2);
            obj.length=double(length);obj.translation_=reshape(double(translation),1,3);
            obj.num_=double(num);obj.icohp_=normalizeSpinScalar(icohp);
            obj.are_coops_=logical(options.are_coops);obj.are_cobis_=logical(options.are_cobis);
            obj.orbitals=normalizeOrbitalData(options.orbitals);
        end
        function value=get.num_bonds(obj),value=obj.num_;end
        function value=get.are_coops(obj),value=obj.are_coops_;end
        function value=get.are_cobis(obj),value=obj.are_cobis_;end
        function value=get.is_spin_polarized(obj),value=isfield(obj.icohp_,"down");end
        function value=get.translation(obj),value=obj.translation_;end
        function value=get.icohp(obj),value=obj.icohp_;end
        function value=get.summed_icohp(obj)
            value=obj.icohp_.up;if obj.is_spin_polarized,value=value+obj.icohp_.down;end
        end
        function value=icohpvalue(obj,spin)
            if nargin<2,spin="up";end
            field=spinField(spin);
            if ~isfield(obj.icohp_,field)
                error("KSSOLV:Matgenlab:IcohpValue:MissingSpin", ...
                    "The calculation was not spin polarized.");
            end
            value=obj.icohp_.(field);
        end
        function value=icohpvalue_orbital(obj,orbitals,spin)
            if nargin<3,spin="up";end
            if isempty(obj.orbitals)
                error("KSSOLV:Matgenlab:IcohpValue:MissingOrbitals", ...
                    "Orbital-resolved values are absent.");
            end
            if iscell(orbitals)||(~ischar(orbitals)&&~isstring(orbitals))
                if iscell(orbitals)
                    parts=orbitals;
                else
                    parts=num2cell(orbitals);
                end
                key=char(string(parts{1})+"-"+string(parts{2}));
            else
                key=char(string(orbitals));
            end
            item=obj.orbitals(key);
            value=item.icohp.(spinField(spin));
        end
        function value=get.summed_orbital_icohp(obj)
            if isempty(obj.orbitals)
                error("KSSOLV:Matgenlab:IcohpValue:MissingOrbitals", ...
                    "Orbital-resolved values are absent.");
            end
            keys=obj.orbitals.keys;value=containers.Map("KeyType","char","ValueType","double");
            for ii=1:numel(keys)
                item=obj.orbitals(keys{ii});number=item.icohp.up;
                if isfield(item.icohp,"down"),number=number+item.icohp.down;end
                value(keys{ii})=number;
            end
        end
        function text=char(obj)
            if obj.are_coops
                populationName="ICOOP";
            elseif obj.are_cobis
                populationName="ICOBI";
            else
                populationName="ICOHP";
            end
            text=sprintf("%s %s between %s and %s ([%g %g %g]): %g eV (Spin up)", ...
                populationName,obj.label,obj.atom1,obj.atom2,obj.translation_,obj.icohp_.up);
            if obj.is_spin_polarized,text=text+sprintf(" and %g eV (Spin down)",obj.icohp_.down);end
            text=char(text);
        end
        function data=as_dict(obj)
            data=struct(x_module="pymatgen.electronic_structure.cohp", ...
                x_class="IcohpValue",label=obj.label,atom1=obj.atom1,atom2=obj.atom2, ...
                length=obj.length,translation=obj.translation_,num=obj.num_, ...
                icohp=spinWire(obj.icohp_),are_coops=obj.are_coops, ...
                are_cobis=obj.are_cobis);
            if ~isempty(obj.orbitals),data.orbitals=orbitalWire(obj.orbitals);end
        end
        function data=asDict(obj),data=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(data)
            args={"are_coops",fieldOr(data,"are_coops",false), ...
                "are_cobis",fieldOr(data,"are_cobis",false)};
            if isfield(data,"orbitals"),args=[args,{"orbitals",data.orbitals}];end
            obj=kssolv.analysis.matgenlab.electronic_structure.IcohpValue( ...
                data.label,data.atom1,data.atom2,data.length,data.translation, ...
                data.num,data.icohp,args{:});
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.electronic_structure.IcohpValue.from_dict(data);end
    end
end

function value=normalizeSpinScalar(input)
if isa(input,"containers.Map"),keys=input.keys;getter=@(k)input(k);
else,keys=fieldnames(input);getter=@(k)input.(k);end
value=struct();
for ii=1:numel(keys),value.(spinField(keys{ii}))=double(getter(keys{ii}));end
end
function field=spinField(spin)
if isa(spin,"kssolv.analysis.matgenlab.electronic_structure.Spin"),spin=double(spin);end
if any(lower(string(spin))==["-1","down","x_1"]),field="down";else,field="up";end
field=char(field);
end
function value=normalizeOrbitalData(input)
if isempty(input),value=[];return,end
if isa(input,"containers.Map"),raw=input;else,raw=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),raw(originalKey(names{ii}))=input.(names{ii});end,end
value=containers.Map("KeyType","char","ValueType","any");keys=raw.keys;
for ii=1:numel(keys)
    item=raw(keys{ii});item.icohp=normalizeSpinScalar(item.icohp);value(keys{ii})=item;
end
end
function key=originalKey(field),key=char(field);if startsWith(key,"x")&&contains(key,"_"),key=strrep(key(2:end),"_","-");end,end
function value=spinWire(input)
keys={'1'};vals={input.up};if isfield(input,"down"),keys{2}='-1';vals{2}=input.down;end
value=containers.Map(keys,vals);
end
function value=orbitalWire(input)
value=containers.Map("KeyType","char","ValueType","any");
keys=input.keys;
for ii=1:numel(keys)
    item=input(keys{ii});
    item.icohp=spinWire(item.icohp);
    if isfield(item,"orbitals")
        item.orbitals=orbitalListWire(item.orbitals);
    end
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
