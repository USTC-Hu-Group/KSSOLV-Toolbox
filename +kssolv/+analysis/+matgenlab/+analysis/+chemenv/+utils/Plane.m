classdef Plane < handle
    %PLANE Normalized representation of ax+by+cz+d=0.
    %#ok<*ALIGN>
    properties
        normal_vector (1,3) double
        p1 (1,3) double
        p2 (1,3) double
        p3 (1,3) double
        vector_to_origin (1,3) double
        e1=[]
        e2=[]
        e3 (1,3) double
    end
    properties (Access=private)
        coefficients_ (1,4) double
        crosses_origin_ (1,1) logical
    end
    properties (Dependent,SetAccess=private)
        coefficients
        abcd
        a
        b
        c
        d
        distance_to_origin
        crosses_origin
    end
    methods
        function obj=Plane(coefficients,varargin)
            if nargin==0,return,end
            normal=double(reshape(coefficients(1:3),1,[]));
            normalNorm=norm(normal);
            if normalNorm==0
                error("KSSOLV:Matgenlab:ChemEnv:Plane", ...
                    "Normal vector is equal to zero.");
            end
            normal=normal/normalNorm;
            nonzero=find(abs(normal)>1e-12);
            if normal(nonzero(1))<0
                normal=-normal;offset=-double(coefficients(4))/normalNorm;
            else,offset=double(coefficients(4))/normalNorm;end
            obj.normal_vector=normal;
            obj.coefficients_=[normal,offset];
            obj.crosses_origin_=abs(offset)<=1e-7;
            [one,two,three]=pointOptions(varargin);
            if isempty(one)
                obj.init_3points(nonzero,setdiff(1:3,nonzero));
            else,obj.p1=one;obj.p2=two;obj.p3=three;end
            obj.vector_to_origin=offset*normal;obj.e3=normal;
        end
        function init_3points(obj,nonzero,zeros_)
            if numel(nonzero)==3
                obj.p1=[-obj.d/obj.a,0,0];
                obj.p2=[0,-obj.d/obj.b,0];
                obj.p3=[0,0,-obj.d/obj.c];
            elseif numel(nonzero)==2
                obj.p1=zeros(1,3);
                obj.p1(nonzero(2))=-obj.d/obj.coefficients(nonzero(2));
                obj.p2=obj.p1;obj.p2(zeros_(1))=1;
                obj.p3=zeros(1,3);
                obj.p3(nonzero(1))=-obj.d/obj.coefficients(nonzero(1));
            else
                obj.p1=zeros(1,3);
                obj.p1(nonzero(1))=-obj.d/obj.coefficients(nonzero(1));
                obj.p2=obj.p1;obj.p2(zeros_(1))=1;
                obj.p3=obj.p1;obj.p3(zeros_(2))=1;
            end
        end
        function value=is_in_plane(obj,point,tolerance)
            value=abs(dot(obj.normal_vector,point)+obj.d)<=tolerance;
        end
        function value=is_same_plane_as(obj,other)
            value=all(abs(obj.coefficients-other.coefficients)<= ...
                1e-8+1e-5*abs(other.coefficients));
        end
        function value=is_in_list(obj,list)
            if ~iscell(list),list=num2cell(list);end
            value=any(cellfun(@(plane)obj.is_same_plane_as(plane),list));
        end
        function value=indices_separate(obj,points,tolerance)
            distances_=obj.distances(points);
            inplane=find(abs(distances_)<=tolerance);
            side1=find(abs(distances_)>tolerance&distances_<0);
            side2=find(abs(distances_)>tolerance&distances_>=0);
            value={reshape(side1,1,[]),reshape(inplane,1,[]), ...
                reshape(side2,1,[])};
        end
        function value=distance_to_point(obj,point)
            value=abs(dot(obj.normal_vector,point)+obj.d);
        end
        function value=distances(obj,points)
            value=points*obj.normal_vector.'+obj.d;
            value=reshape(value,1,[]);
        end
        function [distanceValues,indices]=distances_indices_sorted( ...
                obj,points,varargin)
            sign_=false;
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1})
                    sign_=logical(varargin{2});
                else,sign_=logical(varargin{1});end
            end
            distanceValues=obj.distances(points);
            [~,indices]=sort(abs(distanceValues));
            if sign_
                column=indices(:);
                indices=[column,reshape(sign(distanceValues(column)),[],1)];
            end
        end
        function [distanceValues,indices,groups]=distances_indices_groups( ...
                obj,points,varargin)
            defaults=struct(delta=[],delta_factor=.05,sign=false);
            options=parseOptions(defaults,varargin);
            [distanceValues,indices]=obj.distances_indices_sorted(points);
            if isempty(options.delta)
                options.delta=options.delta_factor*abs(distanceValues(indices(end)));
            end
            ends=[];
            for position=1:numel(indices)
                if position==numel(indices)||abs(distanceValues(indices(position+1)))- ...
                        abs(distanceValues(indices(position)))>options.delta
                    ends(end+1)=position; %#ok<AGROW>
                end
            end
            if options.sign
                column=indices(:);
                signed=[column,reshape(sign(distanceValues(column)),[],1)];
            else,signed=indices;end
            groups=cell(1,numel(ends));start=1;
            for group=1:numel(ends)
                if options.sign,groups{group}=signed(start:ends(group),:);
                else,groups{group}=signed(start:ends(group));end
                start=ends(group)+1;
            end
            indices=signed;
        end
        function value=projectionpoints(obj,points)
            offsets=(points-obj.p1)*obj.normal_vector.';
            value=points-offsets*obj.normal_vector;
        end
        function value=orthonormal_vectors(obj)
            if isempty(obj.e1)
                difference=obj.p2-obj.p1;obj.e1=difference/norm(difference);
                obj.e2=cross(obj.e3,obj.e1);
            end
            value=[obj.e1;obj.e2;obj.e3];
        end
        function value=project_and_to2dim_ordered_indices(obj,points,varargin)
            center="mean";if ~isempty(varargin),center=varargin{1};end
            projected=obj.project_and_to2dim(points,center);
            value=kssolv.analysis.matgenlab.analysis.chemenv.utils. ...
                anticlockwise_sort_indices(projected);
        end
        function value=project_and_to2dim(obj,points,center)
            projected=obj.projectionpoints(points);
            orthogonal=obj.orthonormal_vectors();basis=orthogonal.';
            value=(projected*basis);value=value(:,1:2);
            if (ischar(center)||isstring(center))&&string(center)=="mean"
                value=value-mean(value,1);
            elseif ~isempty(center)
                projectedCenter=obj.projectionpoints(reshape(center,1,3));
                center2d=projectedCenter*basis;
                value=value-center2d(1:2);
            end
        end
        function value=fit_error(obj,points,varargin)
            fit="least_square_distance";
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1})
                    if string(varargin{1})=="fit",fit=string(varargin{2});
                    else,fit=string(varargin{1});end
                else,fit=string(varargin{1});end
            end
            if fit=="least_square_distance"
                value=obj.fit_least_square_distance_error(points);
            elseif fit=="maximum_distance"
                value=obj.fit_maximum_distance_error(points);
            else,value=[];end
        end
        function value=fit_least_square_distance_error(obj,points)
            value=sum(obj.distances(points).^2);
        end
        function value=fit_maximum_distance_error(obj,points)
            value=max(abs(obj.distances(points)));
        end
        function value=get.coefficients(obj),value=obj.coefficients_;end
        function value=get.abcd(obj),value=obj.coefficients_;end
        function value=get.a(obj),value=obj.coefficients_(1);end
        function value=get.b(obj),value=obj.coefficients_(2);end
        function value=get.c(obj),value=obj.coefficients_(3);end
        function value=get.d(obj),value=obj.coefficients_(4);end
        function value=get.distance_to_origin(obj),value=obj.d;end
        function value=get.crosses_origin(obj),value=obj.crosses_origin_;end
    end
    methods (Static)
        function obj=from_2points_and_origin(first,second)
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane. ...
                from_3points(first,second,zeros(1,3));
        end
        function obj=from_3points(first,second,third)
            normal=cross(first-third,second-third);normal=normal/norm(normal);
            nonzero=find(abs(normal)>1e-12,1);
            if normal(nonzero)<0,normal=-normal;end
            offset=-dot(normal,first);
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane( ...
                [normal,offset],first,second,third);
        end
        function obj=from_npoints(points,varargin)
            bestFit="least_square_distance";
            if ~isempty(varargin)
                if ischar(varargin{1})||isstring(varargin{1})
                    if string(varargin{1})=="best_fit"
                        bestFit=string(varargin{2});
                    else,bestFit=string(varargin{1});end
                end
            end
            if size(points,1)==2
                obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane. ...
                    from_2points_and_origin(points(1,:),points(2,:));
            elseif size(points,1)==3
                obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane. ...
                    from_3points(points(1,:),points(2,:),points(3,:));
            elseif bestFit=="least_square_distance"
                obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane. ...
                    from_npoints_least_square_distance(points);
            elseif bestFit=="maximum_distance"
                obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane. ...
                    from_npoints_maximum_distance(points);
            else
                error("KSSOLV:Matgenlab:ChemEnv:Plane", ...
                    "Cannot initialize Plane with fit '%s'.",bestFit);
            end
        end
        function obj=from_npoints_least_square_distance(points)
            center=mean(points,1);[~,singular,right]=svd(points-center,0);
            [~,index]=min(diag(singular));normal=right(:,index).';
            nonzero=find(abs(normal)>1e-12,1);
            if normal(nonzero)<0,normal=-normal;end
            offset=-dot(normal,center);
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane( ...
                [normal,offset]);
        end
        function obj=perpendicular_bisector(first,second)
            middle=.5*(first+second);normal=second-first;
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane( ...
                [normal,-dot(normal,middle)]);
        end
        function obj=from_npoints_maximum_distance(points)
            facets=convhulln(points);heights=zeros(size(facets,1),1);
            highest=zeros(size(facets,1),1);planes=cell(size(facets,1),1);
            for index=1:size(facets,1)
                facet=facets(index,:);
                planes{index}=kssolv.analysis.matgenlab.analysis.chemenv. ...
                    utils.Plane.from_3points(points(facet(1),:), ...
                    points(facet(2),:),points(facet(3),:));
                distances_=abs(planes{index}.distances(points));
                [heights(index),highest(index)]=max(distances_);
            end
            [~,index]=min(heights);plane=planes{index};
            point=points(highest(index),:);
            middle=(plane.projectionpoints(point)+point)/2;
            normal=plane.normal_vector;
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane( ...
                [normal,-dot(normal,middle)]);
        end
        function obj=from_coefficients(a,b,c,d)
            obj=kssolv.analysis.matgenlab.analysis.chemenv.utils.Plane( ...
                [a,b,c,d]);
        end
    end
end
function [first,second,third]=pointOptions(args)
first=[];second=[];third=[];
if isempty(args),return,end
if ischar(args{1})||isstring(args{1})
    for index=1:2:numel(args)
        switch string(args{index})
            case "p1",first=args{index+1};
            case "p2",second=args{index+1};
            case "p3",third=args{index+1};
        end
    end
else
    first=args{1};if numel(args)>1,second=args{2};end
    if numel(args)>2,third=args{3};end
end
end
function output=parseOptions(output,args)
names=string(fieldnames(output));
if ~isempty(args)&&(ischar(args{1})||isstring(args{1}))
    for index=1:2:numel(args)
        name=names(strcmpi(string(args{index}),names));
        output.(char(name))=args{index+1};
    end
else
    for index=1:numel(args),output.(char(names(index)))=args{index};end
end
end
