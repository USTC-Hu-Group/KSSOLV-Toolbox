%#ok<*ISCL>
classdef AbstractGeometry < handle
    %ABSTRACTGEOMETRY Centered representation of a local geometry.
    properties
        bare_centre=[]
        bare_points_without_centre double=zeros(0,3)
        bare_points_with_centre double=zeros(0,3)
        centroid_without_centre (1,3) double=[0 0 0]
        centroid_with_centre (1,3) double=[0 0 0]
        centering_type (1,1) string="standard"
        include_central_site_in_centroid (1,1) logical=false
        bare_central_site=[]
        centre (1,3) double=[0 0 0]
        central_site (1,3) double=[0 0 0]
        coords double=zeros(0,3)
        bare_coords double=zeros(0,3)
    end
    properties (Dependent)
        cn
        coordination_number
    end
    properties (Access=private)
        points_wcs_csc_value double=zeros(0,3)
        points_wocs_csc_value double=zeros(0,3)
        points_wcs_ctwcc_value double=zeros(0,3)
        points_wocs_ctwcc_value double=zeros(0,3)
        points_wcs_ctwocc_value double=zeros(0,3)
        points_wocs_ctwocc_value double=zeros(0,3)
    end
    methods
        function obj=AbstractGeometry(varargin)
            opts=parseOptions(varargin{:});
            points=double(opts.bare_coords);
            if isempty(points),points=zeros(0,3);end
            central=opts.central_site;
            if ~isempty(central),central=reshape(double(central),1,3);end
            obj.bare_centre=central;
            obj.bare_central_site=central;
            obj.bare_coords=points;
            obj.bare_points_without_centre=points;
            n=size(points,1);
            if isempty(central)
                obj.bare_points_with_centre=points;
                obj.centroid_with_centre=meanOrZero(points);
                centralForSubtract=[0 0 0];
            else
                obj.bare_points_with_centre=[central;points];
                obj.centroid_with_centre=mean(obj.bare_points_with_centre,1);
                centralForSubtract=central;
            end
            obj.centroid_without_centre=meanOrZero(points);
            obj.points_wcs_csc_value= ...
                obj.bare_points_with_centre-centralForSubtract;
            obj.points_wocs_csc_value=points-centralForSubtract;
            obj.points_wcs_ctwcc_value= ...
                obj.bare_points_with_centre-obj.centroid_with_centre;
            obj.points_wocs_ctwcc_value=points-obj.centroid_with_centre;
            obj.points_wcs_ctwocc_value= ...
                obj.bare_points_with_centre-obj.centroid_without_centre;
            obj.points_wocs_ctwocc_value=points-obj.centroid_without_centre;
            obj.centering_type=string(opts.centering_type);
            obj.include_central_site_in_centroid= ...
                logical(opts.include_central_site_in_centroid);
            if obj.centering_type=="standard"
                if n<5
                    validateCentral(obj,central,false);
                    centre=central;
                elseif obj.include_central_site_in_centroid
                    validateCentral(obj,central,true);
                    centre=obj.centroid_with_centre;
                else
                    centre=obj.centroid_without_centre;
                end
            elseif obj.centering_type=="central_site"
                validateCentral(obj,central,false);
                centre=central;
            elseif obj.centering_type=="centroid"
                if obj.include_central_site_in_centroid
                    validateCentral(obj,central,true);
                    centre=obj.centroid_with_centre;
                else
                    centre=obj.centroid_without_centre;
                end
            else
                error("KSSOLV:Matgenlab:ChemEnv:CenteringType", ...
                    "Unknown centering_type '%s'.",obj.centering_type);
            end
            obj.centre=centre;
            obj.coords=points-centre;
            if isempty(central),obj.central_site=-centre;
            else,obj.central_site=central-centre;end
        end
        function value=points_wcs_csc(obj,varargin)
            value=withPermutation(obj.points_wcs_csc_value, ...
                obj.points_wocs_csc_value,varargin{:});
        end
        function value=points_wocs_csc(obj,varargin)
            value=withoutPermutation(obj.points_wocs_csc_value,varargin{:});
        end
        function value=points_wcs_ctwcc(obj,varargin)
            value=withPermutation(obj.points_wcs_ctwcc_value, ...
                obj.points_wocs_ctwcc_value,varargin{:});
        end
        function value=points_wocs_ctwcc(obj,varargin)
            value=withoutPermutation(obj.points_wocs_ctwcc_value,varargin{:});
        end
        function value=points_wcs_ctwocc(obj,varargin)
            value=withPermutation(obj.points_wcs_ctwocc_value, ...
                obj.points_wocs_ctwocc_value,varargin{:});
        end
        function value=points_wocs_ctwocc(obj,varargin)
            value=withoutPermutation(obj.points_wocs_ctwocc_value,varargin{:});
        end
        function value=get.cn(obj),value=size(obj.coords,1);end
        function value=get.coordination_number(obj),value=obj.cn;end
        function value=char(obj)
            value=sprintf("\nAbstract Geometry with %d points",obj.cn);
        end
    end
    methods (Static)
        function obj=from_cg(cg,varargin)
            opts=parseNamed(struct(centering_type="standard", ...
                include_central_site_in_centroid=false),varargin{:});
            obj=kssolv.analysis.matgenlab.analysis.chemenv. ...
                coordination_environments.AbstractGeometry( ...
                "central_site",cg.get_central_site(), ...
                "bare_coords",cg.points, ...
                "centering_type",opts.centering_type, ...
                "include_central_site_in_centroid", ...
                opts.include_central_site_in_centroid);
        end
    end
end
function validateCentral(obj,central,includesCentral)
if isempty(central)
    error("KSSOLV:Matgenlab:ChemEnv:MissingCentralSite", ...
        "The requested centering requires a central site.");
end
if obj.centering_type=="central_site"&&obj.include_central_site_in_centroid
    error("KSSOLV:Matgenlab:ChemEnv:CenteringConflict", ...
        "A central-site center cannot include the site in a centroid.");
end
if obj.centering_type=="standard"&&obj.cn<5&& ...
        obj.include_central_site_in_centroid&&~includesCentral
    error("KSSOLV:Matgenlab:ChemEnv:CenteringConflict", ...
        "The standard center is the central site for CN below five.");
end
end
function value=meanOrZero(points)
if isempty(points),value=[0 0 0];else,value=mean(points,1);end
end
function value=withPermutation(withCentre,withoutCentre,varargin)
perm=getPermutation(varargin{:});
if isempty(perm),value=withCentre;
else,value=[withCentre(1,:);withoutCentre(normalize(perm,size(withoutCentre,1)),:)];end
end
function value=withoutPermutation(points,varargin)
perm=getPermutation(varargin{:});
if isempty(perm),value=points;else,value=points(normalize(perm,size(points,1)),:);end
end
function value=getPermutation(varargin)
if isempty(varargin),value=[];elseif numel(varargin)==1,value=varargin{1};
else,value=parseNamed(struct(permutation=[]),varargin{:}).permutation;end
end
function value=normalize(value,n)
value=reshape(double(value),1,[]);
if any(value==0),value=value+1;end
if numel(value)~=n||any(sort(value)~=(1:n))
    error("KSSOLV:Matgenlab:ChemEnv:Permutation","Invalid permutation.");
end
end
function opts=parseOptions(varargin)
opts=parseNamed(struct(central_site=[],bare_coords=zeros(0,3), ...
    centering_type="standard", ...
    include_central_site_in_centroid=false,optimization=[]),varargin{:});
end
function opts=parseNamed(opts,varargin)
names=fieldnames(opts);pos=1;
while pos<=numel(varargin)&&~(ischar(varargin{pos})||isstring(varargin{pos}))
    opts.(names{pos})=varargin{pos};pos=pos+1;
end
for ii=pos:2:numel(varargin)
    opts.(char(string(varargin{ii})))=varargin{ii+1};
end
end
