classdef SubstitutionPredictorTransformation < ...
        kssolv.analysis.matgenlab.transformations.AbstractTransformation
    properties (SetAccess=private)
        threshold (1,1) double
        scale_volumes (1,1) logical
        kwargs (1,1) struct
    end
    methods
        function obj=SubstitutionPredictorTransformation( ...
                threshold,scaleVolumes,varargin)
            if nargin<1,threshold=.01;end
            if nargin<2,scaleVolumes=true;end
            obj.threshold=threshold;obj.scale_volumes=scaleVolumes;
            values=struct();
            for index=1:2:numel(varargin)
                values.(char(string(varargin{index})))=varargin{index+1};
            end
            obj.kwargs=values;
        end
        function result=apply_transformation(obj,structure,returnRankedList)
            if nargin<3||~returnRankedList
                error("KSSOLV:Matgenlab:SubstitutionPredictor:RankedOnly", ...
                    "SubstitutionPredictorTransformation requires a ranked list.");
            end
            lambda=[];alpha=-5;
            if isfield(obj.kwargs,"lambda_table"),lambda=obj.kwargs.lambda_table;end
            if isfield(obj.kwargs,"alpha"),alpha=obj.kwargs.alpha;end
            predictor=kssolv.analysis.matgenlab.core. ...
                SubstitutionPredictor(lambda,alpha,obj.threshold);
            predictions=predictor.composition_prediction( ...
                structure.composition,false);
            if isempty(predictions),result=cell(1,0);return,end
            [~,order]=sort([predictions.probability],"descend");
            predictions=predictions(order);
            result=cell(1,numel(predictions));
            for index=1:numel(predictions)
                transformation=kssolv.analysis.matgenlab.transformations. ...
                    SubstitutionTransformation( ...
                    predictions(index).substitutions);
                candidate=transformation.apply_transformation(structure);
                result{index}=struct( ...
                    "structure",candidate, ...
                    "probability",predictions(index).probability, ...
                    "threshold",obj.threshold, ...
                    "substitutions", ...
                    {predictions(index).substitutions});
            end
            count=kssolv.analysis.matgenlab.transformations.internal.Utils. ...
                rankedCount(returnRankedList);
            result=result(1:min(count,numel(result)));
        end
    end
    methods (Access=protected)
        function value=oneToMany(~),value=true;end
    end
    methods (Static)
        function obj=from_dict(value)
            args={};
            names=fieldnames(value.kwargs);
            for index=1:numel(names)
                args(end+(1:2))={names{index},value.kwargs.(names{index})}; %#ok<AGROW>
            end
            obj=kssolv.analysis.matgenlab.transformations. ...
                SubstitutionPredictorTransformation(value.threshold, ...
                value.scale_volumes,args{:});
        end
        function obj=fromDict(value),obj= ...
                kssolv.analysis.matgenlab.transformations. ...
                SubstitutionPredictorTransformation.from_dict(value);end
    end
end
