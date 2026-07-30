classdef ValenceIonicRadiusEvaluator
    %VALENCEIONICRADIUSEVALUATOR Assign oxidation states and ionic radii.
    properties (Access=private)
        structure_
        valences_
        ionic_radii_
    end
    properties (Dependent,SetAccess=private)
        radii
        valences
        structure
    end
    methods
        function obj=ValenceIonicRadiusEvaluator(structure)
            obj.structure_=structure;
            try
                analyzer=kssolv.analysis.matgenlab.core.BVAnalyzer();
                obj.valences_=analyzer.get_valences(structure);
                obj.structure_=analyzer.get_oxi_state_decorated_structure(structure);
            catch
                obj.valences_=zeros(1,structure.num_sites);
                for ii=1:structure.num_sites
                    states=structure(ii).specie.common_oxidation_states;
                    if ~isempty(states),obj.valences_(ii)=states(1);end
                end
                if abs(sum(obj.valences_))>1e-8,obj.valences_=zeros(size(obj.valences_));end
                try
                    obj.structure_=structure.add_oxidation_state_by_site(obj.valences_);
                catch
                end
            end
            obj.ionic_radii_=zeros(1,obj.structure_.num_sites);
            voronoi=kssolv.analysis.matgenlab.core.VoronoiNN();
            for ii=1:obj.structure_.num_sites
                species=obj.structure_(ii).specie;
                if isa(species,"kssolv.analysis.matgenlab.core.Species") && ...
                        isfinite(species.oxi_state)
                    coordination=voronoi.get_cn(obj.structure_,ii);
                    radius=coordinationRadius(species,coordination);
                else
                    radius=species.atomic_radius;
                    if isempty(radius)||isnan(radius)
                        element=species;
                        if isa(species, ...
                                "kssolv.analysis.matgenlab.core.Species")
                            element=species.element;
                        end
                        radius=element.atomic_radius_calculated;
                    end
                end
                if isempty(radius)||isnan(radius)
                    error("KSSOLV:Matgenlab:ValenceIonicRadius:Radius", ...
                        "Cannot assign a radius to %s.",species.symbol);
                end
                obj.ionic_radii_(ii)=radius;
            end
        end
        function value=get.radii(obj)
            value=struct();
            for ii=1:obj.structure_.num_sites
                key=matlab.lang.makeValidName(char(obj.structure_(ii).species_string));
                value.(key)=obj.ionic_radii_(ii);
            end
        end
        function value=get.valences(obj)
            value=struct();
            for ii=1:obj.structure_.num_sites
                key=matlab.lang.makeValidName(char(obj.structure_(ii).species_string));
                value.(key)=obj.valences_(ii);
            end
        end
        function value=get.structure(obj),value=obj.structure_;end
        function value=radius_for_site(obj,index),value=obj.ionic_radii_(index);end
    end
end

function radius=coordinationRadius(species,coordination)
data=ionicRadiiData();symbol=char(species.symbol);
if ~isfield(data,symbol)
    radius=species.ionic_radius;
    return
end
oxidationTable=data.(symbol);
[oxidationField,~]=nearestField(oxidationTable,round(species.oxi_state));
coordinationTable=oxidationTable.(oxidationField);
rounded=round(coordination);
[exact,found]=numericField(coordinationTable,rounded);
if found,radius=exact;return,end
adjacent=rounded-1;
if coordination-rounded>0,adjacent=rounded+1;end
[exact,found]=numericField(coordinationTable,adjacent);
if found,radius=exact;return,end
[~,coordinates]=nearestField(coordinationTable,rounded);
coordinates=sort(coordinates);
if rounded<=coordinates(1)
    radius=numericField(coordinationTable,coordinates(1));
elseif rounded>=coordinates(end)
    radius=numericField(coordinationTable,coordinates(end));
else
    lower=coordinates(find(coordinates<rounded,1,"last"));
    upper=coordinates(find(coordinates>rounded,1));
    radius=(numericField(coordinationTable,lower)+ ...
        numericField(coordinationTable,upper))/2;
end
end

function data=ionicRadiiData()
persistent cached
if isempty(cached)
    filename=fullfile(fileparts(mfilename("fullpath")),"+data", ...
        "ionic_radii.json");
    cached=jsondecode(fileread(filename));
end
data=cached;
end

function [field,numbers]=nearestField(value,target)
names=fieldnames(value);numbers=zeros(1,numel(names));
for ii=1:numel(names)
    numbers(ii)=decodeNumericField(names{ii});
end
[~,which]=min(abs(numbers-target));
field=names{which};
end

function [value,found]=numericField(record,key)
names=fieldnames(record);value=NaN;found=false;
for ii=1:numel(names)
    number=decodeNumericField(names{ii});
    if number==key
        value=record.(names{ii});found=true;
        return
    end
end
end

function number=decodeNumericField(field)
raw=regexprep(string(field),"^x","");
if startsWith(raw,"_"),raw="-"+extractAfter(raw,1);end
number=str2double(raw);
if isnan(number)
    error("KSSOLV:Matgenlab:ValenceIonicRadius:NumericKey", ...
        "Cannot decode ionic-radius key '%s'.",field);
end
end
