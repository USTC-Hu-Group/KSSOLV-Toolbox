classdef GrainBoundary < kssolv.analysis.matgenlab.core.Structure
    %GRAINBOUNDARY Bicrystal structure with CSL metadata.
    properties
        oriented_unit_cell
        rotation_axis
        rotation_angle (1,1) double
        gb_plane
        join_plane
        init_cell
        vacuum_thickness (1,1) double
        ab_shift
    end
    properties (Dependent)
        sigma
        sigma_from_site_prop
        top_grain
        bottom_grain
        coincidents
    end
    methods
        function obj=GrainBoundary(lattice,species,coords,rotationAxis, ...
                rotationAngle,gbPlane,joinPlane,initCell, ...
                vacuumThickness,abShift,siteProperties, ...
                orientedUnitCell,varargin)
            options=struct("validate_proximity",false, ...
                "coords_are_cartesian",false,"properties",struct());
            options=parseOptions(options,varargin{:});
            obj@kssolv.analysis.matgenlab.core.Structure(lattice,species, ...
                coords,validate_proximity=options.validate_proximity, ...
                coords_are_cartesian=options.coords_are_cartesian, ...
                site_properties=siteProperties,properties=options.properties);
            obj.oriented_unit_cell=orientedUnitCell;
            obj.rotation_axis=reshape(double(rotationAxis),1,[]);
            obj.rotation_angle=rotationAngle;
            obj.gb_plane=reshape(double(gbPlane),1,[]);
            obj.join_plane=reshape(double(joinPlane),1,[]);
            obj.init_cell=initCell;obj.vacuum_thickness=vacuumThickness;
            obj.ab_shift=reshape(double(abShift),1,2);
        end
        function value=get.sigma(obj)
            value=round(obj.oriented_unit_cell.volume/obj.init_cell.volume);
        end
        function value=get.sigma_from_site_prop(obj)
            labels=propertyStrings(obj.site_properties.grain_label);
            if any(ismissing(labels))
                error("KSSOLV:Matgenlab:GrainBoundary:Coincident", ...
                    "Sites were merged; sigma_from_site_prop is undefined.");
            end
            count=sum(contains(labels,"incident"));
            if count==0
                error("KSSOLV:Matgenlab:GrainBoundary:Coincident", ...
                    "No coincident-site labels are available.");
            end
            value=round(obj.num_sites/count);
        end
        function value=get.top_grain(obj)
            labels=propertyStrings(obj.site_properties.grain_label);
            value=kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                obj.sites(contains(labels,"top")));
        end
        function value=get.bottom_grain(obj)
            labels=propertyStrings(obj.site_properties.grain_label);
            value=kssolv.analysis.matgenlab.core.Structure.from_sites( ...
                obj.sites(contains(labels,"bottom")));
        end
        function value=get.coincidents(obj)
            labels=propertyStrings(obj.site_properties.grain_label);
            value=obj.sites(contains(labels,"incident"));
        end
        function result=copy(obj)
            result=kssolv.analysis.matgenlab.core.GrainBoundary( ...
                obj.lattice,obj.species_and_occu,obj.frac_coords, ...
                obj.rotation_axis,obj.rotation_angle,obj.gb_plane, ...
                obj.join_plane,obj.init_cell,obj.vacuum_thickness, ...
                obj.ab_shift,obj.site_properties,obj.oriented_unit_cell);
        end
        function result=get_sorted_structure(obj,key,reverse)
            if nargin<2,key=[];end
            if nargin<3,reverse=false;end
            base=get_sorted_structure@ ...
                kssolv.analysis.matgenlab.core.IStructure(obj,key,reverse);
            result=kssolv.analysis.matgenlab.core.GrainBoundary( ...
                base.lattice,base.species_and_occu,base.frac_coords, ...
                obj.rotation_axis,obj.rotation_angle,obj.gb_plane, ...
                obj.join_plane,obj.init_cell,obj.vacuum_thickness, ...
                obj.ab_shift,base.site_properties,obj.oriented_unit_cell);
        end
        function value=as_dict(obj,varargin)
            value=as_dict@kssolv.analysis.matgenlab.core.IStructure( ...
                obj,varargin{:});
            value.x_module="pymatgen.core.interface";
            value.x_class="GrainBoundary";
            value.init_cell=obj.init_cell.as_dict();
            value.rotation_axis=obj.rotation_axis;
            value.rotation_angle=obj.rotation_angle;
            value.gb_plane=obj.gb_plane;value.join_plane=obj.join_plane;
            value.vacuum_thickness=obj.vacuum_thickness;
            value.ab_shift=obj.ab_shift;
            value.oriented_unit_cell=obj.oriented_unit_cell.as_dict();
        end
    end
    methods (Static)
        function obj=from_dict(value)
            base=kssolv.analysis.matgenlab.core.Structure.from_dict(value);
            if isa(value.init_cell,"kssolv.analysis.matgenlab.core.IStructure")
                init=value.init_cell;
            else
                init=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                    value.init_cell);
            end
            if isa(value.oriented_unit_cell, ...
                    "kssolv.analysis.matgenlab.core.IStructure")
                oriented=value.oriented_unit_cell;
            else
                oriented=kssolv.analysis.matgenlab.core.Structure.from_dict( ...
                    value.oriented_unit_cell);
            end
            obj=kssolv.analysis.matgenlab.core.GrainBoundary(base.lattice, ...
                base.species_and_occu,base.frac_coords, ...
                value.rotation_axis,value.rotation_angle,value.gb_plane, ...
                value.join_plane,init,value.vacuum_thickness, ...
                value.ab_shift,base.site_properties,oriented);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.core.GrainBoundary.from_dict(value);
        end
    end
end
function values=propertyStrings(input)
if ~iscell(input),values=string(input);return,end
values=strings(size(input));
for index=1:numel(input)
    item=input{index};
    while iscell(item)&&isscalar(item),item=item{1};end
    if isempty(item)
        values(index)=missing;
    else
        values(index)=string(item);
    end
end
end
function options=parseOptions(options,varargin)
for index=1:2:numel(varargin)
    name=char(string(varargin{index}));
    if isfield(options,name),options.(name)=varargin{index+1};end
end
end
