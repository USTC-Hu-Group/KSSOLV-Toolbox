classdef CompleteCohp < kssolv.analysis.matgenlab.electronic_structure.Cohp
    %COMPLETECOHP Average, bond-resolved and orbital-resolved COHP data.
    properties (SetAccess=private)
        structure
        all_cohps
        bonds
        orb_res_cohp
    end
    methods
        function obj=CompleteCohp(structure,avgCohp,cohpDict,varargin)
            if nargin==0
                structure=[];avgCohp=kssolv.analysis.matgenlab. ...
                    electronic_structure.Cohp(0,0,0);cohpDict=struct();
            end
            options=struct(bonds=[],are_coops=avgCohp.are_coops, ...
                are_cobis=avgCohp.are_cobis, ...
                are_multi_center_cobis=avgCohp.are_multi_center_cobis, ...
                orb_res_cohp=[]);
            options=parseOptions(options,varargin);
            obj@kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                avgCohp.efermi,avgCohp.energies,avgCohp.cohp, ...
                "icohp",avgCohp.icohp,"are_coops",options.are_coops, ...
                "are_cobis",options.are_cobis, ...
                "are_multi_center_cobis",options.are_multi_center_cobis);
            obj.structure=structure;
            obj.all_cohps=asMap(cohpDict);
            if isempty(options.bonds)
                labels=obj.all_cohps.keys;values=repmat({struct()},size(labels));
                if isempty(labels)
                    obj.bonds=containers.Map("KeyType","char","ValueType","any");
                else
                    obj.bonds=containers.Map(labels,values,"UniformValues",false);
                end
            else
                obj.bonds=asMap(options.bonds);
            end
            if isempty(options.orb_res_cohp),obj.orb_res_cohp=[];
            else
                obj.orb_res_cohp=normalizeOrbitalMap(options.orb_res_cohp);
            end
        end
        function value=get_cohp_by_label(obj,label,summedSpinChannels)
            if nargin<3||isempty(summedSpinChannels),summedSpinChannels=false;end
            label=char(string(label));
            if strcmpi(label,"average")
                cohp=obj.cohp;icohp=obj.icohp;
            else
                source=obj.all_cohps(label);cohp=source.cohp;icohp=source.icohp;
            end
            if summedSpinChannels&&isfield(cohp,"down")
                cohp=struct("up",cohp.up+cohp.down);
                if ~isempty(icohp),icohp=struct("up",icohp.up+icohp.down);end
            end
            value=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                obj.efermi,obj.energies,cohp,"icohp",icohp, ...
                "are_coops",obj.are_coops,"are_cobis",obj.are_cobis, ...
                "are_multi_center_cobis",obj.are_multi_center_cobis);
        end
        function value=get_summed_cohp_by_label_list(obj,labels,divisor,summed)
            if nargin<3||isempty(divisor),divisor=1;end
            if nargin<4||isempty(summed),summed=false;end
            labels=cellstr(string(labels));first=obj.get_cohp_by_label(labels{1});
            cohp=first.cohp;icohp=first.icohp;
            for ii=2:numel(labels)
                item=obj.get_cohp_by_label(labels{ii});
                cohp=addSpinMaps(cohp,item.cohp);
                if ~isempty(icohp),icohp=addSpinMaps(icohp,item.icohp);end
            end
            cohp=scaleSpinMap(cohp,1/divisor);
            if ~isempty(icohp),icohp=scaleSpinMap(icohp,1/divisor);end
            if summed&&isfield(cohp,"down")
                cohp=struct("up",cohp.up+cohp.down);
                if ~isempty(icohp),icohp=struct("up",icohp.up+icohp.down);end
            end
            value=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                obj.efermi,obj.energies,cohp,"icohp",icohp, ...
                "are_coops",obj.are_coops,"are_cobis",obj.are_cobis, ...
                "are_multi_center_cobis",obj.are_multi_center_cobis);
        end
        function value=get_summed_cohp_by_label_and_orbital_list( ...
                obj,labels,orbitals,divisor,summed)
            if nargin<4||isempty(divisor),divisor=1;end
            if nargin<5||isempty(summed),summed=false;end
            labels=cellstr(string(labels));orbitals=cellstr(string(orbitals));
            if numel(labels)~=numel(orbitals)
                error("KSSOLV:Matgenlab:CompleteCohp:ListLength", ...
                    "label_list and orbital_list must have the same length.");
            end
            first=obj.get_orbital_resolved_cohp(labels{1},orbitals{1});
            if isempty(first)
                error("KSSOLV:Matgenlab:CompleteCohp:Orbital","Orbital data are absent.");
            end
            cohp=first.cohp;icohp=first.icohp;
            for ii=2:numel(labels)
                item=obj.get_orbital_resolved_cohp(labels{ii},orbitals{ii});
                cohp=addSpinMaps(cohp,item.cohp);
                if ~isempty(icohp),icohp=addSpinMaps(icohp,item.icohp);end
            end
            cohp=scaleSpinMap(cohp,1/divisor);
            if ~isempty(icohp),icohp=scaleSpinMap(icohp,1/divisor);end
            if summed&&isfield(cohp,"down")
                cohp=struct("up",cohp.up+cohp.down);
                if ~isempty(icohp),icohp=struct("up",icohp.up+icohp.down);end
            end
            value=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                obj.efermi,obj.energies,cohp,"icohp",icohp, ...
                "are_coops",obj.are_coops,"are_cobis",obj.are_cobis);
        end
        function value=get_orbital_resolved_cohp(obj,label,orbitals,summed)
            if nargin<4||isempty(summed),summed=false;end
            if isempty(obj.orb_res_cohp),value=[];return,end
            label=char(string(label));bond=obj.orb_res_cohp(label);
            if ischar(orbitals)||isstring(orbitals),key=char(string(orbitals));
            else
                wanted=normalizeOrbitalList(orbitals);key="";
                keys=bond.keys;
                for ii=1:numel(keys)
                    candidate=bond(keys{ii});
                    if orbitalListsEqual(candidate.orbitals,wanted),key=keys{ii};break,end
                end
                if key=="",error("KSSOLV:Matgenlab:CompleteCohp:Orbital", ...
                        "Requested orbital pair is absent.");end
                key=char(key);
            end
            item=bond(key);cohp=item.COHP;
            if isfield(item,"ICOHP"),icohp=item.ICOHP;else,icohp=[];end
            if summed&&isfield(cohp,"down")
                cohp=struct("up",cohp.up+cohp.down);
                if ~isempty(icohp),icohp=struct("up",icohp.up+icohp.down);end
            end
            value=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                obj.efermi,obj.energies,cohp,"icohp",icohp, ...
                "are_coops",obj.are_coops,"are_cobis",obj.are_cobis);
        end
        function data=as_dict(obj)
            cohpWire=containers.Map("KeyType","char","ValueType","any");
            cohpWire("average")=spinWire(obj.cohp);
            if ~isempty(obj.icohp)
                icohpWire=containers.Map("KeyType","char","ValueType","any");
                icohpWire("average")=spinWire(obj.icohp);
            else
                icohpWire=[];
            end
            labels=obj.all_cohps.keys;
            for ii=1:numel(labels)
                item=obj.all_cohps(labels{ii});cohpWire(labels{ii})=spinWire(item.cohp);
                if ~isempty(item.icohp)
                    if isempty(icohpWire),icohpWire=containers.Map("KeyType","char","ValueType","any");end
                    icohpWire(labels{ii})=spinWire(item.icohp);
                end
            end
            data=struct(x_module="pymatgen.electronic_structure.cohp", ...
                x_class="CompleteCohp",are_coops=obj.are_coops, ...
                are_cobis=obj.are_cobis, ...
                are_multi_center_cobis=obj.are_multi_center_cobis, ...
                efermi=obj.efermi,structure=obj.structure.as_dict(), ...
                energies=obj.energies,COHP=cohpWire);
            if ~isempty(icohpWire),data.ICOHP=icohpWire;end
            if ~isempty(obj.bonds)&&obj.bonds.Count>0
                bondWire=containers.Map("KeyType","char","ValueType","any");
                keys=obj.bonds.keys;
                for ii=1:numel(keys)
                    item=obj.bonds(keys{ii});
                    if isempty(fieldnames(item)),continue,end
                    record=struct("length",item.length);
                    if isfield(item,"sites")
                        record.sites=cellfun(@(x)x.as_dict(),asCell(item.sites), ...
                            "UniformOutput",false);
                    end
                    if isfield(item,"cells"),record.cells=item.cells;end
                    bondWire(keys{ii})=record;
                end
                if bondWire.Count>0,data.bonds=bondWire;end
            end
            if ~isempty(obj.orb_res_cohp)
                data.orb_res_cohp=orbitalMapToWire(obj.orb_res_cohp);
            end
        end
        function data=asDict(obj),data=obj.as_dict();end
        function text=char(obj)
            if obj.are_coops,label="COOPs";elseif obj.are_cobis,label="COBIs";else,label="COHPs";end
            text=char("Complete "+label+" for "+string(obj.structure.formula));
        end
    end
    methods (Static)
        function obj=from_dict(data)
            structure=kssolv.analysis.matgenlab.core.Structure.from_dict(data.structure);
            cohpSource=asMap(data.COHP);
            if isfield(data,"ICOHP"),icohpSource=asMap(data.ICOHP);else,icohpSource=[];end
            labels=cohpSource.keys;all=containers.Map("KeyType","char","ValueType","any");
            avg=[];
            for ii=1:numel(labels)
                label=labels{ii};cohp=cohpSource(label);icohp=[];
                if ~isempty(icohpSource)&&isKey(icohpSource,label),icohp=icohpSource(label);end
                item=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                    data.efermi,data.energies,cohp,"icohp",icohp, ...
                    "are_coops",fieldOr(data,"are_coops",false), ...
                    "are_cobis",fieldOr(data,"are_cobis",false), ...
                    "are_multi_center_cobis",fieldOr(data,"are_multi_center_cobis",false));
                if strcmpi(label,"average"),avg=item;else,all(label)=item;end
            end
            if isempty(avg)
                error("KSSOLV:Matgenlab:CompleteCohp:Average","Average COHP is absent.");
            end
            bonds=[];if isfield(data,"bonds"),bonds=decodeBonds(data.bonds);end
            orbitals=[];if isfield(data,"orb_res_cohp"),orbitals=normalizeOrbitalMap(data.orb_res_cohp);end
            obj=kssolv.analysis.matgenlab.electronic_structure.CompleteCohp( ...
                structure,avg,all,"bonds",bonds, ...
                "are_coops",fieldOr(data,"are_coops",false), ...
                "are_cobis",fieldOr(data,"are_cobis",false), ...
                "are_multi_center_cobis",fieldOr(data,"are_multi_center_cobis",false), ...
                "orb_res_cohp",orbitals);
        end
        function obj=fromDict(data),obj=kssolv.analysis.matgenlab.electronic_structure.CompleteCohp.from_dict(data);end
        function obj=from_file(fmt,filename,structureFile,varargin)
            options=struct(are_coops=false,are_cobis=false, ...
                are_multi_center_cobis=false);options=parseOptions(options,varargin);
            if nargin<2||isempty(filename)
                if strcmpi(fmt,"LMTO")
                    filename="COPL";
                elseif options.are_coops
                    filename="COOPCAR.lobster";
                elseif options.are_cobis||options.are_multi_center_cobis
                    filename="COBICAR.lobster";
                else
                    filename="COHPCAR.lobster";
                end
            end
            if endsWith(string(filename),[".json",".json.gz"])
                text=readMaybeGzip(filename);
                obj=kssolv.analysis.matgenlab.electronic_structure.CompleteCohp. ...
                    from_dict(jsondecode(text));return
            end
            if nargin<3||isempty(structureFile)
                if strcmpi(fmt,"LMTO"),structureFile="CTRL";else,structureFile="POSCAR";end
            end
            if strcmpi(fmt,"LOBSTER")
                parsed=parseLobster(filename,options.are_multi_center_cobis);
                structure=kssolv.analysis.matgenlab.io.vasp.Poscar. ...
                    from_file(structureFile).structure;
            elseif strcmpi(fmt,"LMTO")
                if options.are_coops||options.are_cobis||options.are_multi_center_cobis
                    error("KSSOLV:Matgenlab:CompleteCohp:LMTOType", ...
                        "LMTO COPL supports COHP data only.");
                end
                parsed=parseLmto(filename);
                structure=parseCtrlStructure(structureFile);
            else
                error("KSSOLV:Matgenlab:CompleteCohp:Format", ...
                    "Unknown format '%s'; expected LMTO or LOBSTER.",string(fmt));
            end
            labels=parsed.curves.keys;all=containers.Map("KeyType","char","ValueType","any");
            for ii=1:numel(labels)
                item=parsed.curves(labels{ii});
                all(labels{ii})=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                    parsed.efermi,parsed.energies,item.COHP,"icohp",item.ICOHP, ...
                    "are_coops",options.are_coops,"are_cobis",options.are_cobis, ...
                    "are_multi_center_cobis",options.are_multi_center_cobis);
            end
            if strcmpi(fmt,"LMTO")
                avgCohp=meanCurves(all,parsed.efermi,parsed.energies);
            else,avgCohp=kssolv.analysis.matgenlab.electronic_structure.Cohp( ...
                    parsed.efermi,parsed.energies,parsed.average.COHP, ...
                    "icohp",parsed.average.ICOHP,"are_coops",options.are_coops, ...
                    "are_cobis",options.are_cobis, ...
                    "are_multi_center_cobis",options.are_multi_center_cobis);
            end
            bondLabels=parsed.bonds.keys;
            for ii=1:numel(bondLabels)
                record=parsed.bonds(bondLabels{ii});
                if isfield(record,"site_indices")
                    indices=record.site_indices;
                    record.sites=arrayfun(@(index)structure.sites{index}, ...
                        indices,"UniformOutput",false);
                    record=rmfield(record,"site_indices");
                    parsed.bonds(bondLabels{ii})=record;
                end
            end
            obj=kssolv.analysis.matgenlab.electronic_structure.CompleteCohp( ...
                structure,avgCohp,all,"bonds",parsed.bonds, ...
                "are_coops",options.are_coops,"are_cobis",options.are_cobis, ...
                "are_multi_center_cobis",options.are_multi_center_cobis, ...
                "orb_res_cohp",parsed.orbitals);
        end
        function obj=fromFile(varargin),obj=kssolv.analysis.matgenlab.electronic_structure.CompleteCohp.from_file(varargin{:});end
    end
end

function map=asMap(input)
if isa(input,"containers.Map"),map=input;return,end
map=containers.Map("KeyType","char","ValueType","any");
if isempty(input),return,end
names=fieldnames(input);
for ii=1:numel(names),map(originalKey(names{ii}))=input.(names{ii});end
end
function key=originalKey(field)
key=char(field);
if ~isempty(regexp(key,'^x\d+$','once')),key=key(2:end);
elseif startsWith(key,"x_")&&~isempty(regexp(key(3:end),'^\d+$','once')),key=['-',key(3:end)];end
if ~isempty(regexp(key,'^[A-Z][a-z]?\d+_[A-Z][a-z]?\d+(?:_\d+)?$','once'))
    first=find(key=='_',1);key(first)='-';
end
end
function value=normalizeOrbitalMap(input)
outer=asMap(input);labels=outer.keys;
value=containers.Map("KeyType","char","ValueType","any");
for ii=1:numel(labels)
    raw=asMap(outer(labels{ii}));keys=raw.keys;
    bond=containers.Map("KeyType","char","ValueType","any");
    for jj=1:numel(keys)
        item=raw(keys{jj});
        item.COHP=normalizeSpin(item.COHP);
        if isfield(item,"ICOHP") && ~isempty(item.ICOHP),item.ICOHP=normalizeSpin(item.ICOHP);end
        if isfield(item,"orbitals"),item.orbitals=normalizeOrbitalList(item.orbitals);end
        bond(keys{jj})=item;
    end
    value(labels{ii})=bond;
end
end
function value=normalizeSpin(input)
map=asMap(input);value=struct();keys=map.keys;
for ii=1:numel(keys)
    if any(string(keys{ii})==["-1","down"]),field="down";else,field="up";end
    value.(field)=reshape(double(map(keys{ii})),1,[]);
end
end
function value=normalizeOrbitalList(input)
if iscell(input)&&~isempty(input)&&~iscell(input{1})&&numel(input)==2,input={input};end
value=cell(size(input));
for ii=1:numel(input)
    pair=input{ii};if isstruct(pair),pair=struct2cell(pair);end
    if iscell(pair),n=pair{1};orb=pair{2};else,n=pair(1);orb=pair(2);end
    if ~isa(orb,"kssolv.analysis.matgenlab.electronic_structure.Orbital")
        if isnumeric(orb),orb=orbitalByValue(orb);
        else,orb=orbitalByName(orb);end
    end
    value{ii}={double(n),orb};
end
end
function value=orbitalByName(name)
names=["s","py","pz","px","dxy","dyz","dz2","dxz","dx2", ...
    "f_3","f_2","f_1","f0","f1","f2","f3"];
idx=find(names==string(name),1);
if isempty(idx),error("KSSOLV:Matgenlab:CompleteCohp:OrbitalName", ...
        "Unknown orbital '%s'.",string(name));end
value=orbitalByValue(idx-1);
end
function value=orbitalByValue(number)
values=enumeration("kssolv.analysis.matgenlab.electronic_structure.Orbital");
index=find(arrayfun(@double,values)==double(number),1);
if isempty(index),error("KSSOLV:Matgenlab:CompleteCohp:OrbitalValue", ...
        "Unknown orbital value %g.",double(number));end
value=values(index);
end
function yes=orbitalListsEqual(a,b)
if numel(a)~=numel(b),yes=false;return,end
yes=true;
for ii=1:numel(a)
    yes=yes&&double(a{ii}{1})==double(b{ii}{1})&& ...
        double(a{ii}{2})==double(b{ii}{2});
end
end
function value=addSpinMaps(a,b)
value=a;names=fieldnames(a);
for ii=1:numel(names),value.(names{ii})=a.(names{ii})+b.(names{ii});end
end
function value=scaleSpinMap(a,factor)
value=a;names=fieldnames(a);
for ii=1:numel(names),value.(names{ii})=a.(names{ii})*factor;end
end
function value=spinWire(input)
keys={'1'};vals={input.up};if isfield(input,"down"),keys{end+1}='-1';vals{end+1}=input.down;end
value=containers.Map(keys,vals,"UniformValues",false);
end
function value=decodeBonds(input)
raw=asMap(input);value=containers.Map("KeyType","char","ValueType","any");
keys=raw.keys;
for ii=1:numel(keys)
    item=raw(keys{ii});
    if isfield(item,"sites")
        sites=asCell(item.sites);
        item.sites=cellfun(@(x)kssolv.analysis.matgenlab.core. ...
            PeriodicSite.from_dict(x),sites,"UniformOutput",false);
    end
    value(keys{ii})=item;
end
end
function value=orbitalMapToWire(input)
value=containers.Map("KeyType","char","ValueType","any");labels=input.keys;
for ii=1:numel(labels)
    source=input(labels{ii});bond=containers.Map("KeyType","char","ValueType","any");
    keys=source.keys;
    for jj=1:numel(keys)
        item=source(keys{jj});out=struct(COHP=spinWire(item.COHP));
        if isfield(item,"ICOHP") && ~isempty(item.ICOHP),out.ICOHP=spinWire(item.ICOHP);end
        if isfield(item,"orbitals")
            out.orbitals=cellfun(@(p){p{1},char(p{2})},item.orbitals,"UniformOutput",false);
        end
        bond(keys{jj})=out;
    end
    value(labels{ii})=bond;
end
end
function value=asCell(input)
if iscell(input),value=input;elseif isstruct(input),value=num2cell(input);else,value=num2cell(input);end
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
function text=readMaybeGzip(path)
path=string(path);
if endsWith(path,".gz")
    folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,"s"));
    files=gunzip(path,folder);text=fileread(files{1});clear cleanup
else
    text=fileread(path);
end
end

function parsed=parseLobster(path,areMultiCenter)
lines=splitlines(string(readMaybeGzip(path)));lines=lines(strlength(strtrim(lines))>0);
parameters=sscanf(lines(2),"%f").';count=parameters(1);spinCount=parameters(2);
energyCount=parameters(3);efermi=parameters(end);
headers=lines(3:2+count);numbers=zeros(energyCount,1+2*count*spinCount);
for ii=1:energyCount,numbers(ii,:)=sscanf(lines(2+count+ii),"%f").';end
energies=numbers(:,1).'+efermi;curves=containers.Map("KeyType","char","ValueType","any");
bonds=containers.Map("KeyType","char","ValueType","any");
orbitals=containers.Map("KeyType","char","ValueType","any");average=[];
orbitalSums=containers.Map("KeyType","char","ValueType","any");
for record=1:count
    cohp=struct("up",numbers(:,2*(record-1)+2).');
    icohp=struct("up",numbers(:,2*(record-1)+3).');
    if spinCount==2
        offset=2*count;
        cohp.down=numbers(:,offset+2*(record-1)+2).';
        icohp.down=numbers(:,offset+2*(record-1)+3).';
    end
    header=strtrim(headers(record));
    if strcmpi(header,"Average"),average=struct(COHP=cohp,ICOHP=icohp);continue,end
    if areMultiCenter
        main=regexp(header,'No\.(\d+):(.*)$','tokens','once');
        length=[];
    else
        main=regexp(header,'No\.(\d+):(.*)\(([-+0-9.eE]+)\)$','tokens','once');
        if ~isempty(main),length=str2double(main{3});end
    end
    if isempty(main),error("KSSOLV:Matgenlab:CompleteCohp:LobsterHeader", ...
            "Cannot parse COHPCAR header '%s'.",header);end
    endpoints=split(string(main{2}),"->");
    endpointData=cell(1,numel(endpoints));
    for endpointIndex=1:numel(endpoints)
        endpointData{endpointIndex}=parseEndpoint(endpoints(endpointIndex),areMultiCenter);
    end
    label=main{1};
    sites=cellfun(@(item)siteNumber(item.atom),endpointData);
    recordData=struct("length",length,"site_indices",sites);
    if areMultiCenter
        recordData.cells=cell2mat(cellfun(@(item)item.cell,endpointData, ...
            "UniformOutput",false).');
    end
    bonds(label)=recordData;
    orbitalTexts=strings(1,numel(endpointData));
    for endpointIndex=1:numel(endpointData)
        orbitalTexts(endpointIndex)=endpointData{endpointIndex}.orbital;
    end
    if any(strlength(orbitalTexts)>0)
        if ~isKey(orbitals,label),orbitals(label)=containers.Map("KeyType","char","ValueType","any");end
        bond=orbitals(label);key=orbitalLabel(orbitalTexts);
        orbitalList=cellfun(@parseLobsterOrbital,num2cell(orbitalTexts), ...
            "UniformOutput",false);
        bond(key)=struct(COHP=cohp,ICOHP=icohp, ...
            orbitals={orbitalList});
        orbitals(label)=bond;
        if ~isKey(orbitalSums,label),orbitalSums(label)=struct(COHP=cohp,ICOHP=icohp);
        else,item=orbitalSums(label);item.COHP=addSpinMaps(item.COHP,cohp);item.ICOHP=addSpinMaps(item.ICOHP,icohp);orbitalSums(label)=item;end
    else
        curves=insertUnique(curves,label,struct(COHP=cohp,ICOHP=icohp));
    end
end
labels=orbitals.keys;
for ii=1:numel(labels),if ~isKey(curves,labels{ii}),curves(labels{ii})=orbitalSums(labels{ii});end,end
if isempty(average)
    if areMultiCenter
        average=meanTwoCenterCurveStruct(curves,bonds);
    else
        average=meanCurveStruct(curves);
    end
end
parsed=struct(efermi=efermi,energies=energies,curves=curves, ...
    bonds=bonds,orbitals=orbitals,average=average);
end

function parsed=parseLmto(path)
lines=splitlines(string(readMaybeGzip(path)));lines=lines(strlength(strtrim(lines))>0);
parameters=sscanf(lines(2),"%f").';count=parameters(1);spinCount=parameters(2);
energyCount=parameters(3);ry=13.605693122990296;
numbers=zeros(energyCount,1+2*count*spinCount);
for ii=1:energyCount,numbers(ii,:)=sscanf(lines(2+count+ii),"%f").';end
energies=arrayfun(@(x)roundSig(x*ry,5),numbers(:,1)).';
efermi=roundSig(parameters(end)*ry,5);
curves=containers.Map("KeyType","char","ValueType","any");
bonds=containers.Map("KeyType","char","ValueType","any");
for record=1:count
    header=strtrim(lines(2+record));
    tokens=regexp(header,'(.*?)-(\d+)/(.*?)-(\d+)-tr\(([-\d,]+)\)\s*:\s*([-+0-9.]+)','tokens','once');
    if isempty(tokens),error("KSSOLV:Matgenlab:CompleteCohp:LMTOHeader","Cannot parse COPL header '%s'.",header);end
    base=sprintf("%s%d-%s%d",tokens{1},str2double(tokens{2}),tokens{3},str2double(tokens{4}));
    label=uniqueLabel(curves,base);cohp=struct("up",numbers(:,2*(record-1)+2).');
    icohp=struct("up",arrayfun(@(x)roundSig(x*ry,5),numbers(:,2*(record-1)+3)).');
    if spinCount==2
        offset=2*count;cohp.down=numbers(:,offset+2*(record-1)+2).';
        icohp.down=arrayfun(@(x)roundSig(x*ry,5),numbers(:,offset+2*(record-1)+3)).';
    end
    curves(label)=struct(COHP=cohp,ICOHP=icohp);
    translation=sscanf(tokens{5},"%f,%f,%f").';
    bonds(label)=struct(length=str2double(tokens{6}), ...
        site_indices=[str2double(tokens{2}),str2double(tokens{4})], ...
        cells=translation);
end
parsed=struct(efermi=efermi,energies=energies,curves=curves, ...
    bonds=bonds,orbitals=[],average=[]);
end

function structure=parseCtrlStructure(path)
lines=splitlines(string(readMaybeGzip(path)));
joined=strjoin(lines,newline);alatToken=regexp(joined,'ALAT=([-+0-9.eE]+)','tokens','once');
alat=str2double(alatToken{1})*.529177210903;
platToken=regexp(joined,'PLAT=([^\n]+)\n\s+([^\n]+)\n\s+([^\n]+)','tokens','once');
matrix=zeros(3);for ii=1:3,matrix(ii,:)=sscanf(platToken{ii},"%f").';end
lattice=kssolv.analysis.matgenlab.core.Lattice(matrix*alat);
siteLines=lines(startsWith(strtrim(lines),"SITE"));species=cell(1,numel(siteLines));coords=zeros(numel(siteLines),3);
for ii=1:numel(siteLines)
    token=regexp(siteLines(ii),'ATOM=([A-Za-z]+)\s+POS=\s*([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)','tokens','once');
    species{ii}=token{1};coords(ii,:)=str2double(token(2:4))*alat;
end
structure=kssolv.analysis.matgenlab.core.Structure(lattice,species,coords, ...
    coords_are_cartesian=true);
end

function avg=meanCurves(map,efermi,energies)
keys=map.keys;first=map(keys{1});data=struct(COHP=first.cohp,ICOHP=first.icohp);
names=fieldnames(first.cohp);
for nn=1:numel(names)
    cohpRows=cell2mat(cellfun(@(k)reshape(map(k).cohp.(names{nn}),1,[]),keys,"UniformOutput",false).');
    icohpRows=cell2mat(cellfun(@(k)reshape(map(k).icohp.(names{nn}),1,[]),keys,"UniformOutput",false).');
    data.COHP.(names{nn})=mean(cohpRows,1);
    data.ICOHP.(names{nn})=mean(icohpRows,1);
end
data.ICOHP.up=arrayfun(@(x)roundSig(x,5),data.ICOHP.up);
if isfield(data.ICOHP,"down"),data.ICOHP.down=arrayfun(@(x)roundSig(x,5),data.ICOHP.down);end
avg=kssolv.analysis.matgenlab.electronic_structure.Cohp(efermi,energies, ...
    data.COHP,"icohp",data.ICOHP);
end
function result=meanCurveStruct(map)
keys=map.keys;first=map(keys{1});result=first;
names=fieldnames(first.COHP);
for nn=1:numel(names)
    rows=cell2mat(cellfun(@(k)reshape(map(k).COHP.(names{nn}),1,[]),keys,"UniformOutput",false).');
    result.COHP.(names{nn})=mean(rows,1);
    rows=cell2mat(cellfun(@(k)reshape(map(k).ICOHP.(names{nn}),1,[]),keys,"UniformOutput",false).');
    result.ICOHP.(names{nn})=mean(rows,1);
end
end
function result=meanTwoCenterCurveStruct(curves,bonds)
selected=containers.Map("KeyType","char","ValueType","any");
keys=curves.keys;
for ii=1:numel(keys)
    record=bonds(keys{ii});
    if numel(record.site_indices)<=2
        selected(keys{ii})=curves(keys{ii});
    end
end
if selected.Count==0
    error("KSSOLV:Matgenlab:CompleteCohp:MultiCenterAverage", ...
        "A multi-center COBI average requires at least one two-center curve.");
end
result=meanCurveStruct(selected);
end
function map=insertUnique(map,label,value),map(uniqueLabel(map,label))=value;end
function label=uniqueLabel(map,base),label=char(base);index=1;while isKey(map,label),label=char(string(base)+"-"+index);index=index+1;end,end
function number=siteNumber(text),token=regexp(text,'(\d+)$','tokens','once');number=str2double(token{1});end
function key=orbitalLabel(orbitals)
key=char(strjoin(arrayfun(@cleanOrb,string(orbitals)),"-"));
end
function value=cleanOrb(input)
value=replace(lower(string(input)),["_"," "],"");
value=replace(value,["dz^2","dx^2-y^2"],["dz2","dx2"]);
end
function pair=parseLobsterOrbital(text)
token=regexp(char(text),'(\d+)(.*)','tokens','once');pair={str2double(token{1}),orbitalByName(cleanOrb(token{2}))};
end
function value=parseEndpoint(text,areMultiCenter)
atom=regexp(char(text),'^[A-Za-z]+\d+','match','once');
brackets=regexp(char(text),'\[([^\]]+)\]','tokens');
value=struct(atom=string(atom),orbital="",cell=zeros(1,3));
if areMultiCenter
    if isempty(brackets)
        error("KSSOLV:Matgenlab:CompleteCohp:LobsterHeader", ...
            "Multi-center COBI endpoint '%s' has no lattice cell.",text);
    end
    value.cell=sscanf(brackets{1}{1},"%f").';
    if numel(brackets)>1,value.orbital=string(brackets{2}{1});end
elseif ~isempty(brackets)
    value.orbital=string(brackets{1}{1});
end
end
function value=roundSig(input,digits)
if input==0,value=0;else,value=round(input,digits-1-floor(log10(abs(input))));end
end
