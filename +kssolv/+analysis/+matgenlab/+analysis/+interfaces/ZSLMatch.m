classdef ZSLMatch
    %ZSLMATCH A coincident two-dimensional superlattice match.
    properties
        film_sl_vectors
        substrate_sl_vectors
        film_vectors
        substrate_vectors
        film_transformation
        substrate_transformation
    end
    properties (Dependent, SetAccess=private)
        match_area
        match_transformation
    end
    methods
        function obj=ZSLMatch(filmSLVectors,substrateSLVectors, ...
                filmVectors,substrateVectors,filmTransformation, ...
                substrateTransformation)
            if nargin==0,return,end
            obj.film_sl_vectors=double(filmSLVectors);
            obj.substrate_sl_vectors=double(substrateSLVectors);
            obj.film_vectors=double(filmVectors);
            obj.substrate_vectors=double(substrateVectors);
            obj.film_transformation=double(filmTransformation);
            obj.substrate_transformation=double(substrateTransformation);
        end
        function value=get.match_area(obj)
            value=kssolv.analysis.matgenlab.analysis.interfaces. ...
                vec_area(obj.film_sl_vectors(1,:), ...
                obj.film_sl_vectors(2,:));
        end
        function value=get.match_transformation(obj)
            film=[obj.film_sl_vectors;cross( ...
                obj.film_sl_vectors(1,:),obj.film_sl_vectors(2,:))];
            substrate=obj.substrate_sl_vectors;
            normal=cross(substrate(1,:),substrate(2,:));
            normal=normal*norm(film(3,:))/norm(normal);
            substrate=[substrate;normal];
            value=(film\substrate).';
        end
        function value=as_dict(obj)
            value=struct( ...
                "x_module","pymatgen.analysis.interfaces.zsl", ...
                "x_class","ZSLMatch", ...
                "film_sl_vectors",obj.film_sl_vectors, ...
                "substrate_sl_vectors",obj.substrate_sl_vectors, ...
                "film_vectors",obj.film_vectors, ...
                "substrate_vectors",obj.substrate_vectors, ...
                "film_transformation",obj.film_transformation, ...
                "substrate_transformation",obj.substrate_transformation);
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
end
