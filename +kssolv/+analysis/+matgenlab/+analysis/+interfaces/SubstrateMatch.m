classdef SubstrateMatch < ...
        kssolv.analysis.matgenlab.analysis.interfaces.ZSLMatch
    %SUBSTRATEMATCH ZSL match enriched with orientation and strain energy.
    properties
        film_miller (1,3) double = [0,0,1]
        substrate_miller (1,3) double = [0,0,1]
        strain = kssolv.analysis.matgenlab.core.Strain(zeros(3))
        von_mises_strain (1,1) double = 0
        ground_state_energy (1,1) double = 0
        elastic_energy (1,1) double = 0
    end
    properties (Dependent, SetAccess=private)
        total_energy
    end
    methods
        function obj=SubstrateMatch(match,filmMiller, ...
                substrateMiller,strain,groundStateEnergy,elasticEnergy)
            obj@kssolv.analysis.matgenlab.analysis.interfaces.ZSLMatch();
            if nargin==0,return,end
            obj.film_sl_vectors=match.film_sl_vectors;
            obj.substrate_sl_vectors=match.substrate_sl_vectors;
            obj.film_vectors=match.film_vectors;
            obj.substrate_vectors=match.substrate_vectors;
            obj.film_transformation=match.film_transformation;
            obj.substrate_transformation=match.substrate_transformation;
            obj.film_miller=reshape(double(filmMiller),1,3);
            obj.substrate_miller=reshape(double(substrateMiller),1,3);
            obj.strain=strain;
            obj.von_mises_strain=strain.von_mises_strain;
            obj.ground_state_energy=groundStateEnergy;
            obj.elastic_energy=elasticEnergy;
        end
        function value=get.total_energy(obj)
            value=obj.ground_state_energy+obj.elastic_energy;
        end
        function value=as_dict(obj)
            value=as_dict@kssolv.analysis.matgenlab. ...
                analysis.interfaces.ZSLMatch(obj);
            value.x_class="SubstrateMatch";
            value.film_miller=obj.film_miller;
            value.substrate_miller=obj.substrate_miller;
            value.strain=obj.strain.asDict();
            value.von_mises_strain=obj.von_mises_strain;
            value.ground_state_energy=obj.ground_state_energy;
            value.elastic_energy=obj.elastic_energy;
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
    methods (Static)
        function obj=from_zsl(match,film,filmMiller, ...
                substrateMiller,elasticityTensor,groundStateEnergy)
            if nargin<5,elasticityTensor=[];end
            if nargin<6||isempty(groundStateEnergy),groundStateEnergy=0;end
            deformation=kssolv.analysis.matgenlab.core.Deformation( ...
                match.match_transformation);
            strain=deformation.green_lagrange_strain;
            if exist("kssolv.analysis.matgenlab.core.SlabGenerator", ...
                    "class")==8
                generator=kssolv.analysis.matgenlab.core.SlabGenerator( ...
                    film,filmMiller,20,15,"primitive",false);
                slab=generator.get_slab();
                strain=strain.convert_to_ieee( ...
                    slab.oriented_unit_cell,false);
            else
                strain=strain.convert_to_ieee(film,false);
            end
            if isempty(elasticityTensor)
                elasticEnergy=0;
            else
                density=elasticityTensor.energy_density(strain);
                elasticEnergy=film.volume*density/film.num_sites;
            end
            obj=kssolv.analysis.matgenlab.analysis.interfaces. ...
                SubstrateMatch(match,filmMiller,substrateMiller, ...
                strain,groundStateEnergy,elasticEnergy);
        end
    end
end
