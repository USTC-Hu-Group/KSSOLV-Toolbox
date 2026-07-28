classdef StructureVis < handle
    %STRUCTUREVIS Native MATLAB visualization of structures and molecules.
    %
    % The public method names follow pymatgen.vis.structure_vtk.StructureVis,
    % while MATLAB graphics replace the optional VTK runtime. Figures are
    % created invisible so construction and image export work headlessly.

    properties
        figure_handle
        axes_handle
        el_color_mapping
        show_unit_cell (1,1) logical = true
        show_bonds (1,1) logical = false
        show_polyhedron (1,1) logical = true
        poly_radii_tol_factor (1,1) double = .5
        excluded_bonding_elements = strings(1,0)
        show_help (1,1) logical = true
        supercell (3,3) double = eye(3)
        structure = []
        title (1,1) string = "Structure Visualizer"
        mapper_map cell = cell(1,0)
        picker = []
        interactor_style = []
        scene cell = cell(1,0)
        graphics_handles = gobjects(1,0)
        help_text (1,1) string = ""
        camera_state (1,1) struct = struct()
    end

    methods
        function obj=StructureVis(elementColorMapping,showUnitCell, ...
                showBonds,showPolyhedron,polyRadiiTolFactor, ...
                excludedBondingElements)
            if nargin<1||isempty(elementColorMapping)
                schemes=jsondecode(fileread(fullfile( ...
                    fileparts(mfilename("fullpath")), ...
                    "ElementColorSchemes.json")));
                elementColorMapping=schemes.VESTA;
            end
            if nargin<2,showUnitCell=true;end
            if nargin<3,showBonds=false;end
            if nargin<4,showPolyhedron=true;end
            if nargin<5,polyRadiiTolFactor=.5;end
            if nargin<6||isempty(excludedBondingElements)
                excludedBondingElements=strings(1,0);
            end
            obj.el_color_mapping=elementColorMapping;
            obj.show_unit_cell=showUnitCell;
            obj.show_bonds=showBonds;
            obj.show_polyhedron=showPolyhedron;
            obj.poly_radii_tol_factor=polyRadiiTolFactor;
            obj.excluded_bonding_elements= ...
                reshape(string(excludedBondingElements),1,[]);
            obj.createFigure();
            obj.interactor_style= ...
                kssolv.analysis.matgenlab.vis. ...
                StructureInteractorStyle(obj);
            obj.installCallbacks();
            obj.redraw();
        end

        function rotate_view(obj,axisInd,angle)
            if nargin<2,axisInd=0;end
            if nargin<3,angle=0;end
            obj.ensureFigure();
            switch axisInd
                case 0
                    camroll(obj.axes_handle,angle);
                case 1
                    camorbit(obj.axes_handle,angle,0,"camera");
                otherwise
                    camorbit(obj.axes_handle,0,angle,"camera");
            end
            drawnow;
            obj.captureCamera();
        end

        function write_image(obj,filename,magnification,imageFormat)
            if nargin<2,filename="image.png";end
            if nargin<3,magnification=1;end
            if nargin<4,imageFormat="png";end
            if ~isscalar(magnification)||~isfinite(magnification)|| ...
                    magnification<=0
                error("KSSOLV:Matgenlab:StructureVis:Magnification", ...
                    "magnification must be a positive finite scalar.");
            end
            format=lower(string(imageFormat));
            if format=="jpeg",format="jpg";end
            if ~ismember(format,["png","jpg"])
                format="png";
            end
            obj.ensureFigure();
            drawnow;
            resolution=max(1,round(96*magnification));
            target=string(filename);
            [~,~,extension]=fileparts(target);
            expected="."+format;
            temporary=target;
            needsMove=~strcmpi(string(extension),expected);
            if needsMove
                temporary=string(tempname)+expected;
            end
            exportgraphics(obj.axes_handle,temporary, ...
                "Resolution",resolution,"BackgroundColor","white");
            if needsMove
                movefile(temporary,target,"f");
            end
        end

        function redraw(obj,resetCamera)
            if nargin<2,resetCamera=false;end
            obj.ensureFigure();
            if isempty(obj.structure)
                obj.clearScene();
                obj.add_picker_fixed();
                if obj.show_help,obj.display_help();end
            else
                obj.set_structure(obj.structure,resetCamera);
            end
            drawnow;
        end

        function orthogonalize_structure(obj)
            if ~isempty(obj.structure)&& ...
                    isa(obj.structure, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                obj.set_structure(obj.structure.copy([],true));
            end
            drawnow;
        end

        function display_help(obj)
            lines=[ ...
                "h : Toggle help"
                "A/a, B/b or C/c : Increase/decrease cell"
                "# : Toggle showing of polyhedrons"
                "- : Toggle showing of bonds"
                "r : Reset camera direction"
                "[/] : Change polyhedron radius tolerance"
                "Arrow keys : Rotate view"
                "s : Save view to image.png"
                "o : Orthogonalize structure"];
            obj.help_text=strjoin(lines,newline);
            handle=text(obj.axes_handle,.01,.01,obj.help_text, ...
                "Units","normalized","VerticalAlignment","bottom", ...
                "Color",[0,0,0],"FontName","Times", ...
                "FontSize",10,"Interpreter","none", ...
                "PickableParts","none");
            obj.rememberHandle(handle);
            obj.record(struct("kind","help","text",obj.help_text));
        end

        function set_structure(obj,structure,resetCamera,toUnitCell)
            if nargin<3,resetCamera=true;end
            if nargin<4,toUnitCell=true;end
            if ~isa(structure, ...
                    "kssolv.analysis.matgenlab.core.SiteCollection")
                error("KSSOLV:Matgenlab:StructureVis:Structure", ...
                    "structure must be a Structure or Molecule.");
            end
            obj.ensureFigure();
            obj.clearScene();
            hasLattice=isa(structure, ...
                "kssolv.analysis.matgenlab.core.IStructure");
            if hasLattice
                rendered=kssolv.analysis.matgenlab.core.Structure. ...
                    from_sites(structure.sites,to_unit_cell=toUnitCell);
                rendered=rendered*obj.supercell;
            else
                rendered=structure.copy();
            end
            included=zeros(0,3);
            for siteIndex=1:rendered.num_sites
                obj.add_site(rendered(siteIndex));
                included(end+1,:)=rendered(siteIndex).coords; %#ok<AGROW>
            end
            if obj.show_unit_cell&&hasLattice
                matrix=rendered.lattice.matrix;
                labels=["a","b","c"];
                colors=[1,0,0;0,1,0;0,0,1];
                obj.add_text([0,0,0],"o");
                for index=1:3
                    obj.add_line([0,0,0],matrix(index,:), ...
                        colors(index,:));
                    obj.add_text(matrix(index,:),labels(index), ...
                        colors(index,:));
                end
                permutations=perms(1:3);
                for index=1:size(permutations,1)
                    order=permutations(index,:);
                    obj.add_line(matrix(order(1),:), ...
                        matrix(order(1),:)+matrix(order(2),:));
                    obj.add_line(matrix(order(1),:)+ ...
                        matrix(order(2),:),sum(matrix(order,:),1));
                end
            end
            if (obj.show_bonds||obj.show_polyhedron)&&hasLattice
                obj.addCoordination(rendered,included);
            end
            obj.add_picker_fixed();
            if obj.show_help,obj.display_help();end
            axis(obj.axes_handle,"equal");
            axis(obj.axes_handle,"vis3d");
            grid(obj.axes_handle,"off");
            if resetCamera,obj.resetCamera(rendered,hasLattice);end
            obj.structure=structure;
            obj.title=string(rendered.formula);
            obj.figure_handle.Name=char(obj.title);
            drawnow;
        end

        function zoom(obj,factor)
            if ~isscalar(factor)||~isfinite(factor)||factor<=0
                error("KSSOLV:Matgenlab:StructureVis:Zoom", ...
                    "Zoom factor must be a positive finite scalar.");
            end
            camzoom(obj.axes_handle,factor);
            drawnow;
            obj.captureCamera();
        end

        function show(obj)
            obj.ensureFigure();
            obj.figure_handle.Visible="on";
            obj.figure_handle.Position(3:4)=[800,800];
            drawnow;
        end

        function handles=add_site(obj,site)
            if ~isa(site,"kssolv.analysis.matgenlab.core.Site")
                error("KSSOLV:Matgenlab:StructureVis:Site", ...
                    "site must be a Site or PeriodicSite.");
            end
            [species,occupancies]=site.species.items();
            radius=0;
            total=sum(occupancies);
            for index=1:numel(species)
                radius=radius+occupancies(index)* ...
                    obj.speciesRadius(species{index});
            end
            visualRadius=.2+.002*radius;
            startAngle=0;
            handles=gobjects(1,numel(species)+(total<1));
            for index=1:numel(species)
                color=obj.elementColor(species{index}.symbol);
                finish=startAngle+360*occupancies(index);
                handle=obj.add_partial_sphere(site.coords, ...
                    visualRadius,color,startAngle,finish);
                handle.UserData=site;
                handles(index)=handle;
                obj.mapper_map{end+1}=struct( ... %#ok<AGROW>
                    "handle",handle,"sites",{{site}});
                startAngle=finish;
            end
            if total<1
                handle=obj.add_partial_sphere(site.coords, ...
                    visualRadius,[1,1,1],startAngle, ...
                    startAngle+360*(1-total));
                handle.UserData=site;
                handles(end)=handle;
                obj.mapper_map{end+1}=struct( ... %#ok<AGROW>
                    "handle",handle,"sites",{{site}});
            end
            obj.record(struct("kind","site", ...
                "coords",reshape(site.coords,1,3), ...
                "radius",visualRadius,"total_occupancy",total, ...
                "species",string(cellfun(@string,species, ...
                "UniformOutput",false))));
        end

        function handle=add_partial_sphere(obj,coords,radius,color, ...
                startAngle,endAngle,opacity)
            if nargin<5,startAngle=0;end
            if nargin<6,endAngle=360;end
            if nargin<7,opacity=1;end
            obj.validatePoint(coords,"coords");
            if ~isscalar(radius)||~isfinite(radius)||radius<0
                error("KSSOLV:Matgenlab:StructureVis:Radius", ...
                    "Sphere radius must be a nonnegative finite scalar.");
            end
            color=obj.normalizeColor(color);
            opacity=obj.validateOpacity(opacity);
            theta=linspace(deg2rad(startAngle),deg2rad(endAngle),19);
            phi=linspace(-pi/2,pi/2,19);
            [thetaGrid,phiGrid]=meshgrid(theta,phi);
            coords=reshape(double(coords),1,3);
            x=coords(1)+radius*cos(phiGrid).*cos(thetaGrid);
            y=coords(2)+radius*cos(phiGrid).*sin(thetaGrid);
            z=coords(3)+radius*sin(phiGrid);
            handle=surf(obj.axes_handle,x,y,z, ...
                "FaceColor",color,"EdgeColor","none", ...
                "FaceAlpha",opacity,"SpecularStrength",.15, ...
                "DiffuseStrength",.8);
            obj.rememberHandle(handle);
            obj.record(struct("kind","partial_sphere", ...
                "coords",coords,"radius",radius,"color",color, ...
                "start",startAngle,"end",endAngle, ...
                "opacity",opacity,"x",x,"y",y,"z",z));
        end

        function handle=add_text(obj,coords,textValue,color)
            if nargin<4,color=[0,0,0];end
            obj.validatePoint(coords,"coords");
            color=obj.normalizeColor(color);
            coords=reshape(double(coords),1,3);
            handle=text(obj.axes_handle,coords(1),coords(2), ...
                coords(3),string(textValue),"Color",color, ...
                "FontSize",10,"Interpreter","none");
            obj.rememberHandle(handle);
            obj.record(struct("kind","text","coords",coords, ...
                "text",string(textValue),"color",color));
        end

        function handle=add_line(obj,startPoint,endPoint,color,width)
            if nargin<4,color=[.5,.5,.5];end
            if nargin<5,width=1;end
            obj.validatePoint(startPoint,"start");
            obj.validatePoint(endPoint,"end");
            if ~isscalar(width)||~isfinite(width)||width<=0
                error("KSSOLV:Matgenlab:StructureVis:LineWidth", ...
                    "Line width must be a positive finite scalar.");
            end
            color=obj.normalizeColor(color);
            points=[reshape(double(startPoint),1,3); ...
                reshape(double(endPoint),1,3)];
            handle=plot3(obj.axes_handle,points(:,1),points(:,2), ...
                points(:,3),"Color",color,"LineWidth",width);
            obj.rememberHandle(handle);
            obj.record(struct("kind","line","points",points, ...
                "color",color,"width",width));
        end

        function handle=add_polyhedron(obj,neighbors,center,color, ...
                opacity,drawEdges,edgesColor,edgesLinewidth)
            if nargin<5,opacity=1;end
            if nargin<6,drawEdges=false;end
            if nargin<7,edgesColor=[0,0,0];end
            if nargin<8,edgesLinewidth=2;end
            points=obj.coordinates(neighbors);
            if size(points,1)<4
                error("KSSOLV:Matgenlab:StructureVis:Polyhedron", ...
                    "A polyhedron requires at least four vertices.");
            end
            color=obj.resolveElementColor(color,center);
            opacity=obj.validateOpacity(opacity);
            try
                faces=convhulln(points);
            catch exception
                error("KSSOLV:Matgenlab:StructureVis:Polyhedron", ...
                    "Polyhedron vertices must span three dimensions: %s", ...
                    exception.message);
            end
            edgeColor="none";
            if drawEdges,edgeColor=obj.normalizeColor(edgesColor);end
            handle=patch(obj.axes_handle,"Vertices",points, ...
                "Faces",faces,"FaceColor",color, ...
                "FaceAlpha",opacity,"EdgeColor",edgeColor, ...
                "LineWidth",edgesLinewidth);
            obj.rememberHandle(handle);
            sites=[{center},obj.asCell(neighbors)];
            obj.mapper_map{end+1}=struct( ... %#ok<AGROW>
                "handle",handle,"sites",{sites});
            obj.record(struct("kind","polyhedron","vertices",points, ...
                "faces",faces,"color",color,"opacity",opacity, ...
                "draw_edges",logical(drawEdges)));
        end

        function handle=add_triangle(obj,neighbors,color,center, ...
                opacity,drawEdges,edgesColor,edgesLinewidth)
            if nargin<4,center=[];end
            if nargin<5,opacity=.4;end
            if nargin<6,drawEdges=false;end
            if nargin<7,edgesColor=[0,0,0];end
            if nargin<8,edgesLinewidth=2;end
            points=obj.coordinates(neighbors);
            if size(points,1)~=3
                error("KSSOLV:Matgenlab:StructureVis:Triangle", ...
                    "A triangle requires exactly three vertices.");
            end
            if (ischar(color)||isstring(color))&& ...
                    string(color)=="element"&&isempty(center)
                error("KSSOLV:Matgenlab:StructureVis:TriangleCenter", ...
                    "Color should be chosen according to the central "+ ...
                    "atom, and central atom is not provided.");
            end
            color=obj.resolveElementColor(color,center);
            opacity=obj.validateOpacity(opacity);
            edgeColor="none";
            if drawEdges,edgeColor=obj.normalizeColor(edgesColor);end
            handle=patch(obj.axes_handle,"Vertices",points, ...
                "Faces",[1,2,3],"FaceColor",color, ...
                "FaceAlpha",opacity,"EdgeColor",edgeColor, ...
                "LineWidth",edgesLinewidth);
            obj.rememberHandle(handle);
            obj.record(struct("kind","triangle","vertices",points, ...
                "color",color,"opacity",opacity, ...
                "draw_edges",logical(drawEdges)));
        end

        function handles=add_faces(obj,faces,color,opacity)
            if nargin<4,opacity=.35;end
            faceList=obj.asCell(faces);
            handles=gobjects(1,0);
            for index=1:numel(faceList)
                points=obj.coordinates(faceList{index});
                if size(points,1)<3
                    error("KSSOLV:Matgenlab:StructureVis:Face", ...
                        "Number of points for a face should be >= 3.");
                end
                if size(points,1)==3
                    triangles=[1,2,3];
                    vertices=points;
                else
                    center=mean(points,1);
                    vertices=[points;center];
                    count=size(points,1);
                    triangles=zeros(count,3);
                    for pointIndex=1:count
                        triangles(pointIndex,:)=[pointIndex, ...
                            mod(pointIndex,count)+1,count+1];
                    end
                end
                handle=patch(obj.axes_handle,"Vertices",vertices, ...
                    "Faces",triangles,"FaceColor", ...
                    obj.normalizeColor(color),"FaceAlpha", ...
                    obj.validateOpacity(opacity),"EdgeColor","none");
                obj.rememberHandle(handle);
                handles(end+1)=handle; %#ok<AGROW>
                obj.record(struct("kind","face","vertices",vertices, ...
                    "faces",triangles,"color", ...
                    obj.normalizeColor(color),"opacity",opacity));
            end
        end

        function handles=add_edges(obj,edges,typeValue,linewidth,color)
            if nargin<3,typeValue="line";end
            if nargin<4,linewidth=2;end
            if nargin<5,color=[0,0,0];end
            edgeList=obj.edgeList(edges);
            handles=gobjects(1,numel(edgeList));
            for index=1:numel(edgeList)
                handles(index)=obj.add_line(edgeList{index}(1,:), ...
                    edgeList{index}(2,:),color,linewidth);
            end
            obj.record(struct("kind","edges","edges",{edgeList}, ...
                "type",string(typeValue),"linewidth",linewidth, ...
                "color",obj.normalizeColor(color)));
        end

        function handles=add_bonds(obj,neighbors,center,color, ...
                opacity,radius)
            if nargin<4||isempty(color),color=[.5,.5,.5];end
            if nargin<5||isempty(opacity),opacity=1;end
            if nargin<6,radius=.1;end
            points=obj.coordinates(neighbors);
            handles=gobjects(1,size(points,1));
            for index=1:size(points,1)
                handles(index)=obj.drawCylinder(center.coords, ...
                    points(index,:),radius,color,opacity);
            end
            obj.record(struct("kind","bonds", ...
                "center",reshape(center.coords,1,3), ...
                "neighbors",points,"radius",radius, ...
                "color",obj.normalizeColor(color), ...
                "opacity",obj.validateOpacity(opacity)));
        end

        function add_picker_fixed(obj)
            obj.picker="fixed";
            if isgraphics(obj.figure_handle)
                obj.figure_handle.WindowButtonDownFcn= ...
                    @(~,~)obj.pickNearest();
            end
        end

        function add_picker(obj)
            obj.picker="floating";
            if isgraphics(obj.figure_handle)
                obj.figure_handle.WindowButtonDownFcn= ...
                    @(~,~)obj.pickNearest();
            end
        end

        function delete(obj)
            if ~isempty(obj.figure_handle)&& ...
                    isgraphics(obj.figure_handle)
                delete(obj.figure_handle);
            end
        end
    end

    methods (Access=protected)
        function installCallbacks(obj)
            if ~isgraphics(obj.figure_handle),return,end
            obj.figure_handle.WindowKeyPressFcn= ...
                @(source,event)obj.interactor_style. ...
                keyPressEvent(source,event);
            obj.figure_handle.WindowButtonDownFcn= ...
                @(source,event)obj.interactor_style. ...
                leftButtonPressEvent(source,event);
            obj.figure_handle.WindowButtonMotionFcn= ...
                @(source,event)obj.interactor_style. ...
                mouseMoveEvent(source,event);
            obj.figure_handle.WindowButtonUpFcn= ...
                @(source,event)obj.interactor_style. ...
                leftButtonReleaseEvent(source,event);
        end

        function clearScene(obj)
            cla(obj.axes_handle);
            hold(obj.axes_handle,"on");
            view(obj.axes_handle,3);
            obj.axes_handle.Color=[1,1,1];
            obj.axes_handle.Visible="off";
            obj.scene=cell(1,0);
            obj.graphics_handles=gobjects(1,0);
            obj.mapper_map=cell(1,0);
        end

        function createFigure(obj)
            obj.figure_handle=figure("Visible","off", ...
                "Color","white","Name",char(obj.title), ...
                "NumberTitle","off");
            obj.axes_handle=axes(obj.figure_handle);
            hold(obj.axes_handle,"on");
            view(obj.axes_handle,3);
            axis(obj.axes_handle,"equal");
            obj.axes_handle.Visible="off";
        end

        function ensureFigure(obj)
            if isempty(obj.figure_handle)||~isgraphics(obj.figure_handle)
                obj.createFigure();
                if isempty(obj.interactor_style)
                    obj.interactor_style= ...
                        kssolv.analysis.matgenlab.vis. ...
                        StructureInteractorStyle(obj);
                end
                obj.installCallbacks();
            end
        end

        function captureCamera(obj)
            obj.camera_state=struct( ...
                "position",campos(obj.axes_handle), ...
                "target",camtarget(obj.axes_handle), ...
                "up",camup(obj.axes_handle), ...
                "view_angle",camva(obj.axes_handle));
        end

        function resetCamera(obj,rendered,hasLattice)
            if hasLattice
                matrix=rendered.lattice.matrix;
                lengths=rendered.lattice.lengths;
                position=(matrix(2,:)+matrix(3,:))*.5+ ...
                    matrix(1,:)*max(lengths)/lengths(1)*3.5;
                target=sum(matrix,1)*.5;
                up=matrix(3,:);
            else
                target=rendered.center_of_mass;
                distances=vecnorm(rendered.cart_coords-target,2,2);
                [~,index]=max(distances);
                direction=rendered(index).coords-target;
                if norm(direction)<eps,direction=[1,0,0];end
                position=target+5*direction;
                up=[0,0,1];
            end
            campos(obj.axes_handle,position);
            camtarget(obj.axes_handle,target);
            camup(obj.axes_handle,up);
            camproj(obj.axes_handle,"perspective");
            obj.captureCamera();
        end

        function addCoordination(obj,structure,included)
            elements=structure.elements;
            electronegativity=cellfun(@(item)item.X,elements);
            [~,index]=max(electronegativity);
            anion=elements{index};
            anionRadius=anion.average_ionic_radius;
            for siteIndex=1:structure.num_sites
                site=structure(siteIndex);
                [species,occupancies]=site.species.items();
                excluded=false;
                maximumRadius=0;
                color=[0,0,0];
                for speciesIndex=1:numel(species)
                    symbol=species{speciesIndex}.symbol;
                    if any(obj.excluded_bonding_elements==symbol)|| ...
                            symbol==anion.symbol
                        excluded=true;
                        break
                    end
                    maximumRadius=max(maximumRadius, ...
                        obj.speciesRadius(species{speciesIndex}));
                    color=color+occupancies(speciesIndex)* ...
                        obj.elementColor(symbol);
                end
                if excluded,continue,end
                cutoff=(1+obj.poly_radii_tol_factor)* ...
                    (maximumRadius+anionRadius);
                neighbors=structure.get_neighbors(site,cutoff);
                anionNeighbors=cell(1,0);
                for neighborIndex=1:numel(neighbors)
                    [neighborSpecies,~]= ...
                        neighbors{neighborIndex}.species.items();
                    contains=any(cellfun(@(item) ...
                        item.symbol==anion.symbol,neighborSpecies));
                    if ~contains,continue,end
                    anionNeighbors{end+1}=neighbors{neighborIndex}; ...
                        %#ok<AGROW>
                    if isempty(included)||~any(vecnorm( ...
                            included-neighbors{neighborIndex}.coords, ...
                            2,2)<1e-8)
                        obj.add_site(neighbors{neighborIndex});
                    end
                end
                if obj.show_bonds&&~isempty(anionNeighbors)
                    obj.add_bonds(anionNeighbors,site);
                end
                if obj.show_polyhedron&&numel(anionNeighbors)>=4
                    obj.add_polyhedron(anionNeighbors,site,color);
                end
            end
        end

        function radius=speciesRadius(~,species)
            if isa(species,"kssolv.analysis.matgenlab.core.Species")
                radius=species.ionic_radius;
                if isnan(radius)
                    radius=species.element.average_ionic_radius;
                end
            else
                radius=species.average_ionic_radius;
            end
            if isempty(radius)||~isfinite(radius),radius=0;end
        end

        function color=elementColor(obj,symbol)
            key=char(string(symbol));
            mapping=obj.el_color_mapping;
            if isa(mapping,"containers.Map")&&isKey(mapping,key)
                color=mapping(key);
            elseif isstruct(mapping)&&isfield(mapping,key)
                color=mapping.(key);
            else
                color=[255,255,255];
            end
            color=obj.normalizeColor(color);
        end

        function color=resolveElementColor(obj,color,center)
            if (ischar(color)||isstring(color))&& ...
                    string(color)=="element"
                [species,occupancies]=center.species.items();
                [~,index]=max(occupancies);
                color=obj.elementColor(species{index}.symbol);
            else
                color=obj.normalizeColor(color);
            end
        end

        function points=coordinates(obj,values)
            entries=obj.asCell(values);
            if isscalar(entries)&&isnumeric(entries{1})
                points=double(entries{1});
                if isvector(points),points=reshape(points,1,3);end
            else
                points=zeros(numel(entries),3);
                for index=1:numel(entries)
                    value=entries{index};
                    if isnumeric(value),points(index,:)=reshape(value,1,3);
                    else,points(index,:)=reshape(value.coords,1,3);end
                end
            end
            if size(points,2)~=3||any(~isfinite(points),"all")
                error("KSSOLV:Matgenlab:StructureVis:Coordinates", ...
                    "Coordinates must be a finite N-by-3 array.");
            end
        end

        function entries=asCell(~,values)
            if iscell(values)
                entries=reshape(values,1,[]);
            elseif isnumeric(values)
                entries={values};
            else
                entries=num2cell(values);
            end
        end

        function edges=edgeList(obj,values)
            if iscell(values)
                edges=reshape(values,1,[]);
            elseif isnumeric(values)&&ndims(values)==3&& ...
                    size(values,2)==2&&size(values,3)==3
                edges=cell(1,size(values,1));
                for index=1:size(values,1)
                    edges{index}=reshape(values(index,:,:),2,3);
                end
            elseif isnumeric(values)&&isequal(size(values),[2,3])
                edges={values};
            else
                error("KSSOLV:Matgenlab:StructureVis:Edges", ...
                    "Edges must contain pairs of three-dimensional points.");
            end
            for index=1:numel(edges)
                edges{index}=obj.coordinates(edges{index});
                if ~isequal(size(edges{index}),[2,3])
                    error("KSSOLV:Matgenlab:StructureVis:Edges", ...
                        "Each edge must contain exactly two points.");
                end
            end
        end

        function handle=drawCylinder(obj,startPoint,endPoint,radius, ...
                color,opacity)
            startPoint=reshape(double(startPoint),1,3);
            endPoint=reshape(double(endPoint),1,3);
            direction=endPoint-startPoint;
            lengthValue=norm(direction);
            if lengthValue<eps
                error("KSSOLV:Matgenlab:StructureVis:Bond", ...
                    "A bond must have nonzero length.");
            end
            [x,y,z]=cylinder(radius,12);
            z=z*lengthValue;
            axisVector=direction/lengthValue;
            rotation=obj.alignRotation([0,0,1],axisVector);
            vertices=[x(:),y(:),z(:)]*rotation.'+startPoint;
            x=reshape(vertices(:,1),size(x));
            y=reshape(vertices(:,2),size(y));
            z=reshape(vertices(:,3),size(z));
            handle=surf(obj.axes_handle,x,y,z, ...
                "FaceColor",obj.normalizeColor(color), ...
                "FaceAlpha",obj.validateOpacity(opacity), ...
                "EdgeColor","none");
            obj.rememberHandle(handle);
        end

        function pickNearest(obj)
            if isempty(obj.structure)||~isgraphics(obj.axes_handle),return,end
            point=obj.axes_handle.CurrentPoint(1,:);
            coordinates=obj.structure.cart_coords;
            [~,index]=min(vecnorm(coordinates-point,2,2));
            site=obj.structure(index);
            obj.help_text=site.species_string+" - "+ ...
                strjoin(compose("%.3f",site.frac_coords),", ")+" ["+ ...
                strjoin(compose("%.3f",site.coords),", ")+"]";
        end

        function rememberHandle(obj,handle)
            obj.graphics_handles(end+1)=handle;
        end

        function record(obj,value)
            obj.scene{end+1}=value;
        end
    end

    methods (Static,Access=protected)
        function validatePoint(value,name)
            if ~isnumeric(value)||numel(value)~=3|| ...
                    any(~isfinite(value))
                error("KSSOLV:Matgenlab:StructureVis:Point", ...
                    "%s must contain three finite coordinates.",name);
            end
        end

        function color=normalizeColor(value)
            if ~isnumeric(value)||numel(value)~=3|| ...
                    any(~isfinite(value))
                error("KSSOLV:Matgenlab:StructureVis:Color", ...
                    "Color must contain three finite numeric values.");
            end
            color=reshape(double(value),1,3);
            if any(color>1),color=color/255;end
            if any(color<0)||any(color>1)
                error("KSSOLV:Matgenlab:StructureVis:Color", ...
                    "Color components must lie between zero and one.");
            end
        end

        function value=validateOpacity(value)
            if ~isscalar(value)||~isfinite(value)||value<0||value>1
                error("KSSOLV:Matgenlab:StructureVis:Opacity", ...
                    "Opacity must lie between zero and one.");
            end
        end

        function rotation=alignRotation(from,to)
            from=from/norm(from);
            to=to/norm(to);
            crossValue=cross(from,to);
            sine=norm(crossValue);
            cosine=max(-1,min(1,dot(from,to)));
            if sine<1e-12
                if cosine>0
                    rotation=eye(3);
                else
                    candidate=[1,0,0];
                    if abs(dot(candidate,from))>.9
                        candidate=[0,1,0];
                    end
                    axisValue=cross(from,candidate);
                    axisValue=axisValue/norm(axisValue);
                    rotation=2*(axisValue.'*axisValue)-eye(3);
                end
                return
            end
            skew=[0,-crossValue(3),crossValue(2); ...
                crossValue(3),0,-crossValue(1); ...
                -crossValue(2),crossValue(1),0];
            rotation=eye(3)+skew+skew*skew*((1-cosine)/(sine^2));
        end
    end
end
