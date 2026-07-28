classdef MagneticStructureEnumerator
    %MAGNETICSTRUCTUREENUMERATOR Generate plausible collinear orderings.
    %#ok<*AGROW,*MSNU>
    properties (Constant)
        available_strategies=["ferromagnetic","antiferromagnetic", ...
            "ferrimagnetic_by_motif","ferrimagnetic_by_species", ...
            "antiferromagnetic_by_motif","nonmagnetic"]
    end
    properties
        structure
        default_magmoms
        strategies string
        automatic (1,1) logical
        truncate_by_symmetry
        num_orderings
        max_unique_sites (1,1) double=8
        transformation_kwargs (1,1) struct
        input_analyzer
        sanitized_structure
        transformations
        ordered_structures cell={}
        ordered_structure_origins string=strings(1,0)
        input_index=[]
        input_origin=[]
    end
    methods
        function obj=MagneticStructureEnumerator(structure,varargin)
            defaults=struct(default_magmoms=[],strategies= ...
                ["ferromagnetic","antiferromagnetic"],automatic=true, ...
                truncate_by_symmetry=true,max_orderings=64, ...
                transformation_kwargs=struct());
            options=kssolv.analysis.matgenlab.analysis.magnetism.internal. ...
                options(defaults,varargin);
            obj.structure=structure;obj.default_magmoms=options.default_magmoms;
            obj.strategies=reshape(string(options.strategies),1,[]);
            invalid=setdiff(obj.strategies,obj.available_strategies);
            if ~isempty(invalid)
                error("KSSOLV:Matgenlab:Magnetism:Strategy", ...
                    "Unknown magnetic enumeration strategy '%s'.",invalid(1));
            end
            obj.automatic=logical(options.automatic);
            obj.truncate_by_symmetry=options.truncate_by_symmetry;
            obj.num_orderings=options.max_orderings;
            obj.transformation_kwargs=options.transformation_kwargs;
            if ~isfield(obj.transformation_kwargs,"check_ordered_symmetry")
                obj.transformation_kwargs.check_ordered_symmetry=false;
            end
            if ~isfield(obj.transformation_kwargs,"timeout")
                obj.transformation_kwargs.timeout=5;
            end
            if ~structure.is_ordered
                error("KSSOLV:Matgenlab:Magnetism:Disordered", ...
                    "Obtain an ordered approximation before enumeration.");
            end
            Analyzer=@kssolv.analysis.matgenlab.analysis.magnetism. ...
                CollinearMagneticStructureAnalyzer;
            obj.input_analyzer=Analyzer(structure,"default_magmoms", ...
                obj.default_magmoms,"overwrite_magmom_mode","none");
            if ~obj.input_analyzer.is_collinear
                error("KSSOLV:Matgenlab:Magnetism:Noncollinear", ...
                    "Magnetic ordering enumeration requires collinear moments.");
            end
            clean=structure.copy();clean=clean.remove_spin();
            clean=clean.get_primitive_structure();
            if isfield(clean.site_properties,"magmom")
                clean=clean.remove_site_property("magmom");
            end
            obj.sanitized_structure=clean;
            [obj,obj.transformations]=generateTransformations(obj,clean);
            obj=generateStructures(obj);
        end
    end
end

function [obj,transformations]=generateTransformations(obj,structure)
Analyzer=@kssolv.analysis.matgenlab.analysis.magnetism. ...
    CollinearMagneticStructureAnalyzer;
analyzer=Analyzer(structure,"default_magmoms",obj.default_magmoms, ...
    "overwrite_magmom_mode","replace_all");
if ~analyzer.is_magnetic
    error("KSSOLV:Matgenlab:Magnetism:NotMagnetic", ...
        "No magnetic species detected; supply default_magmoms.");
end
speciesSpin=analyzer.magnetic_species_and_magmoms;
names=speciesSpin.keys();
for index=1:numel(names)
    value=speciesSpin(names{index});
    if numel(value)>1,value=value(1);end
    speciesSpin(names{index})=value;
end
types=string(cellfun(@string,analyzer.types_of_magnetic_species, ...
    "UniformOutput",false));
if analyzer.number_of_unique_magnetic_sites()>obj.max_unique_sites
    error("KSSOLV:Matgenlab:Magnetism:TooManySites", ...
        "Too many unique magnetic sites for sensible enumeration.");
end
symm=kssolv.analysis.matgenlab.symmetry.analyzer. ...
    SpacegroupAnalyzer(structure).get_symmetrized_structure();
wyckoff=repmat("n/a",1,structure.num_sites);
for group=1:numel(symm.equivalent_indices)
    ids=symm.equivalent_indices{group};
    for site=ids
        if any(string(structure(site).specie)==types)
            wyckoff(site)=symm.wyckoff_symbols(group);
        end
    end
end
structure=structure.add_site_property("wyckoff",wyckoff);
obj.sanitized_structure=structure;
symbols=setdiff(unique(wyckoff),"n/a");
if obj.automatic&&numel(symbols)>1&&isscalar(types)
    obj.strategies=unique([obj.strategies,"ferrimagnetic_by_motif", ...
        "antiferromagnetic_by_motif"],"stable");
end
if obj.automatic&&numel(types)>1
    obj.strategies=unique([obj.strategies,"ferrimagnetic_by_species"],"stable");
end
if any(obj.strategies=="ferromagnetic")
    fm=analyzer.get_ferromagnetic_structure();
    fmMoments=fm.site_properties.magmom;
    if iscell(fmMoments),fmMoments=cellfun(@double,fmMoments);end
    fm=fm.add_spin_by_site(fmMoments);
    fm=fm.remove_site_property("magmom");
    obj.ordered_structures{end+1}=fm;
    obj.ordered_structure_origins(end+1)="fm";
end
if any(obj.strategies=="nonmagnetic")
    obj.ordered_structures{end+1}=analyzer.get_nonmagnetic_structure();
    obj.ordered_structure_origins(end+1)="nonmagnetic";
end
entries={};
Constraint=@kssolv.analysis.matgenlab.transformations. ...
    MagOrderParameterConstraint;
if any(obj.strategies=="antiferromagnetic")
    entries(end+1,:)={"afm",{Constraint(.5,cellstr(types))}}; %#ok<AGROW>
    if numel(types)>1
        for specie=types
            entries(end+1,:)={"afm_by_"+specie, ...
                {Constraint(.5,char(specie))}}; %#ok<AGROW>
        end
    end
end
if any(obj.strategies=="ferrimagnetic_by_motif")&&numel(symbols)>1
    for symbol=symbols
        rest=setdiff(symbols,symbol);
        entries(end+1,:)={"ferri_by_motif_"+symbol,{ ... %#ok<AGROW>
            Constraint(.5,{},"wyckoff",char(symbol)), ...
            Constraint(1,{},"wyckoff",cellstr(rest))}};
    end
end
if any(obj.strategies=="ferrimagnetic_by_species")&&numel(types)>1
    siteTypes=string(cellfun(@(site)string(site.specie),structure.sites, ...
        "UniformOutput",false));
    counts=arrayfun(@(name)nnz(siteTypes==name),types);
    for index=1:numel(types)
        specie=types(index);rest=setdiff(types,specie);
        entries(end+1,:)={"ferri_by_"+specie,counts(index)/sum(counts)}; %#ok<AGROW>
        entries(end+1,:)={"ferri_by_"+specie+"_afm",{ ... %#ok<AGROW>
            Constraint(.5,char(specie)),Constraint(1,cellstr(rest))}};
    end
end
if any(obj.strategies=="antiferromagnetic_by_motif")
    for symbol=symbols
        entries(end+1,:)={"afm_by_motif_"+symbol,{ ... %#ok<AGROW>
            Constraint(.5,{},"wyckoff",char(symbol))}};
    end
end
transformations=containers.Map("KeyType","char","ValueType","any");
for index=1:size(entries,1)
    kwargs=structToArgs(obj.transformation_kwargs);
    transformations(char(entries{index,1}))= ...
        kssolv.analysis.matgenlab.transformations. ...
        MagOrderingTransformation(speciesSpin,entries{index,2},[],kwargs{:});
end
end

function obj=generateStructures(obj)
names=obj.transformations.keys();
for index=1:numel(names)
    transformed=obj.transformations(names{index}).apply_transformation( ...
        obj.sanitized_structure,obj.num_orderings);
    if ~iscell(transformed),transformed={transformed};end
    for item=1:numel(transformed)
        candidate=transformed{item};
        if isstruct(candidate),candidate=candidate.structure;end
        obj.ordered_structures{end+1}=candidate; %#ok<AGROW>
        obj.ordered_structure_origins(end+1)=string(names{index}); %#ok<AGROW>
    end
end
remove=false(1,numel(obj.ordered_structures));
for first=1:numel(obj.ordered_structures)
    if remove(first),continue,end
    analyzer=kssolv.analysis.matgenlab.analysis.magnetism. ...
        CollinearMagneticStructureAnalyzer(obj.ordered_structures{first});
    for second=first+1:numel(obj.ordered_structures)
        if ~remove(second)&&analyzer.matches_ordering(obj.ordered_structures{second})
            remove(second)=true;
        end
    end
end
obj.ordered_structures=obj.ordered_structures(~remove);
obj.ordered_structure_origins=obj.ordered_structure_origins(~remove);
if ~isequal(obj.truncate_by_symmetry,false)&&numel(obj.ordered_structures)>1
    keepKinds=double(obj.truncate_by_symmetry);
    if islogical(obj.truncate_by_symmetry),keepKinds=5;end
    operations=zeros(1,numel(obj.ordered_structures));
    for index=1:numel(operations)
        analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
            SpacegroupAnalyzer(obj.ordered_structures{index});
        operations(index)=numel(analyzer.get_symmetry_operations());
    end
    levels=sort(unique(operations),"descend");
    levels=levels(1:min(keepKinds,numel(levels)));
    keep=ismember(operations,levels);
    [~,order]=sort(operations(keep),"descend");
    obj.ordered_structures=obj.ordered_structures(keep);
    obj.ordered_structure_origins=obj.ordered_structure_origins(keep);
    obj.ordered_structures=obj.ordered_structures(order);
    obj.ordered_structure_origins=obj.ordered_structure_origins(order);
    fm=find(obj.ordered_structure_origins=="fm",1);
    if ~isempty(fm)
        obj.ordered_structures=[obj.ordered_structures(fm), ...
            obj.ordered_structures([1:fm-1,fm+1:end])];
        obj.ordered_structure_origins=[obj.ordered_structure_origins(fm), ...
            obj.ordered_structure_origins([1:fm-1,fm+1:end])];
    end
end
obj.input_index=[];obj.input_origin=[];
if obj.input_analyzer.ordering~= ...
        kssolv.analysis.matgenlab.analysis.magnetism.Ordering.NM
    matches=false(1,numel(obj.ordered_structures));
    for index=1:numel(matches)
        matches(index)=obj.input_analyzer.matches_ordering( ...
            obj.ordered_structures{index});
    end
    found=find(matches,1);
    if isempty(found)
        obj.ordered_structures{end+1}=obj.input_analyzer.structure;
        obj.ordered_structure_origins(end+1)="input";
    else
        obj.input_index=found;obj.input_origin=obj.ordered_structure_origins(found);
    end
end
end

function args=structToArgs(value)
names=fieldnames(value);args=cell(1,2*numel(names));
for index=1:numel(names)
    args{2*index-1}=names{index};args{2*index}=value.(names{index});
end
end
