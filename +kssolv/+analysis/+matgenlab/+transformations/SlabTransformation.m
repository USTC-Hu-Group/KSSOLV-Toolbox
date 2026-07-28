classdef SlabTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        miller_index (1,3) double
        min_slab_size (1,1) double
        min_vacuum_size (1,1) double
        lll_reduce (1,1) logical
        center_slab (1,1) logical
        in_unit_planes (1,1) logical
        primitive (1,1) logical
        max_normal_search
        shift (1,1) double
        tol (1,1) double
    end
    methods
        function obj=SlabTransformation(hkl,slabSize,vacuumSize, ...
                lllReduce,centerSlab,inUnitPlanes,primitive, ...
                maxNormalSearch,shift,tol)
            if nargin<4,lllReduce=false;end
            if nargin<5,centerSlab=false;end
            if nargin<6,inUnitPlanes=false;end
            if nargin<7,primitive=true;end
            if nargin<8,maxNormalSearch=[];end
            if nargin<9,shift=0;end
            if nargin<10,tol=.1;end
            hkl=reshape(double(hkl),1,3);
            divisor=gcd(gcd(abs(round(hkl(1))),abs(round(hkl(2)))), ...
                abs(round(hkl(3))));
            if divisor>0,hkl=hkl/divisor;end
            obj.miller_index=hkl;obj.min_slab_size=slabSize;
            obj.min_vacuum_size=vacuumSize;obj.lll_reduce=lllReduce;
            obj.center_slab=centerSlab;obj.in_unit_planes=inUnitPlanes;
            obj.primitive=primitive;obj.max_normal_search=maxNormalSearch;
            obj.shift=shift;obj.tol=tol;
        end
        function result=apply_transformation(obj,structure,varargin)
            generator=kssolv.analysis.matgenlab.core.SlabGenerator( ...
                structure,obj.miller_index,obj.min_slab_size, ...
                obj.min_vacuum_size,lll_reduce=obj.lll_reduce, ...
                center_slab=obj.center_slab, ...
                in_unit_planes=obj.in_unit_planes, ...
                primitive=obj.primitive, ...
                max_normal_search=obj.max_normal_search);
            result=generator.get_slab(obj.shift,obj.tol);
        end
    end
    methods (Access=private)
        function transform=orientationMatrix(obj,lattice)
            h=obj.miller_index;
            if all(h==0)
                error("KSSOLV:Matgenlab:Slab:Miller", ...
                    "Miller index cannot be zero.");
            end
            normal=h/lattice;normal=normal/norm(normal);
            basis=eye(3);inPlane=cell(1,0);nonOrth=[];
            for index=1:3
                if h(index)==0
                    inPlane{end+1}=basis(index,:); %#ok<AGROW>
                else
                    projection=abs(dot(normal,lattice(index,:)))/ ...
                        norm(lattice(index,:));
                    nonOrth(end+1,:)=[index,projection]; %#ok<AGROW>
                end
            end
            [~,which]=max(nonOrth(:,2));cIndex=nonOrth(which,1);
            if size(nonOrth,1)>1
                multiple=1;
                for index=1:size(nonOrth,1)
                    multiple=lcm(multiple,abs(round( ...
                        h(nonOrth(index,1)))));
                end
                pairs=nchoosek(1:size(nonOrth,1),2);
                for pair=1:size(pairs,1)
                    vector=zeros(1,3);
                    first=nonOrth(pairs(pair,1),1);
                    second=nonOrth(pairs(pair,2),1);
                    vector(first)=-round(multiple/h(first));
                    vector(second)=round(multiple/h(second));
                    inPlane{end+1}=vector; %#ok<AGROW>
                    if numel(inPlane)==2,break,end
                end
            end
            if isempty(obj.max_normal_search)
                cVector=basis(cIndex,:);
            else
                bestScore=[-Inf,Inf];cVector=[];
                search=obj.max_normal_search;
                for a=-search:search
                    for b=-search:search
                        for c=-search:search
                            vector=[a,b,c];
                            if ~any(vector)|| ...
                                    abs(det([inPlane{1};inPlane{2};vector]))<1e-8
                                continue
                            end
                            cart=vector*lattice;
                            cosine=abs(dot(cart,normal)/norm(cart));
                            score=[cosine,-norm(cart)];
                            if score(1)>bestScore(1)+1e-12|| ...
                                    (abs(score(1)-bestScore(1))<1e-12&& ...
                                    score(2)>bestScore(2))
                                bestScore=score;cVector=vector;
                            end
                        end
                    end
                end
            end
            transform=round([inPlane{1};inPlane{2};cVector]);
            if det(transform)<0,transform=-transform;end
            for row=1:3
                divisor=gcd(gcd(abs(transform(row,1)), ...
                    abs(transform(row,2))),abs(transform(row,3)));
                if divisor>1,transform(row,:)=transform(row,:)/divisor;end
            end
        end
        function properties=repeatProperties(~,properties,layers)
            names=fieldnames(properties);
            for index=1:numel(names)
                values=properties.(names{index});
                if iscell(values),properties.(names{index})=repmat(values,1,layers);
                elseif size(values,1)>1
                    properties.(names{index})=repmat(values,layers,1);
                else
                    properties.(names{index})=repmat(values,1,layers);
                end
            end
        end
        function reduced=reduceSurfaceCell(obj,structure,slabMatrix,normal)
            candidates=[slabMatrix(1,:),norm(slabMatrix(1,:)); ...
                slabMatrix(2,:),norm(slabMatrix(2,:))];
            fractional=structure.frac_coords;
            for first=1:structure.num_sites-1
                for second=first+1:structure.num_sites
                    if ~structure(first).species.almost_equals( ...
                            structure(second).species),continue,end
                    delta=fractional(second,:)-fractional(first,:);
                    delta=delta-round(delta);
                    vector=delta*slabMatrix;
                    if norm(vector)>obj.tol&& ...
                            abs(dot(vector,normal))<obj.tol&& ...
                            obj.isTranslation(structure,delta,obj.tol)
                        candidates(end+1,:)=[vector,norm(vector)]; %#ok<AGROW>
                    end
                end
            end
            [~,order]=sort(candidates(:,4));candidates=candidates(order,:);
            firstVector=candidates(1,1:3);secondVector=[];
            for index=2:size(candidates,1)
                if norm(cross(firstVector,candidates(index,1:3)))>obj.tol
                    secondVector=candidates(index,1:3);break
                end
            end
            if isempty(secondVector),reduced=structure;return,end
            matrix=[firstVector;secondVector;slabMatrix(3,:)];
            if abs(det(matrix))>=abs(det(slabMatrix))-1e-8
                reduced=structure;return
            end
            % Match Slab/Lattice.from_parameters' conventional choice:
            % both in-plane vectors form obtuse angles with c when the
            % equivalent sign choice is available.
            if dot(matrix(1,:),matrix(3,:))>0,matrix(1,:)=-matrix(1,:);end
            if dot(matrix(2,:),matrix(3,:))>0,matrix(2,:)=-matrix(2,:);end
            cartesian=structure.cart_coords;
            transformed=mod(cartesian/matrix,1);
            keep=true(1,structure.num_sites);
            for index=1:structure.num_sites
                if ~keep(index),continue,end
                for later=index+1:structure.num_sites
                    if ~keep(later)||~structure(index).species. ...
                            almost_equals(structure(later).species),continue,end
                    delta=transformed(index,:)-transformed(later,:);
                    delta=delta-round(delta);
                    if norm(delta*matrix)<obj.tol,keep(later)=false;end
                end
            end
            properties=structure.site_properties;
            names=fieldnames(properties);
            for index=1:numel(names)
                values=properties.(names{index});
                if iscell(values),properties.(names{index})=values(keep);
                elseif size(values,1)==structure.num_sites
                    properties.(names{index})=values(keep,:);
                else
                    properties.(names{index})=values(:,keep);
                end
            end
            species=structure.species_and_occu;
            reduced=kssolv.analysis.matgenlab.core.Structure( ...
                kssolv.analysis.matgenlab.core.Lattice(matrix), ...
                species(keep),transformed(keep,:), ...
                site_properties=properties);
        end
        function value=isTranslation(~,structure,delta,tolerance)
            fractional=structure.frac_coords;
            value=true;
            for index=1:structure.num_sites
                target=mod(fractional(index,:)+delta,1);
                found=false;
                for candidate=1:structure.num_sites
                    if ~structure(index).species.almost_equals( ...
                            structure(candidate).species),continue,end
                    difference=target-fractional(candidate,:);
                    difference=difference-round(difference);
                    if norm(difference*structure.lattice.matrix)<tolerance
                        found=true;break
                    end
                end
                if ~found,value=false;return,end
            end
        end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                SlabTransformation(value.miller_index,value.min_slab_size, ...
                value.min_vacuum_size,value.lll_reduce,value.center_slab, ...
                value.in_unit_planes,value.primitive, ...
                value.max_normal_search,value.shift,value.tol);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                SlabTransformation.from_dict(value);end
    end
end
