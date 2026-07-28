classdef EwaldSummation < handle
    %EWALDSUMMATION Electrostatic energy of a periodic array of charges.

    properties (Constant)
        CONV_FACT=14.399645468667815
    end
    properties (Access=private)
        struct_
        charged_ logical
        vol_ double
        compute_forces_ logical
        acc_factor_ double
        eta_ double
        sqrt_eta_ double
        rmax_ double
        gmax_ double
        oxi_states_ double
        coords_ double
        initialized_ logical=false
        recip_=[]
        real_=[]
        point_=[]
        forces_=[]
        charged_cell_energy_ double
    end
    properties (Dependent,SetAccess=private)
        reciprocal_space_energy
        reciprocal_space_energy_matrix
        real_space_energy
        real_space_energy_matrix
        point_energy
        point_energy_matrix
        total_energy
        total_energy_matrix
        forces
        eta
    end
    methods
        function obj=EwaldSummation(structure,varargin)
            options=struct(real_space_cut=[],recip_space_cut=[],eta=[], ...
                acc_factor=12,w=1/sqrt(2),compute_forces=false);
            names=fieldnames(options);pos=1;ii=1;
            while ii<=numel(varargin)
                if (ischar(varargin{ii})||isstring(varargin{ii}))&& ...
                        any(strcmpi(string(varargin{ii}),string(names)))
                    key=names{strcmpi(string(varargin{ii}),string(names))};
                    options.(key)=varargin{ii+1};ii=ii+2;
                else
                    options.(names{pos})=varargin{ii};pos=pos+1;ii=ii+1;
                end
            end
            real_space_cut=options.real_space_cut;
            recip_space_cut=options.recip_space_cut;eta=options.eta;
            acc_factor=options.acc_factor;w=options.w;
            compute_forces=options.compute_forces;
            obj.struct_=structure;
            obj.vol_=structure.volume;obj.compute_forces_=logical(compute_forces);
            obj.acc_factor_=double(acc_factor);
            if isempty(eta)||eta==0
                obj.eta_=(structure.num_sites*w/obj.vol_^2)^(1/3)*pi;
            else
                obj.eta_=double(eta);
            end
            obj.sqrt_eta_=sqrt(obj.eta_);
            accf=sqrt(log(10^obj.acc_factor_));
            if isempty(real_space_cut)||real_space_cut==0
                obj.rmax_=accf/obj.sqrt_eta_;
            else
                obj.rmax_=double(real_space_cut);
            end
            if isempty(recip_space_cut)||recip_space_cut==0
                obj.gmax_=2*obj.sqrt_eta_*accf;
            else
                obj.gmax_=double(recip_space_cut);
            end
            obj.oxi_states_=zeros(1,structure.num_sites);
            for index=1:structure.num_sites
                obj.oxi_states_(index)= ...
                    kssolv.analysis.matgenlab.core. ...
                    compute_average_oxidation_state(structure(index));
            end
            cellCharge=sum(obj.oxi_states_);
            obj.charged_=abs(cellCharge)>1e-8;
            obj.coords_=structure.cart_coords;
            obj.charged_cell_energy_=-obj.CONV_FACT/2*pi/structure.volume/ ...
                obj.eta_*cellCharge^2;
        end

        function value=compute_partial_energy(obj,removed_indices)
            matrix=obj.total_energy_matrix;
            indices=obj.matlabIndices(removed_indices);
            matrix(indices,:)=0;matrix(:,indices)=0;value=sum(matrix,"all");
        end
        function value=compute_sub_structure(obj,sub_structure,tol)
            if nargin<3,tol=1e-3;end
            matrix=obj.total_energy_matrix;matches=cell(1,0);
            for ii=1:obj.struct_.num_sites
                matching=[];
                for jj=1:sub_structure.num_sites
                    difference=mod(abs(obj.struct_(ii).frac_coords- ...
                        sub_structure(jj).frac_coords),1);
                    if all(difference<tol|difference>1-tol)
                        matching=sub_structure(jj);break
                    end
                end
                if ~isempty(matching)
                    newCharge=kssolv.analysis.matgenlab.core. ...
                        compute_average_oxidation_state(matching);
                    scale=newCharge/obj.oxi_states_(ii);
                    matches{end+1}=matching; %#ok<AGROW>
                else
                    scale=0;
                end
                matrix(ii,:)=matrix(ii,:)*scale;
                matrix(:,ii)=matrix(:,ii)*scale;
            end
            if numel(matches)~=sub_structure.num_sites
                error("KSSOLV:Matgenlab:Ewald:MissingSites", ...
                    "Missing sites in Ewald substructure.");
            end
            value=sum(matrix,"all");
        end

        function value=get.reciprocal_space_energy(obj)
            obj.initialize();value=sum(obj.recip_,"all");
        end
        function value=get.reciprocal_space_energy_matrix(obj)
            obj.initialize();value=obj.recip_;
        end
        function value=get.real_space_energy(obj)
            obj.initialize();value=sum(obj.real_,"all");
        end
        function value=get.real_space_energy_matrix(obj)
            obj.initialize();value=obj.real_;
        end
        function value=get.point_energy(obj)
            obj.initialize();value=sum(obj.point_);
        end
        function value=get.point_energy_matrix(obj)
            obj.initialize();value=obj.point_;
        end
        function value=get.total_energy(obj)
            obj.initialize();value=sum(obj.recip_,"all")+sum(obj.real_,"all")+ ...
                sum(obj.point_)+obj.charged_cell_energy_;
        end
        function value=get.total_energy_matrix(obj)
            obj.initialize();value=obj.recip_+obj.real_;
            value(1:size(value,1)+1:end)= ...
                value(1:size(value,1)+1:end)+obj.point_;
        end
        function value=get.forces(obj)
            obj.initialize();
            if ~obj.compute_forces_
                error("KSSOLV:Matgenlab:Ewald:ForcesNotComputed", ...
                    "Forces are available only if compute_forces is true.");
            end
            value=obj.forces_;
        end
        function value=get.eta(obj),value=obj.eta_;end
        function value=get_site_energy(obj,site_index)
            obj.initialize();index=obj.matlabIndices(site_index);
            value=sum(obj.recip_(:,index))+sum(obj.real_(:,index))+obj.point_(index);
        end
        function data=as_dict(obj,varargin)
            reciprocal=obj.recip_;realSpace=obj.real_;
            point=obj.point_;forceValues=obj.forces_;
            if isempty(reciprocal),reciprocal=NaN;end
            if isempty(realSpace),realSpace=NaN;end
            if isempty(point),point=NaN;end
            if isempty(forceValues),forceValues=NaN;end
            data=struct(x_module="pymatgen.core.ewald",x_class="EwaldSummation", ...
                structure=obj.struct_.as_dict(), ...
                compute_forces=obj.compute_forces_,eta=obj.eta_, ...
                acc_factor=obj.acc_factor_,real_space_cut=obj.rmax_, ...
                recip_space_cut=obj.gmax_,x_recip=reciprocal, ...
                x_real=realSpace,x_point=point,x_forces=forceValues);
        end
        function data=asDict(obj,varargin),data=obj.as_dict(varargin{:});end
        function text=char(obj)
            text=sprintf("Real = %.15g\nReciprocal = %.15g\n" + ...
                "Point = %.15g\nTotal = %.15g",obj.real_space_energy, ...
                obj.reciprocal_space_energy,obj.point_energy,obj.total_energy);
        end
    end
    methods (Access=private)
        function initialize(obj)
            if obj.initialized_,return,end
            [obj.recip_,recipForces]=obj.calcReciprocal();
            [obj.real_,obj.point_,realForces]=obj.calcRealAndPoint();
            if obj.compute_forces_,obj.forces_=recipForces+realForces;end
            obj.initialized_=true;
        end
        function [energy,forces]=calcReciprocal(obj)
            n=obj.struct_.num_sites;prefactor=2*pi/obj.vol_;
            reciprocal=obj.struct_.lattice.reciprocal_lattice;
            [fractional,distances]=reciprocal.get_points_in_sphere( ...
                [0,0,0],[0,0,0],obj.gmax_,zip_results=false);
            fractional=fractional(distances~=0,:);
            gs=reciprocal.get_cartesian_coords(fractional);
            g2=sum(gs.^2,2);weights=exp(-g2/(4*obj.eta_))./g2;
            phases=gs*obj.coords_.';cosines=cos(phases);sines=sin(phases);
            charges=obj.oxi_states_;
            % Direct cosine form is algebraically identical to pymatgen's
            % factorized U/V implementation and is easier to audit.
            weightedCos=cosines.*weights;
            weightedSin=sines.*weights;
            pairSum=weightedCos.'*cosines+weightedSin.'*sines;
            energy=prefactor*obj.CONV_FACT* ...
                (charges(:)*charges(:).').*pairSum;
            forces=zeros(n,3);
            if obj.compute_forces_
                realS=cosines*charges(:);imagS=sines*charges(:);
                amplitudes=2*weights.*( ...
                    realS.*sines-imagS.*cosines);
                forces=prefactor*(charges(:).*(amplitudes.'*gs))*obj.CONV_FACT;
            end
        end
        function [energy,point,forces]=calcRealAndPoint(obj)
            lattice=obj.struct_.lattice;fractional=obj.struct_.frac_coords;
            n=obj.struct_.num_sites;energy=zeros(n);forces=zeros(n,3);
            charges=obj.oxi_states_;
            point=-(charges.^2)*sqrt(obj.eta_/pi)*obj.CONV_FACT;
            forcePrefactor=2*obj.sqrt_eta_/sqrt(pi);
            for ii=1:n
                [near,distance,indices]=lattice.get_points_in_sphere( ...
                    fractional,obj.coords_(ii,:),obj.rmax_,zip_results=false);
                keep=distance>1e-8;near=near(keep,:);distance=distance(keep);
                indices=indices(keep);
                if isempty(distance),continue,end
                qi=charges(ii);qj=charges(indices);
                complement=erfc(obj.sqrt_eta_*distance);
                contributions=complement.*qi.*qj(:)./distance;
                for kk=1:numel(indices)
                    energy(indices(kk),ii)=energy(indices(kk),ii)+contributions(kk);
                end
                if obj.compute_forces_
                    cartesian=lattice.get_cartesian_coords(near);
                    difference=obj.coords_(ii,:)-cartesian;
                    factor=qj(:)./(distance.^3).*(complement+ ...
                        forcePrefactor*distance.*exp(-obj.eta_*distance.^2));
                    forces(ii,:)=sum(factor.*difference*qi*obj.CONV_FACT,1);
                end
            end
            energy=energy*.5*obj.CONV_FACT;
        end
        function indices=matlabIndices(~,indices)
            % Ewald site methods use MATLAB's native one-based indexing.
            indices=double(indices);
            if any(indices<1)||any(indices~=fix(indices))
                error("KSSOLV:Matgenlab:Ewald:Index", ...
                    "Site indices must be positive integers.");
            end
        end
    end
    methods (Static)
        function obj=from_dict(data,varargin)
            structure=data.structure;
            if ~isa(structure,"kssolv.analysis.matgenlab.core.Structure")
                structure=kssolv.analysis.matgenlab.core.Structure.from_dict(structure);
            end
            obj=kssolv.analysis.matgenlab.core.EwaldSummation( ...
                structure,data.real_space_cut,data.recip_space_cut,data.eta, ...
                data.acc_factor,1/sqrt(2),data.compute_forces);
            hasCache=isfield(data,"x_recip")&&~isempty(data.x_recip)&& ...
                ~(isscalar(data.x_recip)&&isnan(data.x_recip));
            if hasCache
                obj.recip_=data.x_recip;obj.real_=data.x_real;
                obj.point_=reshape(data.x_point,1,[]);
                if isscalar(data.x_forces)&&isnan(data.x_forces)
                    obj.forces_=[];
                else
                    obj.forces_=data.x_forces;
                end
                obj.initialized_=true;
            end
        end
        function obj=fromDict(data,varargin)
            obj=kssolv.analysis.matgenlab.core.EwaldSummation.from_dict(data,varargin{:});
        end
    end
end
