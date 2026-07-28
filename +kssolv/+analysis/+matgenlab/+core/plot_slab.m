function axesHandle=plot_slab(slab,axesHandle,scale,repeat,window, ...
        drawUnitCell,decay,adsorptionSites,inverse)
%PLOT_SLAB Render a deterministic top-down slab view using MATLAB graphics.
if nargin<2||isempty(axesHandle)
    figureHandle=figure("Visible","off","Color","white");
    axesHandle=axes(figureHandle);
end
if nargin<3,scale=.8;end
if nargin<4,repeat=5;end
if nargin<5,window=1.5;end
if nargin<6,drawUnitCell=true;end
if nargin<7,decay=.2;end
if nargin<8,adsorptionSites=true;end
if nargin<9,inverse=false;end
if ~isa(slab,"kssolv.analysis.matgenlab.core.IStructure")
    error("KSSOLV:Matgenlab:Adsorption:Structure", ...
        "slab must be a Structure or Slab.");
end
if ~isscalar(repeat)||repeat~=fix(repeat)||repeat<1
    error("KSSOLV:Matgenlab:Adsorption:PlotRepeat", ...
        "repeat must be a positive integer.");
end
if ~isgraphics(axesHandle,"axes")
    error("KSSOLV:Matgenlab:Adsorption:Axes", ...
        "axesHandle must be a valid MATLAB axes.");
end
original=slab.copy();
rendered=kssolv.analysis.matgenlab.core.reorient_z(slab);
originalCell=rendered.lattice.matrix;
rendered=rendered.make_supercell([repeat,repeat,1],true,true);
[~,order]=sort(rendered.cart_coords(:,3));
coordinates=rendered.cart_coords(order,:);
sites=rendered.sites(order);
alphas=max(0,1-decay*(max(coordinates(:,3))-coordinates(:,3)));
topFractional=rendered.lattice. ...
    get_fractional_coords(coordinates(end,:));
cornerFrac=[0,0,topFractional(3)];
corner=rendered.lattice.get_cartesian_coords(cornerFrac);
corner=corner(1:2);
vertices=originalCell(1:2,1:2);
latticeSum=sum(vertices,1);
if logical(inverse)
    alphas=flipud(alphas);
    sites=fliplr(sites);
    coordinates=flipud(coordinates);
end
holdState=ishold(axesHandle);
hold(axesHandle,"on");
offset=latticeSum*floor(repeat/2);
for index=1:size(coordinates,1)
    element=sites{index}.species.elements{1};
    radius=element.atomic_radius*scale;
    if ~isfinite(radius),radius=.5*scale;end
    center=coordinates(index,1:2)-offset;
    rectangle(axesHandle,"Position", ...
        [center-radius,2*radius,2*radius],"Curvature",[1,1], ...
        "FaceColor","white","EdgeColor","none");
    color=elementColor(element.symbol);
    rectangle(axesHandle,"Position", ...
        [center-radius,2*radius,2*radius],"Curvature",[1,1], ...
        "FaceColor",color,"FaceAlpha",alphas(index), ...
        "EdgeColor","black","LineWidth",.3);
end
adsorptionCoordinates=zeros(0,2);
if logical(adsorptionSites)
    source=original;
    if logical(inverse)
        source=source.make_supercell([1,1,-1],true,true);
    end
    finder=kssolv.analysis.matgenlab.core.AdsorbateSiteFinder(source);
    adsorption=finder.find_adsorption_sites();
    operation=kssolv.analysis.matgenlab.core.get_rot(original);
    transformed=operation.operate(adsorption.all);
    adsorptionCoordinates=transformed(:,1:2);
    if ~isempty(adsorptionCoordinates)
        plot(axesHandle,adsorptionCoordinates(:,1), ...
            adsorptionCoordinates(:,2),"kx","MarkerSize",10, ...
            "LineWidth",1,"LineStyle","none");
    end
end
if logical(drawUnitCell)
    cellVertices=[0,0;vertices(1,:);latticeSum; ...
        vertices(2,:);0,0]+corner;
    plot(axesHandle,cellVertices(:,1),cellVertices(:,2), ...
        "Color",[0,0,0,.5],"LineWidth",2);
end
axis(axesHandle,"equal");
center=corner+latticeSum/2;
extent=max(latticeSum);
axesHandle.XLim=[center(1)-extent*window, ...
    center(1)+extent*window];
axesHandle.YLim=[center(2)-extent*window, ...
    center(2)+extent*window];
axesHandle.UserData=struct("site_count",size(coordinates,1), ...
    "adsorption_sites",adsorptionCoordinates, ...
    "unit_cell_vertices",vertices);
if ~holdState,hold(axesHandle,"off");end
end

function color=elementColor(symbol)
persistent colors
if isempty(colors)
    path=fullfile(fileparts(mfilename("fullpath")),"..","+vis", ...
        "ElementColorSchemes.json");
    colors=jsondecode(fileread(path)).Jmol;
end
name=matlab.lang.makeValidName(char(symbol));
if isfield(colors,name)
    color=reshape(double(colors.(name)),1,[])/256.001;
else
    color=[.5,.5,.5];
end
end
