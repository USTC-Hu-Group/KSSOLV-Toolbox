classdef PartialRemoveSpecieTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (Constant)
        ALGO_FAST=0
        ALGO_COMPLETE=1
        ALGO_BEST_FIRST=2
        ALGO_ENUMERATE=3
    end
    properties (SetAccess=private)
        specie_to_remove
        fraction_to_remove (1,1) double
        algo (1,1) double
    end
    methods
        function obj=PartialRemoveSpecieTransformation(species,fraction,algo)
            if nargin<3,algo=obj.ALGO_FAST;end
            obj.specie_to_remove=species;
            obj.fraction_to_remove=fraction;
            obj.algo=algo;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3,returnRankedList=false;end
            target=kssolv.analysis.matgenlab.core.getElSp( ...
                obj.specie_to_remove);
            indices=[];
            for index=1:structure.num_sites
                if structure(index).is_ordered&&structure(index).specie==target
                    indices(end+1)=index; %#ok<AGROW>
                end
            end
            transformation=kssolv.analysis.matgenlab.transformations. ...
                PartialRemoveSitesTransformation({indices}, ...
                obj.fraction_to_remove,obj.algo);
            result=transformation.apply_transformation( ...
                structure,returnRankedList);
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                PartialRemoveSpecieTransformation(value.specie_to_remove, ...
                value.fraction_to_remove,value.algo);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                PartialRemoveSpecieTransformation.from_dict(value);end
    end
end
