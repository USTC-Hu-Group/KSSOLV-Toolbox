classdef BSPlotterProjected < kssolv.analysis.matgenlab.electronic_structure.BSPlotter
    %BSPLOTTERPROJECTED Projected-band dot and RGB visualizations.
    methods
        function obj=BSPlotterProjected(bs)
            if iscell(bs),bs=bs{1};elseif numel(bs)>1,bs=bs(1);end
            if isempty(fieldnames(bs.projections))
                error("KSSOLV:Matgenlab:BSPlotterProjected:MissingProjections", ...
                    "Cannot plot projections without projection data.");
            end
            obj@kssolv.analysis.matgenlab.electronic_structure.BSPlotter(bs);
        end
        function axesOut=get_projected_plots_dots(obj,specification, ...
                zeroToEfermi,ylim,vbmCbmMarker,bandLinewidth,markerSize)
            if nargin<3||isempty(zeroToEfermi),zeroToEfermi=true;end
            if nargin<4,ylim=[];end
            if nargin<5||isempty(vbmCbmMarker),vbmCbmMarker=false;end
            if nargin<6||isempty(bandLinewidth),bandLinewidth=1;end
            if nargin<7||isempty(markerSize),markerSize=15;end
            band=obj.bs{1};spec=normalizeSpec(specification);
            projections=band.get_projections_on_elements_and_orbitals(spec);
            elements=fieldnames(spec);counts=cellfun(@(e)numel(string(spec.(e))),elements);
            nRows=max(counts);nCols=numel(elements);panels=cell(nRows*nCols,2);
            figureHandle=figure("Visible","off");layout=tiledlayout(figureHandle,nRows,nCols);
            axesOut=gobjects(1,nRows*nCols);data=obj.bs_plot_data(zeroToEfermi);
            for row=1:nRows
                for col=1:nCols
                    index=(row-1)*nCols+col;axesOut(index)=nexttile(layout);
                    orbitals=cellstr(string(spec.(elements{col})));
                    if row<=numel(orbitals),panels(index,:)={elements{col},orbitals{row}};
                    else,axesOut(index).Visible="off";end
                end
            end
            spins=fieldnames(band.bands);
            for panel=1:size(panels,1)
                if isempty(panels{panel,1}),continue,end
                ax=axesOut(panel);hold(ax,"on");
                for ss=1:numel(spins)
                    style="-";if strcmp(spins{ss},"down"),style="--";end
                    for piece=1:numel(data.distances)
                        plot(ax,data.distances{piece},data.energy.(spins{ss}){piece}.', ...
                            style,"Color",[.3,.3,.3],"LineWidth",bandLinewidth);
                    end
                    weights=projectionMatrix(projections.(spins{ss}), ...
                        panels{panel,1},panels{panel,2});
                    scatterBands(ax,band.distance,band.bands.(spins{ss})-data.zero_energy, ...
                        weights,markerSize,[0,.45,.74]);
                end
                title(ax,panels{panel,1}+" "+panels{panel,2});
                decorateProjected(ax,obj,data,ylim,vbmCbmMarker);
            end
        end
        function axesOut=get_elt_projected_plots(obj,zeroToEfermi,ylim, ...
                vbmCbmMarker,bandLinewidth)
            if nargin<2||isempty(zeroToEfermi),zeroToEfermi=true;end
            if nargin<3,ylim=[];end
            if nargin<4||isempty(vbmCbmMarker),vbmCbmMarker=false;end
            if nargin<5||isempty(bandLinewidth),bandLinewidth=1;end
            band=obj.bs{1};projections=band.get_projection_on_elements();
            spins=fieldnames(projections);sample=projections.(spins{1}){1,1};
            elements=fieldnames(sample);spec=struct();
            for ii=1:numel(elements),spec.(elements{ii})="total";end
            data=obj.bs_plot_data(zeroToEfermi);fig=figure("Visible","off");
            layout=tiledlayout(fig,2,2);axesOut=gobjects(1,4);
            for ee=1:4
                ax=nexttile(layout);axesOut(ee)=ax;
                if ee>numel(elements),ax.Visible="off";continue,end
                hold(ax,"on");
                for ss=1:numel(spins)
                    style="-";if strcmp(spins{ss},"down"),style="--";end
                    for piece=1:numel(data.distances)
                        plot(ax,data.distances{piece},data.energy.(spins{ss}){piece}.', ...
                            style,"Color",[.3,.3,.3],"LineWidth",bandLinewidth);
                    end
                    weights=elementProjectionMatrix(projections.(spins{ss}),elements{ee});
                    scatterBands(ax,band.distance,band.bands.(spins{ss})-data.zero_energy,weights,18,[.85,.33,.1]);
                end
                title(ax,elements{ee});decorateProjected(ax,obj,data,ylim,vbmCbmMarker);
            end
        end
        function ax=get_elt_projected_plots_color(obj,zeroToEfermi, ...
                elementOrder,bandLinewidth)
            if nargin<2||isempty(zeroToEfermi),zeroToEfermi=true;end
            if nargin<3,elementOrder=[];end
            if nargin<4||isempty(bandLinewidth),bandLinewidth=3;end
            band=obj.bs{1};projected=band.get_projection_on_elements();
            spins=fieldnames(projected);sample=projected.(spins{1}){1,1};
            if isempty(elementOrder),elements=fieldnames(sample);else,elements=cellstr(string(elementOrder));end
            if numel(elements)>3,error("KSSOLV:Matgenlab:BSPlotterProjected:RGB", ...
                    "RGB projection supports at most three elements.");end
            fig=figure("Visible","off");ax=axes(fig);hold(ax,"on");
            data=obj.bs_plot_data(zeroToEfermi);
            for ss=1:numel(spins)
                array=band.bands.(spins{ss})-data.zero_energy;
                weights=zeros([size(array),3]);
                for ee=1:numel(elements),weights(:,:,ee)=elementProjectionMatrix(projected.(spins{ss}),elements{ee});end
                total=sum(weights,3);total(total==0)=1;weights=weights./total;
                for bb=1:size(array,1)
                    for kk=1:size(array,2)-1
                        color=squeeze(mean(weights(bb,kk:kk+1,:),2)).';
                        plot(ax,band.distance(kk:kk+1),array(bb,kk:kk+1), ...
                            "Color",color,"LineWidth",bandLinewidth);
                    end
                end
            end
            decorateProjected(ax,obj,data,[],false);
        end
        function axesOut=get_projected_plots_dots_patom_pmorb(obj, ...
                specification,atomSpecification,sumAtoms,sumMorbs, ...
                zeroToEfermi,ylim,vbmCbmMarker,selectedBranches,windowSize,numColumn)
            if nargin<4,sumAtoms=[];end
            if nargin<5,sumMorbs=[];end
            if nargin<6||isempty(zeroToEfermi),zeroToEfermi=true;end
            if nargin<7,ylim=[];end
            if nargin<8||isempty(vbmCbmMarker),vbmCbmMarker=false;end
            if nargin<9,selectedBranches=[];end
            if nargin<10||isempty(windowSize),windowSize=[12,8];end
            if nargin<11,numColumn=[];end
            band=obj.bs{1};spec=normalizeSpec(specification);atoms=normalizeSpec(atomSpecification);
            panels=makeSiteOrbitalPanels(spec,atoms,sumAtoms,sumMorbs,band);
            if isempty(panels)
                error("KSSOLV:Matgenlab:BSPlotterProjected:EmptyProjection", ...
                    "At least one site-orbital projection is required.");
            end
            if isempty(numColumn),numColumn=ceil(sqrt(size(panels,1)));end
            if ~isscalar(numColumn)||numColumn<1||fix(numColumn)~=numColumn
                error("KSSOLV:Matgenlab:BSPlotterProjected:Columns", ...
                    "num_column must be a positive integer.");
            end
            fig=figure("Visible","off","Position",[100,100,windowSize(1)*80,windowSize(2)*80]);
            layout=tiledlayout(fig,ceil(size(panels,1)/numColumn),numColumn);
            axesOut=gobjects(1,size(panels,1));data=obj.bs_plot_data(zeroToEfermi);
            [branches,xPieces,indices,xTicks,tickLabels]=selectedBranchData( ...
                band,data,selectedBranches);
            spins=fieldnames(band.bands);
            for pp=1:size(panels,1)
                ax=nexttile(layout);axesOut(pp)=ax;hold(ax,"on");
                for ss=1:numel(spins)
                    weights=siteOrbitalWeights(band,spins{ss}, ...
                        panels{pp,2},panels{pp,4});
                    for branchIndex=1:numel(branches)
                        branch=branches(branchIndex);pointIndices=indices{branchIndex};
                        plot(ax,xPieces{branchIndex}, ...
                            data.energy.(spins{ss}){branch}.', ...
                            "Color",[.4,.4,.4]);
                        scatterBands(ax,xPieces{branchIndex}, ...
                            band.bands.(spins{ss})(:,pointIndices)-data.zero_energy, ...
                            weights(:,pointIndices),20,[.49,.18,.56]);
                    end
                end
                title(ax,sprintf("%s %s %s",panels{pp,1}, ...
                    panels{pp,3},panels{pp,5}));
                decorateSelected(ax,data,ylim,vbmCbmMarker,xTicks,tickLabels);
            end
        end
    end
end

function spec=normalizeSpec(input)
if isstruct(input),spec=input;elseif isa(input,"containers.Map"),spec=struct();keys=input.keys;for ii=1:numel(keys),spec.(matlab.lang.makeValidName(keys{ii}))=input(keys{ii});end,end
end
function matrix=projectionMatrix(cells,element,orbital)
matrix=zeros(size(cells));ef=matlab.lang.makeValidName(element);of=matlab.lang.makeValidName(orbital);
for ii=1:numel(cells),item=cells{ii};if isfield(item,ef)&&isfield(item.(ef),of),matrix(ii)=item.(ef).(of);end,end
end
function matrix=elementProjectionMatrix(cells,element)
matrix=zeros(size(cells));field=matlab.lang.makeValidName(element);
for ii=1:numel(cells),item=cells{ii};if isfield(item,field),matrix(ii)=item.(field);end,end
end
function scatterBands(ax,x,energy,weights,scale,color)
for bb=1:size(energy,1),scatter(ax,x,energy(bb,:),max(weights(bb,:),0)*scale+eps,color,"filled","HandleVisibility","off");end
end
function decorateProjected(ax,obj,data,limits,markers)
ticks=obj.get_ticks();[distance,~,groups]=unique(ticks.distance,"stable");
labels=strings(size(distance));for ii=1:numel(distance),labels(ii)=strjoin(unique(ticks.label(groups==ii),"stable"),"|");end
set(ax,"XTick",distance,"XTickLabel",labels);
if ~isempty(limits),ylim(ax,reshape(double(limits),1,2));end
xlim(ax,[0,obj.bs{1}.distance(end)]);yline(ax,0,"k--");
if markers&&~data.is_metal,scatter(ax,data.vbm(:,1),data.vbm(:,2),50,"g","filled");scatter(ax,data.cbm(:,1),data.cbm(:,2),50,"r","filled");end
xlabel(ax,"Wave Vector");ylabel(ax,"E - E_f (eV)");box(ax,"on");
end
function value=siteOrbitalWeights(band,spin,sites,orbitals)
array=band.projections.(spin);orbitalNames=["s","py","pz","px","dxy","dyz","dz2","dxz","dx2","f_3","f_2","f_1","f0","f1","f2","f3"];
requested=reshape(string(orbitals),1,[]);mask=false(size(orbitalNames));
for ii=1:numel(requested)
    if any(requested(ii)==["p","d","f"])
        mask=mask|startsWith(orbitalNames,requested(ii));
    else
        mask=mask|(orbitalNames==requested(ii));
    end
end
indices=find(mask);
if isempty(indices)
    error("KSSOLV:Matgenlab:BSPlotterProjected:Orbital", ...
        "No requested orbital exists in the projection tensor.");
end
value=squeeze(sum(array(:,:,indices,reshape(double(sites),1,[])),[3,4]));
if isvector(value)&&size(array,1)==1,value=reshape(value,1,[]);end
end

function panels=makeSiteOrbitalPanels(spec,atoms,sumAtoms,sumMorbs,band)
elements=fieldnames(spec);atomElements=fieldnames(atoms);
if ~isequal(sort(elements),sort(atomElements))
    error("KSSOLV:Matgenlab:BSPlotterProjected:Elements", ...
        "Orbital and site specifications must contain the same elements.");
end
atomSums=optionalSpec(sumAtoms);orbitalSums=optionalSpec(sumMorbs);
panels=cell(0,5);
for ee=1:numel(elements)
    element=elements{ee};
    siteValues=siteNumbers(atoms.(element),element,band);
    siteGroups=num2cell(reshape(siteValues,1,[]));
    siteLabels=string(siteValues);
    if ~isempty(atomSums)&&isfield(atomSums,element)
        selected=siteNumbers(atomSums.(element),element,band);
        if numel(selected)<2||~all(ismember(selected,siteValues))
            error("KSSOLV:Matgenlab:BSPlotterProjected:AtomSum", ...
                "sum_atoms must select at least two requested sites.");
        end
        keep=siteValues(~ismember(siteValues,selected));
        siteGroups=[num2cell(keep),{selected}];
        siteLabels=[string(keep),summedLabel(selected,siteValues)];
    end
    requested=reshape(string(spec.(element)),1,[]);
    orbitalGroups=num2cell(requested);
    orbitalLabels=requested;
    if ~isempty(orbitalSums)&&isfield(orbitalSums,element)
        selected=reshape(string(orbitalSums.(element)),1,[]);
        selectedExpanded=expandOrbitals(selected);
        requestedExpanded=expandOrbitals(requested);
        if numel(selectedExpanded)<2||~all(ismember(selectedExpanded,requestedExpanded))
            error("KSSOLV:Matgenlab:BSPlotterProjected:OrbitalSum", ...
                "sum_morbs must select at least two requested orbitals.");
        end
        keep=requested(~cellfun(@(orb)any(ismember( ...
            expandOrbitals(orb),selectedExpanded)),num2cell(requested)));
        orbitalGroups=[num2cell(keep),{selectedExpanded}];
        orbitalLabels=[keep,orbitalSumLabel(selected,selectedExpanded)];
    end
    for aa=1:numel(siteGroups)
        for oo=1:numel(orbitalGroups)
            panels(end+1,:)={element,siteGroups{aa},siteLabels(aa), ...
                orbitalGroups{oo},orbitalLabels(oo)}; %#ok<AGROW>
        end
    end
end
end

function spec=optionalSpec(input)
if isempty(input),spec=[];else,spec=normalizeSpec(input);end
end

function values=siteNumbers(input,element,band)
if (ischar(input)||isstring(input))&&any(strcmpi(string(input),"all"))
    values=find(cellfun(@(site)startsWith(string(site.species_string), ...
        string(element)),band.structure.sites));
else
    values=reshape(double(input),1,[]);
end
if isempty(values)||any(values<1)||any(values>size(band.projections.up,4))|| ...
        any(fix(values)~=values)
    error("KSSOLV:Matgenlab:BSPlotterProjected:Site", ...
        "Site numbers must be valid one-based structure indices.");
end
end

function value=expandOrbitals(input)
source=reshape(string(input),1,[]);value=strings(1,0);
for ii=1:numel(source)
    switch source(ii)
        case "p",current=["px","py","pz"];
        case "d",current=["dxy","dyz","dxz","dx2","dz2"];
        case "f",current=["f_3","f_2","f_1","f0","f1","f2","f3"];
        otherwise,current=source(ii);
    end
    value=[value,current]; %#ok<AGROW>
end
value=unique(value,"stable");
end

function value=summedLabel(selected,allValues)
if numel(selected)==numel(allValues)&&all(sort(selected)==sort(allValues))
    value="all";
else
    value=strjoin(string(selected),"-");
end
end

function value=orbitalSumLabel(source,expanded)
if isscalar(source)&&any(source==["p","d","f"])
    value=source;
else
    value=strjoin(expanded,"+");
end
end

function [branches,xPieces,indices,ticks,labels]=selectedBranchData( ...
        band,data,selected)
if isempty(selected)
    branches=1:numel(data.distances);
else
    branches=reshape(double(selected),1,[])+1;
    if any(branches<1)||any(branches>numel(data.distances))|| ...
            any(fix(branches)~=branches)
        error("KSSOLV:Matgenlab:BSPlotterProjected:Branch", ...
            "selected_branches contains an invalid zero-based branch index.");
    end
end
xPieces=cell(size(branches));indices=cell(size(branches));
ticks=zeros(1,numel(branches)+1);labels=strings(size(ticks));offset=0;
for ii=1:numel(branches)
    branch=band.branches{branches(ii)};
    local=data.distances{branches(ii)}-data.distances{branches(ii)}(1);
    xPieces{ii}=local+offset;
    indices{ii}=branch.start_index:branch.end_index;
    names=split(string(branch.name),"-");
    if ii==1,labels(1)=names(1);end
    if ii>1&&labels(ii)~=names(1),labels(ii)=labels(ii)+"|"+names(1);end
    offset=xPieces{ii}(end);ticks(ii+1)=offset;labels(ii+1)=names(end);
end
end

function decorateSelected(ax,data,limits,markers,ticks,labels)
set(ax,"XTick",ticks,"XTickLabel",labels);
for ii=2:numel(ticks)-1,xline(ax,ticks(ii),"k-");end
xlim(ax,[0,ticks(end)]);yline(ax,0,"k--");
if isempty(limits)
    if data.is_metal,limits=[-10,10];
    else,limits=[data.vbm(1,2)-4,data.cbm(1,2)+4];end
end
ylim(ax,reshape(double(limits),1,2));
if markers&&~data.is_metal
    scatter(ax,data.vbm(:,1),data.vbm(:,2),50,"g","filled");
    scatter(ax,data.cbm(:,1),data.cbm(:,2),50,"r","filled");
end
xlabel(ax,"Wave Vector");ylabel(ax,"E - E_f (eV)");box(ax,"on");
end
