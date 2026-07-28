classdef SuperTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        transformations cell
        nstructures_per_trans (1,1) double
    end
    methods
        function obj=SuperTransformation(transformations,count)
            if nargin<2,count=1;end
            if ~iscell(transformations),transformations=num2cell(transformations);end
            obj.transformations=reshape(transformations,1,[]);
            obj.nstructures_per_trans=count;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3||~returnRankedList
                error("KSSOLV:Matgenlab:SuperTransformation:RankedOnly", ...
                    "SuperTransformation requires return_ranked_list.");
            end
            perTransformation=max(1,obj.nstructures_per_trans);
            if ~isfinite(perTransformation),perTransformation=1;end
            capacity=numel(obj.transformations)*perTransformation;
            result=cell(1,capacity);
            outputIndex=0;
            for index=1:numel(obj.transformations)
                transformation=obj.transformations{index};
                if transformation.is_one_to_many
                    values=transformation.apply_transformation( ...
                        structure,obj.nstructures_per_trans);
                    if ~iscell(values),values={struct("structure",values)};end
                    for item=1:numel(values)
                        entry=values{item};
                        if ~isstruct(entry),entry=struct("structure",entry);end
                        entry.transformation=transformation;
                        outputIndex=outputIndex+1;
                        result{outputIndex}=entry;
                    end
                else
                    outputIndex=outputIndex+1;
                    result{outputIndex}=struct( ...
                        "transformation",transformation, ...
                        "structure", ...
                        transformation.apply_transformation(structure));
                end
            end
            result=result(1:outputIndex);
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function obj=from_dict(value)
            obj=kssolv.analysis.matgenlab.transformations. ...
                SuperTransformation(value.transformations, ...
                value.nstructures_per_trans);
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                SuperTransformation.from_dict(value);end
    end
end
