classdef PackingBuilder
    %PACKINGBUILDER Deterministic density-controlled molecular construction.

    % This builder performs geometry packing only.  Its output is explicitly
    % tagged packed_not_equilibrated and must not be confused with an MD or
    % force-field equilibration result.

    methods (Static)
        function estimate = estimate(components, counts, density)
            [components, counts] = normalizeInputs(components, counts);
            mass = 0;
            atomCount = 0;
            for index = 1:numel(components)
                mass = mass + components{index}.composition.weight * counts(index);
                atomCount = atomCount + components{index}.num_sites * counts(index);
            end
            volume = mass * 1.66053906892 / double(density);
            estimate = struct("moleculeCount",sum(counts), ...
                "atomCount",atomCount,"massAmu",mass,"volume",volume, ...
                "boxLength",volume^(1/3),"density",double(density));
        end

        function [structure, metadata] = pack(components, counts, options)
            arguments
                components
                counts
                options.density (1,1) double {mustBePositive} = 1
                options.seed (1,1) double {mustBeInteger} = 1
                options.tolerance (1,1) double {mustBeNonnegative} = 1.2
                options.atomLimit (1,1) double {mustBeInteger,mustBePositive} = 100000
                options.axis (1,1) double {mustBeInteger,mustBeBetween(options.axis,1,3)} = 3
                options.region double = []
                options.boxLengths double = []
                options.exclusionCenter double = []
                options.exclusionRadius (1,1) double ...
                    {mustBeNonnegative} = 0
                options.obstacleCoordinates double = zeros(0,3)
                options.densityRamp double = []
                options.batchSize (1,1) double ...
                    {mustBeInteger,mustBePositive} = 100
                options.cancelFcn = @()false
                options.progressFcn = @(~,~)[]
            end
            [components, counts] = normalizeInputs(components, counts);
            estimate = kssolv.modeling.packing.PackingBuilder.estimate( ...
                components, counts, options.density);
            if estimate.atomCount > options.atomLimit
                error("KSSOLV:Modeling:AtomLimit", ...
                    "Estimated packed model size exceeds atomLimit before construction.");
            end
            moleculeIds = repelem(1:numel(components), counts);
            stream = RandStream("mt19937ar",Seed=options.seed);
            moleculeIds = moleculeIds(randperm(stream,numel(moleculeIds)));

            if isempty(options.boxLengths)
                boxVector = repmat(estimate.boxLength,1,3);
            else
                boxVector=reshape(double(options.boxLengths),1,[]);
                if numel(boxVector)~=3 || any(~isfinite(boxVector)) || ...
                        any(boxVector<=0)
                    error("KSSOLV:Modeling:PackingBox", ...
                        "boxLengths must contain three positive lengths.");
                end
            end
            densityRamp=reshape(double(options.densityRamp),1,[]);
            if isempty(densityRamp), densityRamp=options.density; end
            if any(~isfinite(densityRamp)) || any(densityRamp<=0) || ...
                    any(diff(densityRamp)<0) || ...
                    abs(densityRamp(end)-options.density)>1e-12
                error("KSSOLV:Modeling:PackingDensityRamp", ...
                    "densityRamp must be positive, nondecreasing, and end at density.");
            end
            if isempty(options.region)
                lower = [0,0,0]; upper = boxVector;
            else
                region = reshape(double(options.region),1,[]);
                if numel(region)==2 && all(region>=0) && all(region<=1)
                    region=region*boxVector(options.axis);
                end
                if numel(region) ~= 2 || region(1) < 0 || ...
                        region(2) <= region(1) || ...
                        region(2) > boxVector(options.axis)
                    error("KSSOLV:Modeling:PackingRegion", ...
                        "region must be [lower upper] inside the target cell.");
                end
                lower = [0,0,0]; upper = boxVector;
                lower(options.axis)=region(1); upper(options.axis)=region(2);
            end
            if numel(densityRamp)>1
                if ~isempty(options.boxLengths) || ~isempty(options.region) || ...
                        options.exclusionRadius>0
                    error("KSSOLV:Modeling:PackingDensityRamp", ...
                        "Density ramp construction requires a new unconstrained box.");
                end
                placementScale=(options.density/densityRamp(1))^(1/3);
                placementUpper=upper*placementScale;
            else
                placementUpper=upper;
            end
            centers = gridCenters(numel(moleculeIds),lower,placementUpper,stream, ...
                options.exclusionCenter,options.exclusionRadius);
            species = strings(1,estimate.atomCount);
            coordinates = zeros(estimate.atomCount,3);
            componentBySite = zeros(1,estimate.atomCount);
            moleculeBySite = zeros(1,estimate.atomCount);
            atomInComponent = zeros(1,estimate.atomCount);
            batchBySite = zeros(1,estimate.atomCount);
            globalBonds = zeros(0,3); globalRings=cell(1,0);
            componentBonds=cellfun(@(item) ...
                kssolv.modeling.chemistry.MoleculeDiagnostics.topology(item), ...
                components,UniformOutput=false);
            componentRings=cellfun(@(item) ...
                kssolv.modeling.packing.PackingDiagnostics.componentRings(item), ...
                components,UniformOutput=false);
            cursor = 0;
            for moleculeIndex = 1:numel(moleculeIds)
                if options.cancelFcn()
                    error("KSSOLV:Modeling:PackingCancelled", ...
                        "Packing was cancelled before committing a structure.");
                end
                componentIndex = moleculeIds(moleculeIndex);
                molecule = components{componentIndex};
                local = molecule.cart_coords - mean(molecule.cart_coords,1);
                rotation = randomRotation(stream);
                placed = local*rotation + centers(moleculeIndex,:);
                if options.exclusionRadius>0 && ...
                        any(vecnorm(placed-reshape( ...
                        options.exclusionCenter,1,3),2,2) < ...
                        options.exclusionRadius)
                    error("KSSOLV:Modeling:PackingExclusion", ...
                        "A component intersects the nanoparticle exclusion region.");
                end
                if ~isempty(options.region) && ...
                        (min(placed(:,options.axis))<lower(options.axis) || ...
                        max(placed(:,options.axis))>upper(options.axis))
                    error("KSSOLV:Modeling:PackingInfeasible", ...
                        "A component does not fit inside the confined region.");
                end
                indices = cursor+(1:molecule.num_sites);
                species(indices) = string(cellfun(@(site) ...
                    site.species_string,molecule.sites,UniformOutput=false));
                coordinates(indices,:) = placed;
                componentBySite(indices)=componentIndex;
                moleculeBySite(indices)=moleculeIndex;
                atomInComponent(indices)=1:molecule.num_sites;
                batchBySite(indices)=ceil(moleculeIndex/options.batchSize);
                bonds=componentBonds{componentIndex};
                if ~isempty(bonds)
                    bonds(:,1:2)=bonds(:,1:2)+cursor;
                    globalBonds=[globalBonds;bonds]; %#ok<AGROW>
                end
                rings=componentRings{componentIndex};
                for ringIndex=1:numel(rings)
                    globalRings{end+1}=rings{ringIndex}+cursor; %#ok<AGROW>
                end
                cursor=cursor+molecule.num_sites;
                options.progressFcn(moleculeIndex,numel(moleculeIds));
            end
            if numel(densityRamp)>1
                for stage=2:numel(densityRamp)
                    scale=(densityRamp(1)/densityRamp(stage))^(1/3);
                    for moleculeIndex=1:numel(moleculeIds)
                        indices=find(moleculeBySite==moleculeIndex);
                        currentCenter=mean(coordinates(indices,:),1);
                        targetCenter=centers(moleculeIndex,:)*scale;
                        coordinates(indices,:)=coordinates(indices,:)+ ...
                            targetCenter-currentCenter;
                    end
                end
            end
            obstacleCount=size(options.obstacleCoordinates,1);
            diagnosticCoordinates=[reshape(double( ...
                options.obstacleCoordinates),[],3);coordinates];
            diagnosticIds=[zeros(1,obstacleCount),moleculeBySite];
            assertSeparated(diagnosticCoordinates,diagnosticIds, ...
                boxVector,options.tolerance);
            piercings=kssolv.modeling.packing.PackingDiagnostics. ...
                ringPiercings(coordinates,moleculeBySite,globalBonds,globalRings);
            interlocks=kssolv.modeling.packing.PackingDiagnostics. ...
                chainInterlocks(coordinates,moleculeBySite,globalBonds,globalRings);
            if ~isempty(interlocks)
                error("KSSOLV:Modeling:PackingChainInterlock", ...
                    "Packing produced %d potential chain interlock(s); try another seed.", ...
                    numel(interlocks));
            end
            if ~isempty(piercings)
                error("KSSOLV:Modeling:PackingRingPiercing", ...
                    "Packing produced %d ring-piercing chain segment(s); try another seed.", ...
                    numel(piercings));
            end
            siteProperties=struct();
            siteProperties.component_id=num2cell(componentBySite);
            siteProperties.molecule_id=num2cell(moleculeBySite);
            siteProperties.component_atom_index=num2cell(atomInComponent);
            siteProperties.packing_batch=num2cell(batchBySite);
            packing=struct("schemaVersion",1,"seed",options.seed, ...
                "targetDensity",options.density,"actualDensity",NaN, ...
                "counts",counts,"tolerance",options.tolerance, ...
                "ringPiercings",numel(piercings), ...
                "chainInterlocks",numel(interlocks), ...
                "densityRamp",densityRamp, ...
                "densityStageVolumes",estimate.massAmu*1.66053906892 ./ ...
                    densityRamp, ...
                "batchSize",options.batchSize, ...
                "batchCount",ceil(sum(counts)/options.batchSize), ...
                "state","packed_not_equilibrated");
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                diag(boxVector),cellstr(species),coordinates, ...
                coords_are_cartesian=true,site_properties=siteProperties, ...
                properties=struct("packing",packing));
            packing.actualDensity=structure.density;
            properties=structure.structure_properties;
            properties.packing=packing;
            structure=structure.copy([],false,properties);
            metadata=packing;
            metadata.atomCount=structure.num_sites;
            metadata.moleculeCount=sum(counts);
            metadata.boxLength=boxVector;
        end

        function [structure,metadata]=packInto(container,components,counts,options)
            arguments
                container kssolv.analysis.matgenlab.core.IStructure
                components
                counts
                options.seed (1,1) double {mustBeInteger} = 1
                options.tolerance (1,1) double {mustBeNonnegative} = 1.2
                options.atomLimit (1,1) double ...
                    {mustBeInteger,mustBePositive} = 100000
                options.exclusionCenter double = []
                options.exclusionRadius (1,1) double ...
                    {mustBeNonnegative} = 0
                options.batchSize (1,1) double ...
                    {mustBeInteger,mustBePositive} = 100
                options.densityRamp double = []
                options.cancelFcn = @()false
                options.progressFcn = @(~,~)[]
            end
            matrix=double(container.lattice.matrix);
            if norm(matrix-diag(diag(matrix)),"fro")>1e-10 || ...
                    any(diag(matrix)<=0)
                error("KSSOLV:Modeling:PackingExistingBox", ...
                    "Packing into an existing box currently requires an orthorhombic cell.");
            end
            boxVector=reshape(diag(matrix),1,3);
            [components,counts]=normalizeInputs(components,counts);
            addedMass=sum(cellfun(@(item,count) ...
                item.composition.weight*count,components,num2cell(counts)));
            addedDensity=addedMass*1.66053906892/prod(boxVector);
            targetDensity=addedDensity;
            if ~isempty(options.densityRamp), targetDensity=options.densityRamp(end); end
            [added,metadata]=kssolv.modeling.packing.PackingBuilder.pack( ...
                components,counts,density=targetDensity,seed=options.seed, ...
                tolerance=options.tolerance,atomLimit=options.atomLimit, ...
                boxLengths=boxVector, ...
                exclusionCenter=options.exclusionCenter, ...
                exclusionRadius=options.exclusionRadius, ...
                obstacleCoordinates=container.cart_coords, ...
                densityRamp=options.densityRamp,batchSize=options.batchSize, ...
                cancelFcn=options.cancelFcn,progressFcn=options.progressFcn);
            existingCount=container.num_sites; addedCount=added.num_sites;
            species=[cellfun(@(site)site.species,container.sites, ...
                UniformOutput=false),cellfun(@(site)site.species,added.sites, ...
                UniformOutput=false)];
            coordinates=[container.cart_coords;added.cart_coords];
            siteProperties=mergeSiteProperties(container,added);
            properties=container.structure_properties;
            metadata.containerAtoms=existingCount;
            metadata.addedAtoms=addedCount;
            metadata.preservedExistingBox=true;
            metadata.exclusionCenter=reshape(double( ...
                options.exclusionCenter),1,[]);
            metadata.exclusionRadius=options.exclusionRadius;
            properties.packing=metadata;
            structure=kssolv.analysis.matgenlab.core.Structure( ...
                matrix,species,coordinates,coords_are_cartesian=true, ...
                site_properties=siteProperties,properties=properties);
            metadata.actualDensity=structure.density;
            properties=structure.structure_properties;
            properties.packing=metadata;
            structure=structure.copy([],false,properties);
        end
    end
end

function [components,counts]=normalizeInputs(components,counts)
if ~iscell(components), components={components}; end
counts=reshape(double(counts),1,[]);
if numel(components)~=numel(counts) || isempty(components) || ...
        any(counts<1) || any(counts~=fix(counts))
    error("KSSOLV:Modeling:PackingComponents", ...
        "Components and positive integer counts must align.");
end
for index=1:numel(components)
    if ~isa(components{index},"kssolv.analysis.matgenlab.core.IMolecule")
        error("KSSOLV:Modeling:PackingComponentKind", ...
            "Every packing component must be a molecule.");
    end
end
end

function centers=gridCenters(count,lower,upper,stream,exclusionCenter,exclusionRadius)
if nargin<5, exclusionCenter=[]; exclusionRadius=0; end
span=upper-lower;
densityMultiplier=1;
if exclusionRadius>0, densityMultiplier=8; end
dims=max(1,ceil((count*densityMultiplier*span/prod(span)).^(1/3)));
while prod(dims)<count
    [~,index]=max(span./dims); dims(index)=dims(index)+1;
end
axesValues=cell(1,3);
for axis=1:3
    step=span(axis)/dims(axis);
    axesValues{axis}=lower(axis)+step*((1:dims(axis))-.5);
end
[x,y,z]=ndgrid(axesValues{1},axesValues{2},axesValues{3});
centers=[x(:),y(:),z(:)];
if exclusionRadius>0
    center=reshape(double(exclusionCenter),1,[]);
    if numel(center)~=3
        error("KSSOLV:Modeling:PackingExclusion", ...
            "exclusionCenter must contain three Cartesian coordinates.");
    end
    centers=centers(vecnorm(centers-center,2,2)>=exclusionRadius,:);
end
if size(centers,1)<count
    error("KSSOLV:Modeling:PackingExclusion", ...
        "The permitted region has too little space for the requested molecules.");
end
centers=centers(randperm(stream,size(centers,1),count),:);
end

function rotation=randomRotation(stream)
q=randn(stream,1,4); q=q/norm(q);
w=q(1); x=q(2); y=q(3); z=q(4);
rotation=[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w); ...
    2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w); ...
    2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)];
end

function properties=mergeSiteProperties(container,added)
firstCount=container.num_sites; secondCount=added.num_sites;
properties=struct();
first=container.site_properties; second=added.site_properties;
names=union(string(fieldnames(first)),string(fieldnames(second)),"stable");
for index=1:numel(names)
    name=char(names(index));
    values=repmat({[]},1,firstCount+secondCount);
    if isfield(first,name), values(1:firstCount)=propertyCells( ...
            first.(name),firstCount); end
    if isfield(second,name), values(firstCount+1:end)=propertyCells( ...
            second.(name),secondCount); end
    properties.(name)=values;
end
properties.container_site=[num2cell(1:firstCount), ...
    repmat({[]},1,secondCount)];
end

function values=propertyCells(input,count)
if iscell(input), values=reshape(input,1,[]);
elseif isvector(input), values=num2cell(reshape(input,1,[]));
else, values=mat2cell(input,ones(1,count),size(input,2)).';
end
end

function assertSeparated(coordinates,moleculeIds,boxLength,tolerance)
for first=1:size(coordinates,1)-1
    candidates=find(moleculeIds(first+1:end)~=moleculeIds(first))+first;
    if isempty(candidates), continue, end
    delta=abs(coordinates(candidates,:)-coordinates(first,:));
    delta=min(delta,boxLength-delta);
    if any(vecnorm(delta,2,2)<tolerance)
        error("KSSOLV:Modeling:PackingInfeasible", ...
            "Requested density and tolerance cannot be packed by the " + ...
            "deterministic constructor. Lower density/tolerance or use fewer molecules.");
    end
end
end
