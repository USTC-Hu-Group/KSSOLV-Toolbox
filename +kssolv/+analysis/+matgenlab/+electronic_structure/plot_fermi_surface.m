function figures=plot_fermi_surface(data,structure,cbm,energyLevels, ...
        multipleFigure,existingFigure,kpoints,colors,transparency, ...
        labelsScale,pointsScale,interactive)
%PLOT_FERMI_SURFACE Plot isosurfaces of a reciprocal-space energy grid.
if nargin<4||isempty(energyLevels)
    if cbm,energyLevels=min(-data,[],"all")+.01;else,energyLevels=max(data,[],"all")-.01;end
end
if nargin<5||isempty(multipleFigure),multipleFigure=true;end
if nargin<6,existingFigure=[];end
if nargin<7,kpoints=[];end
if nargin<8||isempty(colors),colors=repmat([0,0,1],numel(energyLevels),1);end
if nargin<9||isempty(transparency),transparency=ones(1,numel(energyLevels));end
if nargin<10||isempty(labelsScale),labelsScale=.05;end %#ok<NASGU>
if nargin<11||isempty(pointsScale),pointsScale=.02;end
if nargin<12||isempty(interactive),interactive=true;end
factor=1;if cbm,factor=-1;end;values=factor*double(data);
if any(energyLevels<min(values,[],"all")|energyLevels>max(values,[],"all"))
    error("KSSOLV:Matgenlab:FermiSurface:EnergyRange","An energy level lies outside the data range.");
end
lattice=structure.lattice.reciprocal_lattice;figures=gobjects(1,numel(energyLevels));
shared=existingFigure;
if ~multipleFigure&&isempty(shared),shared=kssolv.analysis.matgenlab.electronic_structure.plot_brillouin_zone(lattice,"labels",kpoints);end
for ii=1:numel(energyLevels)
    if multipleFigure
        fig=kssolv.analysis.matgenlab.electronic_structure.plot_brillouin_zone(lattice,"labels",kpoints);
    else
        fig=shared;
    end
    ax=findobj(fig,"Type","axes");hold(ax,"on");
    surface=isosurface(values,energyLevels(ii));scale=lattice.matrix./size(values).';
    vertices=surface.vertices*scale;vertices=(vertices-mean(vertices,1))*2;
    patch(ax,"Faces",surface.faces,"Vertices",vertices,"FaceColor",colors(ii,:), ...
        "FaceAlpha",transparency(ii),"EdgeColor","none");camlight(ax);lighting(ax,"gouraud");
    if ~isempty(kpoints)
        map=asMap(kpoints);pts=cell2mat(cellfun(@(k)reshape(map(k),1,3),map.keys,"UniformOutput",false).');
        kssolv.analysis.matgenlab.electronic_structure.plot_points(pts,lattice,false,false,ax,"size",pointsScale*1000);
    end
    if ~interactive,fig.Visible="off";end
    figures(ii)=fig;
end
if ~multipleFigure,figures=shared;end
end
function value=asMap(input),if isa(input,"containers.Map"),value=input;else,value=containers.Map("KeyType","char","ValueType","any");names=fieldnames(input);for ii=1:numel(names),value(names{ii})=input.(names{ii});end,end,end
