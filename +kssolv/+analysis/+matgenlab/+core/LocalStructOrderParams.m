classdef LocalStructOrderParams < handle
    %#ok<*ALIGN>
    %LOCALSTRUCTORDERPARAMS Local coordination and orientational order parameters.
    %
    % This is a MATLAB implementation of pymatgen.core.local_env's
    % LocalStructOrderParams. Site indices follow MATLAB's one-based convention.

    properties (SetAccess=private)
        types (1,:) string
        parameters cell
        cutoff (1,1) double
        voronoi_neighbors (1,1) logical
        num_ops (1,1) double
        last_nneigh (1,1) double = -1
    end
    properties (Access=private)
        stored_thetas double = []
        stored_phis double = []
    end

    methods
        function obj=LocalStructOrderParams(types,varargin)
            supported=["cn","sgl_bd","bent","tri_plan","tri_plan_max", ...
                "reg_tri","sq_plan","sq_plan_max","pent_plan", ...
                "pent_plan_max","sq","tet","tet_max","tri_pyr","sq_pyr", ...
                "sq_pyr_legacy","tri_bipyr","sq_bipyr","oct","oct_legacy", ...
                "pent_pyr","hex_pyr","pent_bipyr","hex_bipyr","T","cuboct", ...
                "cuboct_max","see_saw_rect","bcc","q2","q4","q6","oct_max", ...
                "hex_plan_max","sq_face_cap_trig_pris"];
            obj.types=reshape(string(types),1,[]);
            unknown=setdiff(obj.types,supported);
            if ~isempty(unknown)
                error("KSSOLV:Matgenlab:LocalStructOrderParams:Type", ...
                    "Unknown order parameter type (%s).",unknown(1));
            end
            options=struct(parameters=[],cutoff=-10);
            options=parseOptions(options,varargin);
            obj.num_ops=numel(obj.types);
            obj.parameters=cell(1,obj.num_ops);
            supplied=options.parameters;
            for ii=1:obj.num_ops
                obj.parameters{ii}=defaultParameters(obj.types(ii));
                if ~isempty(supplied)
                    if iscell(supplied),candidate=supplied{ii};
                    elseif obj.num_ops==1,candidate=supplied;
                    else,candidate=[];end
                    if ~isempty(candidate),obj.parameters{ii}=candidate;end
                end
            end
            if options.cutoff==0
                error("KSSOLV:Matgenlab:LocalStructOrderParams:Cutoff", ...
                    "Cutoff radius is zero.");
            end
            obj.voronoi_neighbors=options.cutoff<0;
            obj.cutoff=abs(double(options.cutoff));
        end

        function value=get_type(obj,index)
            validateIndex(obj,index);value=obj.types(index);
        end
        function value=get_parameters(obj,index)
            validateIndex(obj,index);value=obj.parameters{index};
        end
        function obj=compute_trigonometric_terms(obj,thetas,phis)
            if numel(thetas)~=numel(phis)
                error("KSSOLV:Matgenlab:LocalStructOrderParams:Angles", ...
                    "Lists of polar and azimuthal angles must have equal length.");
            end
            obj.stored_thetas=reshape(double(thetas),1,[]);
            obj.stored_phis=reshape(double(phis),1,[]);
        end
        function value=get_q2(obj,varargin),value=obj.getQ(2,varargin{:});end
        function value=get_q4(obj,varargin),value=obj.getQ(4,varargin{:});end
        function value=get_q6(obj,varargin),value=obj.getQ(6,varargin{:});end

        function [ops,obj]=get_order_parameters(obj,structure,n,varargin)
            options=struct(indices_neighs=[],tol=0,target_spec=[]);
            options=parseOptions(options,varargin);
            count=siteCount(structure);
            if n<1,error("KSSOLV:Matgenlab:LocalStructOrderParams:Index", ...
                    "Site index smaller than one.");end
            if n>count,error("KSSOLV:Matgenlab:LocalStructOrderParams:Index", ...
                    "Site index beyond maximum.");end
            if options.tol<0,error("KSSOLV:Matgenlab:LocalStructOrderParams:Tolerance", ...
                    "Negative tolerance for weighted solid angle.");end
            center=getSite(structure,n);
            neighsites={};
            if ~isempty(options.indices_neighs)
                ids=reshape(options.indices_neighs,1,[]);
                if any(ids<1|ids>count)
                    error("KSSOLV:Matgenlab:LocalStructOrderParams:NeighborIndex", ...
                        "Neighbor site index beyond maximum.");
                end
                neighsites=arrayfun(@(ii)getSite(structure,ii),ids, ...
                    "UniformOutput",false);
            elseif obj.voronoi_neighbors
                if ~isa(structure,"kssolv.analysis.matgenlab.core.Structure")
                    error("KSSOLV:Matgenlab:LocalStructOrderParams:Structure", ...
                        "Voronoi neighbor discovery requires a Structure.");
                end
                finder=kssolv.analysis.matgenlab.core.VoronoiNN( ...
                    "tol",options.tol,"targets",options.target_spec);
                neighsites=finder.get_nn(structure,n);
            else
                if isa(structure,"kssolv.analysis.matgenlab.core.Structure")
                    candidates=structure.get_sites_in_sphere(center.coords,obj.cutoff);
                    for ii=1:numel(candidates)
                        site=candidates{ii};
                        if site.nn_distance<1e-12,continue,end
                        if matchesTarget(site,options.target_spec)
                            neighsites{end+1}=site; %#ok<AGROW>
                        end
                    end
                else
                    for ii=1:count
                        if ii==n,continue,end
                        site=getSite(structure,ii);
                        if norm(site.coords-center.coords)<=obj.cutoff && ...
                                matchesTarget(site,options.target_spec)
                            neighsites{end+1}=site; %#ok<AGROW>
                        end
                    end
                end
            end
            nneigh=numel(neighsites);obj.last_nneigh=nneigh;
            vectors=zeros(nneigh,3);dist=zeros(1,nneigh);
            for jj=1:nneigh
                vectors(jj,:)=neighsites{jj}.coords-center.coords;
                dist(jj)=norm(vectors(jj,:));
            end
            unit=vectors./max(dist.',realmin);
            ops=nan(1,obj.num_ops);

            % Coordination, single-bond and bond-orientational parameters.
            for tt=1:obj.num_ops
                typ=obj.types(tt);param=obj.parameters{tt};
                switch typ
                    case "cn",ops(tt)=nneigh/param.norm;
                    case "sgl_bd"
                        ordered=sort(dist);
                        if isscalar(ordered),ops(tt)=1;
                        elseif numel(ordered)>1,ops(tt)=1-ordered(1)/ordered(2);end
                    case "q2",if nneigh>0,ops(tt)=steinhardt(unit,2);end
                    case "q4",if nneigh>0,ops(tt)=steinhardt(unit,4);end
                    case "q6",if nneigh>0,ops(tt)=steinhardt(unit,6);end
                end
            end

            geomTypes=["bent","tri_plan","tri_plan_max","pent_plan", ...
                "pent_plan_max","tet","tet_max","T","tri_pyr","sq_pyr", ...
                "pent_pyr","hex_pyr","sq_plan","sq_plan_max","oct", ...
                "oct_legacy","oct_max","see_saw_rect","tri_bipyr", ...
                "sq_bipyr","pent_bipyr","hex_bipyr","bcc","cuboct", ...
                "cuboct_max","hex_plan_max","sq_pyr_legacy", ...
                "sq_face_cap_trig_pris"];
            if nneigh>1 && any(ismember(obj.types,geomTypes))
                [q,norms]=obj.peters(unit);
                averageTypes=["tri_plan","tet","bent","sq_plan","oct", ...
                    "oct_legacy","cuboct","pent_plan"];
                maximumTypes=["T","tri_pyr","see_saw_rect","sq_pyr", ...
                    "tri_bipyr","sq_bipyr","pent_pyr","hex_pyr", ...
                    "pent_bipyr","hex_bipyr","oct_max","tri_plan_max", ...
                    "tet_max","sq_plan_max","pent_plan_max","cuboct_max", ...
                    "hex_plan_max","sq_face_cap_trig_pris"];
                for tt=1:obj.num_ops
                    typ=obj.types(tt);
                    if any(typ==averageTypes)
                        den=sum(norms{tt},"all");
                        if den>1e-12,ops(tt)=sum(q{tt},"all")/den;end
                    elseif any(typ==maximumTypes)
                        normalized=q{tt}./max(norms{tt},realmin);
                        normalized(norms{tt}<=1e-12)=0;
                        ops(tt)=max(normalized,[],"all");
                    elseif typ=="bcc" && nneigh>3
                        ops(tt)=sum(q{tt},"all")/(.5*nneigh*(6+(nneigh-2)*(nneigh-3)));
                    elseif typ=="sq_pyr_legacy"
                        normalized=q{tt}./max(norms{tt},realmin);
                        normalized(norms{tt}<=1e-12)=0;
                        p=obj.parameters{tt};dmean=mean(dist);
                        radial=mean(exp(-.5*(p.distance_width*(dist-dmean)).^2));
                        ops(tt)=radial*max(normalized,[],"all");
                    end
                end
            end

            % Neighbor-neighbor-distance order parameters.
            if any(obj.types=="reg_tri"|obj.types=="sq")
                pairDistances=[];
                for jj=1:nneigh-1
                    for kk=jj+1:nneigh
                        pairDistances(end+1)=norm(vectors(kk,:)-vectors(jj,:)); %#ok<AGROW>
                    end
                end
                angles=[];
                for jj=1:nneigh-1
                    for kk=jj+1:nneigh
                        angles(end+1)=acos(clamp(dot(unit(jj,:),unit(kk,:)))); %#ok<AGROW>
                    end
                end
                angles=sort(angles);
                h=norm(mean(vectors,1));
                if isempty(pairDistances),side=0;diagonalHalf=0;
                else,side=min(pairDistances);diagonalHalf=max(pairDistances)/2;end
                for tt=1:obj.num_ops
                    if obj.types(tt)=="reg_tri"||obj.types(tt)=="sq"
                        if nneigh<3,continue,end
                        p=obj.parameters{tt};
                        if obj.types(tt)=="reg_tri"
                            target=2*asin(clamp(side/(2*sqrt(h^2+ ...
                                (side/(2*cos(pi/6)))^2))));nmax=3;
                        else
                            target=2*asin(clamp(side/(2*sqrt(h^2+diagonalHalf^2))));
                            nmax=4;
                        end
                        ops(tt)=prod(exp(-.5*((angles(1:min([nneigh,nmax,numel(angles)]))- ...
                            target)*p.angle_width).^2));
                    end
                end
            end
        end
    end

    methods (Access=private)
        function value=getQ(obj,l,varargin)
            if nargin>2 && ~isempty(varargin{1})
                thetas=varargin{1};phis=varargin{2};
            else,thetas=obj.stored_thetas;phis=obj.stored_phis;end
            if numel(thetas)~=numel(phis)
                error("KSSOLV:Matgenlab:LocalStructOrderParams:Angles", ...
                    "Lists of polar and azimuthal angles must have equal length.");
            end
            vectors=[sin(thetas(:)).*cos(phis(:)), ...
                sin(thetas(:)).*sin(phis(:)),cos(thetas(:))];
            value=steinhardt(vectors,l);
        end

        function [q,norms]=peters(obj,unit)
            nneigh=size(unit,1);q=cell(1,obj.num_ops);norms=cell(1,obj.num_ops);
            for tt=1:obj.num_ops
                q{tt}=zeros(nneigh,max(nneigh-1,1));
                norms{tt}=zeros(nneigh,max(nneigh-1,1));
            end
            ipi=1/pi;facBcc=exp(.5);small=1e-12;
            for jj=1:nneigh
                zaxis=unit(jj,:);kc=0;
                for kk=1:nneigh
                    if jj==kk,continue,end
                    kc=kc+1;
                    thetaK=acos(clamp(dot(zaxis,unit(kk,:))));
                    xaxis=unit(kk,:)-dot(unit(kk,:),zaxis)*zaxis;
                    nx=norm(xaxis);validX=nx>=small;
                    if validX,xaxis=xaxis/nx;yaxis=cross(zaxis,xaxis);
                    else,yaxis=[0,0,0];end
                    gaussianK=zeros(1,obj.num_ops);
                    for tt=1:obj.num_ops
                        typ=obj.types(tt);p=obj.parameters{tt};
                        if typ=="bent"||typ=="sq_pyr_legacy"
                            a=p.IGW_TA*(thetaK*ipi-p.TA);
                            q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a);
                            norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                        elseif any(typ==["tri_plan","tri_plan_max","tet","tet_max"])
                            a=p.IGW_TA*(thetaK*ipi-p.TA);
                            gaussianK(tt)=exp(-.5*a*a);
                            if endsWith(typ,"_max")
                                q{tt}(jj,kc)=q{tt}(jj,kc)+gaussianK(tt);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            end
                        elseif any(typ==["T","tri_pyr","sq_pyr","pent_pyr","hex_pyr"])
                            a=p.IGW_EP*(thetaK*ipi-.5);
                            q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a);
                            norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                        elseif any(typ==["sq_plan","oct","oct_legacy","cuboct","cuboct_max"])
                            if thetaK>=p.min_SPP
                                a=p.IGW_SPP*(thetaK*ipi-1);
                                q{tt}(jj,kc)=q{tt}(jj,kc)+p.w_SPP*exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+p.w_SPP;
                            end
                        elseif any(typ==["see_saw_rect","tri_bipyr","sq_bipyr", ...
                                "pent_bipyr","hex_bipyr","oct_max","sq_plan_max","hex_plan_max"])
                            if thetaK<p.min_SPP
                                if typ=="hex_plan_max"
                                    a=p.IGW_TA*(abs(thetaK*ipi-.5)-p.TA);
                                else,a=p.IGW_EP*(thetaK*ipi-.5);end
                                q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            end
                        elseif typ=="pent_plan"||typ=="pent_plan_max"
                            target=.8;if thetaK<=p.TA*pi,target=.4;end
                            a=p.IGW_TA*(thetaK*ipi-target);
                            gaussianK(tt)=exp(-.5*a*a);
                            if typ=="pent_plan_max"
                                q{tt}(jj,kc)=q{tt}(jj,kc)+gaussianK(tt);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            end
                        elseif typ=="bcc" && jj<kk && thetaK>=p.min_SPP
                            a=p.IGW_SPP*(thetaK*ipi-1);
                            q{tt}(jj,kc)=q{tt}(jj,kc)+p.w_SPP*exp(-.5*a*a);
                            norms{tt}(jj,kc)=norms{tt}(jj,kc)+p.w_SPP;
                        elseif typ=="sq_face_cap_trig_pris" && thetaK<p.TA3
                            a=p.IGW_TA1*(thetaK*ipi-p.TA1);
                            q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a);
                            norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                        end
                    end
                    if ~validX,continue,end
                    for mm=1:nneigh
                        if mm==jj||mm==kk,continue,end
                        thetaM=acos(clamp(dot(zaxis,unit(mm,:))));
                        x2=unit(mm,:)-dot(unit(mm,:),zaxis)*zaxis;
                        n2=norm(x2);validX2=n2>=small;
                        if validX2
                            x2=x2/n2;phi=acos(clamp(dot(x2,xaxis)));
                            phi2=atan2(dot(x2,yaxis),dot(x2,xaxis));
                        else,phi=0;phi2=0;end
                        for tt=1:obj.num_ops
                            typ=obj.types(tt);p=obj.parameters{tt};
                            if any(typ==["tri_bipyr","sq_bipyr","pent_bipyr", ...
                                    "hex_bipyr","oct_max","sq_plan_max", ...
                                    "hex_plan_max","see_saw_rect"]) && thetaM>=p.min_SPP
                                a=p.IGW_SPP*(thetaM*ipi-1);
                                q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            end
                            if ~validX2,continue,end
                            if any(typ==["tri_plan","tri_plan_max","tet","tet_max"])
                                a=p.IGW_TA*(thetaM*ipi-p.TA);
                                angular=cos(p.fac_AA*phi)^p.exp_cos_AA;
                                base=gaussianK(tt);if endsWith(typ,"_max"),base=1;end
                                q{tt}(jj,kc)=q{tt}(jj,kc)+base*exp(-.5*a*a)*angular;
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif typ=="pent_plan"||typ=="pent_plan_max"
                                target=.8;if thetaM<=p.TA*pi,target=.4;end
                                a=p.IGW_TA*(thetaM*ipi-target);
                                base=gaussianK(tt);if typ=="pent_plan_max",base=1;end
                                q{tt}(jj,kc)=q{tt}(jj,kc)+ ...
                                    base*exp(-.5*a*a)*cos(phi)^2;
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif any(typ==["T","tri_pyr","sq_pyr","pent_pyr","hex_pyr"])
                                angular=cos(p.fac_AA*phi)^p.exp_cos_AA;
                                a=p.IGW_EP*(thetaM*ipi-.5);
                                q{tt}(jj,kc)=q{tt}(jj,kc)+angular*exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif any(typ==["sq_plan","oct","oct_legacy"]) && ...
                                    thetaK<p.min_SPP && thetaM<p.min_SPP
                                angular=cos(p.fac_AA*phi)^p.exp_cos_AA;
                                a=p.IGW_EP*(thetaM*ipi-.5);
                                contribution=angular*exp(-.5*a*a);
                                if typ=="oct_legacy"
                                    contribution=contribution-angular*p.legacy6*p.legacy7;
                                end
                                q{tt}(jj,kc)=q{tt}(jj,kc)+contribution;
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif any(typ==["tri_bipyr","sq_bipyr","pent_bipyr", ...
                                    "hex_bipyr","oct_max","sq_plan_max","hex_plan_max"]) && ...
                                    thetaK<p.min_SPP && thetaM<p.min_SPP
                                angular=cos(p.fac_AA*phi)^p.exp_cos_AA;
                                if typ=="hex_plan_max"
                                    a=p.IGW_TA*(abs(thetaM*ipi-.5)-p.TA);
                                else,a=p.IGW_EP*(thetaM*ipi-.5);end
                                q{tt}(jj,kc)=q{tt}(jj,kc)+angular*exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif typ=="bcc" && jj<kk && thetaK<p.min_SPP
                                factor=1;if thetaK<=pi/2,factor=-1;end
                                a=(thetaM-pi/2)/asin(1/3);
                                q{tt}(jj,kc)=q{tt}(jj,kc)+ ...
                                    factor*cos(3*phi)*facBcc*a*exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif typ=="see_saw_rect" && thetaM<p.min_SPP && ...
                                    thetaK<p.min_SPP && phi<.75*pi
                                angular=cos(p.fac_AA*phi)^p.exp_cos_AA;
                                a=p.IGW_EP*(thetaM*ipi-.5);
                                q{tt}(jj,kc)=q{tt}(jj,kc)+angular*exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            elseif any(typ==["cuboct","cuboct_max"]) && ...
                                    thetaM<p.min_SPP && thetaK>p.angle4 && thetaK<p.angle2
                                if thetaM>p.angle4 && thetaM<p.angle2
                                    a=p.width5*(thetaM*ipi-.5);
                                    q{tt}(jj,kc)=q{tt}(jj,kc)+cos(phi)^2*exp(-.5*a*a);
                                    norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                                elseif thetaM<p.angle4
                                    a=.0556*(cos(phi-.5*pi)-.81649658);
                                    b=p.width6*(thetaM*ipi-1/3);
                                    q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a)*exp(-.5*b*b);
                                    norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                                elseif thetaM>p.angle2
                                    a=.0556*(cos(phi-.5*pi)-.81649658);
                                    b=p.width6*(thetaM*ipi-2/3);
                                    q{tt}(jj,kc)=q{tt}(jj,kc)+exp(-.5*a*a)*exp(-.5*b*b);
                                    norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                                end
                            elseif typ=="sq_face_cap_trig_pris" && thetaK<p.TA3
                                if thetaM<p.TA3
                                    angular=cos(p.fac_AA1*phi2)^p.exp_cos_AA1;
                                    a=p.IGW_TA1*(thetaM*ipi-p.TA1);
                                else
                                    angular=cos(p.fac_AA2*(phi2+p.shift_AA2))^p.exp_cos_AA2;
                                    a=p.IGW_TA2*(thetaM*ipi-p.TA2);
                                end
                                q{tt}(jj,kc)=q{tt}(jj,kc)+angular*exp(-.5*a*a);
                                norms{tt}(jj,kc)=norms{tt}(jj,kc)+1;
                            end
                        end
                    end
                end
            end
        end
        function validateIndex(obj,index)
            if index<1||index>obj.num_ops||index~=fix(index)
                error("KSSOLV:Matgenlab:LocalStructOrderParams:Index", ...
                    "Order parameter index is out of bounds.");
            end
        end
    end
end

function value=steinhardt(unit,l)
n=size(unit,1);
if n==0,value=NaN;return,end
cosines=max(-1,min(1,unit*unit.'));
switch l
    case 2,p=(3*cosines.^2-1)/2;
    case 4,p=(35*cosines.^4-30*cosines.^2+3)/8;
    case 6,p=(231*cosines.^6-315*cosines.^4+105*cosines.^2-5)/16;
end
value=sqrt(max(0,sum(p,"all")/n^2));
end

function p=defaultParameters(typ)
switch typ
    case "cn",p=struct(norm=1);
    case "bent",p=struct(TA=1,IGW_TA=8.667);
    case "T",p=struct(IGW_EP=15.5,fac_AA=1,exp_cos_AA=2);
    case "see_saw_rect",p=struct(min_SPP=2.356194490192345,IGW_SPP=11.5, ...
        IGW_EP=27,fac_AA=2,exp_cos_AA=2);
    case "tet_max",p=struct(IGW_TA=18.5,TA=.6081734479693927,fac_AA=1.5,exp_cos_AA=2);
    case "tet",p=struct(IGW_TA=15,TA=.6081734479693927,fac_AA=1.5,exp_cos_AA=2);
    case "oct_max",p=struct(min_SPP=2.356194490192345,IGW_SPP=15, ...
        IGW_EP=18,w_SPP=1,fac_AA=2,exp_cos_AA=2);
    case "oct",p=struct(min_SPP=2.792526803190927,IGW_SPP=15, ...
        IGW_EP=18,w_SPP=3,fac_AA=2,exp_cos_AA=2);
    case "bcc",p=struct(min_SPP=2.5261129449194057,IGW_SPP=15,w_SPP=6);
    case "tri_plan",p=struct(IGW_TA=13.5,TA=.66666666667,fac_AA=1,exp_cos_AA=2);
    case "tri_plan_max",p=struct(IGW_TA=17.5,TA=.66666666667,fac_AA=1,exp_cos_AA=2);
    case "sq_plan",p=struct(min_SPP=2.792526803190927,IGW_SPP=15, ...
        IGW_EP=18,w_SPP=1,fac_AA=1,exp_cos_AA=2);
    case "sq_plan_max",p=struct(min_SPP=2.356194490192345,IGW_SPP=13.5, ...
        IGW_EP=17.7,w_SPP=1,fac_AA=1,exp_cos_AA=2);
    case "pent_plan",p=struct(TA=.6,IGW_TA=18);
    case "pent_plan_max",p=struct(TA=.6,IGW_TA=19.333);
    case "tri_pyr",p=struct(IGW_EP=15.5,fac_AA=1.5,exp_cos_AA=2);
    case "sq_pyr",p=struct(IGW_EP=14.9,fac_AA=2,exp_cos_AA=2);
    case "pent_pyr",p=struct(IGW_EP=13.8,fac_AA=2.5,exp_cos_AA=2);
    case "hex_pyr",p=struct(IGW_EP=12.5,fac_AA=3,exp_cos_AA=2);
    case "tri_bipyr",p=struct(min_SPP=2.356194490192345,IGW_SPP=12, ...
        IGW_EP=16.6,fac_AA=1.5,exp_cos_AA=2,w_SPP=1);
    case "sq_bipyr",p=struct(min_SPP=2.356194490192345,IGW_SPP=15, ...
        IGW_EP=18,fac_AA=2,exp_cos_AA=2,w_SPP=1);
    case "pent_bipyr",p=struct(min_SPP=2.356194490192345,IGW_SPP=12.5, ...
        IGW_EP=14.75,fac_AA=2.5,exp_cos_AA=2,w_SPP=1);
    case "hex_bipyr",p=struct(min_SPP=2.356194490192345,IGW_SPP=14.1, ...
        IGW_EP=13.6,fac_AA=3,exp_cos_AA=2,w_SPP=1);
    case "cuboct",p=struct(min_SPP=2.792526803190927,IGW_SPP=15, ...
        angle2=1.8325957145940461,w_SPP=1.8,angle4=1.3089969389957472, ...
        width5=18,width6=18);
    case "cuboct_max",p=struct(min_SPP=2.792526803190927,IGW_SPP=28.75, ...
        angle2=1.8325957145940461,w_SPP=1.8,angle4=1.3089969389957472, ...
        width5=25.5,width6=31.25);
    case "reg_tri",p=struct(angle_width=45);
    case "sq",p=struct(angle_width=30);
    case "oct_legacy",p=struct(min_SPP=2.792526803190927,IGW_SPP=15, ...
        IGW_EP=18,w_SPP=3,fac_AA=2,exp_cos_AA=2,legacy6=.25,legacy7=1.33333333);
    case "sq_pyr_legacy",p=struct(TA=.5,IGW_TA=30,distance_width=10);
    case "hex_plan_max",p=struct(min_SPP=2.6179938779914944,IGW_SPP=7.5, ...
        w_SPP=1,fac_AA=1,exp_cos_AA=2,IGW_TA=25,TA=.16666667,IGW_EP=1);
    case "sq_face_cap_trig_pris"
        p=struct(TA1=.37662414278557504,TA2=.7728144741714951, ...
            TA3=1.8055339573923717,IGW_TA1=15.5,IGW_TA2=13, ...
            fac_AA1=2,exp_cos_AA1=2,fac_AA2=1, ...
            shift_AA2=-.7853981633974483,exp_cos_AA2=2);
    otherwise,p=[];
end
end

function value=clamp(value),value=max(-1,min(1,value));end
function value=siteCount(structure)
if iscell(structure),value=numel(structure);else,value=structure.num_sites;end
end
function site=getSite(structure,index)
if iscell(structure),site=structure{index};else,site=structure(index);end
end
function tf=matchesTarget(site,target)
if isempty(target),tf=true;return,end
target=kssolv.analysis.matgenlab.core.getElSp(target);
tf=site.specie.symbol==target.symbol;
end
function output=parseOptions(output,input)
names=fieldnames(output);ii=1;position=1;
while ii<=numel(input)
    if (ischar(input{ii})||isstring(input{ii}))&& ...
            any(strcmpi(string(input{ii}),string(names)))
        key=names{strcmpi(string(input{ii}),string(names))};
        output.(key)=input{ii+1};ii=ii+2;
    else
        output.(names{position})=input{ii};position=position+1;ii=ii+1;
    end
end
end
