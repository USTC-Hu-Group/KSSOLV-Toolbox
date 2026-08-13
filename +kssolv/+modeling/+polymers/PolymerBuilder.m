classdef PolymerBuilder
    %POLYMERBUILDER Deterministic topology-first polymer construction.

    methods (Static)
        function estimate = estimate(kind, count)
            template = repeatTemplate(kind);
            heavy = numel(template.species) * count;
            estimate = struct("repeatUnits", count, ...
                "heavyAtoms", heavy, ...
                "estimatedAtomsWithHydrogen", heavy * 3, ...
                "kind", upper(string(kind)));
        end

        function [molecule, metadata] = homopolymer(kind, count, options)
            arguments
                kind {mustBeTextScalar}
                count (1,1) double {mustBeInteger, mustBePositive}
                options.seed (1,1) double {mustBeInteger} = 1
                options.tacticity {mustBeTextScalar} = "atactic"
                options.addHydrogens (1,1) logical = true
                options.atomLimit (1,1) double {mustBeInteger, mustBePositive} = 100000
                options.storePath {mustBeTextScalar} = ""
                options.chainCount (1,1) double {mustBeInteger,mustBePositive} = 1
                options.headGroup {mustBeTextScalar} = "none"
                options.tailGroup {mustBeTextScalar} = "none"
                options.conformation {mustBeTextScalar} = "extended"
                options.headTailMode {mustBeTextScalar} = "regular"
            end
            sequence = repmat(upper(string(kind)), 1, count);
            [molecule, metadata] = ...
                kssolv.modeling.polymers.PolymerBuilder.sequence( ...
                sequence, seed=options.seed, tacticity=options.tacticity, ...
                addHydrogens=options.addHydrogens, ...
                atomLimit=options.atomLimit,storePath=options.storePath, ...
                chainCount=options.chainCount,headGroup=options.headGroup, ...
                tailGroup=options.tailGroup,conformation=options.conformation, ...
                headTailMode=options.headTailMode);
        end

        function [molecule, metadata] = block(blockKinds, blockLengths, options)
            arguments
                blockKinds
                blockLengths
                options.seed (1,1) double {mustBeInteger} = 1
                options.tacticity {mustBeTextScalar} = "atactic"
                options.addHydrogens (1,1) logical = true
                options.atomLimit (1,1) double {mustBeInteger, mustBePositive} = 100000
                options.storePath {mustBeTextScalar} = ""
                options.superunitCount (1,1) double {mustBeInteger,mustBePositive} = 1
                options.chainCount (1,1) double {mustBeInteger,mustBePositive} = 1
                options.headGroup {mustBeTextScalar} = "none"
                options.tailGroup {mustBeTextScalar} = "none"
                options.conformation {mustBeTextScalar} = "extended"
                options.headTailMode {mustBeTextScalar} = "regular"
            end
            kinds = reshape(upper(string(blockKinds)), 1, []);
            lengths = reshape(double(blockLengths), 1, []);
            if numel(kinds) ~= numel(lengths) || isempty(kinds) || ...
                    any(lengths < 1) || any(lengths ~= fix(lengths))
                error("KSSOLV:Modeling:PolymerBlocks", ...
                    "Block kinds and positive integer lengths must align.");
            end
            sequence = strings(1, 0);
            for index = 1:numel(kinds)
                sequence = [sequence, repmat(kinds(index),1,lengths(index))]; %#ok<AGROW>
            end
            sequence = repmat(sequence,1,options.superunitCount);
            [molecule, metadata] = ...
                kssolv.modeling.polymers.PolymerBuilder.sequence( ...
                sequence, seed=options.seed, tacticity=options.tacticity, ...
                addHydrogens=options.addHydrogens, ...
                atomLimit=options.atomLimit,storePath=options.storePath, ...
                chainCount=options.chainCount,headGroup=options.headGroup, ...
                tailGroup=options.tailGroup,conformation=options.conformation, ...
                headTailMode=options.headTailMode);
            metadata.blocks = table(kinds.',lengths.', ...
                VariableNames=["Kind","Length"]);
            metadata.superunitCount=options.superunitCount;
        end

        function [molecule,metadata] = branched(kind,count,interval,options)
            arguments
                kind {mustBeTextScalar}
                count (1,1) double {mustBeInteger,mustBePositive}
                interval (1,1) double {mustBeInteger,mustBePositive}
                options.seed (1,1) double {mustBeInteger} = 1
                options.tacticity {mustBeTextScalar} = "atactic"
                options.branchFragment {mustBeTextScalar} = "Methyl"
                options.atomLimit (1,1) double {mustBeInteger,mustBePositive} = 100000
                options.storePath {mustBeTextScalar} = ""
                options.reactivityRatios = [1,1]
                options.chainCount (1,1) double {mustBeInteger,mustBePositive} = 1
                options.headGroup {mustBeTextScalar} = "none"
                options.tailGroup {mustBeTextScalar} = "none"
                options.conformation {mustBeTextScalar} = "extended"
                options.headTailMode {mustBeTextScalar} = "regular"
            end
            [molecule,metadata]=kssolv.modeling.polymers.PolymerBuilder. ...
                homopolymer(kind,count,seed=options.seed, ...
                tacticity=options.tacticity,addHydrogens=false, ...
                atomLimit=options.atomLimit,storePath=options.storePath);
            originalSites=molecule.num_sites;
            branchUnits=interval:interval:max(1,count-1);
            branchHosts=zeros(1,numel(branchUnits));
            repeatValues=cellfun(@double,molecule.site_properties.repeat_unit);
            for index=1:numel(branchUnits)
                branchHosts(index)=find(repeatValues==branchUnits(index),1);
                molecule=kssolv.modeling.fragments.FragmentLibrary.attach( ...
                    molecule,options.branchFragment,branchHosts(index));
            end
            if molecule.num_sites>options.atomLimit
                error("KSSOLV:Modeling:AtomLimit", ...
                    "Branched polymer exceeds atomLimit after branch attachment.");
            end
            molecule=addPolymerHydrogens(molecule);
            metadata.branchFragment=string(options.branchFragment);
            metadata.branchInterval=interval;
            metadata.branchCount=numel(branchUnits);
            metadata.branchHosts=branchHosts;
            metadata.backboneHeavyAtoms=originalSites;
            metadata.atomCount=molecule.num_sites;
        end

        function [molecule,metadata] = dendrimer(generations,options)
            %DENDRIMER Build a deterministic, topology-first basic dendrimer.
            arguments
                generations (1,1) double {mustBeInteger,mustBePositive}
                options.coreFunctionality (1,1) double ...
                    {mustBeInteger,mustBePositive} = 3
                options.branchingFactor (1,1) double ...
                    {mustBeInteger,mustBePositive} = 2
                options.element {mustBeTextScalar} = "C"
                options.bondLength (1,1) double {mustBePositive} = 1.54
                options.addHydrogens (1,1) logical = true
                options.seed (1,1) double {mustBeInteger} = 1
                options.atomLimit (1,1) double ...
                    {mustBeInteger,mustBePositive} = 100000
            end
            if options.coreFunctionality < 2 || options.branchingFactor < 2
                error("KSSOLV:Modeling:DendrimerFunctionality", ...
                    "Core functionality and branching factor must be at least two.");
            end
            generationCounts = options.coreFunctionality * ...
                options.branchingFactor .^ (0:generations-1);
            heavyCount = 1 + sum(generationCounts);
            estimatedAtoms = heavyCount * 4;
            if estimatedAtoms > options.atomLimit
                error("KSSOLV:Modeling:AtomLimit", ...
                    "Estimated dendrimer size exceeds atomLimit before construction.");
            end
            species = repmat(string(options.element),1,heavyCount);
            coordinates = zeros(heavyCount,3);
            bonds = zeros(heavyCount-1,3);
            generationBySite = zeros(1,heavyCount);
            parents = 1; cursor = 1; bondCursor = 0;
            for generation = 1:generations
                if generation == 1
                    childrenPerParent = options.coreFunctionality;
                else
                    childrenPerParent = options.branchingFactor;
                end
                nextParents = zeros(1,numel(parents)*childrenPerParent);
                nextCursor = 0;
                for parentPosition = 1:numel(parents)
                    parent = parents(parentPosition);
                    outward = coordinates(parent,:);
                    if norm(outward) < eps, outward = [1,0,0]; end
                    outward = outward/norm(outward);
                    for childPosition = 1:childrenPerParent
                        cursor = cursor + 1; nextCursor = nextCursor + 1;
                        direction = dendrimerDirection(generation, ...
                            parentPosition,childPosition,childrenPerParent, ...
                            outward,options.seed);
                        coordinates(cursor,:) = coordinates(parent,:) + ...
                            options.bondLength*direction;
                        bondCursor = bondCursor + 1;
                        bonds(bondCursor,:) = [parent,cursor,1];
                        generationBySite(cursor) = generation;
                        nextParents(nextCursor) = cursor;
                    end
                end
                parents = nextParents;
            end
            properties = struct("topology",struct("bonds",bonds, ...
                "origin","source","schemaVersion",1), ...
                "polymer",struct("schemaVersion",1, ...
                "architecture","basic_dendrimer", ...
                "state","constructed_not_equilibrated", ...
                "generations",generations));
            siteProperties = struct();
            siteProperties.generation = num2cell(generationBySite);
            molecule = kssolv.analysis.matgenlab.core.Molecule( ...
                compositionObjects(species),coordinates, ...
                charge_spin_check=false,site_properties=siteProperties, ...
                properties=properties);
            if options.addHydrogens
                molecule = addPolymerHydrogens(molecule);
            end
            metadata = struct("schemaVersion",1, ...
                "architecture","basic_dendrimer", ...
                "generations",generations, ...
                "coreFunctionality",options.coreFunctionality, ...
                "branchingFactor",options.branchingFactor, ...
                "generationCounts",generationCounts, ...
                "heavyAtomCount",heavyCount, ...
                "estimatedAtoms",estimatedAtoms, ...
                "atomCount",molecule.num_sites, ...
                "seed",options.seed, ...
                "state","constructed_not_equilibrated");
        end

        function [molecule, metadata] = random(kinds, count, fractions, options)
            arguments
                kinds
                count (1,1) double {mustBeInteger, mustBePositive}
                fractions
                options.seed (1,1) double {mustBeInteger} = 1
                options.exactComposition (1,1) logical = true
                options.tacticity {mustBeTextScalar} = "atactic"
                options.addHydrogens (1,1) logical = true
                options.atomLimit (1,1) double {mustBeInteger, mustBePositive} = 100000
                options.storePath {mustBeTextScalar} = ""
                options.reactivityRatios = [1,1]
                options.chainCount (1,1) double {mustBeInteger,mustBePositive} = 1
                options.headGroup {mustBeTextScalar} = "none"
                options.tailGroup {mustBeTextScalar} = "none"
                options.conformation {mustBeTextScalar} = "extended"
                options.headTailMode {mustBeTextScalar} = "regular"
            end
            kinds = reshape(upper(string(kinds)),1,[]);
            fractions = reshape(double(fractions),1,[]);
            if numel(kinds) ~= numel(fractions) || isempty(kinds) || ...
                    any(fractions < 0) || sum(fractions) <= 0
                error("KSSOLV:Modeling:PolymerComposition", ...
                    "Monomer kinds require nonnegative fractions.");
            end
            fractions = fractions / sum(fractions);
            stream = RandStream("mt19937ar",Seed=options.seed);
            if options.exactComposition
                amounts = floor(fractions * count);
                [~,order] = sort(fractions*count-amounts,"descend");
                amounts(order(1:count-sum(amounts))) = ...
                    amounts(order(1:count-sum(amounts))) + 1;
                sequence = strings(1,0);
                for index=1:numel(kinds)
                    sequence=[sequence,repmat(kinds(index),1,amounts(index))]; %#ok<AGROW>
                end
                sequence=sequence(randperm(stream,count));
            else
                ratios=reshape(double(options.reactivityRatios),1,[]);
                if numel(kinds)==2 && numel(ratios)==2
                    sequence=reactiveSequence( ...
                        kinds,fractions,count,ratios,stream);
                else
                    cumulative=cumsum(fractions); draws=rand(stream,1,count);
                    sequence=strings(1,count);
                    for index=1:count
                        sequence(index)=kinds(find( ...
                            draws(index)<=cumulative,1));
                    end
                end
            end
            [molecule,metadata]=kssolv.modeling.polymers.PolymerBuilder. ...
                sequence(sequence,seed=options.seed,tacticity=options.tacticity, ...
                addHydrogens=options.addHydrogens,atomLimit=options.atomLimit, ...
                storePath=options.storePath,chainCount=options.chainCount, ...
                headGroup=options.headGroup,tailGroup=options.tailGroup, ...
                conformation=options.conformation, ...
                headTailMode=options.headTailMode);
            metadata.requestedFractions=fractions;
            metadata.exactComposition=options.exactComposition;
            metadata.reactivityRatios= ...
                reshape(double(options.reactivityRatios),1,[]);
        end

        function [molecule,metadata] = sequence(sequence,options)
            arguments
                sequence
                options.seed (1,1) double {mustBeInteger} = 1
                options.tacticity {mustBeTextScalar} = "atactic"
                options.addHydrogens (1,1) logical = true
                options.atomLimit (1,1) double {mustBeInteger, mustBePositive} = 100000
                options.storePath {mustBeTextScalar} = ""
                options.chainCount (1,1) double {mustBeInteger,mustBePositive} = 1
                options.headGroup {mustBeTextScalar} = "none"
                options.tailGroup {mustBeTextScalar} = "none"
                options.conformation {mustBeTextScalar} = "extended"
                options.headTailMode {mustBeTextScalar} = "regular"
            end
            sequence=reshape(upper(string(sequence)),1,[]);
            if isempty(sequence)
                error("KSSOLV:Modeling:PolymerSequence", ...
                    "A polymer sequence cannot be empty.");
            end
            templates=arrayfun(@(kind)repeatTemplate( ...
                kind,options.storePath),sequence);
            heavyCount=sum(arrayfun(@(item)numel(item.species),templates));
            if heavyCount*3*options.chainCount>options.atomLimit
                error("KSSOLV:Modeling:AtomLimit", ...
                    "Estimated polymer size exceeds atomLimit before construction.");
            end
            species=strings(1,heavyCount); coordinates=zeros(heavyCount,3);
            bonds=zeros(0,3); repeatIndex=zeros(1,heavyCount);
            headIndices=zeros(1,numel(sequence)); tailIndices=headIndices;
            cursor=0; xOffset=0;
            conformation=lower(string(options.conformation));
            if ~any(conformation==["extended","zigzag","random_coil"])
                error("KSSOLV:Modeling:PolymerConformation", ...
                    "Conformation must be extended, zigzag, or random_coil.");
            end
            headTailMode=lower(string(options.headTailMode));
            switch headTailMode
                case "regular", flipped=false(1,numel(sequence));
                case "alternating", flipped=mod(1:numel(sequence),2)==0;
                case "random"
                    flipStream=RandStream("mt19937ar",Seed=options.seed+7919);
                    flipped=rand(flipStream,1,numel(sequence))>=.5;
                otherwise
                    error("KSSOLV:Modeling:PolymerHeadTail", ...
                        "Head-tail mode must be regular, alternating, or random.");
            end
            pathStream=RandStream("mt19937ar",Seed=options.seed+1543);
            pathOffset=[0,0];
            for unit=1:numel(sequence)
                template=templates(unit); indices=cursor+(1:numel(template.species));
                species(indices)=template.species;
                local=template.coordinates;
                head=template.head; tail=template.tail;
                if flipped(unit)
                    local(:,1)=max(local(:,1))+min(local(:,1))-local(:,1);
                    head=template.tail; tail=template.head;
                end
                local(:,1)=local(:,1)-local(head,1);
                if local(tail,1)<0, local(:,1)=-local(:,1); end
                if conformation=="zigzag"
                    pathOffset=[.35*(-1)^unit,0];
                elseif conformation=="random_coil"
                    pathOffset=pathOffset+.22*randn(pathStream,1,2);
                end
                local(:,1)=local(:,1)+xOffset;
                local(:,2:3)=local(:,2:3)+pathOffset;
                coordinates(indices,:)=local;
                internal=template.bonds; internal(:,1:2)=internal(:,1:2)+cursor;
                bonds=[bonds;internal]; %#ok<AGROW>
                headIndices(unit)=cursor+head;
                tailIndices(unit)=cursor+tail;
                xOffset=local(tail,1)+1.45;
                repeatIndex(indices)=unit; cursor=cursor+numel(template.species);
            end
            for unit=1:numel(sequence)-1
                bonds(end+1,:)=[tailIndices(unit),headIndices(unit+1),1]; %#ok<AGROW>
            end
            props=struct("topology",struct("bonds",bonds, ...
                "origin","source","schemaVersion",1), ...
                "polymer",struct("schemaVersion",1,"sequence",sequence, ...
                "seed",options.seed,"tacticity",string(options.tacticity), ...
                "state","constructed_not_equilibrated"));
            stereoByUnit = stereoSequence(numel(sequence), ...
                options.tacticity, options.seed);
            stereoBySite = stereoByUnit(repeatIndex);
            siteProps = struct();
            siteProps.repeat_unit = num2cell(repeatIndex);
            siteProps.stereo = num2cell(stereoBySite);
            molecule=kssolv.analysis.matgenlab.core.Molecule( ...
                compositionObjects(species),coordinates,charge_spin_check=false, ...
                site_properties=siteProps,properties=props);
            if lower(string(options.headGroup))~="none"
                molecule=kssolv.modeling.fragments.FragmentLibrary.attach( ...
                    molecule,options.headGroup,headIndices(1));
            end
            if lower(string(options.tailGroup))~="none"
                molecule=kssolv.modeling.fragments.FragmentLibrary.attach( ...
                    molecule,options.tailGroup,tailIndices(end));
            end
            molecule=replicateChains(molecule,options.chainCount);
            if options.addHydrogens
                molecule=addPolymerHydrogens(molecule);
            end
            kinds=unique(sequence); actual=zeros(size(kinds));
            for index=1:numel(kinds),actual(index)=sum(sequence==kinds(index));end
            metadata=struct("schemaVersion",1,"sequence",sequence, ...
                "seed",options.seed,"tacticity",string(options.tacticity), ...
                "repeatUnits",numel(sequence),"actualKinds",kinds, ...
                "actualCounts",actual,"estimatedAtoms",heavyCount*3, ...
                "atomCount",molecule.num_sites, ...
                "chainCount",options.chainCount, ...
                "headGroup",string(options.headGroup), ...
                "tailGroup",string(options.tailGroup), ...
                "conformation",conformation, ...
                "headTailMode",headTailMode, ...
                "headTailFlipped",flipped, ...
                "state","constructed_not_equilibrated");
        end
    end
end

function template=repeatTemplate(kind,storePath)
if nargin<2, storePath=""; end
template=kssolv.modeling.polymers.RepeatUnitLibrary.get( ...
    kind,storePath=storePath);
end
function molecule=addPolymerHydrogens(molecule)
originalCount=molecule.num_sites;
bonds=kssolv.modeling.chemistry.MoleculeDiagnostics.topology(molecule);
bondSums=zeros(originalCount,1);
for row=1:size(bonds,1)
    first=bonds(row,1); second=bonds(row,2); order=bonds(row,3);
    bondSums(first)=bondSums(first)+order;
    bondSums(second)=bondSums(second)+order;
end
symbols=string(cellfun(@(site)site.specie.symbol, ...
    molecule.sites,UniformOutput=false));
targets=zeros(1,originalCount);
targets(symbols=="H")=1; targets(ismember(symbols,["F","Cl","Br","I"]))=1;
targets(ismember(symbols,["O","S","Se"]))=2;
targets(ismember(symbols,["N","P"]))=3;
targets(ismember(symbols,["C","Si"]))=4;
targets(ismember(symbols,["B","Al"]))=3;
unknown=targets==0; targets(unknown)=bondSums(unknown);
hydrogenCounts=max(round(targets-bondSums.'),0);
uniqueSymbols=unique(symbols); lengthBySite=zeros(1,originalCount);
for symbolIndex=1:numel(uniqueSymbols)
    symbol=uniqueSymbols(symbolIndex);
    lengthBySite(symbols==symbol)=kssolv.modeling.chemistry. ...
        MoleculeDiagnostics.idealBondLength(symbol,"H",1);
end
numberHydrogens=sum(hydrogenCounts);
if numberHydrogens==0, return, end
total=originalCount+numberHydrogens;
species=cell(1,total);
species(1:originalCount)=cellfun(@(site)site.species, ...
    molecule.sites,UniformOutput=false);
hydrogenSpecies=kssolv.analysis.matgenlab.core.Composition("H");
species(originalCount+1:end)=repmat({hydrogenSpecies},1,numberHydrogens);
coordinates=zeros(total,3);
coordinates(1:originalCount,:)=molecule.cart_coords;
siteProperties=molecule.site_properties;
names=fieldnames(siteProperties);
for nameIndex=1:numel(names)
    name=names{nameIndex};
    siteProperties.(name)(originalCount+1:total)={[]};
end
newBonds=zeros(numberHydrogens,3);
cursor=originalCount; bondCursor=0;
tetra=[1,1,1;1,-1,-1;-1,1,-1;-1,-1,1];
tetra=tetra./vecnorm(tetra,2,2);
for site=1:originalCount
    count=hydrogenCounts(site);
    if count==0, continue, end
    directions=tetra(1:count,:);
    lengthValue=lengthBySite(site);
    indices=cursor+(1:count);
    coordinates(indices,:)=coordinates(site,:)+lengthValue*directions;
    for local=1:count
        bondCursor=bondCursor+1;
        newBonds(bondCursor,:)=[site,indices(local),1];
        setProperty("formal_charge",indices(local),0);
        setProperty("hybridization",indices(local),"s");
        setProperty("is_aromatic",indices(local),false);
        copyProperty("repeat_unit",site,indices(local));
        copyProperty("stereo",site,indices(local));
        copyProperty("chain_id",site,indices(local));
    end
    cursor=cursor+count;
end
properties=molecule.properties;
properties.topology=struct("bonds",[bonds;newBonds], ...
    "origin","source","schemaVersion",1);
labels=[molecule.labels,repmat({missing},1,numberHydrogens)];
molecule=kssolv.analysis.matgenlab.core.Molecule( ...
    species,coordinates,charge=molecule.charge,spin_multiplicity=1, ...
    charge_spin_check=false,site_properties=siteProperties, ...
    labels=labels,properties=properties);

    function setProperty(name,index,value)
        if ~isfield(siteProperties,name)
            siteProperties.(name)=repmat({[]},1,total);
        end
        siteProperties.(name){index}=value;
    end
    function copyProperty(name,source,target)
        if isfield(siteProperties,name)
            siteProperties.(name){target}=siteProperties.(name){source};
        end
    end
end

function molecule=replicateChains(molecule,count)
baseCount=molecule.num_sites;
properties=molecule.properties;
baseBonds=kssolv.modeling.chemistry.MoleculeDiagnostics.topology(molecule);
span=max(molecule.cart_coords(:,2))-min(molecule.cart_coords(:,2))+4;
species=cell(1,baseCount*count);
coordinates=zeros(baseCount*count,3);
bonds=zeros(size(baseBonds,1)*count,3);
labels=cell(1,baseCount*count);
siteProperties=struct();
names=fieldnames(molecule.site_properties);
for nameIndex=1:numel(names)
    siteProperties.(names{nameIndex})=cell(1,baseCount*count);
end
for chain=1:count
    range=(chain-1)*baseCount+(1:baseCount);
    species(range)=cellfun(@(site)site.species,molecule.sites, ...
        UniformOutput=false);
    coordinates(range,:)=molecule.cart_coords+[0,(chain-1)*span,0];
    labels(range)=molecule.labels;
    bondRange=(chain-1)*size(baseBonds,1)+(1:size(baseBonds,1));
    chainBonds=baseBonds;
    chainBonds(:,1:2)=chainBonds(:,1:2)+(chain-1)*baseCount;
    bonds(bondRange,:)=chainBonds;
    for nameIndex=1:numel(names)
        name=names{nameIndex};
        siteProperties.(name)(range)=propertyCells( ...
            molecule.site_properties.(name),baseCount);
    end
end
siteProperties.chain_id=num2cell(repelem(1:count,baseCount));
properties.topology=struct("bonds",bonds,"origin","source", ...
    "schemaVersion",1);
properties.polymer.chainCount=count;
molecule=kssolv.analysis.matgenlab.core.Molecule( ...
    species,coordinates,charge=molecule.charge,spin_multiplicity=1, ...
    charge_spin_check=false,site_properties=siteProperties, ...
    labels=labels,properties=properties);
end

function values=propertyCells(input,count)
if iscell(input)
    values=reshape(input,1,[]);
elseif isvector(input)
    values=num2cell(reshape(input,1,[]));
else
    values=mat2cell(input,ones(1,count),size(input,2)).';
end
end

function sequence=reactiveSequence(kinds,fractions,count,ratios,stream)
if any(~isfinite(ratios)) || any(ratios<0) || all(ratios==0)
    error("KSSOLV:Modeling:ReactivityRatios", ...
        "Reactivity ratios must be finite nonnegative values.");
end
sequence=strings(1,count);
sequence(1)=kinds(1+(rand(stream)>fractions(1)));
for index=2:count
    if sequence(index-1)==kinds(1)
        probability=ratios(1)*fractions(1)/ ...
            max(ratios(1)*fractions(1)+fractions(2),eps);
    else
        probability=fractions(1)/ ...
            max(fractions(1)+ratios(2)*fractions(2),eps);
    end
    sequence(index)=kinds(1+(rand(stream)>probability));
end
end
function direction=dendrimerDirection(generation,parentPosition, ...
        childPosition,childCount,outward,seed)
% Spread children on a reproducible cone about the parent's radial vector.
reference=[0,0,1];
if abs(dot(outward,reference))>.9, reference=[0,1,0]; end
first=cross(outward,reference); first=first/norm(first);
second=cross(outward,first); second=second/norm(second);
phase=2*pi*mod(seed*.61803398875+parentPosition*.38196601125,1);
azimuth=phase+2*pi*(childPosition-1)/childCount;
cone=min(pi/3,pi/(childCount+1)+.08*generation);
direction=cos(cone)*outward+sin(cone)*( ...
    cos(azimuth)*first+sin(azimuth)*second);
direction=direction/norm(direction);
end
function values=compositionObjects(symbols)
symbols=reshape(string(symbols),1,[]);
values=cell(1,numel(symbols)); uniqueSymbols=unique(symbols);
objects=cell(1,numel(uniqueSymbols));
for index=1:numel(uniqueSymbols)
    objects{index}=kssolv.analysis.matgenlab.core.Composition(uniqueSymbols(index));
end
for index=1:numel(uniqueSymbols)
    values(symbols==uniqueSymbols(index))=objects(index);
end
end
function values=stereoSequence(count,tacticity,seed)
tacticity=lower(string(tacticity));
switch tacticity
    case "isotactic", values=ones(1,count);
    case "syndiotactic", values=(-1).^(0:count-1);
    case "atactic"
        stream=RandStream("mt19937ar",Seed=seed);
        values=2*(rand(stream,1,count)>=0.5)-1;
    otherwise
        error("KSSOLV:Modeling:Tacticity", ...
            "Tacticity must be isotactic, syndiotactic, or atactic.");
end
end
