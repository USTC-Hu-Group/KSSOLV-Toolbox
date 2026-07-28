classdef QuasiHarmonicDebyeApprox
    %QUASIHARMONICDEBYEAPPROX Quasi-harmonic Debye thermodynamics.
    properties
        energies (1,:) double
        volumes (1,:) double
        structure
        temperature_min (1,1) double = 300
        temperature_max (1,1) double = 300
        temperature_step (1,1) double = 100
        eos_name (1,1) string = "vinet"
        pressure (1,1) double = 0
        poisson (1,1) double = .25
        use_mie_gruneisen (1,1) logical = false
        anharmonic_contribution (1,1) logical = false
        mass (1,1) double
        natoms (1,1) double
        avg_mass (1,1) double
        kb (1,1) double = 8.617333262e-5
        hbar (1,1) double = 6.582119569e-16
        gpa_to_ev_ang (1,1) double = 1/160.21766208
        gibbs_free_energy (1,:) double = zeros(1,0)
        temperatures (1,:) double = zeros(1,0)
        optimum_volumes (1,:) double = zeros(1,0)
        eos
        ev_eos_fit
        bulk_modulus (1,1) double
    end
    methods
        function obj=QuasiHarmonicDebyeApprox( ...
                energies,volumes,structure,tMin,tStep,tMax,eosName, ...
                pressure,poisson,useMieGruneisen,anharmonicContribution)
            if nargin<4||isempty(tMin),tMin=300;end
            if nargin<5||isempty(tStep),tStep=100;end
            if nargin<6||isempty(tMax),tMax=300;end
            if nargin<7||isempty(eosName),eosName="vinet";end
            if nargin<8||isempty(pressure),pressure=0;end
            if nargin<9||isempty(poisson),poisson=.25;end
            if nargin<10||isempty(useMieGruneisen)
                useMieGruneisen=false;
            end
            if nargin<11||isempty(anharmonicContribution)
                anharmonicContribution=false;
            end
            if useMieGruneisen&&anharmonicContribution
                error("KSSOLV:Matgenlab:QuasiHarmonic:Circular", ...
                    "Mie-Gruneisen and anharmonic contributions cannot " + ...
                    "be enabled together.");
            end
            obj.energies=reshape(double(energies),1,[]);
            obj.volumes=reshape(double(volumes),1,[]);
            if numel(obj.energies)~=numel(obj.volumes)
                error("KSSOLV:Matgenlab:QuasiHarmonic:DataSize", ...
                    "energies and volumes must have equal length.");
            end
            obj.structure=structure;
            obj.temperature_min=tMin;obj.temperature_step=tStep;
            obj.temperature_max=tMax;obj.eos_name=string(eosName);
            obj.pressure=pressure;obj.poisson=poisson;
            obj.use_mie_gruneisen=logical(useMieGruneisen);
            obj.anharmonic_contribution=logical(anharmonicContribution);
            species=structure.species;obj.mass=0;
            for index=1:numel(species)
                if iscell(species),specie=species{index};
                else,specie=species(index);end
                obj.mass=obj.mass+specie.atomic_mass;
            end
            obj.natoms=structure.composition.num_atoms;
            obj.avg_mass=1.66053906892e-27*obj.mass/obj.natoms;
            obj.eos=kssolv.analysis.matgenlab.analysis.EOS(obj.eos_name);
            obj.ev_eos_fit=obj.eos.fit(obj.volumes,obj.energies);
            obj.bulk_modulus=obj.ev_eos_fit.b0_GPa;
            obj=obj.optimize_gibbs_free_energy();
        end
        function obj=optimize_gibbs_free_energy(obj)
            count=ceil((obj.temperature_max-obj.temperature_min)/ ...
                obj.temperature_step)+1;
            values=linspace(obj.temperature_min,obj.temperature_max,count);
            obj.gibbs_free_energy=nan(1,count);
            obj.temperatures=values;
            obj.optimum_volumes=nan(1,count);
            for index=1:count
                try
                    [energy,volume]=obj.optimizer(values(index));
                    obj.gibbs_free_energy(index)=energy;
                    obj.optimum_volumes(index)=volume;
                catch exception
                    if count<=1,rethrow(exception);end
                end
            end
        end
        function [energy,volume]=optimizer(obj,temperature)
            gibbs=zeros(size(obj.volumes));
            for index=1:numel(obj.volumes)
                gibbs(index)=obj.energies(index)+ ...
                    obj.pressure*obj.volumes(index)*obj.gpa_to_ev_ang+ ...
                    obj.vibrational_free_energy( ...
                    temperature,obj.volumes(index));
            end
            fit=obj.eos.fit(obj.volumes,gibbs);
            [~,minimum]=min(fit.energies);guess=fit.volumes(minimum);
            options=optimset("Display","off","TolX",1e-12, ...
                "TolFun",1e-12,"MaxFunEvals",10000,"MaxIter",10000);
            [volume,energy,exitFlag]=fminsearch( ...
                @(value)fit.func(value),guess,options);
            if exitFlag<=0
                error("KSSOLV:Matgenlab:QuasiHarmonic:Optimization", ...
                    "Gibbs free-energy minimization failed.");
            end
        end
        function value=vibrational_free_energy(obj,temperature,volume)
            y=obj.debye_temperature(volume)/temperature;
            value=obj.kb*obj.natoms*temperature* ...
                (9/8*y+3*log(1-exp(-y))- ...
                kssolv.analysis.matgenlab.analysis. ...
                QuasiHarmonicDebyeApprox.debye_integral(y));
        end
        function value=vibrational_internal_energy( ...
                obj,temperature,volume)
            y=obj.debye_temperature(volume)/temperature;
            value=obj.kb*obj.natoms*temperature* ...
                (9/8*y+3*kssolv.analysis.matgenlab.analysis. ...
                QuasiHarmonicDebyeApprox.debye_integral(y));
        end
        function value=debye_temperature(obj,volume)
            term1=(2/3*(1+obj.poisson)/(1-2*obj.poisson))^1.5;
            term2=(1/3*(1+obj.poisson)/(1-obj.poisson))^1.5;
            fSigma=(3/(2*term1+term2))^(1/3);
            value=2.9772e-11*(volume/obj.natoms)^(-1/6)* ...
                fSigma*sqrt(obj.bulk_modulus/obj.avg_mass);
            if obj.anharmonic_contribution
                gamma=obj.gruneisen_parameter(0,obj.ev_eos_fit.v0);
                value=value*(obj.ev_eos_fit.v0/volume)^gamma;
            end
        end
        function gamma=gruneisen_parameter(obj,temperature,volume)
            if isa(obj.ev_eos_fit, ...
                    "kssolv.analysis.matgenlab.analysis.PolynomialEOS")
                polynomial=obj.ev_eos_fit.eos_params;
                first=polyval(polyder(polynomial),volume);
                second=polyval(polyder(polyder(polynomial)),volume);
                third=polyval( ...
                    polyder(polyder(polyder(polynomial))),volume);
            else
                first=finiteDerivative(@(x)obj.ev_eos_fit.func(x), ...
                    volume,1,3,1e-3);
                second=finiteDerivative(@(x)obj.ev_eos_fit.func(x), ...
                    volume,2,5,1e-3);
                third=finiteDerivative(@(x)obj.ev_eos_fit.func(x), ...
                    volume,3,7,1e-3);
            end
            if obj.use_mie_gruneisen
                gamma=obj.gpa_to_ev_ang*volume* ...
                    (obj.pressure+first/obj.gpa_to_ev_ang)/ ...
                    obj.vibrational_internal_energy(temperature,volume);
                return
            end
            derivativeBulk=second+third*volume;
            bulkEvAng=obj.ev_eos_fit.b0_GPa*obj.gpa_to_ev_ang;
            gamma=-(1/6+.5*volume*derivativeBulk/bulkEvAng);
        end
        function conductivity=thermal_conductivity( ...
                obj,temperature,volume)
            gamma=obj.gruneisen_parameter(temperature,volume);
            theta=obj.debye_temperature(volume);
            acousticTheta=theta*obj.natoms^(-1/3);
            prefactor=(.849*3*4^(1/3))/(20*pi^3);
            prefactor=prefactor*(obj.kb/obj.hbar)^3*obj.avg_mass;
            conductivity=prefactor/(gamma^2-.514*gamma+.228)* ...
                acousticTheta^2*volume^(1/3)*1e-10;
        end
        function summary=get_summary_dict(obj)
            summary=struct("pressure",obj.pressure, ...
                "poisson",obj.poisson,"mass",obj.mass, ...
                "natoms",round(obj.natoms), ...
                "bulk_modulus",obj.bulk_modulus, ...
                "gibbs_free_energy",obj.gibbs_free_energy, ...
                "temperatures",obj.temperatures, ...
                "optimum_volumes",obj.optimum_volumes, ...
                "debye_temperature",zeros(size(obj.temperatures)), ...
                "gruneisen_parameter",zeros(size(obj.temperatures)), ...
                "thermal_conductivity",zeros(size(obj.temperatures)));
            for index=1:numel(obj.temperatures)
                volume=obj.optimum_volumes(index);
                temperature=obj.temperatures(index);
                summary.debye_temperature(index)= ...
                    obj.debye_temperature(volume);
                summary.gruneisen_parameter(index)= ...
                    obj.gruneisen_parameter(temperature,volume);
                summary.thermal_conductivity(index)= ...
                    obj.thermal_conductivity(temperature,volume);
            end
        end
    end
    methods (Static)
        function value=debye_integral(y)
            y=double(y);factor=3/y^3;
            if y<155
                integralValue=integral(@(x)x.^3./expm1(x),0,y, ...
                    "AbsTol",1e-12,"RelTol",1e-12);
                value=integralValue*factor;
            else
                value=6.493939*factor;
            end
        end
    end
end

function value=finiteDerivative(functionHandle,point,order,count,step)
half=floor(count/2);x=(-half:half).';
matrix=zeros(count,count);
for power=0:count-1,matrix(:,power+1)=x.^power;end
inverse=inv(matrix);
weights=factorial(order)*inverse(order+1,:);
samples=zeros(count,1);
for index=1:count
    samples(index)=functionHandle(point+x(index)*step);
end
value=(weights*samples)/step^order;
end
