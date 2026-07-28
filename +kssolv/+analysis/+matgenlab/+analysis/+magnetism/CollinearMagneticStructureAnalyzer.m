classdef CollinearMagneticStructureAnalyzer
    %COLLINEARMAGNETICSTRUCTUREANALYZER Analyze collinear magnetic structures.
    %#ok<*ALIGN,*NOCOMMA>
    properties (SetAccess=private)
        structure
        default_magmoms
        is_collinear (1,1) logical
        total_magmoms (1,1) double
        magnetization (1,1) double
        threshold_ordering (1,1) double
    end
    properties (Dependent,SetAccess=private)
        is_magnetic
        magmoms
        types_of_magnetic_species
        types_of_magnetic_specie
        magnetic_species_and_magmoms
        number_of_magnetic_sites
        ordering
    end
    methods
        function obj=CollinearMagneticStructureAnalyzer(structure,varargin)
            defaults=struct(overwrite_magmom_mode="none",round_magmoms=false, ...
                detect_valences=false,make_primitive=true,default_magmoms=[], ...
                set_net_positive=true,threshold=0,threshold_nonmag=.1, ...
                threshold_ordering=1e-8);
            options=kssolv.analysis.matgenlab.analysis.magnetism.internal. ...
                options(defaults,varargin);
            mode=string(options.overwrite_magmom_mode);
            if isa(options.overwrite_magmom_mode, ...
                    "kssolv.analysis.matgenlab.analysis.magnetism.OverwriteMagmomMode")
                mode=string(options.overwrite_magmom_mode);
            end
            allowed=["none","respect_sign","respect_zeros","replace_all", ...
                "replace_all_if_undefined","normalize"];
            if ~isscalar(mode)||~any(mode==allowed)
                error("KSSOLV:Matgenlab:Magnetism:OverwriteMode", ...
                    "Invalid overwrite_magmom_mode '%s'.",mode);
            end
            if isempty(options.default_magmoms)
                obj.default_magmoms=kssolv.analysis.matgenlab.analysis. ...
                    magnetism.internal.default_magmoms();
            else,obj.default_magmoms=options.default_magmoms;end
            structure=structure.copy();
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Magnetism:Disordered", ...
                    "Collinear magnetic analysis requires an ordered structure.");
            end
            if options.detect_valences
                transform=kssolv.analysis.matgenlab.transformations. ...
                    AutoOxiStateDecorationTransformation();
                try,structure=transform.apply_transformation(structure);
                catch exception
                    warning("KSSOLV:Matgenlab:Magnetism:Valence", ...
                        "Could not assign valences: %s",exception.message);
                end
            end
            props=structure.site_properties;
            hasMag=isfield(props,"magmom")&& ...
                any(~cellfun(@isempty,props.magmom));
            hasSpin=false;
            for index=1:structure.num_sites
                specie=structure(index).specie;
                hasSpin=hasSpin||(isa(specie, ...
                    "kssolv.analysis.matgenlab.core.Species")&& ...
                    ~isnan(specie.spin)&&specie.spin~=0);
            end
            if hasMag&&hasSpin
                error("KSSOLV:Matgenlab:Magnetism:AmbiguousMoments", ...
                    "Magnetic moments occur as both site properties and species spins.");
            end
            if hasMag
                raw=props.magmom;
                if iscell(raw)
                    vectors=cell(1,numel(raw));
                    for index=1:numel(raw)
                        if isempty(raw{index}),vectors{index}=0;
                        else,vectors{index}=double(raw{index});end
                    end
                else,vectors=num2cell(raw,2).';end
            elseif hasSpin
                vectors=cell(1,structure.num_sites);
                for index=1:structure.num_sites
                    specie=structure(index).specie;
                    spin=0;
                    if isa(specie,"kssolv.analysis.matgenlab.core.Species")
                        spin=specie.spin;
                    end
                    if isnan(spin),spin=0;end
                    vectors{index}=spin;
                end
                structure=structure.remove_spin();
            else
                vectors=num2cell(zeros(1,structure.num_sites));
                if mode=="replace_all_if_undefined",mode="replace_all";end
            end
            [obj.is_collinear,moments]=collinearMoments(vectors);
            obj.total_magmoms=sum(moments);
            obj.magnetization=obj.total_magmoms/structure.volume;
            for index=1:structure.num_sites
                speciesKey=string(structure(index).species_string);
                [~,isMagSpecies]=kssolv.analysis.matgenlab.analysis. ...
                    magnetism.internal.map_value(obj.default_magmoms,speciesKey);
                limit=options.threshold_nonmag;
                if isMagSpecies,limit=options.threshold;end
                if abs(moments(index))<=limit,moments(index)=0;end
                [default,found]=kssolv.analysis.matgenlab.analysis. ...
                    magnetism.internal.map_value(obj.default_magmoms,speciesKey);
                if ~found
                    [default,found]=kssolv.analysis.matgenlab.analysis. ...
                        magnetism.internal.map_value(obj.default_magmoms, ...
                        structure(index).specie.symbol);
                end
                if ~found,default=0;end
                switch mode
                    case "respect_sign"
                        options.set_net_positive=false;
                        moments(index)=sign(moments(index))*default;
                    case "respect_zeros"
                        if moments(index)~=0,moments(index)=default;end
                    case "replace_all"
                        moments(index)=default;
                    case "normalize"
                        moments(index)=sign(moments(index));
                end
            end
            if ~isequal(options.round_magmoms,false)
                moments=roundMoments(moments,options.round_magmoms);
            end
            if options.set_net_positive&&sum(moments)<0,moments=-moments;end
            structure=structure.add_site_property("magmom",moments);
            if options.make_primitive
                structure=magneticPrimitive(structure);
            end
            obj.structure=structure;
            obj.threshold_ordering=double(options.threshold_ordering);
        end
        function value=get.is_magnetic(obj),value=any(abs(obj.magmoms)>0);end
        function value=get.magmoms(obj)
            raw=obj.structure.site_properties.magmom;
            if iscell(raw),value=cellfun(@double,raw);
            else,value=double(raw);end
            value=reshape(value,1,[]);
        end
        function value=get.number_of_magnetic_sites(obj)
            value=nnz(abs(obj.magmoms)>0);
        end
        function value=get.types_of_magnetic_species(obj)
            value={};identifiers=strings(1,0);
            moments=obj.magmoms;
            for index=find(abs(moments)>0)
                specie=obj.structure(index).specie;key=string(specie);
                if ~any(identifiers==key)
                    identifiers(end+1)=key;value{end+1}=specie; %#ok<AGROW>
                end
            end
            if numel(value)>1
                [~,order]=sort(string(cellfun(@string,value, ...
                    "UniformOutput",false)));value=value(order);
            end
        end
        function value=get.types_of_magnetic_specie(obj)
            value=obj.types_of_magnetic_species;
        end
        function value=get.magnetic_species_and_magmoms(obj)
            value=containers.Map("KeyType","char","ValueType","any");
            moments=abs(obj.magmoms);
            for index=find(moments>0)
                key=char(string(obj.structure(index).specie));
                if isKey(value,key),items=unique([value(key),moments(index)]);
                else,items=moments(index);end
                value(key)=items;
            end
        end
        function value=get.ordering(obj)
            if ~obj.is_collinear
                value=kssolv.analysis.matgenlab.analysis.magnetism. ...
                    Ordering.Unknown;return
            end
            moments=obj.magmoms;total=abs(sum(moments));
            sameSign=all(moments>=0)||all(moments<=0);
            if total>obj.threshold_ordering&&sameSign
                value=kssolv.analysis.matgenlab.analysis.magnetism.Ordering.FM;
            elseif total>obj.threshold_ordering
                value=kssolv.analysis.matgenlab.analysis.magnetism.Ordering.FiM;
            elseif max(moments)>0
                value=kssolv.analysis.matgenlab.analysis.magnetism.Ordering.AFM;
            else
                value=kssolv.analysis.matgenlab.analysis.magnetism.Ordering.NM;
            end
        end
        function structure=get_structure_with_spin(obj)
            structure=obj.structure.copy();
            structure=structure.add_spin_by_site(obj.magmoms);
            structure=structure.remove_site_property("magmom");
        end
        function structure=get_structure_with_only_magnetic_atoms(obj,makePrimitive)
            if nargin<2,makePrimitive=true;end
            sites=obj.structure.sites(abs(obj.magmoms)>0);
            if isempty(sites)
                error("KSSOLV:Matgenlab:Magnetism:NoMagneticSites", ...
                    "The structure contains no magnetic sites.");
            end
            structure=kssolv.analysis.matgenlab.core.Structure.from_sites(sites);
            if makePrimitive,structure=magneticPrimitive(structure);end
        end
        function structure=get_nonmagnetic_structure(obj,makePrimitive)
            if nargin<2,makePrimitive=true;end
            structure=obj.structure.copy();
            structure=structure.remove_site_property("magmom");
            if makePrimitive,structure=structure.get_primitive_structure();end
        end
        function structure=get_ferromagnetic_structure(obj,makePrimitive)
            if nargin<2,makePrimitive=true;end
            structure=obj.structure.copy();
            structure=structure.add_site_property("magmom",abs(obj.magmoms));
            if makePrimitive,structure=magneticPrimitive(structure);end
        end
        function count=number_of_unique_magnetic_sites(obj,symprec,angleTolerance)
            if nargin<2,symprec=1e-3;end
            if nargin<3,angleTolerance=5;end
            plain=obj.get_nonmagnetic_structure(false);
            sga=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(plain,symprec,angleTolerance);
            symm=sga.get_symmetrized_structure();count=0;
            identifiers=string(cellfun(@string,obj.types_of_magnetic_species, ...
                "UniformOutput",false));
            for group=1:numel(symm.equivalent_sites)
                if any(string(symm.equivalent_sites{group}{1}.specie)==identifiers)
                    count=count+1;
                end
            end
        end
        function info=get_exchange_group_info(obj,symprec,angleTolerance)
            if nargin<2,symprec=1e-2;end
            if nargin<3,angleTolerance=5;end
            info=obj.get_structure_with_spin().get_space_group_info( ...
                symprec,angleTolerance);
        end
        function value=matches_ordering(obj,other)
            cls="kssolv.analysis.matgenlab.analysis.magnetism." + ...
                "CollinearMagneticStructureAnalyzer";
            first=feval(cls,obj.structure,"overwrite_magmom_mode","normalize");
            first=first.get_structure_with_spin();
            positive=feval(cls,other,"overwrite_magmom_mode","normalize", ...
                "make_primitive",false);
            negative=positive.structure.copy();
            negative=negative.add_site_property("magmom",-positive.magmoms);
            negative=feval(cls,negative,"overwrite_magmom_mode","normalize", ...
                "make_primitive",false);
            matcher=kssolv.analysis.matgenlab.core.StructureMatcher();
            value=matcher.fit(first,positive.get_structure_with_spin())|| ...
                matcher.fit(first,negative.get_structure_with_spin());
        end
    end
end

function [isCollinear,moments]=collinearMoments(values)
n=numel(values);matrix=zeros(n,3);scalar=true;
for index=1:n
    item=reshape(double(values{index}),1,[]);
    if isscalar(item),matrix(index,:)=[0,0,item];
    elseif numel(item)==3,matrix(index,:)=item;scalar=false;
    else
        error("KSSOLV:Matgenlab:Magnetism:MagmomShape", ...
            "A magnetic moment must be scalar or a three-vector.");
    end
end
nonzero=vecnorm(matrix,2,2)>1e-12;
if nnz(nonzero)<2,isCollinear=true;
else
    reference=matrix(find(nonzero,1),:);
    isCollinear=all(vecnorm(cross(matrix(nonzero,:), ...
        repmat(reference,nnz(nonzero),1),2),2,2)<= ...
        1e-8*max(vecnorm(matrix(nonzero,:),2,2)*norm(reference),1));
end
if scalar,moments=matrix(:,3).';
elseif isCollinear
    reference=matrix(find(nonzero,1),:);reference=reference/norm(reference);
    moments=(matrix*reference.').';
else,moments=vecnorm(matrix,2,2).';end
end

function moments=roundMoments(moments,mode)
if islogical(mode),mode=0;end
if mode==fix(mode)
    moments=round(moments,double(mode));return
end
width=double(mode);
try
    range=1.5*max([max(moments),abs(min(moments))]);
    count=max(3,fix(1000*range/width));
    grid=linspace(-range,range,count);
    sigma=std(moments,0)*width;
    if sigma<=0,error("KSSOLV:Matgenlab:Magnetism:SingularKDE","Singular KDE.");end
    density=sum(exp(-.5*((grid.'-moments)/sigma).^2),2);
    peaks=grid([false;density(2:end-1)>density(1:end-2)& ...
        density(2:end-1)>density(3:end);false]);
    if isempty(peaks),error("KSSOLV:Matgenlab:Magnetism:NoKDEPeak","No KDE peak.");end
    for index=1:numel(moments)
        [~,nearest]=min(abs(peaks-moments(index)));moments(index)=peaks(nearest);
    end
catch exception
    warning("KSSOLV:Matgenlab:Magnetism:Round", ...
        "Intelligent magnetic-moment rounding failed: %s",exception.message);
end
text=char(string(width));point=strfind(text,'.');
if isempty(point),digits=1;else,digits=numel(text)-point+1;end
moments=round(moments,digits);
end

function structure=magneticPrimitive(structure)
moments=structure.site_properties.magmom;
if iscell(moments),moments=cellfun(@double,moments);end
structure=structure.remove_site_property("magmom");
structure=structure.add_spin_by_site(moments);
structure=structure.get_primitive_structure(.25,true);
moments=zeros(1,structure.num_sites);
for index=1:structure.num_sites
    moments(index)=structure(index).specie.spin;
end
structure=structure.remove_spin();
structure=structure.add_site_property("magmom",moments);
end
