classdef QuasiRRHO
    %QUASIRRHO Grimme quasi-rigid-rotor harmonic-oscillator thermochemistry.
    properties (SetAccess=private)
        temp (1,1) double
        press (1,1) double
        v0 (1,1) double
        entropy_quasiRRHO
        free_energy_quasiRRHO
        h_corrected
        entropy_ho
        free_energy_ho
    end
    methods
        function obj=QuasiRRHO(molecule,frequencies,energy, ...
                multiplicity,sigmaR,temp,press,cutoff)
            if nargin<5||isempty(sigmaR),sigmaR=1;end
            if nargin<6||isempty(temp),temp=298.15;end
            if nargin<7||isempty(press),press=101317;end
            if nargin<8||isempty(cutoff),cutoff=100;end
            obj.temp=temp;obj.press=press;obj.v0=cutoff;
            obj=obj.calculate(molecule,multiplicity,sigmaR, ...
                frequencies,energy);
        end
    end
    methods (Static)
        function obj=from_gaussian_output(output,varargin)
            frequencies=output.frequencies{end};
            if isstruct(frequencies)
                values=arrayfun(@(record)record.frequency,frequencies);
            elseif iscell(frequencies)
                values=cellfun(@(record)record.frequency,frequencies);
            else
                values=frequencies;
            end
            obj=kssolv.analysis.matgenlab.analysis.QuasiRRHO( ...
                output.final_structure,values,output.final_energy, ...
                output.spin_multiplicity,varargin{:});
        end

        function obj=from_qc_output(output,varargin)
            data=output.data;
            if data.optimization
                molecule=data.molecule_from_last_geometry;
            else
                molecule=data.initial_molecule;
            end
            obj=kssolv.analysis.matgenlab.analysis.QuasiRRHO( ...
                molecule,data.frequencies, ...
                data.SCF_energy_in_the_final_basis_set, ...
                data.multiplicity,varargin{:});
        end
    end
    methods (Access=private)
        function obj=calculate(obj,molecule,multiplicity,sigmaR, ...
                frequencies,electronicEnergy)
            kb=1.380649e-23;
            speed=29979245800;
            planck=6.62607015e-34;
            gasConstant=8.31446261815324/4.184;
            amu=1.66053906892e-27;
            hartree=4.359744722206e-18;
            avogadro=6.02214076e23;
            kcalToHartree=1000*4.184/hartree/avogadro;
            mass=0;
            for index=1:molecule.num_sites
                mass=mass+double( ...
                    molecule.sites{index}.specie.atomic_mass);
            end
            mass=mass*amu;
            frequencies=double(frequencies(:));
            vibrationTemperatures= ...
                frequencies(frequencies>0)*speed*planck/kb;
            qt=(2*pi*mass*kb*obj.temp/planck^2)^(3/2)* ...
                kb*obj.temp/obj.press;
            translationalEntropy=gasConstant*(log(qt)+5/2);
            translationalEnergy=3*gasConstant*obj.temp/2;
            electronicEntropy=gasConstant*log(multiplicity);
            [averageInertia,inertias]= ...
                kssolv.analysis.matgenlab.analysis. ...
                get_avg_mom_inertia(molecule);
            coordinates=molecule.cart_coords;
            linear=isLinear(coordinates);
            if linear
                inertia=max(inertias);
                qr=8*pi^2*inertia*kb*obj.temp/ ...
                    (sigmaR*planck^2);
                rotationalEntropy=gasConstant*(log(qr)+1);
                rotationalEnergy=gasConstant*obj.temp;
            else
                rotationalTemperatures= ...
                    planck^2./(8*pi^2*kb*inertias);
                qr=sqrt(pi)/sigmaR*obj.temp^(3/2)/ ...
                    sqrt(prod(rotationalTemperatures));
                rotationalEntropy=gasConstant*(log(qr)+3/2);
                rotationalEnergy=3*gasConstant*obj.temp/2;
            end
            vibrationEnergy=0;
            quasiEntropy=0;
            harmonicEntropy=0;
            for vibrationTemperature= ...
                    reshape(vibrationTemperatures,1,[])
                ratio=vibrationTemperature/obj.temp;
                vibrationEnergy=vibrationEnergy+ ...
                    vibrationTemperature*(1/2+1/(exp(ratio)-1));
                temporary=ratio/(exp(ratio)-1)- ...
                    log(1-exp(-ratio));
                harmonicEntropy=harmonicEntropy+temporary;
                mu=planck/(8*pi^2*vibrationTemperature*speed);
                reduced=mu*averageInertia/(mu+averageInertia);
                rotorEntropy=1/2+log(sqrt( ...
                    8*pi^3*reduced*kb*obj.temp/planck^2));
                weight=1/(1+(obj.v0/vibrationTemperature)^4);
                quasiEntropy=quasiEntropy+ ...
                    weight*temporary+(1-weight)*rotorEntropy;
            end
            quasiEntropy=quasiEntropy*gasConstant;
            harmonicEntropy=harmonicEntropy*gasConstant;
            vibrationEnergy=vibrationEnergy*gasConstant;
            totalEnergy=(translationalEnergy+rotationalEnergy+ ...
                vibrationEnergy)*kcalToHartree/1000;
            obj.h_corrected=totalEnergy+ ...
                gasConstant*obj.temp*kcalToHartree/1000;
            obj.entropy_ho=translationalEntropy+ ...
                rotationalEntropy+harmonicEntropy+electronicEntropy;
            obj.free_energy_ho=electronicEnergy+obj.h_corrected- ...
                obj.temp*obj.entropy_ho*kcalToHartree/1000;
            obj.entropy_quasiRRHO=translationalEntropy+ ...
                rotationalEntropy+quasiEntropy+electronicEntropy;
            obj.free_energy_quasiRRHO=electronicEnergy+ ...
                obj.h_corrected-obj.temp*obj.entropy_quasiRRHO* ...
                kcalToHartree/1000;
        end
    end
end

function value=isLinear(coordinates)
if size(coordinates,1)<=2,value=true;return,end
axis=coordinates(2,:)-coordinates(1,:);
value=true;
for index=2:size(coordinates,1)
    displacement=coordinates(index,:)-coordinates(1,:);
    if norm(displacement)==0,continue,end
    cosine=abs(dot(displacement,axis)/(norm(displacement)*norm(axis)));
    if abs(cosine-1)>1e-4,value=false;return,end
end
end
