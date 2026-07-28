classdef WulffShape
    %WULFFSHAPE Convex Wulff polyhedron generated from facet energies.
    properties
        lattice
        structure
        miller_list double
        hkl_list double
        e_surf_list double
        symprec (1,1) double = 1e-5
        vertices double = zeros(0,3)
        wulff_pt_list double = zeros(0,3)
        facets cell = cell(1,0)
        planes double = zeros(0,4)
        plane_family double = zeros(0,1)
        on_wulff logical = false(1,0)
        color_area double = zeros(1,0)
        miller_area cell = cell(1,0)
        miller_area_dict
        miller_energy_dict
        area_fraction_dict
        area_fractions double
        volume (1,1) double = 0
        surface_area (1,1) double = 0
        effective_radius (1,1) double = 0
        weighted_surface_energy (1,1) double = NaN
        total_surface_energy (1,1) double = 0
        anisotropy (1,1) double = NaN
        shape_factor (1,1) double = NaN
        tot_corner_sites (1,1) double = 0
        tot_edges (1,1) double = 0
    end
    methods
        function obj=WulffShape(lattice,millerList,energies,symprec)
            if nargin<4,symprec=1e-5;end
            inputMiller=double(millerList);
            if size(inputMiller,2)==4
                hklList=inputMiller(:,[1,2,4]);
            else
                hklList=inputMiller;
            end
            if size(hklList,2)~=3||numel(energies)~=size(hklList,1)
                error("KSSOLV:Matgenlab:WulffShape:Size", ...
                    "One surface energy is required per Miller index.");
            end
            if any(energies<0)
                warning("KSSOLV:Matgenlab:WulffShape:NegativeEnergy", ...
                    "Unphysical (negative) surface energy detected.");
            end
            if any(energies==0)
                error("KSSOLV:Matgenlab:WulffShape:Energy", ...
                    "Zero surface energies do not define a finite dual point.");
            end
            obj.lattice=lattice;obj.miller_list=inputMiller;
            obj.hkl_list=hklList;
            obj.e_surf_list=reshape(double(energies),1,[]);
            obj.symprec=symprec;
            obj.structure=kssolv.analysis.matgenlab.core.Structure( ...
                lattice,"H",[0,0,0]);
            [planes,families,millers]=allPlanes(lattice,obj.hkl_list, ...
                obj.e_surf_list,symprec);
            obj.planes=planes;obj.plane_family=families;
            % Construct the polar hull and dualise each of its triangular
            % simplices, following scipy.spatial.ConvexHull in pymatgen.
            % Retaining the resulting point order (including any repeated
            % coplanar points) is important because Qhull's second
            % triangulation determines ownership at degenerate facets.
            dualPoints=planes(:,1:3)./planes(:,4);
            % Qf makes the outside-point partition deterministic across
            % MATLAB's and SciPy's Qhull builds for nearly coplanar dual
            % facets.
            dualSimplices=convhulln(dualPoints,{'Qt','Qf'});
            wulffPoints=zeros(size(dualSimplices,1),3);
            for simplex=1:size(dualSimplices,1)
                selected=dualSimplices(simplex,:);
                wulffPoints(simplex,:)= ...
                    (inv(planes(selected,1:3))* ...
                    planes(selected,4)).'; %#ok<MINV>
            end
            if size(wulffPoints,1)<4
                error("KSSOLV:Matgenlab:WulffShape:Unbounded", ...
                    "Facet set does not define a bounded three-dimensional shape.");
            end
            obj.vertices=wulffPoints;
            obj.wulff_pt_list=wulffPoints;
            % Q14 reproduces SciPy/Qhull's pinched-vertex merge before
            % triangulating the primal hull.
            [simplices,obj.volume]=convhulln( ...
                wulffPoints,{'Qt','Q14'});
            obj.effective_radius=(3*obj.volume/(4*pi))^(1/3);
            familyAreas=zeros(1,size(obj.miller_list,1));
            facets=cell(1,size(planes,1));
            for plane=1:size(planes,1)
                facet=kssolv.analysis.matgenlab.analysis.WulffFacet( ...
                    planes(plane,1:3),planes(plane,4), ...
                    planes(plane,1:3)*planes(plane,4), ...
                    planes(plane,1:3)/planes(plane,4), ...
                    families(plane),families(plane),millers(plane,:));
                facets{plane}=facet;
            end
            % Match pymatgen's simplex ownership rule exactly.  In
            % particular, a Qhull triangle whose centre is within 1e-5 of
            % two nearly coincident planes belongs to the first
            % (surface-energy-sorted) plane, rather than being split by an
            % independently reconstructed polygon.
            for simplex=1:size(simplices,1)
                indices=simplices(simplex,:);
                points=obj.vertices(indices,:);
                center=mean(points,1);
                for plane=1:size(planes,1)
                    if abs(dot(planes(plane,1:3),center)- ...
                            planes(plane,4))<1e-5
                        family=families(plane);
                        familyAreas(family)=familyAreas(family)+ ...
                            kssolv.analysis.matgenlab.analysis. ...
                            get_tri_area(points);
                        facet=facets{plane};
                        facet.points{end+1}=points;
                        facet.outer_lines=[facet.outer_lines; ...
                            sort([indices(1),indices(2)]); ...
                            sort([indices(2),indices(3)]); ...
                            sort([indices(1),indices(3)])];
                        facets{plane}=facet;
                        break
                    end
                end
            end
            allEdges=zeros(0,2);
            for plane=1:numel(facets)
                facet=facets{plane};
                if ~isempty(facet.outer_lines)
                    [uniqueLines,~,membership]=unique( ...
                        facet.outer_lines,"rows","stable");
                    counts=accumarray(membership,1);
                    facet.outer_lines=uniqueLines(counts~=2,:);
                    allEdges=[allEdges;facet.outer_lines]; %#ok<AGROW>
                    facets{plane}=facet;
                end
            end
            obj.facets=facets;
            obj.on_wulff=familyAreas>0;
            obj.color_area=familyAreas;
            obj.area_fractions=familyAreas/max(sum(familyAreas),eps);
            obj.surface_area=sum(familyAreas);
            obj.total_surface_energy=sum(familyAreas.*obj.e_surf_list);
            obj.weighted_surface_energy=sum( ...
                familyAreas.*obj.e_surf_list)/max(sum(familyAreas),eps);
            obj.anisotropy=sqrt(sum(obj.area_fractions.* ...
                (obj.e_surf_list-obj.weighted_surface_energy).^2))/ ...
                obj.weighted_surface_energy;
            obj.shape_factor=obj.surface_area/obj.volume^(2/3);
            obj.tot_corner_sites=numel(unique(simplices(:)));
            obj.tot_edges=size(unique(allEdges,"rows"),1);
            obj.miller_area_dict=struct("miller",num2cell(obj.miller_list,2), ...
                "value",num2cell(familyAreas.'));
            obj.miller_energy_dict=struct("miller",num2cell(obj.miller_list,2), ...
                "value",num2cell(obj.e_surf_list.'));
            obj.area_fraction_dict=struct("miller",num2cell(obj.miller_list,2), ...
                "value",num2cell(obj.area_fractions.'));
            obj.miller_area=arrayfun(@(index) ...
                char(kssolv.analysis.matgenlab.analysis. ...
                hkl_tuple_to_str(obj.miller_list(index,:))+" : "+ ...
                string(round(familyAreas(index),4))), ...
                1:size(obj.miller_list,1),"UniformOutput",false);
        end

        function show(obj,varargin)
            axesHandle=obj.get_plot(varargin{:});
            axesHandle.Parent.Visible="on";
            drawnow;
        end

        function points=get_line_in_facet(obj,facet)
            if isempty(facet.outer_lines)
                points=zeros(0,3);
                return
            end
            lines=facet.outer_lines;
            ordered=lines(1,1:2);lines(1,:)=[];
            while ~isempty(lines)
                match=find(lines(:,1)==ordered(end),1);
                if isempty(match)
                    match=find(lines(:,2)==ordered(end),1);
                    if isempty(match),break,end
                    lines(match,:)=fliplr(lines(match,:));
                end
                ordered(end+1)=lines(match,2); %#ok<AGROW>
                lines(match,:)=[];
            end
            points=obj.wulff_pt_list(ordered,:);
        end

        function axesHandle=get_plot(obj,varargin)
            options=parsePlotOptions(varargin{:});
            if isempty(options.axes)
                figureHandle=figure("Visible","off", ...
                    "Position",[100,100,800,800]);
                axesHandle=axes(figureHandle);
            else
                axesHandle=options.axes;
            end
            hold(axesHandle,"on");
            colors=facetColors(obj,options.custom_colors);
            for plane=1:numel(obj.facets)
                facet=obj.facets{plane};
                if isempty(facet.points),continue,end
                points=obj.get_line_in_facet(facet);
                patch(axesHandle,"Vertices",points, ...
                    "Faces",1:size(points,1), ...
                    "FaceColor",colors(facet.index,:), ...
                    "FaceAlpha",options.alpha, ...
                    "EdgeColor",[0.5,0.5,0.5]);
            end
            axis(axesHandle,"equal");
            xlabel(axesHandle,"x");ylabel(axesHandle,"y");
            zlabel(axesHandle,"z");
            if options.grid_off,grid(axesHandle,"off");end
            if options.axis_off,axis(axesHandle,"off");end
            if ~isempty(options.direction)
                [azimuth,elevation]=obj.get_azimuth_elev( ...
                    options.direction);
                view(axesHandle,azimuth,elevation);
            end
            hold(axesHandle,"off");
        end

        function figureData=get_plotly(obj,varargin)
            options=parsePlotlyOptions(varargin{:});
            colors=facetColors(obj,options.custom_colors);
            meshes=cell(1,sum(~cellfun(@(facet) ...
                isempty(facet.points),obj.facets)));
            meshIndex=0;
            for plane=1:numel(obj.facets)
                facet=obj.facets{plane};
                if isempty(facet.points),continue,end
                points=obj.get_line_in_facet(facet);
                meshIndex=meshIndex+1;
                meshes{meshIndex}=struct( ...
                    "type","mesh3d","vertices",points, ...
                    "miller",facet.miller, ...
                    "surface_energy",facet.e_surf, ...
                    "color",colors(facet.index,:), ...
                    "alpha",options.alpha, ...
                    "units",options.units);
            end
            figureData=struct("data",{meshes},"layout",struct( ...
                "showlegend",true,"scene",struct("aspectmode","data")));
        end

        function [azimuth,elevation]=get_azimuth_elev(obj,millerIndex)
            millerIndex=reshape(double(millerIndex),1,[]);
            if numel(millerIndex)==4
                millerIndex=millerIndex([1,2,4]);
            end
            if isequal(millerIndex,[0,0,1])
                azimuth=0;elevation=90;return
            end
            cart=obj.lattice.get_cartesian_coords(millerIndex);
            azimuth=atan2d(cart(2),cart(1));
            elevation=atan2d(cart(3),hypot(cart(1),cart(2)));
            azimuth=mod(azimuth,360);
        end
    end
end
function [planes,families,millerPlanes]= ...
        allPlanes(lattice,millers,energies,symprec)
operations=lattice.get_recp_symmetry_operation(symprec);
reciprocal=lattice.reciprocal_lattice_crystallographic;
planes=zeros(0,4);families=zeros(0,1);indices=zeros(0,3);
for family=1:size(millers,1)
    for operation=1:numel(operations)
        hkl=round(operations{operation}.operate(millers(family,:)));
        if any(all(indices==hkl,2)),continue,end
        normal=reciprocal.get_cartesian_coords(hkl);
        normal=normal/norm(normal);
        indices(end+1,:)=hkl; %#ok<AGROW>
        planes(end+1,:)=[normal,energies(family)]; %#ok<AGROW>
        families(end+1,1)=family; %#ok<AGROW>
    end
end
[~,order]=sort(planes(:,4));
planes=planes(order,:);families=families(order);
millerPlanes=indices(order,:);
end
function options=parsePlotOptions(varargin)
options=struct("color_set","PuBu","grid_off",true,"axis_off",true, ...
    "show_area",false,"alpha",1,"off_color","red","direction",[], ...
    "bar_pos",[.75,.15,.05,.65],"bar_on",false, ...
    "units_in_JPERM2",true,"legend_on",true, ...
    "aspect_ratio",[8,8],"custom_colors",[], ...
    "axes",[]);
options=parseOptions(options,varargin{:});
end

function options=parsePlotlyOptions(varargin)
options=struct("color_set","PuBu","off_color","red","alpha",1, ...
    "custom_colors",[],"units_in_JPERM2",true);
options=parseOptions(options,varargin{:});
if options.units_in_JPERM2,options.units="Jm⁻²";
else,options.units="eVÅ⁻²";end
end

function options=parseOptions(options,varargin)
names=fieldnames(options);
if ~isempty(varargin)&&~(ischar(varargin{1})|| ...
        (isstring(varargin{1})&&isscalar(varargin{1})&& ...
        any(strcmpi(varargin{1},names))))
    for index=1:min(numel(varargin),numel(names)-1)
        options.(names{index})=varargin{index};
    end
    return
end
for index=1:2:numel(varargin)
    if index==numel(varargin),break,end
    match=find(strcmpi(string(varargin{index}),string(names)),1);
    if ~isempty(match),options.(names{match})=varargin{index+1};end
end
end

function colors=facetColors(obj,custom)
count=size(obj.miller_list,1);
if count==1
    colors=[0.2,0.5,0.8];
else
    colors=parula(count);
end
if isempty(custom),return,end
for index=1:count
    key=sprintf("%d,",obj.miller_list(index,:));
    if isa(custom,"containers.Map")&&isKey(custom,key)
        value=double(custom(key));colors(index,:)=value(1:3);
    end
end
end
